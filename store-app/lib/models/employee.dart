class Employee {
  final int? id;
  final String name;
  final String code; // unique login code chosen by the admin
  final String passwordHash;
  final String role; // 'admin' or 'cashier'
  final bool active;
  final DateTime createdAt;

  const Employee({
    this.id,
    required this.name,
    required this.code,
    required this.passwordHash,
    required this.role,
    this.active = true,
    required this.createdAt,
  });

  bool get isAdmin => role == 'admin';

  Employee copyWith({
    int? id,
    String? name,
    String? code,
    String? passwordHash,
    String? role,
    bool? active,
    DateTime? createdAt,
  }) {
    return Employee(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      passwordHash: passwordHash ?? this.passwordHash,
      role: role ?? this.role,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'password_hash': passwordHash,
      'role': role,
      'active': active ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Employee.fromMap(Map<String, Object?> map) {
    return Employee(
      id: map['id'] as int?,
      name: map['name'] as String,
      code: map['code'] as String,
      passwordHash: map['password_hash'] as String,
      role: map['role'] as String,
      active: (map['active'] as int? ?? 1) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
