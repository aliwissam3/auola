import 'dart:js_interop';

import 'ocr_result.dart';

/// Calls `window.pmOcrRecognize(imageSource)` — defined in
/// web/tesseract/bridge.js, loaded by index.html — which runs
/// Tesseract.js against the bundled (fully offline) wasm engine and
/// English language data and resolves with the recognized text.
@JS('pmOcrRecognize')
external JSPromise<JSString> _pmOcrRecognize(JSString imageSource);

/// Desktop/web build: no native ML Kit plugin exists here, but the app
/// bundles Tesseract.js itself (see web/tesseract/) so OCR still works,
/// entirely offline, via the JS bridge above.
bool get isSupported => true;

Future<String?> recognizeRawText(String imagePath) async {
  try {
    // `imagePath` is whatever image_picker's XFile.path returns on web —
    // a blob: object URL — which Tesseract.js accepts directly as an
    // image source, same as a plain file or data URL.
    final text = (await _pmOcrRecognize(imagePath.toJS).toDart).toDart;
    return text.trim().isEmpty ? null : text;
  } catch (_) {
    // Bundled assets failed to load/parse, or Tesseract.js itself never
    // loaded — surfaced to the caller as "nothing recognized" so the UI
    // falls back to manual entry instead of crashing.
    return null;
  }
}

Future<OcrPurchaseData?> recognizeReceipt(String imagePath) async {
  final text = await recognizeRawText(imagePath);
  if (text == null) return null;
  return parseReceiptText(text);
}
