import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../models/detection.dart';
import 'yolo_utils.dart';

/// Wraps ONE tflite YOLO11 model (detect or segment).
/// Must be created and used inside the same isolate.
class YoloRunner {
  factory YoloRunner(
    Uint8List modelBytes, {
    required int numClasses,
    required List<String> labels,
    required List<DetectionKind> kinds,
    int extraChannels = 0,
    int threads = 4,
  }) {
    if (Platform.isAndroid) {
      Interpreter? interpreter;
      GpuDelegateV2? delegate;
      try {
        delegate = GpuDelegateV2();
        final options = InterpreterOptions()..threads = threads;
        try {
          options.addDelegate(delegate);
          interpreter = Interpreter.fromBuffer(modelBytes, options: options);
        } finally {
          options.delete();
        }
        return YoloRunner._(
          interpreter,
          numClasses: numClasses,
          labels: labels,
          kinds: kinds,
          extraChannels: extraChannels,
          delegate: delegate,
        );
      } catch (e) {
        interpreter?.close();
        delegate?.delete();
        debugPrint('TFLite GPU initialization failed; retrying on CPU: $e');
      }
    }

    final options = InterpreterOptions()..threads = threads;
    Interpreter? interpreter;
    try {
      interpreter = Interpreter.fromBuffer(modelBytes, options: options);
      return YoloRunner._(
        interpreter,
        numClasses: numClasses,
        labels: labels,
        kinds: kinds,
        extraChannels: extraChannels,
      );
    } catch (_) {
      interpreter?.close();
      rethrow;
    } finally {
      options.delete();
    }
  }

  YoloRunner._(
    this._interpreter, {
    required this.numClasses,
    required this.labels,
    required this.kinds,
    required this.extraChannels,
    GpuDelegateV2? delegate,
  }) : _delegate = delegate {
    final inShape = _interpreter.getInputTensor(0).shape;
    if (inShape.length != 4 || inShape[0] != 1) {
      throw StateError(
          'Unexpected input shape $inShape (expected a batch of 1 RGB images)');
    }
    if (inShape[3] == 3 && inShape[1] == inShape[2]) {
      _channelsFirst = false;
      inputSize = inShape[1];
    } else if (inShape[1] == 3 && inShape[2] == inShape[3]) {
      _channelsFirst = true;
      inputSize = inShape[2];
    } else {
      throw StateError(
          'Unexpected input shape $inShape (expected [1,H,W,3] or [1,3,H,W])');
    }
    _detOutput = _findDetectionOutput();
    _interpreter.allocateTensors();
  }

  final Interpreter _interpreter;
  final GpuDelegateV2? _delegate;
  final int numClasses;
  final int extraChannels; // 32 for the -seg model
  final List<String> labels;
  final List<DetectionKind> kinds;
  late final bool _channelsFirst;
  late final int inputSize;
  late final int _detOutput;

  /// The seg model has 2 outputs (detections + mask prototypes).
  /// Pick the one whose shape contains 4 + nc + extra channels.
  int _findDetectionOutput() {
    final channels = 4 + numClasses + extraChannels;
    final outs = _interpreter.getOutputTensors();
    for (var i = 0; i < outs.length; i++) {
      final s = outs[i].shape;
      if (s.length == 3 && (s[1] == channels || s[2] == channels)) return i;
    }
    throw StateError(
        'No detection output with $channels channels. Shapes: ${outs.map((t) => t.shape).toList()}');
  }

  List<Detection> detect(
    Float32List input,
    Letterbox lb, {
    required double conf,
    required double iou,
  }) {
    final modelInput = _channelsFirst ? rgbNhwcToNchw(input, inputSize) : input;
    _interpreter.getInputTensor(0).data = modelInput.buffer
        .asUint8List(modelInput.offsetInBytes, modelInput.lengthInBytes);
    _interpreter.invoke();

    final tensor = _interpreter.getOutputTensor(_detOutput);
    final out = Uint8List.fromList(tensor.data).buffer.asFloat32List();

    final raw = decodeYolo(
      out,
      tensor.shape,
      numClasses: numClasses,
      extraChannels: extraChannels,
      confThreshold: conf,
      inputSize: inputSize,
    );
    final kept = nms(raw, iou);

    // model pixels -> original upright image -> normalised 0..1
    double nx(double v) =>
        (((v - lb.padX) / lb.scale) / lb.srcW).clamp(0.0, 1.0);
    double ny(double v) =>
        (((v - lb.padY) / lb.scale) / lb.srcH).clamp(0.0, 1.0);

    final result = <Detection>[];
    for (final b in kept) {
      final box = NormBox(nx(b.x1), ny(b.y1), nx(b.x2), ny(b.y2));
      if (box.width < 0.005 || box.height < 0.005) continue;
      result.add(Detection(box, kinds[b.cls], labels[b.cls], b.score));
    }
    return result;
  }

  void close() {
    _interpreter.close();
    _delegate?.delete();
  }
}
