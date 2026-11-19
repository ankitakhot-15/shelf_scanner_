import 'dart:typed_data';

enum DetectionKind { shelf, product, empty }

class NormBox {
  final double left, top, right, bottom;
  const NormBox(this.left, this.top, this.right, this.bottom);
  double get width => right - left;
  double get height => bottom - top;
}

class Detection {
  final NormBox box;
  final DetectionKind kind;
  final String label;
  final double confidence;
  const Detection(this.box, this.kind, this.label, this.confidence);
}

class FrameResult {
  final List<Detection>? shelves;
  final List<Detection> items; // products + empty gaps
  final int imageWidth; // upright size
  final int imageHeight;
  final int totalMs;
  const FrameResult({
    required this.shelves,
    required this.items,
    required this.imageWidth,
    required this.imageHeight,
    required this.totalMs,
  });
}

class VideoSampleResult {
  final int timeMs;
  final Uint8List imageBytes;
  final FrameResult result;

  const VideoSampleResult({
    required this.timeMs,
    required this.imageBytes,
    required this.result,
  });
}
