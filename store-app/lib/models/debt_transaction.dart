/// A single ledger entry against a customer's debt balance.
/// type == 'charge'  -> increases what the customer owes (e.g. a partly-paid sale)
/// type == 'payment' -> decreases what the customer owes (customer paid something back)
class DebtTransaction {
  final String id;
  final String customerId;
  final String type;
  final double amount;
  final DateTime date;
  final String note;
  final String? saleId;

  const DebtTransaction({
    required this.id,
    required this.customerId,
    required this.type,
    required this.amount,
    required this.date,
    this.note = '',
    this.saleId,
  });

  bool get isCharge => type == 'charge';

  factory DebtTransaction.fromMap(Map<String, dynamic> map) {
    return DebtTransaction(
      id: map['id'] as String,
      customerId: map['customer_id'] as String,
      type: map['type'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String? ?? '',
      saleId: map['sale_id'] as String?,
    );
  }
}
