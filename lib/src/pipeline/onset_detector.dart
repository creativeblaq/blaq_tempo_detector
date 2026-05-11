import 'dart:typed_data';

import 'package:blaq_tempo_detector/src/pipeline/adaptive_threshold.dart';
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
    AdaptiveThreshold.apply(result, sampleRate: sampleRate, hopSize: hopSize);
    return result;
  }
}
