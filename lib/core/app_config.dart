class AppConfig {
  AppConfig._();

  static const String productModelAsset =
      'assets/models/product_detector.tflite';
  static const String shelfModelAsset = 'assets/models/shelf_segmenter.tflite';
  static const int inputSize = 640; 
  static const int shelfClasses = 1; 
  static const int segMaskCoeffs = 32; 
  static const double productConfidence = 0.25;
  static const double shelfConfidence = 0.35;
  static const double nmsIou = 0.45;
  static const int shelfEveryNFrames = 3;
  static const int interpreterThreads = 4;
}
