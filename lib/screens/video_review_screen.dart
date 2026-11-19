import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import '../controllers/detection_ctrl.dart';
import '../models/detection.dart';
import '../widgets/detection_painter.dart';
import '../widgets/stat_chip.dart';

class VideoReviewScreen extends StatefulWidget {
  const VideoReviewScreen({super.key, required this.videoPath});

  final String videoPath;

  @override
  State<VideoReviewScreen> createState() => _VideoReviewScreenState();
}

class _VideoReviewScreenState extends State<VideoReviewScreen> {
  late final VideoPlayerController _player;
  bool _playerReady = false;
  int _selectedFrame = 0;

  DetectionCtrl get _detection => Get.find<DetectionCtrl>();

  @override
  void initState() {
    super.initState();
    _player = VideoPlayerController.file(File(widget.videoPath));
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _player.initialize();
      if (!mounted) return;
      setState(() => _playerReady = true);
      await _detection.processVideo(
        widget.videoPath,
        _player.value.duration.inMilliseconds,
      );
    } catch (e) {
      _detection.videoError.value = e.toString();
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Video detection results'),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: _playerReady
                ? Center(
                    child: AspectRatio(
                      aspectRatio: _player.value.aspectRatio,
                      child: VideoPlayer(_player),
                    ),
                  )
                : const Center(child: CircularProgressIndicator()),
          ),
          if (_playerReady)
            Row(
              children: [
                IconButton(
                  color: Colors.white,
                  onPressed: () async {
                    if (_player.value.isPlaying) {
                      await _player.pause();
                    } else {
                      await _player.play();
                    }
                    if (mounted) setState(() {});
                  },
                  icon: Icon(
                    _player.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  ),
                ),
                Expanded(
                  child: VideoProgressIndicator(
                    _player,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: Colors.tealAccent,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
          Expanded(
            flex: 3,
            child: Obx(() {
              final frames = _detection.videoFrames.value;
              if (frames.isEmpty) {
                final error = _detection.videoError.value;
                if (error != null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Could not analyze video: $error',
                        style: const TextStyle(color: Colors.redAccent),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (_detection.videoBusy.value) {
                  return _Progress(
                    processed: _detection.videoProcessedFrames.value,
                    total: _detection.videoFrameCount.value,
                    progress: _detection.videoProgress.value,
                  );
                }
                return const Center(
                  child: Text(
                    'Preparing video for analysis…',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }

              final index = _selectedFrame.clamp(0, frames.length - 1);
              final sample = frames[index];
              return Column(
                children: [
                  if (_detection.videoBusy.value)
                    _Progress(
                      processed: _detection.videoProcessedFrames.value,
                      total: _detection.videoFrameCount.value,
                      progress: _detection.videoProgress.value,
                    ),
                  if (_detection.videoError.value != null)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        _detection.videoError.value!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  Expanded(
                    child: PageView.builder(
                      itemCount: frames.length,
                      onPageChanged: (page) =>
                          setState(() => _selectedFrame = page),
                      itemBuilder: (context, page) {
                        final frame = frames[page];
                        return Center(
                          child: AspectRatio(
                            aspectRatio: frame.result.imageWidth /
                                frame.result.imageHeight,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.memory(
                                  frame.imageBytes,
                                  fit: BoxFit.fill,
                                ),
                                CustomPaint(
                                  painter: DetectionPainter(
                                    shelves: frame.result.shelves ?? const [],
                                    items: frame.result.items,
                                    showLabels: _detection.showLabels.value,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Text(
                    'Frame ${index + 1}/${frames.length} · '
                    '${(sample.timeMs / 1000).toStringAsFixed(1)} s',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  _Summary(result: sample.result),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({
    required this.processed,
    required this.total,
    required this.progress,
  });

  final int processed;
  final int total;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 6),
          Text(
            'Analyzing video frames: $processed/$total',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
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
      child: Wrap(
        spacing: 6,
        children: [
          StatChip(
            label: 'Shelves ${result.shelves?.length ?? 0}',
            color: DetectionPainter.colorFor(DetectionKind.shelf),
          ),
          StatChip(
            label: 'Products $products',
            color: DetectionPainter.colorFor(DetectionKind.product),
          ),
          StatChip(
            label: 'Empty $empty',
            color: DetectionPainter.colorFor(DetectionKind.empty),
          ),
          StatChip(label: '${result.totalMs} ms', color: Colors.amber),
        ],
      ),
    );
  }
}
