import 'package:barcode_widget/barcode_widget.dart' as bw;
import 'package:flutter/material.dart';
import '../services/local_web_server_service.dart';
import '../utils/web_deep_link.dart';

/// Shows a QR code that opens this same app in a browser on any other
/// device connected to the same local network (Wi-Fi/LAN) — not the
/// internet. Scanning it with an ordinary phone camera lands on this
/// app's own login screen, where the person picks their name/code as
/// usual; any sale made from there is stored in the same shared data as
/// the desktop app, so it shows up on the admin's dashboard immediately,
/// exactly like a second cash register.
///
/// The address comes from whichever of the two ways this app can be
/// reachable over the network applies: [webOrigin] when this very tab
/// *is* a deployed Flutter Web page, or — the normal case for the
/// desktop build run at the counter — the address
/// [LocalWebServerService] is already hosting this app's own web build
/// on, started at app launch.
Future<void> showNetworkLoginQrDialog(BuildContext context) async {
  final origin =
      webOrigin() ?? LocalWebServerService.instance.networkUrl?.toString();
  if (origin == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'تعذّر تشغيل هذه الميزة — تأكد من بناء نسخة الويب مرة واحدة '
          '(flutter build web) ومن اتصال الجهاز بالشبكة',
        ),
      ),
    );
    return;
  }

  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('باركود الدخول عبر الشبكة'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: bw.BarcodeWidget(
                barcode: bw.Barcode.qrCode(),
                data: origin,
                width: 220,
                height: 220,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'امسح هذا الباركود بكاميرا أي موبايل متصل بنفس شبكة الواي فاي '
              'ليفتح صفحة تسجيل الدخول على هذا الجهاز — يعمل داخل الشبكة فقط '
              'ولا يعمل عبر الإنترنت',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF4A4A4A),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            SelectableText(
              origin,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            if (_alternateAddresses(origin).isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                'إذا فتح ولكن الشاشة ما اشتغلت أو ما وصل أصلاً، هذا الجهاز '
                'عنده أكثر من اتصال شبكة — جرّب يدوياً بمتصفح الموبايل '
                'أحد هذي العناوين بدل الأول:',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              for (final alt in _alternateAddresses(origin))
                SelectableText(
                  alt,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('إغلاق'),
        ),
      ],
    ),
  );
}

/// The other IPv4 addresses this machine has besides the one already
/// shown/encoded in the QR (`origin`) — same port, different host.
/// Combines whatever [LocalWebServerService] itself tracks (the desktop-
/// build path) with the `_altips` Electron passed in on this page's own
/// URL (the web-build-in-Electron path — see [alternateOrigins]), since
/// exactly one of the two is ever populated depending on how the app is
/// actually running.
List<String> _alternateAddresses(String origin) {
  final server = LocalWebServerService.instance;
  final port = server.networkUrl?.port;
  final fromLocalServer = port == null
      ? <String>[]
      : server.candidateIps.skip(1).map((ip) => 'http://$ip:$port');
  return {...fromLocalServer, ...alternateOrigins()}
      .where((url) => url != origin)
      .toList();
}
