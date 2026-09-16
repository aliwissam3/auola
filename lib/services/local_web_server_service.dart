import 'local_web_server_engine_stub.dart'
    if (dart.library.io) 'local_web_server_engine_io.dart' as engine;

/// Hosts this same app's compiled web build (`flutter build web`'s
/// `build/web` output) over the local network from inside the desktop
/// app itself — no separate `flutter run -d chrome` process needed. Any
/// phone on the same Wi-Fi/LAN can open the resulting address in its
/// browser and use the app from there, sharing the exact same Supabase
/// data as this desktop instance: a sale made from the phone shows up on
/// the admin's dashboard immediately, like a second cash register.
///
/// Resolves at compile time to the dart:io/shelf engine everywhere
/// except Web (which has no dart:io — same conditional-import pattern
/// as `services/ocr/ocr_service.dart`), and at runtime the io engine
/// further restricts itself to desktop platforms, where a "counter"
/// device to host from actually exists. Web and mobile therefore both
/// report [isRunning] == false.
class LocalWebServerService {
  LocalWebServerService._();
  static final instance = LocalWebServerService._();

  bool get isRunning => engine.isRunning;

  List<String> get candidateIps => engine.candidateIps;

  Uri? get networkUrl => engine.networkUrl;

  Future<Uri?> start() => engine.start();

  Future<void> stop() => engine.stop();
}
