import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/camera_ctrl.dart';

/// Bottom controls: mode switch, flash, shutter / record button.
class CaptureControls extends StatelessWidget {
  const CaptureControls({super.key});

  @override
  Widget build(BuildContext context) {
    final cam = Get.find<CameraCtrl>();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withValues(alpha: 0.75), Colors.transparent],
        ),
      ),
      child: Obx(() {
        final isVideo = cam.mode.value == CaptureMode.video;
        final recording = cam.isRecording.value;
        return Column(mainAxisSize: MainAxisSize.min, children: [
          if (recording)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.fiber_manual_record,
                    color: Colors.red, size: 14),
                const SizedBox(width: 6),
                Text(_fmt(cam.recordSeconds.value),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ]),
            ),
          SegmentedButton<CaptureMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                  value: CaptureMode.photo,
                  icon: Icon(Icons.photo_camera),
                  label: Text('Photo')),
              ButtonSegment(
                  value: CaptureMode.video,
                  icon: Icon(Icons.videocam),
                  label: Text('Video')),
            ],
            selected: {cam.mode.value},
            onSelectionChanged: recording ? null : (s) => cam.setMode(s.first),
          ),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            IconButton.filledTonal(
              iconSize: 28,
              onPressed: cam.toggleFlash,
              icon: Icon(cam.flashMode.value == FlashMode.torch
                  ? Icons.flash_on
                  : Icons.flash_off),
            ),
            GestureDetector(
              onTap: cam.onShutter,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 76,
                height: 76,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isVideo ? Colors.red : Colors.white,
                    shape: recording ? BoxShape.rectangle : BoxShape.circle,
                    borderRadius: recording ? BorderRadius.circular(10) : null,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 48), // keeps the shutter centred
          ]),
        ]);
      }),
    );
  }

  static String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}
