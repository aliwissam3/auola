import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';

/// Real implementation — only ever compiled in on platforms that have
/// `dart:io` (Windows/macOS/Linux/Android/iOS), never on Web. See
/// `local_web_server_service.dart` for how the two are switched between.

const _candidatePorts = [8089, 8090, 8091];

HttpServer? _server;
List<String> _candidateIps = [];

bool get isRunning => _server != null;

/// Every IPv4 address this machine has, best guess first — same order
/// [networkUrl] picks its host from. Exposed so the QR dialog can also
/// show the rest as a manual fallback: guessing which adapter a phone
/// can actually reach is a heuristic, not a certainty (see
/// [_findLocalIPv4Candidates]), so if the QR's first pick turns out to
/// be a virtual adapter the phone can't reach, the next one usually is
/// the real one.
List<String> get candidateIps => _candidateIps;

/// The address to encode in the QR, e.g. `http://192.168.1.5:8089` —
/// null until [start] has run and actually succeeded.
Uri? get networkUrl {
  final server = _server;
  if (server == null || _candidateIps.isEmpty) return null;
  return Uri(scheme: 'http', host: _candidateIps.first, port: server.port);
}

/// Looks for an already-built `flutter build web` output next to the
/// running executable first (production deployment: copy `build/web`
/// there and rename it `web` — see SETUP.md), then falls back to
/// `build/web` relative to the current working directory, which is
/// where `flutter run -d windows` finds it when launched from the
/// project folder (exactly what `update_and_run.bat` does).
String? _findWebBuildDir() {
  final sep = Platform.pathSeparator;
  final exeDir = File(Platform.resolvedExecutable).parent.path;
  final candidates = [
    '$exeDir${sep}web',
    '${Directory.current.path}${sep}build${sep}web',
  ];
  for (final dir in candidates) {
    if (File('$dir${sep}index.html').existsSync()) return dir;
  }
  return null;
}

/// Windows machines commonly report several IPv4 addresses at once —
/// the real Wi-Fi/Ethernet adapter, plus virtual ones from VMware,
/// VirtualBox, Hyper-V, Docker/WSL, VPNs, etc. A phone on the shop's
/// Wi-Fi can only ever reach the real one, and a virtual adapter's
/// address often *looks* just as "private LAN" as a real one (VMware's
/// default NAT/host-only networks are plain `192.168.x.0/24` ranges
/// too) — an IP-range check alone can't tell them apart. The adapter's
/// *name* usually can, so rank by that first: real-looking adapter
/// names, ordered by how private-LAN-like the address itself is, then
/// everything else the same way as a last resort. [candidateIps]
/// exposes the full ranked list so the QR dialog can offer the rest as
/// a manual fallback if the top pick turns out wrong.
const _virtualAdapterNameHints = [
  'vmware', 'virtualbox', 'virtual', 'hyper-v', 'vethernet', 'docker',
  'wsl', 'tailscale', 'zerotier', 'npcap', 'loopback', 'bluetooth',
];

Future<List<String>> _findLocalIPv4Candidates() async {
  final interfaces = await NetworkInterface.list(
    includeLoopback: false,
    type: InternetAddressType.IPv4,
  );
  final real = <String>[];
  final virtual = <String>[];
  for (final iface in interfaces) {
    final looksVirtual = _virtualAdapterNameHints
        .any((hint) => iface.name.toLowerCase().contains(hint));
    final bucket = looksVirtual ? virtual : real;
    for (final addr in iface.addresses) {
      if (!addr.isLoopback) bucket.add(addr.address);
    }
  }
  List<String> byLanRangeFirst(List<String> ips) => [
        ...ips.where(_isPrivateLan),
        ...ips.where((ip) => !_isPrivateLan(ip)),
      ];
  return [...byLanRangeFirst(real), ...byLanRangeFirst(virtual)];
}

bool _isPrivateLan(String ip) {
  if (ip.startsWith('192.168.')) return true;
  if (ip.startsWith('10.')) return true;
  final parts = ip.split('.');
  if (parts.length == 4 && parts[0] == '172') {
    final second = int.tryParse(parts[1]) ?? -1;
    if (second >= 16 && second <= 31) return true;
  }
  return false;
}

/// Starts the server once; safe to call again (a no-op once running).
/// Returns the URL to encode in the QR, or null if hosting isn't
/// possible right now (running on mobile, no `build/web` found on disk
/// yet, no network interface, or every candidate port is busy).
Future<Uri?> start() async {
  if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    return null;
  }
  if (_server != null) return networkUrl;

  final webDir = _findWebBuildDir();
  if (webDir == null) return null;

  final candidates = await _findLocalIPv4Candidates();
  if (candidates.isEmpty) return null;

  final handler = createStaticHandler(webDir, defaultDocument: 'index.html');
  for (final port in _candidatePorts) {
    try {
      _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
      _candidateIps = candidates;
      return networkUrl;
    } on SocketException {
      continue;
    }
  }
  return null;
}

Future<void> stop() async {
  await _server?.close(force: true);
  _server = null;
  _candidateIps = [];
}
