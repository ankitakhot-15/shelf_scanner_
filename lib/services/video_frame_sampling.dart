import 'dart:math' as math;

List<int> sampleVideoTimestamps(int durationMs, {int maxFrames = 8}) {
  if (durationMs <= 0) {
    throw ArgumentError.value(durationMs, 'durationMs', 'Must be positive');
  }
  if (maxFrames < 1) {
    throw ArgumentError.value(maxFrames, 'maxFrames', 'Must be positive');
  }

  final frameCount = math.min(
    maxFrames,
    math.max(1, (durationMs / 1000).ceil()),
  );
  return List<int>.generate(
    frameCount,
    (index) => ((index * 2 + 1) * durationMs / (frameCount * 2)).floor(),
  );
}
