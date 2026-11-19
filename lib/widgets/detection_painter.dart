import 'package:flutter/material.dart';

import '../models/detection.dart';

/// Draws bounding boxes + "label 87%" tags on top of the camera / photo.
/// Boxes are normalised (0..1), so this works for any widget size.
class DetectionPainter extends CustomPainter {
  DetectionPainter(
      {required this.shelves, required this.items, required this.showLabels});

  final List<Detection> shelves;
  final List<Detection> items;
  final bool showLabels;

  static Color colorFor(DetectionKind k) => switch (k) {
        DetectionKind.shelf => const Color(0xFF29B6F6), // blue
        DetectionKind.product => const Color(0xFF66BB6A), // green
        DetectionKind.empty => const Color(0xFFEF5350), // red
      };

  @override
  void paint(Canvas canvas, Size size) {
    for (final d in shelves) {
      _draw(canvas, size, d, stroke: 3, fill: true, fontSize: 12);
    }
    for (final d in items) {
      _draw(canvas, size, d, stroke: 1.6, fill: false, fontSize: 9);
    }
  }

  void _draw(Canvas canvas, Size size, Detection d,
      {required double stroke, required bool fill, required double fontSize}) {
    final color = colorFor(d.kind);
    final rect = Rect.fromLTRB(
      d.box.left * size.width,
      d.box.top * size.height,
      d.box.right * size.width,
      d.box.bottom * size.height,
    );
    if (fill) {
      canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.10));
    }
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = color,
    );

    if (!showLabels) return;
    final tp = TextPainter(
      text: TextSpan(
        text: ' ${d.label} ${d.confidence.toStringAsFixed(2)} ',
        style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final dy = rect.top - tp.height >= 0 ? rect.top - tp.height : rect.top;
    final tagRect = Rect.fromLTWH(rect.left, dy, tp.width, tp.height);
    canvas.drawRect(tagRect, Paint()..color = color);
    tp.paint(canvas, tagRect.topLeft);
  }

  @override
  bool shouldRepaint(DetectionPainter old) =>
      old.shelves != shelves ||
      old.items != items ||
      old.showLabels != showLabels;
}
