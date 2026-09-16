import 'ocr_result.dart';

/// Fallback used only when neither dart:io (desktop/mobile) nor a
/// browser (dart:js_interop, see ocr_engine_web.dart) is available —
/// not expected to ever actually run in this app, but keeps the
/// conditional import exhaustive.
bool get isSupported => false;

Future<String?> recognizeRawText(String imagePath) async => null;

Future<OcrPurchaseData?> recognizeReceipt(String imagePath) async => null;
