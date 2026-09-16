/// Web build: there's no "host this app for other devices" concept here
/// — the browser tab that loaded this code already *is* the served page
/// — so every call below is a safe no-op/empty value. This file exists
/// purely so `local_web_server_service.dart` has a `dart:io`-free
/// implementation to fall back to on Web (see `services/ocr/ocr_service.dart`
/// for the exact same conditional-import pattern): without it, the
/// `dart:io` import in `local_web_server_engine_io.dart` — reachable from
/// `main.dart` on every platform — would make `flutter build web` fail
/// to compile the entire app.
bool get isRunning => false;

List<String> get candidateIps => const [];

Uri? get networkUrl => null;

Future<Uri?> start() async => null;

Future<void> stop() async {}
