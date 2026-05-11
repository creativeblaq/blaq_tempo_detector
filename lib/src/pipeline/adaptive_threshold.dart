import 'dart:math';
import 'dart:typed_data';

/// Moving-median adaptive thresholding used by all novelty / onset curves
/// in this package.
///
/// Two-pass algorithm: first computes the moving median over a ~0.5 s window
/// from the *original* signal, then subtracts and half-wave rectifies in a
/// second pass. The two-pass form is required so the thresholded curves from
/// different detectors (onset, chroma novelty, log-mel flux) remain
/// scale-comparable for later fusion — a one-pass form would pollute later
/// windows with already-subtracted values.
class AdaptiveThreshold {
  const AdaptiveThreshold._();

  /// Mutates [signal] in place, subtracting the moving median and clamping
  /// non-negative. Window size is ~0.5 s of frames given [sampleRate] and
  /// [hopSize], with a minimum of 3 frames.
  static void apply(
    Float64List signal, {
    required int sampleRate,
    required int hopSize,
  }) {
    if (signal.isEmpty) return;

    final windowSize = max(3, (0.5 * sampleRate / hopSize).round());
    final half = windowSize ~/ 2;
    final medians = Float64List(signal.length);

    for (var i = 0; i < signal.length; i++) {
      final start = max(0, i - half);
      final end = min(signal.length, i + half + 1);
      final window = signal.sublist(start, end).toList()..sort();
      medians[i] = window[window.length ~/ 2];
    }

    for (var i = 0; i < signal.length; i++) {
      signal[i] = max(0.0, signal[i] - medians[i]);
    }
  }
}
