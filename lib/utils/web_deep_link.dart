import 'package:flutter/foundation.dart' show kIsWeb;

/// The origin (scheme://host:port) of the page currently serving this
/// app — only meaningful when actually running as a deployed Flutter
/// Web build (i.e. reachable by a phone's camera scanning a QR code).
/// `Uri.base` compiles fine on every platform (it's plain dart:core),
/// but only reflects a real, scannable address on web — elsewhere it's
/// some meaningless local file/entry-point URI, so this deliberately
/// returns null off-web rather than a bogus link.
///
/// Note this is only ever reachable from a phone if the page itself was
/// opened via the PC's LAN address (e.g. http://192.168.1.5:8080) rather
/// than localhost/127.0.0.1 — localhost never resolves to anything but
/// the machine it's typed on, no matter what serves the page.
String? webOrigin() {
  if (!kIsWeb) return null;
  final uri = Uri.base;
  final port = uri.hasPort &&
          !((uri.scheme == 'http' && uri.port == 80) ||
              (uri.scheme == 'https' && uri.port == 443))
      ? ':${uri.port}'
      : '';
  return '${uri.scheme}://${uri.host}$port';
}

/// Builds the URL a printed/shown QR code should encode so that
/// scanning it with an ordinary phone camera app opens this app in the
/// phone's browser and logs the employee straight in — the login screen
/// reads [employeeId]+[code] back out and auto-submits them as soon as
/// the page loads. Falls back to the bare code (works with a barcode
/// scanner or manual entry, paired with picking the name on-screen) when
/// not running on web, since there's no "open in a browser" concept there.
String buildLoginLink(String code, {required String employeeId}) {
  final origin = webOrigin();
  if (origin == null) return code;
  return '$origin/?code=$code&emp=$employeeId';
}

/// Other LAN IPs this machine has besides the one already encoded in
/// [webOrigin] — passed in by Electron's `main.js` (which can see every
/// network adapter) as a `?_altips=ip1,ip2` query param on the page's
/// very first load, since a picked "best" adapter can still turn out to
/// be the wrong one (a second Wi-Fi band, a VLAN the phone isn't on...).
/// Shown as manual-entry fallbacks alongside the QR code.
List<String> alternateOrigins() {
  if (!kIsWeb) return [];
  final uri = Uri.base;
  final raw = uri.queryParameters['_altips'];
  if (raw == null || raw.isEmpty) return [];
  final port = uri.hasPort &&
          !((uri.scheme == 'http' && uri.port == 80) ||
              (uri.scheme == 'https' && uri.port == 443))
      ? ':${uri.port}'
      : '';
  return raw
      .split(',')
      .map((ip) => ip.trim())
      .where((ip) => ip.isNotEmpty)
      .map((ip) => '${uri.scheme}://$ip$port')
      .toList();
}

/// Reads the `?emp=...&code=...` query parameters from the page's current
/// URL, if this was opened via a [buildLoginLink] QR code. Null on any
/// other platform, or when the app was opened normally, or when only one
/// of the two is present.
(String employeeId, String code)? initialLoginInfoFromUrl() {
  if (!kIsWeb) return null;
  final params = Uri.base.queryParameters;
  final employeeId = params['emp']?.trim();
  final code = params['code']?.trim();
  if (employeeId == null || employeeId.isEmpty || code == null || code.isEmpty) {
    return null;
  }
  return (employeeId, code);
}
