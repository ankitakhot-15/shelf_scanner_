import 'dart:math' as math;
import 'dart:typed_data';
class Letterbox {
  final int srcW, srcH, size;
  late final double scale;
  late final int newW, newH, padX, padY;

  Letterbox(this.srcW, this.srcH, this.size) {
    scale = math.min(size / srcW, size / srcH);
    newW = (srcW * scale).round();
    newH = (srcH * scale).round();
    padX = (size - newW) ~/ 2;
    padY = (size - newH) ~/ 2;
  }
}
class RawBox {
  double x1, y1, x2, y2;
  final double score;
  final int cls;
  RawBox(this.x1, this.y1, this.x2, this.y2, this.score, this.cls);

  double get area => math.max(0, x2 - x1) * math.max(0, y2 - y1);
}

Float32List rgbNhwcToNchw(Float32List input, int size) {
  final planeSize = size * size;
  if (input.length != planeSize * 3) {
    throw ArgumentError.value(
        input.length, 'input.length', 'Expected ${planeSize * 3} RGB values');
  }

  final output = Float32List(input.length);
  for (var pixel = 0; pixel < planeSize; pixel++) {
    output[pixel] = input[pixel * 3];
    output[planeSize + pixel] = input[pixel * 3 + 1];
    output[2 * planeSize + pixel] = input[pixel * 3 + 2];
  }
  return output;
}
List<RawBox> decodeYolo(
  Float32List out,
  List<int> shape, {
  required int numClasses,
  required int extraChannels,
  required double confThreshold,
  required int inputSize,
}) {
  final channels = 4 + numClasses + extraChannels;
  final bool channelsFirst;
  if (shape.length == 3 && shape[1] == channels) {
    channelsFirst = true;
  } else if (shape.length == 3 && shape[2] == channels) {
    channelsFirst = false;
  } else {
    throw StateError(
        'Unexpected output shape $shape (expected $channels channels)');
  }
  final n = channelsFirst ? shape[2] : shape[1];

  double at(int c, int i) =>
      channelsFirst ? out[c * n + i] : out[i * channels + c];

  final res = <RawBox>[];
  double maxCoord = 0;
  for (var i = 0; i < n; i++) {
    var best = -1.0;
    var cls = 0;
    for (var c = 0; c < numClasses; c++) {
      final s = at(4 + c, i);
      if (s > best) {
        best = s;
        cls = c;
      }
    }
    if (best < confThreshold) continue;
    final cx = at(0, i), cy = at(1, i), w = at(2, i), h = at(3, i);
    maxCoord = math.max(maxCoord, math.max(math.max(cx, cy), math.max(w, h)));
    res.add(RawBox(cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2, best, cls));
  }
  if (res.isNotEmpty && maxCoord <= 2.0) {
    final s = inputSize.toDouble();
    for (final b in res) {
      b.x1 *= s;
      b.y1 *= s;
      b.x2 *= s;
      b.y2 *= s;
    }
  }
  return res;
}

double _iou(RawBox a, RawBox b) {
  final ix1 = math.max(a.x1, b.x1), iy1 = math.max(a.y1, b.y1);
  final ix2 = math.min(a.x2, b.x2), iy2 = math.min(a.y2, b.y2);
  final inter = math.max(0, ix2 - ix1) * math.max(0, iy2 - iy1);
  final union = a.area + b.area - inter;
  return union <= 0 ? 0 : inter / union;
}

List<RawBox> nms(List<RawBox> boxes, double iouThreshold, {int maxDet = 300}) {
  boxes.sort((a, b) => b.score.compareTo(a.score));
  final candidates = boxes.length > 1000 ? boxes.sublist(0, 1000) : boxes;
  final keep = <RawBox>[];
  for (final b in candidates) {
    var ok = true;
    for (final k in keep) {
      if (k.cls == b.cls && _iou(k, b) > iouThreshold) {
        ok = false;
        break;
      }
    }
    if (ok) {
      keep.add(b);
      if (keep.length >= maxDet) break;
    }
  }
  return keep;
}
