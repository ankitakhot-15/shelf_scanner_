import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../screens/review_screen.dart';
import '../screens/video_review_screen.dart';
import 'detection_ctrl.dart';

enum CameraStatus { idle, initializing, ready, error }

enum CaptureMode { photo, video }

int cameraFrameRotation({
  required int sensorOrientation,
  required DeviceOrientation deviceOrientation,
  int manualOffset = 0,
}) {
  final deviceDegrees = switch (deviceOrientation) {
    DeviceOrientation.portraitUp => 0,
    DeviceOrientation.landscapeLeft => 90,
    DeviceOrientation.portraitDown => 180,
    DeviceOrientation.landscapeRight => 270,
  };
  return (sensorOrientation - deviceDegrees + manualOffset + 360) % 360;
}

class CameraCtrl extends GetxController with WidgetsBindingObserver {
  CameraController? cameraController;

  final status = CameraStatus.idle.obs;
  final errorMessage = RxnString();
  final mode = CaptureMode.photo.obs;
  final flashMode = FlashMode.off.obs;
  final isRecording = false.obs;
  final recordSeconds = 0.obs;
  final rotationOffset = 0.obs;

  Timer? _timer;
  bool _recordingCommandInProgress = false;
  void Function(CameraImage image, int rotation)? onFrame;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    onFrame = Get.find<DetectionCtrl>().onCameraFrame;
  }

  @override
  void onReady() {
    super.onReady();
    start();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    onFrame = null;
    releaseCamera(force: true);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      releaseCamera(); 
    } else if (state == AppLifecycleState.resumed) {
      start();
    }
  }

  Future<void> start() async {
    await initialize();
    await startStream();
  }

  Future<void> initialize() async {
    if (status.value == CameraStatus.initializing ||
        status.value == CameraStatus.ready) {
      return;
    }
    status.value = CameraStatus.initializing;
    errorMessage.value = null;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw CameraException('none', 'No camera found');
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final c = CameraController(
        back,
        ResolutionPreset.medium, 
        enableAudio: true, 
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await c.initialize();
      await c.setFlashMode(FlashMode.off);
      cameraController = c;
      flashMode.value = FlashMode.off;
      status.value = CameraStatus.ready;
    } on CameraException catch (e) {
      errorMessage.value = _describeCameraError(e);
      status.value = CameraStatus.error;
    } catch (e) {
      errorMessage.value = e.toString();
      status.value = CameraStatus.error;
    }
  }

  Future<void> releaseCamera({bool force = false}) async {
    if (!force && status.value == CameraStatus.initializing) {
      return;
    }
    _timer?.cancel();
    final c = cameraController;
    cameraController = null;
    status.value = CameraStatus.idle;
    isRecording.value = false;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    try {
      await c?.dispose();
    } catch (_) {}
  }
  int _rotationFor() {
    final c = cameraController;
    return cameraFrameRotation(
      sensorOrientation: c?.description.sensorOrientation ?? 90,
      deviceOrientation:
          c?.value.deviceOrientation ?? DeviceOrientation.portraitUp,
      manualOffset: rotationOffset.value,
    );
  }

  Future<void> startStream() async {
    final c = cameraController;
    if (c == null || !c.value.isInitialized || c.value.isStreamingImages) {
      return;
    }
    try {
      await c.startImageStream((img) => onFrame?.call(img, _rotationFor()));
    } catch (e) {
      debugPrint('startImageStream failed: $e');
    }
  }

  Future<void> stopStream() async {
    final c = cameraController;
    if (c == null || !c.value.isStreamingImages) return;
    try {
      await c.stopImageStream();
    } catch (_) {}
  }

  void cycleRotation() =>
      rotationOffset.value = (rotationOffset.value + 90) % 360;

  void setMode(CaptureMode m) {
    if (isRecording.value || mode.value == m) return;
    mode.value = m;
    Get.find<DetectionCtrl>().setVideoMode(m == CaptureMode.video);
    if (m == CaptureMode.photo) {
      unawaited(startStream());
    }
  }

  Future<void> toggleFlash() async {
    final c = cameraController;
    if (c == null) return;
    final next =
        flashMode.value == FlashMode.off ? FlashMode.torch : FlashMode.off;
    await c.setFlashMode(next);
    flashMode.value = next;
  }
  Future<void> onShutter() async {
    if (mode.value == CaptureMode.photo) {
      final file = await capturePhoto();
      if (file == null) return;
      Get.find<DetectionCtrl>().clearStill();
      await Get.to(
          () => ReviewScreen(photo: file)); 
      await startStream(); 
    } else if (isRecording.value) {
      final path = await stopRecording();
      if (path == null) {
        Get.snackbar(
          'Error',
          errorMessage.value ?? 'Could not save video',
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 4),
        );
        return;
      }

      Get.find<DetectionCtrl>().clearVideo();
      await Get.to(() => VideoReviewScreen(videoPath: path));
    } else {
      await startRecording();
    }
  }

  Future<XFile?> capturePhoto() async {
    final c = cameraController;
    if (c == null || c.value.isTakingPicture || isRecording.value) return null;
    try {
      await stopStream();
      return await c.takePicture();
    } on CameraException catch (e) {
      errorMessage.value = _describeCameraError(e);
      await startStream();
      return null;
    }
  }

  Future<void> startRecording() async {
    final c = cameraController;
    if (c == null ||
        isRecording.value ||
        c.value.isRecordingVideo ||
        _recordingCommandInProgress) {
      return;
    }

    _recordingCommandInProgress = true;
    errorMessage.value = null;
    try {
      await stopStream();
      await c.startVideoRecording();
      Get.find<DetectionCtrl>().clearLiveResults();
      isRecording.value = true;
      recordSeconds.value = 0;
      _timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => recordSeconds.value++,
      );
    } on CameraException catch (e) {
      errorMessage.value = _describeCameraError(e);
      if (mode.value == CaptureMode.photo) {
        await startStream();
      }
      Get.snackbar(
        'Could not start video',
        errorMessage.value!,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 5),
      );
    } catch (e) {
      errorMessage.value = e.toString();
      if (mode.value == CaptureMode.photo) {
        await startStream();
      }
      Get.snackbar(
        'Could not start video',
        errorMessage.value!,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 5),
      );
    } finally {
      _recordingCommandInProgress = false;
    }
  }

  String _describeCameraError(CameraException error) {
    switch (error.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
      case 'CameraAccessRestricted':
        return 'Camera permission is unavailable. Allow camera access in app settings, then try again.';
      case 'AudioAccessDenied':
      case 'AudioAccessDeniedWithoutPrompt':
      case 'AudioAccessRestricted':
        return 'Microphone permission is unavailable. Allow microphone access in app settings to record video with sound.';
      default:
        return error.description ?? error.code;
    }
  }
  Future<String?> stopRecording() async {
    final c = cameraController;
    if (c == null || !c.value.isRecordingVideo || _recordingCommandInProgress) {
      return null;
    }

    _recordingCommandInProgress = true;
    _timer?.cancel();
    errorMessage.value = null;
    String? savedPath;
    try {
      final file = await c.stopVideoRecording();
      final dir = (await getExternalStorageDirectory()) ??
          await getApplicationDocumentsDirectory();
      await dir.create(recursive: true);
      savedPath = p.join(
          dir.path, 'shelf_${DateTime.now().millisecondsSinceEpoch}.mp4');
      await File(file.path).copy(savedPath);
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isRecording.value = false;
      _recordingCommandInProgress = false;
      if (mode.value == CaptureMode.photo) {
        await startStream();
      }
    }
    return savedPath;
  }
}
