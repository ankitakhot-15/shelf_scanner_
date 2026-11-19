import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/detection_ctrl.dart';
import '../models/detection.dart';
import '../widgets/detection_painter.dart';
import '../widgets/stat_chip.dart';

class ReviewScreen extends GetView<DetectionCtrl> {
  const ReviewScreen({super.key, required this.photo});
  final XFile photo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Review photo'),
      ),
      body: Column(children: [
        Expanded(
          child: Center(
            child: Obx(() {
              final result = controller.stillResult.value;
              if (result == null) {
                return Image.file(File(photo.path), fit: BoxFit.contain);
              }
              return AspectRatio(
                aspectRatio: result.imageWidth / result.imageHeight,
                child: Stack(fit: StackFit.expand, children: [
                  Image.file(File(photo.path), fit: BoxFit.fill),
                  CustomPaint(
                    painter: DetectionPainter(
                      shelves: result.shelves ?? const [],
                      items: result.items,
                      showLabels: controller.showLabels.value,
                    ),
                  ),
                ]),
              );
            }),
          ),
        ),
        Obx(() {
          final r = controller.stillResult.value;
          return r == null ? const SizedBox() : _Summary(result: r);
        }),
        Obx(() {
          final e = controller.stillError.value;
          return e == null
              ? const SizedBox()
              : Padding(
                  padding: const EdgeInsets.all(8),
                  child:
                      Text(e, style: const TextStyle(color: Colors.redAccent)),
                );
        }),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Obx(() {
              final busy = controller.stillBusy.value;
              final done = controller.stillResult.value != null;
              return Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : Get.back, // Retake
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retake'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed:
                        busy ? null : () => controller.processStill(photo.path),
                    icon: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.auto_awesome),
                    label: Text(done ? 'Process again' : 'Process'),
                  ),
                ),
              ]);
            }),
          ),
        ),
      ]),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.result});
  final FrameResult result;

  @override
  Widget build(BuildContext context) {
    final products =
        result.items.where((d) => d.kind == DetectionKind.product).length;
    final empty =
        result.items.where((d) => d.kind == DetectionKind.empty).length;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(spacing: 6, children: [
        StatChip(
            label: 'Shelves ${result.shelves?.length ?? 0}',
            color: DetectionPainter.colorFor(DetectionKind.shelf)),
        StatChip(
            label: 'Products $products',
            color: DetectionPainter.colorFor(DetectionKind.product)),
        StatChip(
            label: 'Empty $empty',
            color: DetectionPainter.colorFor(DetectionKind.empty)),
        StatChip(label: '${result.totalMs} ms', color: Colors.amber),
      ]),
    );
  }
}
