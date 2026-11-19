import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/camera_ctrl.dart';
import '../controllers/detection_ctrl.dart';
import 'camera_screen.dart';

class HomeScreen extends GetView<DetectionCtrl> {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.shelves, size: 96, color: cs.primary),
            const SizedBox(height: 16),
            Text('Shelf Scanner',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Point the camera at a supermarket shelf to detect shelf rows, products and empty spaces in real time.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            Obx(() => switch (controller.status.value) {
                  ModelStatus.loading => const Column(children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Loading AI models…'),
                    ]),
                  ModelStatus.error => Column(children: [
                      Text(controller.error.value ?? 'Failed to load models',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cs.error)),
                      const SizedBox(height: 12),
                      OutlinedButton(
                          onPressed: controller.loadModels,
                          child: const Text('Retry')),
                    ]),
                  ModelStatus.ready => FilledButton.icon(
                      onPressed: () => Get.to(
                        () => const CameraScreen(),
                        binding:
                            BindingsBuilder<CameraCtrl>.put(() => CameraCtrl()),
                      ),
                      icon: const Icon(Icons.camera_alt),
                      label: const Padding(
                        padding:
                            EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                        child: Text('Start scanning',
                            style: TextStyle(fontSize: 18)),
                      ),
                    ),
                }),
          ]),
        ),
      ),
    );
  }
}
