class Employee {
  final String id;
  final String name;
  final String code;
  final String role; // 'admin' or 'cashier'
  final bool active;
  final DateTime createdAt;

  const Employee({
    required this.id,
    required this.name,
    required this.code,
    required this.role,
    this.active = true,
    required this.createdAt,
  });

  bool get isAdmin => role == 'admin';

  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      id: map['id'] as String,
      name: map['name'] as String,
      code: map['code'] as String,
      role: map['role'] as String,
      active: map['active'] as bool? ?? true,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
