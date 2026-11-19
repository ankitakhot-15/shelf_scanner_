import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/detection_ctrl.dart';
import 'detection_painter.dart';

/// Live overlay. Obx rebuilds ONLY this widget when detections change.
class DetectionOverlay extends StatelessWidget {
  const DetectionOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final det = Get.find<DetectionCtrl>();
    return IgnorePointer(
      child: RepaintBoundary(
        child: Obx(
          () => CustomPaint(
            size: Size.infinite,
            painter: DetectionPainter(
              shelves: det.shelves.value,
              items: det.items.value,
              showLabels: det.showLabels.value,
            ),
          ),
        ),
      ),
    );
  }
}
