/// A photographed purchase list/invoice from a supplier — captured with
/// the camera and filed under that supplier automatically, so nothing
/// has to be typed in by hand right away; the photo itself is the record.
class SupplierList {
  SupplierList({
    required this.id,
    required this.supplierId,
    required this.name,
    required this.imageBase64,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String supplierId;
  String name;
  String imageBase64;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'supplierId': supplierId,
        'name': name,
        'imageBase64': imageBase64,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SupplierList.fromJson(Map<String, dynamic> j) => SupplierList(
        id: j['id'] as String,
        supplierId: j['supplierId'] as String,
        name: j['name'] as String,
        imageBase64: j['imageBase64'] as String,
        createdAt: j['createdAt'] != null ? DateTime.tryParse(j['createdAt'] as String) : null,
      );
}
