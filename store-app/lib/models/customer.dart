class Customer {
  final String id;
  final String name;
  final String phone;
  final String note;

  const Customer({
    required this.id,
    required this.name,
    this.phone = '',
    this.note = '',
  });

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String? ?? '',
      note: map['note'] as String? ?? '',
    );
  }
}
