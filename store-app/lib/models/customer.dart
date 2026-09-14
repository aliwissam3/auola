class Customer {
  final int? id;
  final String name;
  final String phone;
  final String note;
  final DateTime createdAt;

  const Customer({
    this.id,
    required this.name,
    this.phone = '',
    this.note = '',
    required this.createdAt,
  });

  Customer copyWith({
    int? id,
    String? name,
    String? phone,
    String? note,
    DateTime? createdAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Customer.fromMap(Map<String, Object?> map) {
    return Customer(
      id: map['id'] as int?,
      name: map['name'] as String,
      phone: map['phone'] as String? ?? '',
      note: map['note'] as String? ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
