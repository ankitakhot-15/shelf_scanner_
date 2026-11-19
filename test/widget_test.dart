// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:shelf_scanner/controllers/camera_ctrl.dart';
import 'package:shelf_scanner/controllers/detection_ctrl.dart';
import 'package:shelf_scanner/screens/home_screen.dart';
import 'package:shelf_scanner/services/detection_service.dart';
import 'package:shelf_scanner/services/video_frame_sampling.dart';
import 'package:shelf_scanner/services/yolo_utils.dart';
import 'package:shelf_scanner/widgets/capture_controls.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    Get.reset();
  });

  tearDown(() {
    Get.reset();
    Get.testMode = false;
  });

  testWidgets('video mode selection pauses detection and returns to photo',
      (tester) async {
    final detectionCtrl =
        Get.put<DetectionCtrl>(_ReadyDetectionCtrl(), permanent: true);
    final cameraCtrl = Get.put<CameraCtrl>(CameraCtrl());

    await tester.pumpWidget(const GetMaterialApp(
      home: Scaffold(body: CaptureControls()),
    ));
    await tester.tap(find.text('Video'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    expect(cameraCtrl.mode.value, CaptureMode.video);
    expect(detectionCtrl.videoMode.value, isTrue);
    expect(detectionCtrl.items.value, isEmpty);

    await tester.tap(find.text('Photo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    expect(cameraCtrl.mode.value, CaptureMode.photo);
    expect(detectionCtrl.videoMode.value, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 60));
  });

  testWidgets('start scanning registers CameraCtrl before building its route',
      (tester) async {
    final detectionCtrl =
        Get.put<DetectionCtrl>(_ReadyDetectionCtrl(), permanent: true);
    detectionCtrl.status.value = ModelStatus.ready;

    await tester.pumpWidget(const GetMaterialApp(home: HomeScreen()));
    await tester.tap(find.text('Start scanning'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(Get.isRegistered<CameraCtrl>(), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 60));
  });

  test('converts RGB input from NHWC to NCHW', () {
    final input = Float32List.fromList([
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12,
    ]);

    expect(
      rgbNhwcToNchw(input, 2),
      Float32List.fromList([1, 4, 7, 10, 2, 5, 8, 11, 3, 6, 9, 12]),
    );
  });

  test('camera frame rotation follows sensor and display orientation', () {
    expect(
      cameraFrameRotation(
        sensorOrientation: 90,
        deviceOrientation: DeviceOrientation.portraitUp,
      ),
      90,
    );
    expect(
      cameraFrameRotation(
        sensorOrientation: 90,
        deviceOrientation: DeviceOrientation.landscapeRight,
      ),
      180,
    );
    expect(
      cameraFrameRotation(
        sensorOrientation: 90,
        deviceOrientation: DeviceOrientation.landscapeLeft,
        manualOffset: 90,
      ),
      90,
    );
  });

  test('decodes the channel-first product model output shape', () {
    const candidates = 8400;
    final output = Float32List(6 * candidates);
    output[0] = 320;
    output[candidates] = 320;
    output[2 * candidates] = 100;
    output[3 * candidates] = 80;
    output[4 * candidates] = 0.9;

    final boxes = decodeYolo(
      output,
      const [1, 6, candidates],
      numClasses: 2,
      extraChannels: 0,
      confThreshold: 0.25,
      inputSize: 640,
    );

    expect(boxes, hasLength(1));
    expect(boxes.single.x1, 270);
    expect(boxes.single.y1, 280);
    expect(boxes.single.x2, 370);
    expect(boxes.single.y2, 360);
    expect(boxes.single.cls, 0);
  });

  test('decodes the shelf segmentation detection head', () {
    const candidates = 8400;
    const channels = 37;
    final output = Float32List(channels * candidates);
    output[0] = 320;
    output[candidates] = 320;
    output[2 * candidates] = 100;
    output[3 * candidates] = 80;
    output[4 * candidates] = 0.9;

    final boxes = decodeYolo(
      output,
      const [1, channels, candidates],
      numClasses: 1,
      extraChannels: 32,
      confThreshold: 0.35,
      inputSize: 640,
    );

    expect(boxes, hasLength(1));
    expect(boxes.single.cls, 0);
    expect(boxes.single.score, closeTo(0.9, 0.00001));
    expect(boxes.single.x1, 270);
    expect(boxes.single.y1, 280);
  });

  test('samples at most eight timestamps across the full video', () {
    final timestamps = sampleVideoTimestamps(30000);

    expect(timestamps, hasLength(8));
    expect(timestamps.first, greaterThan(0));
    expect(timestamps.last, lessThan(30000));
    expect(timestamps.toSet(), hasLength(8));
  });
}

class _ReadyDetectionCtrl extends DetectionCtrl {
  _ReadyDetectionCtrl() : super(DetectionService());

  @override
  Future<void> loadModels() async {}
}
