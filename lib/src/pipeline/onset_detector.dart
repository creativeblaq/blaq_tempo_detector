import 'dart:math';
import 'dart:typed_data';

import 'package:fftea/fftea.dart';

class OnsetDetector {
  const OnsetDetector._();

  /// Computes spectral flux onset strength for each frame.
  ///
  /// Returns a [Float64List] with one onset strength value per frame.
  /// Applies adaptive thresholding (moving median subtraction) to normalize
  /// against slow energy changes.
  static Float64List detect(
    Iterable<Float64List> frames, {
    required int frameSize,
    required int sampleRate,
    required int hopSize,
  }) {
    final fft = FFT(frameSize);
    Float64List? prevMagnitudes;
    final onsetValues = <double>[];

    for (final frame in frames) {
      final spectrum = fft.realFft(frame);
      final magnitudes = spectrum.discardConjugates().magnitudes();

      if (prevMagnitudes != null) {
        var flux = 0.0;
        for (var i = 0; i < magnitudes.length; i++) {
          final diff = magnitudes[i] - prevMagnitudes[i];
          if (diff > 0) flux += diff;
        }
        onsetValues.add(flux);
      } else {
        onsetValues.add(0.0);
      }

      prevMagnitudes = Float64List.fromList(magnitudes);
    }

    final result = Float64List.fromList(onsetValues);
    _adaptiveThreshold(result, sampleRate: sampleRate, hopSize: hopSize);
    return result;
  }

  /// Subtracts a moving median from the onset signal to remove slow trends.
  /// Window size is ~0.5 seconds of frames.
  static void _adaptiveThreshold(
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
