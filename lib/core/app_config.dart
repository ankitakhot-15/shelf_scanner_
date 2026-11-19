/// Central place for every tunable value. Change here, nothing else.
class AppConfig {
  AppConfig._();

  // ---- Model files (converted from the .pt files you received) ----
  static const String productModelAsset =
      'assets/models/product_detector.tflite';
  static const String shelfModelAsset = 'assets/models/shelf_segmenter.tflite';

  // ---- Model facts (read from the .pt metadata) ----
  static const int inputSize = 640; // both models: imgsz = 640
  static const int productClasses = 2; // 0 = empty space, 1 = product
  static const int shelfClasses = 1; // 0 = row
  static const int segMaskCoeffs = 32; // extra channels of the -seg head

  // ---- Thresholds ----
  static const double productConfidence = 0.25;
  static const double shelfConfidence = 0.35;
  static const double nmsIou = 0.45;

  // ---- Performance ----
  /// Shelf model is slower and shelves move slowly -> run it every N frames.
  static const int shelfEveryNFrames = 3;
  static const int interpreterThreads = 4;
}
