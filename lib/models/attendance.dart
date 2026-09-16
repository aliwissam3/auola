/// One work day's attendance for one employee: when they checked in,
/// when (if) they checked out. Hours worked and overtime (anything past
/// 8h) are computed from these two timestamps rather than stored, so
/// they're always accurate even if a record is edited later.
class AttendanceRecord {
  AttendanceRecord({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.checkIn,
    this.checkOut,
  });

  final String id;
  final String employeeId;
  final String employeeName;
  DateTime checkIn;
  DateTime? checkOut;

  Duration? get workedDuration => checkOut == null ? null : checkOut!.difference(checkIn);

  /// Anything beyond 8 hours counts as overtime, matching how the
  /// pharmacy already thinks about extra hours.
  Duration? get overtime {
    final worked = workedDuration;
    if (worked == null) return null;
    final extra = worked - const Duration(hours: 8);
    return extra.isNegative ? Duration.zero : extra;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'employeeId': employeeId,
        'employeeName': employeeName,
        'checkIn': checkIn.toIso8601String(),
        'checkOut': checkOut?.toIso8601String(),
      };

  factory AttendanceRecord.fromJson(Map<String, dynamic> j) => AttendanceRecord(
        id: j['id'] as String,
        employeeId: j['employeeId'] as String,
        employeeName: j['employeeName'] as String,
        checkIn: DateTime.parse(j['checkIn'] as String),
        checkOut: j['checkOut'] == null ? null : DateTime.parse(j['checkOut'] as String),
      );
}
