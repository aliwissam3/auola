import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'ocr_result.dart';

/// Native builds (Android/iOS/Windows/macOS/Linux): ML Kit on-device text
/// recognition only ships a real implementation for Android/iOS, so
/// [isSupported] gates every call — on desktop the purchases screen shows
/// the same manual-entry fallback as web, just without a compile-time
/// exclusion, since dart:io itself is available on desktop.
bool get isSupported => Platform.isAndroid || Platform.isIOS;

Future<String?> recognizeRawText(String imagePath) async {
  if (!isSupported) return null;
  // ML Kit's on-device recognizer has no Arabic script model; Latin covers
  // the numbers/Latin drug names most printed receipts/boxes use. Arabic-
  // only text should be entered manually.
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final input = InputImage.fromFilePath(imagePath);
    final result = await recognizer.processImage(input);
    return result.text;
  } finally {
    await recognizer.close();
  }
}

Future<OcrPurchaseData?> recognizeReceipt(String imagePath) async {
  final text = await recognizeRawText(imagePath);
  if (text == null) return null;
  return parseReceiptText(text);
}
