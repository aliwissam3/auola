import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/app_data.dart';
import '../../models/operations.dart';
import '../../models/product.dart';
import '../../utils/arabic.dart';
import '../../widgets/sale_shortcut_action.dart';

class MovementScreen extends StatelessWidget {
  const MovementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('حركة مادة'),
          actions: const [SaleShortcutAction()],
          bottom: const TabBar(tabs: [
            Tab(text: 'الأكثر طلباً'),
            Tab(text: 'المواد الراكدة'),
            Tab(text: 'سجل الحركة'),
          ]),
        ),
        body: const TabBarView(children: [_TopSellersTab(), _StagnantTab(), _HistoryTab()]),
      ),
    );
  }
}

class _TopSellersTab extends StatelessWidget {
  const _TopSellersTab();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final now = DateTime.now();

    final soldQty = <String, double>{};
    final withdrawals = <String, int>{};
    for (final sale in data.sales.items) {
      if (sale.createdAt.year != now.year || sale.createdAt.month != now.month) continue;
      for (final item in sale.items) {
        soldQty[item.productId] = (soldQty[item.productId] ?? 0) + item.quantity;
        withdrawals[item.productId] = (withdrawals[item.productId] ?? 0) + 1;
      }
    }

    final ranked = soldQty.keys.toList()
      ..sort((a, b) => soldQty[b]!.compareTo(soldQty[a]!));

    if (ranked.isEmpty) {
      return const Center(child: Text('لا توجد مبيعات هذا الشهر بعد'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: ranked.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final productId = ranked[i];
        final product = data.products.byId(productId);
        return ListTile(
          leading: CircleAvatar(child: Text('${i + 1}')),
          title: Text(product?.name ?? 'مادة محذوفة'),
          subtitle: Text('عدد السحوبات هذا الشهر: ${withdrawals[productId]}'),
          trailing: Text(
            '${soldQty[productId]!.toStringAsFixed(0)} ${product?.unit.labelAr ?? ''}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }
}

class _StagnantTab extends StatelessWidget {
  const _StagnantTab();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final now = DateTime.now();
    final lastMovementByProduct = <String, DateTime>{};
    for (final m in data.movements.items) {
      final prev = lastMovementByProduct[m.productId];
      if (prev == null || m.createdAt.isAfter(prev)) {
        lastMovementByProduct[m.productId] = m.createdAt;
      }
    }

    final stagnant = data.products.items.where((p) {
      final last = lastMovementByProduct[p.id];
      if (last == null) return true; // never moved
      return now.difference(last).inDays >= 60;
    }).toList();

    if (stagnant.isEmpty) {
      return const Center(child: Text('لا توجد مواد راكدة حالياً'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: stagnant.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final p = stagnant[i];
        final last = lastMovementByProduct[p.id];
        return ListTile(
          leading: const Icon(Icons.inventory_2_outlined, color: Colors.orange),
          title: Text(p.name),
          subtitle: Text('المخزون: ${p.quantity} ${p.unit.labelAr}'),
          trailing: Text(
            last == null ? 'بدون حركة' : 'آخر حركة منذ ${now.difference(last).inDays} يوم',
            style: const TextStyle(fontSize: 12, color: Color(0xFF4A4A4A), fontWeight: FontWeight.w600),
          ),
        );
      },
    );
  }
}

class _HistoryTab extends StatefulWidget {
  const _HistoryTab();

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  String _search = '';
  String? _pharmacyId;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final pharmacies = data.pharmacies.items;

    final movements = data.movements.items.where((m) {
      if (_search.isNotEmpty && !arabicContains(m.name, _search)) return false;
      if (_pharmacyId != null) {
        final product = data.products.byId(m.productId);
        if (product?.pharmacyId != _pharmacyId) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(
            children: [
              Expanded(
                flex: pharmacies.length > 1 ? 3 : 1,
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'بحث بحركة المادة',
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              if (pharmacies.length > 1) ...[
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _pharmacyId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'الفرع'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('كل الفروع')),
                      ...pharmacies.map((ph) => DropdownMenuItem<String?>(value: ph.id, child: Text(ph.name))),
                    ],
                    onChanged: (v) => setState(() => _pharmacyId = v),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: movements.isEmpty
              ? const Center(child: Text('لا يوجد سجل حركة بعد'))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: movements.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final m = movements[i];
                    final isIn = m.type == StockMovementType.stockIn;
                    return ListTile(
                      leading: Icon(
                        isIn ? Icons.arrow_downward : Icons.arrow_upward,
                        color: isIn ? Colors.green : Colors.red,
                      ),
                      title: Text(m.name),
                      subtitle: Text('${m.type.labelAr}${m.note.isEmpty ? '' : ' • ${m.note}'}'),
                      trailing: Text(
                        '${isIn ? '+' : '-'}${m.quantity}\n${m.createdAt.year}/${m.createdAt.month}/${m.createdAt.day}',
                        textAlign: TextAlign.left,
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
