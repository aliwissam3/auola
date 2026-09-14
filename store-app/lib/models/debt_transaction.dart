/// A single ledger entry against a customer's debt balance.
/// type == 'charge'  -> increases what the customer owes (e.g. a partly-paid sale)
/// type == 'payment' -> decreases what the customer owes (customer paid something back)
class DebtTransaction {
  final int? id;
  final int customerId;
  final String type;
  final double amount;
  final DateTime date;
  final String note;
  final int? saleId;

  const DebtTransaction({
    this.id,
    required this.customerId,
    required this.type,
    required this.amount,
    required this.date,
    this.note = '',
    this.saleId,
  });

  bool get isCharge => type == 'charge';

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'type': type,
      'amount': amount,
      'date': date.toIso8601String(),
      'note': note,
      'sale_id': saleId,
    };
  }

  factory DebtTransaction.fromMap(Map<String, Object?> map) {
    return DebtTransaction(
      id: map['id'] as int?,
      customerId: map['customer_id'] as int,
      type: map['type'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String? ?? '',
      saleId: map['sale_id'] as int?,
    );
  }
}
