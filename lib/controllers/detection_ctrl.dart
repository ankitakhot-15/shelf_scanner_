import 'package:camera/camera.dart';
import 'package:get/get.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as video_thumbnail;
import '../core/app_config.dart';
import '../models/detection.dart';
import '../services/detection_service.dart';
import '../services/video_frame_sampling.dart';

enum ModelStatus { loading, ready, error }

class DetectionCtrl extends GetxController {
  DetectionCtrl(this._service);
  final DetectionService _service;
  final status = ModelStatus.loading.obs;
  final error = RxnString();
  final liveEnabled = true.obs;
  final videoMode = false.obs;
  final showLabels = true.obs;
  final shelves = Rx<List<Detection>>(const []);
  final items = Rx<List<Detection>>(const []);
  final fps = 0.0.obs;
  final inferenceMs = 0.obs;
  int _frameCounter = 0;
  DateTime? _lastResultAt;
  final stillResult = Rxn<FrameResult>();
  final stillBusy = false.obs;
  final stillError = RxnString();
  final videoFrames = Rx<List<VideoSampleResult>>(const []);
  final videoBusy = false.obs;
  final videoError = RxnString();
  final videoProgress = 0.0.obs;
  final videoProcessedFrames = 0.obs;
  final videoFrameCount = 0.obs;

  int get productCount =>
      items.value.where((d) => d.kind == DetectionKind.product).length;
  int get emptyCount =>
      items.value.where((d) => d.kind == DetectionKind.empty).length;

  @override
  void onInit() {
    super.onInit();
    loadModels(); 
  }

  Future<void> loadModels() async {
    status.value = ModelStatus.loading;
    error.value = null;
    try {
      await _service.init();
      status.value = ModelStatus.ready;
    } catch (e) {
      error.value =
          'AI model loading failed. Check the bundled model files. $e';
      status.value = ModelStatus.error;
    }
  }

  Future<void> onCameraFrame(CameraImage image, int rotation) async {
    if (!liveEnabled.value ||
        videoMode.value ||
        status.value != ModelStatus.ready) {
      return;
    }
    final runShelf = _frameCounter++ % AppConfig.shelfEveryNFrames == 0;
    try {
      final r = await _service.detectFrame(image, rotation, runShelf: runShelf);
      if (r == null || !liveEnabled.value || videoMode.value) return;
      if (r.shelves != null) shelves.value = r.shelves!;
      items.value = r.items;
      inferenceMs.value = r.totalMs;

      final now = DateTime.now();
      if (_lastResultAt != null) {
        final inst =
            1000 / now.difference(_lastResultAt!).inMilliseconds.clamp(1, 5000);
        fps.value =
            fps.value == 0 ? inst : fps.value * 0.8 + inst * 0.2; 
      }
      _lastResultAt = now;
    } catch (e) {
      error.value = e.toString();
    }
  }

  void setLive(bool value) {
    liveEnabled.value = value;
    if (!value) {
      clearLiveResults();
    }
  }

  void setVideoMode(bool value) {
    videoMode.value = value;
    if (value) {
      clearLiveResults();
    }
  }

  void clearLiveResults() {
    shelves.value = const [];
    items.value = const [];
    fps.value = 0;
    inferenceMs.value = 0;
    _lastResultAt = null;
  }

  void setShowLabels(bool value) => showLabels.value = value;
  void clearStill() {
    stillResult.value = null;
    stillError.value = null;
    stillBusy.value = false;
  }

  Future<void> processStill(String path) async {
    stillBusy.value = true;
    stillError.value = null;
    try {
      stillResult.value = await _service.detectStill(path);
    } catch (e) {
      stillError.value = e.toString();
    }
    stillBusy.value = false;
  }

  void clearVideo() {
    videoFrames.value = const [];
    videoError.value = null;
    videoProgress.value = 0;
    videoProcessedFrames.value = 0;
    videoFrameCount.value = 0;
  }

  Future<void> processVideo(String path, int durationMs) async {
    if (videoBusy.value) return;

    clearVideo();
    videoBusy.value = true;
    videoError.value = null;
    try {
      final timestamps = sampleVideoTimestamps(durationMs);
      videoFrameCount.value = timestamps.length;
      final frames = <VideoSampleResult>[];

      for (final timeMs in timestamps) {
        final bytes = await video_thumbnail.VideoThumbnail.thumbnailData(
          video: path,
          timeMs: timeMs,
          imageFormat: video_thumbnail.ImageFormat.JPEG,
          maxWidth: AppConfig.inputSize,
          quality: 85,
        );
        if (bytes == null || bytes.isEmpty) {
          throw StateError('Could not read a video frame at ${timeMs}ms');
        }

        final result = await _service.detectImage(bytes);
        frames.add(VideoSampleResult(
          timeMs: timeMs,
          imageBytes: bytes,
          result: result,
        ));
        videoFrames.value = List.unmodifiable(frames);
        videoProcessedFrames.value = frames.length;
        videoProgress.value = frames.length / timestamps.length;
      }
    } catch (e) {
      videoError.value = e.toString();
    } finally {
      videoBusy.value = false;
    }
  }

  @override
  void onClose() {
    _service.dispose();
    super.onClose();
  }
}
