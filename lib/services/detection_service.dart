import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import '../core/app_config.dart';
import '../models/detection.dart';
import 'frame_preprocessor.dart';
import 'yolo_runner.dart';

class WorkerInit {
  final SendPort reply;
  final Uint8List productModel, shelfModel;
  const WorkerInit(this.reply, this.productModel, this.shelfModel);
}

class WorkerJob {
  final int id;
  final YuvFrame? yuv; // live camera frame ...
  final String? stillPath; // ... or a captured JPEG
  final Uint8List? stillBytes; // ... or an extracted video frame
  final bool runShelf;
  const WorkerJob(
      this.id, this.yuv, this.stillPath, this.stillBytes, this.runShelf);
}

class WorkerResult {
  final int id;
  final FrameResult? result;
  final String? error;
  const WorkerResult(this.id, this.result, this.error);
}

// ───────────────────────── worker isolate (heavy work) ────────────────────

void _workerMain(WorkerInit init) {
  final port = ReceivePort();
  late final YoloRunner product;
  late final YoloRunner shelf;
  try {
    try {
      product = YoloRunner(
        init.productModel,
        numClasses: AppConfig.productClasses,
        labels: const ['empty space', 'product'],
        kinds: const [DetectionKind.empty, DetectionKind.product],
        threads: AppConfig.interpreterThreads,
      );
    } catch (e) {
      throw StateError('Product model initialization failed: $e');
    }
    try {
      shelf = YoloRunner(
        init.shelfModel,
        numClasses: AppConfig.shelfClasses,
        extraChannels: AppConfig.segMaskCoeffs,
        labels: const ['shelf'],
        kinds: const [DetectionKind.shelf],
        threads: AppConfig.interpreterThreads,
      );
    } catch (e) {
      product.close();
      throw StateError('Shelf model initialization failed: $e');
    }
  } catch (e) {
    init.reply.send('Could not load models: $e');
    return;
  }
  init.reply.send(port.sendPort); // "ready"

  port.listen((msg) {
    if (msg is! WorkerJob) return;
    try {
      final sw = Stopwatch()..start();
      final pre = msg.yuv != null
          ? preprocessYuv(msg.yuv!, AppConfig.inputSize)
          : msg.stillBytes != null
              ? _loadImageBytes(msg.stillBytes!)
              : _loadStill(msg.stillPath!);

      final items = product.detect(pre.tensor, pre.letterbox,
          conf: AppConfig.productConfidence, iou: AppConfig.nmsIou);
      final shelves = msg.runShelf
          ? shelf.detect(pre.tensor, pre.letterbox,
              conf: AppConfig.shelfConfidence, iou: AppConfig.nmsIou)
          : null;

      init.reply.send(WorkerResult(
        msg.id,
        FrameResult(
          shelves: shelves,
          items: items,
          imageWidth: pre.letterbox.srcW,
          imageHeight: pre.letterbox.srcH,
          totalMs: sw.elapsedMilliseconds,
        ),
        null,
      ));
    } catch (e) {
      init.reply.send(WorkerResult(msg.id, null, e.toString()));
    }
  });
}

Preprocessed _loadStill(String path) {
  return _loadImageBytes(File(path).readAsBytesSync());
}

Preprocessed _loadImageBytes(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw StateError('Cannot decode image');
  final upright = img.bakeOrientation(decoded); // apply EXIF rotation
  final rgbBytes = upright.getBytes(order: img.ChannelOrder.rgb);
  final channels = rgbBytes.length ~/ (upright.width * upright.height);
  return preprocessRgb(
      rgbBytes, upright.width, upright.height, channels, AppConfig.inputSize);
}

// ───────────────────────── facade used by the app ─────────────────────────

/// Owns the worker isolate. All inference happens off the UI thread, so the
/// camera preview stays smooth.
class DetectionService {
  Isolate? _isolate;
  ReceivePort? _fromWorker;
  SendPort? _toWorker;
  final _pending = <int, Completer<FrameResult>>{};
  int _nextId = 0;
  bool _busy = false;

  bool get isReady => _toWorker != null;

  Future<void> init() async {
    if (isReady) return;
    final productBytes = await _loadAsset(AppConfig.productModelAsset);
    final shelfBytes = await _loadAsset(AppConfig.shelfModelAsset);

    final recv = ReceivePort();
    final ready = Completer<SendPort>();
    recv.listen((m) {
      if (m is SendPort) {
        ready.complete(m);
      } else if (m is String) {
        if (!ready.isCompleted) ready.completeError(m);
      } else if (m is WorkerResult) {
        final c = _pending.remove(m.id);
        if (c == null) return;
        m.result != null
            ? c.complete(m.result!)
            : c.completeError(m.error ?? 'Unknown error');
      }
    });
    _fromWorker = recv;
    _isolate = await Isolate.spawn(
        _workerMain, WorkerInit(recv.sendPort, productBytes, shelfBytes));
    _toWorker = await ready.future;
  }

  Future<Uint8List> _loadAsset(String path) async {
    final d = await rootBundle.load(path);
    return d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes);
  }

  /// Returns null when the worker is still busy (frame is dropped - this is
  /// what keeps the camera smooth when inference is slower than the camera).
  Future<FrameResult?> detectFrame(CameraImage image, int rotation,
      {required bool runShelf}) async {
    if (_busy || _toWorker == null || image.planes.length != 3) return null;
    _busy = true;
    try {
      // Copy bytes NOW: CameraImage buffers are reused after this callback.
      final frame = YuvFrame(
        width: image.width,
        height: image.height,
        y: Uint8List.fromList(image.planes[0].bytes),
        u: Uint8List.fromList(image.planes[1].bytes),
        v: Uint8List.fromList(image.planes[2].bytes),
        yRowStride: image.planes[0].bytesPerRow,
        uvRowStride: image.planes[1].bytesPerRow,
        uvPixelStride: image.planes[1].bytesPerPixel ?? 1,
        rotation: rotation,
      );
      return await _send(WorkerJob(_nextId++, frame, null, null, runShelf));
    } finally {
      _busy = false;
    }
  }

  /// Full detection (products + shelves) on a captured photo.
  Future<FrameResult> detectStill(String path) async {
    while (_busy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    _busy = true;
    try {
      return await _send(WorkerJob(_nextId++, null, path, null, true));
    } finally {
      _busy = false;
    }
  }

  Future<FrameResult> detectImage(Uint8List imageBytes) async {
    while (_busy) {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
    _busy = true;
    try {
      return await _send(WorkerJob(_nextId++, null, null, imageBytes, true));
    } finally {
      _busy = false;
    }
  }

  Future<FrameResult> _send(WorkerJob job) {
    final c = Completer<FrameResult>();
    _pending[job.id] = c;
    _toWorker!.send(job);
    return c.future;
  }

  void dispose() {
    _isolate?.kill(priority: Isolate.immediate);
    _fromWorker?.close();
    _isolate = null;
    _toWorker = null;
  }
}
