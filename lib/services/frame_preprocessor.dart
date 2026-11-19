import 'dart:math' as math;
import 'dart:typed_data';
import 'yolo_utils.dart';

class YuvFrame {
  final int width, height; 
  final Uint8List y, u, v;
  final int yRowStride, uvRowStride, uvPixelStride;
  final int rotation; 
  const YuvFrame({
    required this.width,
    required this.height,
    required this.y,
    required this.u,
    required this.v,
    required this.yRowStride,
    required this.uvRowStride,
    required this.uvPixelStride,
    required this.rotation,
  });
}

class Preprocessed {
  final Float32List tensor; 
  final Letterbox letterbox;
  const Preprocessed(this.tensor, this.letterbox);
}

const double _pad = 114 / 255; 
Preprocessed preprocessYuv(YuvFrame f, int size) {
  final rot = ((f.rotation % 360) + 360) % 360;
  final swap = rot == 90 || rot == 270;
  final uw = swap ? f.height : f.width; 
  final uh = swap ? f.width : f.height;
  final lb = Letterbox(uw, uh, size);
  final out = Float32List(size * size * 3)..fillRange(0, size * size * 3, _pad);
  final inv = 1 / lb.scale;

  for (var oy = lb.padY; oy < lb.padY + lb.newH; oy++) {
    final uy = math.min(uh - 1, ((oy - lb.padY) * inv).floor());
    for (var ox = lb.padX; ox < lb.padX + lb.newW; ox++) {
      final ux = math.min(uw - 1, ((ox - lb.padX) * inv).floor());
      int x, y;
      if (rot == 90) {
        x = uy;
        y = f.height - 1 - ux;
      } else if (rot == 270) {
        x = f.width - 1 - uy;
        y = ux;
      } else if (rot == 180) {
        x = f.width - 1 - ux;
        y = f.height - 1 - uy;
      } else {
        x = ux;
        y = uy;
      }

      final yy = f.y[y * f.yRowStride + x].toDouble();
      final uvIdx = (y >> 1) * f.uvRowStride + (x >> 1) * f.uvPixelStride;
      final uu = f.u[uvIdx] - 128;
      final vv = f.v[uvIdx] - 128;

      final r = (yy + 1.402 * vv).clamp(0.0, 255.0);
      final g = (yy - 0.344136 * uu - 0.714136 * vv).clamp(0.0, 255.0);
      final b = (yy + 1.772 * uu).clamp(0.0, 255.0);

      final o = (oy * size + ox) * 3;
      out[o] = r / 255;
      out[o + 1] = g / 255;
      out[o + 2] = b / 255;
    }
  }
  return Preprocessed(out, lb);
}

Preprocessed preprocessRgb(
    Uint8List rgb, int w, int h, int channels, int size) {
  final lb = Letterbox(w, h, size);
  final out = Float32List(size * size * 3)..fillRange(0, size * size * 3, _pad);
  final inv = 1 / lb.scale;
  for (var oy = lb.padY; oy < lb.padY + lb.newH; oy++) {
    final uy = math.min(h - 1, ((oy - lb.padY) * inv).floor());
    for (var ox = lb.padX; ox < lb.padX + lb.newW; ox++) {
      final ux = math.min(w - 1, ((ox - lb.padX) * inv).floor());
      final i = (uy * w + ux) * channels;
      final o = (oy * size + ox) * 3;
      out[o] = rgb[i] / 255;
      out[o + 1] = rgb[i + 1] / 255;
      out[o + 2] = rgb[i + 2] / 255;
    }
  }
  return Preprocessed(out, lb);
}
