import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/camera_ctrl.dart';
import '../controllers/detection_ctrl.dart';
import '../models/detection.dart';
import 'detection_painter.dart';
import 'stat_chip.dart';

class TopHud extends StatelessWidget {
  const TopHud({super.key});

  @override
  Widget build(BuildContext context) {
    final det = Get.find<DetectionCtrl>();
    final cam = Get.find<CameraCtrl>();

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
        ),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: Get.back,
          ),
          const Spacer(),
          Obx(() => StatChip(
                icon: Icons.speed,
                color: Colors.amber,
                label: det.videoMode.value
                    ? 'Paused for video'
                    : det.liveEnabled.value
                        ? '${det.fps.value.toStringAsFixed(1)} FPS · ${det.inferenceMs.value} ms'
                        : 'Detection off',
              )),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (v) {
              if (v == 'rotate') cam.cycleRotation();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'rotate',
                child:
                    Text('Rotate AI frame (now +${cam.rotationOffset.value}°)'),
              ),
            ],
          ),
        ]),
        Obx(() => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              StatChip(
                  label: 'Shelves ${det.shelves.value.length}',
                  color: DetectionPainter.colorFor(DetectionKind.shelf),
                  icon: Icons.view_agenda),
              const SizedBox(width: 6),
              StatChip(
                  label: 'Products ${det.productCount}',
                  color: DetectionPainter.colorFor(DetectionKind.product),
                  icon: Icons.inventory_2),
              const SizedBox(width: 6),
              StatChip(
                  label: 'Empty ${det.emptyCount}',
                  color: DetectionPainter.colorFor(DetectionKind.empty),
                  icon: Icons.crop_square),
            ])),
        const SizedBox(height: 6),
        Obx(() => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              FilterChip(
                label: const Text('Live detect'),
                selected: det.liveEnabled.value,
                onSelected: det.videoMode.value ? null : det.setLive,
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Labels'),
                selected: det.showLabels.value,
                onSelected: det.setShowLabels,
              ),
            ])),
      ]),
    );
  }
}
