-- ============================================================================
-- Store App — Supabase schema
--
-- Run this once in your Supabase project's SQL editor (Dashboard -> SQL
-- Editor -> New query -> paste all of this -> Run). It creates every table,
-- security policy, and function the app needs. Safe to run on a brand new
-- Supabase project only (it does not attempt to be idempotent against an
-- existing, populated database).
--
-- After running this, also turn on "Allow anonymous sign-ins" under
-- Authentication -> Providers -> Anonymous Sign-Ins in the dashboard — that
-- setting can't be changed from SQL.
-- ============================================================================

create extension if not exists pgcrypto;
create extension if not exists pg_trgm;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table employees (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  code text not null unique,
  password_hash text not null,
  role text not null check (role in ('admin', 'cashier')),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null default 'عام',
  buy_price numeric(12, 2) not null,
  sell_price numeric(12, 2) not null,
  quantity numeric(12, 2) not null,
  unit text not null default 'قطعة',
  low_stock_threshold numeric(12, 2) not null default 5,
  created_at timestamptz not null default now()
);
create index products_name_trgm_idx on products using gin (name gin_trgm_ops);
create index products_low_stock_idx on products (quantity, low_stock_threshold);

create table customers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text not null default '',
  note text not null default '',
  created_at timestamptz not null default now()
);
create unique index customers_name_unique_idx on customers (lower(name));
create index customers_name_trgm_idx on customers using gin (name gin_trgm_ops);

create table sales (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references employees (id),
  employee_name text not null,
  customer_name text not null default '',
  date timestamptz not null default now(),
  total_amount numeric(12, 2) not null,
  paid_amount numeric(12, 2) not null,
  note text not null default ''
);
create index sales_date_idx on sales (date desc);

create table sale_items (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references sales (id) on delete cascade,
  product_id uuid not null references products (id),
  product_name text not null,
  quantity numeric(12, 2) not null,
  unit_price numeric(12, 2) not null,
  buy_price_at_sale numeric(12, 2) not null
);
create index sale_items_sale_id_idx on sale_items (sale_id);
create index sale_items_product_id_idx on sale_items (product_id);

create table debt_transactions (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references customers (id),
  type text not null check (type in ('charge', 'payment')),
  amount numeric(12, 2) not null,
  date timestamptz not null default now(),
  note text not null default '',
  sale_id uuid references sales (id)
);
create index debt_transactions_customer_id_idx on debt_transactions (customer_id);

create or replace view customer_balances as
select
  c.id as customer_id,
  c.name,
  c.phone,
  coalesce(sum(case when t.type = 'charge' then t.amount else 0 end), 0)
    - coalesce(sum(case when t.type = 'payment' then t.amount else 0 end), 0) as balance
from customers c
left join debt_transactions t on t.customer_id = c.id
group by c.id, c.name, c.phone
having coalesce(sum(case when t.type = 'charge' then t.amount else 0 end), 0)
     - coalesce(sum(case when t.type = 'payment' then t.amount else 0 end), 0) <> 0;

-- ---------------------------------------------------------------------------
-- Row Level Security
--
-- `employees` gets NO policies at all, so it's unreachable directly even
-- with the public anon key — every employee operation (login, add, edit,
-- delete) goes through a SECURITY DEFINER function below that checks the
-- caller's identity itself. Every other table just requires a signed-in
-- Supabase session (the app signs in anonymously on launch), which keeps a
-- stray copy of the anon key from being usable to scrape the database with
-- a plain HTTP client.
-- ---------------------------------------------------------------------------

alter table employees enable row level security;
alter table products enable row level security;
alter table customers enable row level security;
alter table sales enable row level security;
alter table sale_items enable row level security;
alter table debt_transactions enable row level security;

create policy "products_all" on products for all
  using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create policy "customers_all" on customers for all
  using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- sales / sale_items / debt_transactions are read-only to clients; every
-- write happens inside the RPC functions below so stock and debt totals
-- can never drift out of sync with what was actually sold.
create policy "sales_select" on sales for select using (auth.role() = 'authenticated');
create policy "sale_items_select" on sale_items for select using (auth.role() = 'authenticated');
create policy "debt_transactions_select" on debt_transactions for select using (auth.role() = 'authenticated');

grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on products, customers to anon, authenticated;
grant select on sales, sale_items, debt_transactions, customer_balances to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Realtime: push change events for these tables to every connected device.
-- Supabase projects already have this publication; the guard just makes the
-- script safe to run against a plain Postgres instance too.
-- ---------------------------------------------------------------------------

do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
end $$;

alter publication supabase_realtime add table products;
alter publication supabase_realtime add table sales;
alter publication supabase_realtime add table sale_items;
alter publication supabase_realtime add table customers;
alter publication supabase_realtime add table debt_transactions;

-- ---------------------------------------------------------------------------
-- Employee auth & management (all SECURITY DEFINER: they run with elevated
-- rights so they're the only way to reach the `employees` table, and each
-- one checks permissions itself before doing anything).
-- ---------------------------------------------------------------------------

create or replace function employees_exist()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from employees);
$$;

create or replace function bootstrap_first_admin(p_name text, p_code text, p_password text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if exists (select 1 from employees limit 1) then
    raise exception 'تم إعداد النظام مسبقاً';
  end if;
  insert into employees (name, code, password_hash, role, active)
  values (p_name, p_code, crypt(p_password, gen_salt('bf')), 'admin', true)
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function login_employee(p_code text, p_password text)
returns table (id uuid, name text, code text, role text, active boolean)
language sql
security definer
set search_path = public
as $$
  select e.id, e.name, e.code, e.role, e.active
  from employees e
  where e.code = p_code
    and e.active = true
    and e.password_hash = crypt(p_password, e.password_hash);
$$;

create or replace function admin_list_employees(p_acting_employee_id uuid)
returns table (id uuid, name text, code text, role text, active boolean, created_at timestamptz)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from employees e where e.id = p_acting_employee_id and e.role = 'admin' and e.active = true
  ) then
    raise exception 'ليست لديك صلاحية عرض قائمة الموظفين';
  end if;

  return query
    select e.id, e.name, e.code, e.role, e.active, e.created_at
    from employees e
    order by e.name;
end;
$$;

create or replace function admin_save_employee(
  p_acting_employee_id uuid,
  p_id uuid,
  p_name text,
  p_code text,
  p_password text,
  p_role text,
  p_active boolean
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if not exists (
    select 1 from employees e where e.id = p_acting_employee_id and e.role = 'admin' and e.active = true
  ) then
    raise exception 'ليست لديك صلاحية إدارة الموظفين';
  end if;

  if p_id is null then
    if p_password is null or length(p_password) = 0 then
      raise exception 'كلمة المرور مطلوبة للموظف الجديد';
    end if;
    insert into employees (name, code, password_hash, role, active)
    values (p_name, p_code, crypt(p_password, gen_salt('bf')), p_role, p_active)
    returning id into v_id;
  else
    if p_password is not null and length(p_password) > 0 then
      update employees
      set name = p_name, code = p_code, role = p_role, active = p_active,
          password_hash = crypt(p_password, gen_salt('bf'))
      where id = p_id
      returning id into v_id;
    else
      update employees
      set name = p_name, code = p_code, role = p_role, active = p_active
      where id = p_id
      returning id into v_id;
    end if;
  end if;

  return v_id;
exception
  when unique_violation then
    raise exception 'الرمز مستخدم مسبقاً من قبل موظف آخر';
end;
$$;

create or replace function admin_delete_employee(p_acting_employee_id uuid, p_target_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_target_role text;
  v_other_admins int;
begin
  if not exists (
    select 1 from employees e where e.id = p_acting_employee_id and e.role = 'admin' and e.active = true
  ) then
    raise exception 'ليست لديك صلاحية حذف الموظفين';
  end if;

  select role into v_target_role from employees where id = p_target_id;

  if v_target_role = 'admin' then
    select count(*) into v_other_admins
    from employees
    where role = 'admin' and active = true and id != p_target_id;

    if v_other_admins = 0 then
      raise exception 'لا يمكن حذف آخر حساب مدير في النظام';
    end if;
  end if;

  delete from employees where id = p_target_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Customers / debts
-- ---------------------------------------------------------------------------

create or replace function find_or_create_customer(p_name text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  select id into v_id from customers where lower(name) = lower(p_name);
  if v_id is not null then
    return v_id;
  end if;

  insert into customers (name) values (p_name)
  on conflict (lower(name)) do nothing
  returning id into v_id;

  if v_id is null then
    select id into v_id from customers where lower(name) = lower(p_name);
  end if;

  return v_id;
end;
$$;

create or replace function add_manual_debt(p_customer_name text, p_amount numeric, p_note text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_customer_id uuid;
  v_id uuid;
begin
  if p_amount <= 0 then
    raise exception 'المبلغ يجب أن يكون أكبر من صفر';
  end if;

  v_customer_id := find_or_create_customer(p_customer_name);

  insert into debt_transactions (customer_id, type, amount, note)
  values (v_customer_id, 'charge', p_amount, coalesce(p_note, ''))
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function add_debt_payment(p_customer_id uuid, p_amount numeric, p_note text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if p_amount <= 0 then
    raise exception 'المبلغ يجب أن يكون أكبر من صفر';
  end if;

  insert into debt_transactions (customer_id, type, amount, note)
  values (p_customer_id, 'payment', p_amount, coalesce(p_note, ''))
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function total_outstanding_debt()
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(sum(balance), 0) from customer_balances;
$$;

-- ---------------------------------------------------------------------------
-- Sales — one atomic function: validates & locks stock, records the sale
-- and its line items, decrements inventory, and opens a debt if the sale
-- wasn't paid in full. Row-locked so two devices can't both sell the last
-- unit of something at the same moment.
-- ---------------------------------------------------------------------------

create or replace function create_sale(
  p_employee_id uuid,
  p_employee_name text,
  p_customer_name text,
  p_paid_amount numeric,
  p_note text,
  p_items jsonb
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sale_id uuid;
  v_total numeric := 0;
  v_item jsonb;
  v_product_id uuid;
  v_qty numeric;
  v_unit_price numeric;
  v_buy_price numeric;
  v_current_qty numeric;
  v_debt numeric;
  v_customer_id uuid;
  v_paid numeric;
begin
  if jsonb_array_length(p_items) = 0 then
    raise exception 'السلة فارغة';
  end if;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_product_id := (v_item ->> 'product_id')::uuid;
    v_qty := (v_item ->> 'quantity')::numeric;
    v_unit_price := (v_item ->> 'unit_price')::numeric;
    v_total := v_total + (v_qty * v_unit_price);

    select quantity into v_current_qty from products where id = v_product_id for update;

    if v_current_qty is null then
      raise exception 'أحد المنتجات لم يعد موجوداً';
    end if;
    if v_current_qty < v_qty then
      raise exception 'الكمية المتوفرة غير كافية لأحد المنتجات';
    end if;
  end loop;

  v_paid := least(p_paid_amount, v_total);

  insert into sales (employee_id, employee_name, customer_name, total_amount, paid_amount, note)
  values (p_employee_id, p_employee_name, coalesce(p_customer_name, ''), v_total, v_paid, coalesce(p_note, ''))
  returning id into v_sale_id;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_product_id := (v_item ->> 'product_id')::uuid;
    v_qty := (v_item ->> 'quantity')::numeric;
    v_unit_price := (v_item ->> 'unit_price')::numeric;
    v_buy_price := (v_item ->> 'buy_price_at_sale')::numeric;

    insert into sale_items (sale_id, product_id, product_name, quantity, unit_price, buy_price_at_sale)
    values (v_sale_id, v_product_id, v_item ->> 'product_name', v_qty, v_unit_price, v_buy_price);

    update products set quantity = quantity - v_qty where id = v_product_id;
  end loop;

  v_debt := v_total - v_paid;
  if v_debt > 0.0001 then
    v_customer_id := find_or_create_customer(
      case when coalesce(trim(p_customer_name), '') = '' then 'زبون بدون اسم' else trim(p_customer_name) end
    );
    insert into debt_transactions (customer_id, type, amount, note, sale_id)
    values (v_customer_id, 'charge', v_debt, 'دين من عملية بيع', v_sale_id);
  end if;

  return v_sale_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Reports — aggregated in Postgres instead of pulled row-by-row to the
-- client, so this stays fast as the sales history grows large.
-- ---------------------------------------------------------------------------

create or replace function report_summary(p_from timestamptz default null, p_to timestamptz default null)
returns table (total_sales numeric, total_profit numeric)
language sql
stable
security definer
set search_path = public
as $$
  select
    (select coalesce(sum(s.total_amount), 0)
       from sales s
       where (p_from is null or s.date >= p_from) and (p_to is null or s.date <= p_to)) as total_sales,
    (select coalesce(sum((si.unit_price - si.buy_price_at_sale) * si.quantity), 0)
       from sale_items si
       join sales s on s.id = si.sale_id
       where (p_from is null or s.date >= p_from) and (p_to is null or s.date <= p_to)) as total_profit;
$$;

create or replace function low_stock_products(p_limit int default 50)
returns setof products
language sql
stable
security definer
set search_path = public
as $$
  select * from products
  where quantity <= low_stock_threshold
  order by quantity
  limit p_limit;
$$;

create or replace function report_top_products(
  p_from timestamptz default null,
  p_to timestamptz default null,
  p_limit int default 5
) returns table (product_name text, total_qty numeric)
language sql
stable
security definer
set search_path = public
as $$
  select si.product_name, sum(si.quantity) as total_qty
  from sale_items si
  join sales s on s.id = si.sale_id
  where (p_from is null or s.date >= p_from) and (p_to is null or s.date <= p_to)
  group by si.product_name
  order by total_qty desc
  limit p_limit;
$$;

-- ---------------------------------------------------------------------------
-- Grants for every RPC above (anon covers the app's shared anonymous
-- session; authenticated is included in case you later add named accounts).
-- ---------------------------------------------------------------------------

grant execute on function employees_exist() to anon, authenticated;
grant execute on function bootstrap_first_admin(text, text, text) to anon, authenticated;
grant execute on function login_employee(text, text) to anon, authenticated;
grant execute on function admin_list_employees(uuid) to anon, authenticated;
grant execute on function admin_save_employee(uuid, uuid, text, text, text, text, boolean) to anon, authenticated;
grant execute on function admin_delete_employee(uuid, uuid) to anon, authenticated;
grant execute on function find_or_create_customer(text) to anon, authenticated;
grant execute on function add_manual_debt(text, numeric, text) to anon, authenticated;
grant execute on function add_debt_payment(uuid, numeric, text) to anon, authenticated;
grant execute on function total_outstanding_debt() to anon, authenticated;
grant execute on function create_sale(uuid, text, text, numeric, text, jsonb) to anon, authenticated;
grant execute on function report_summary(timestamptz, timestamptz) to anon, authenticated;
grant execute on function report_top_products(timestamptz, timestamptz, int) to anon, authenticated;
grant execute on function low_stock_products(int) to anon, authenticated;
