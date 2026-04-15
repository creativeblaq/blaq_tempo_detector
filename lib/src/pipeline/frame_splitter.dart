import 'dart:typed_data';

class FrameSplitter {
  const FrameSplitter._();

  /// Splits [samples] into overlapping frames of [frameSize] with [hopSize] step.
  ///
  /// Returns a lazy iterable. The last frame is zero-padded if it extends
  /// past the end of [samples]. Returns empty iterable if [samples] is empty.
  static Iterable<Float64List> split(
    Float64List samples, {
    required int frameSize,
    required int hopSize,
  }) sync* {
    for (var offset = 0; offset < samples.length; offset += hopSize) {
      // Skip frames where fewer than hopSize real samples remain at this offset,
      // except for the very first frame (offset == 0) which is always emitted.
      final remaining = samples.length - offset;
      if (offset > 0 && remaining <= hopSize) break;

      final end = offset + frameSize;
      if (end <= samples.length) {
        yield Float64List.sublistView(samples, offset, end);
      } else {
        final frame = Float64List(frameSize);
        frame.setRange(0, remaining, samples, offset);
        yield frame;
      }
    }
  }
}
