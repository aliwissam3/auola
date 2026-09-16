import 'ocr_engine_stub.dart'
    if (dart.library.io) 'ocr_engine_io.dart'
    if (dart.library.js_interop) 'ocr_engine_web.dart' as engine;
import 'ocr_result.dart';

export 'ocr_result.dart';

/// Public OCR entry point. Resolves at compile time to the dart:io/ML Kit
/// engine on Android/iOS/desktop native builds, to the bundled-Tesseract.js
/// engine on Web (see ocr_engine_web.dart), and at runtime the io engine
/// further restricts itself to Android/iOS, where ML Kit actually ships a
/// real implementation (desktop native therefore still reports
/// [isSupported] == false there and falls back to manual entry).
class OcrService {
  static bool get isSupported => engine.isSupported;

  static Future<String?> recognizeRawText(String imagePath) =>
      engine.recognizeRawText(imagePath);

  static Future<OcrPurchaseData?> recognizeReceipt(String imagePath) =>
      engine.recognizeReceipt(imagePath);
}
