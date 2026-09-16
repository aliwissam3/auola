import 'dart:math';

final _rand = Random();

/// Generates a locally-unique id (timestamp + random suffix). Good enough
/// for a single-device / single-store local database — no server round
/// trip is involved.
///
/// Uses the literal 2147483647 (2^31 - 1) rather than `1 << 32`: on
/// Flutter Web, `<<` is emulated with JavaScript's 32-bit bitwise
/// operators, whose shift amount is taken mod 32 — so `1 << 32`
/// silently evaluates to `1 << 0 == 1` there (not 4294967296 like on
/// the VM), and in some compiler versions ends up truncating to 0,
/// which makes `Random.nextInt` throw a RangeError at startup.
String newId() {
  final ts = DateTime.now().microsecondsSinceEpoch;
  final suffix = _rand.nextInt(2147483647).toRadixString(36);
  return '${ts.toRadixString(36)}$suffix';
}
