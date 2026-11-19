import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/camera_ctrl.dart';
import '../widgets/capture_controls.dart';
import '../widgets/detection_overlay.dart';
import '../widgets/top_hud.dart';

class CameraScreen extends GetView<CameraCtrl> {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Obx(() {
          switch (controller.status.value) {
            case CameraStatus.idle:
            case CameraStatus.initializing:
              return const Center(child: CircularProgressIndicator());
            case CameraStatus.error:
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.no_photography,
                        color: Colors.white54, size: 64),
                    const SizedBox(height: 12),
                    Text(controller.errorMessage.value ?? 'Camera error',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white)),
                    const SizedBox(height: 16),
                    FilledButton(
                        onPressed: controller.start,
                        child: const Text('Try again')),
                  ]),
                ),
              );
            case CameraStatus.ready:
              final c = controller.cameraController;
              return c == null ? const SizedBox() : _buildCamera(c);
          }
        }),
      ),
    );
  }

  Widget _buildCamera(CameraController c) {
    return Stack(children: [
      Center(
        child: CameraPreview(
          c,
          child: const DetectionOverlay(),
        ),
      ),
      const Positioned(top: 0, left: 0, right: 0, child: TopHud()),
      const Positioned(bottom: 0, left: 0, right: 0, child: CaptureControls()),
    ]);
  }
}
