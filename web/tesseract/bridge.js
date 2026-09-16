// Bridges Dart (lib/services/ocr/ocr_engine_web.dart) to Tesseract.js,
// entirely offline: every file it needs (the wasm engine, the worker
// script, the English language data) is bundled right here alongside
// this page instead of being fetched from a CDN, matching the same
// offline-first approach as the CanvasKit patch applied to
// flutter_bootstrap.js after every build.
window.pmOcrRecognize = function (imageSource) {
  if (typeof Tesseract === "undefined") {
    return Promise.reject(new Error("Tesseract.js failed to load"));
  }
  return Tesseract.recognize(imageSource, "eng", {
    corePath: "tesseract/tesseract-core-simd-lstm.js",
    workerPath: "tesseract/worker.min.js",
    langPath: "tesseract/lang-data",
    gzip: true,
    // Tesseract.js defaults to loading the worker script through a
    // blob: URL, which has no real path of its own - the worker's
    // internal `importScripts(corePath)` (a *relative* URL) then can't
    // resolve where to fetch the wasm core file from at all. Loading
    // the worker from its real bundled path instead fixes that, since
    // relative URLs inside it now resolve against this page's own
    // origin like any other same-origin script.
    workerBlobURL: false,
  }).then(function (result) {
    return result && result.data ? result.data.text || "" : "";
  });
};
