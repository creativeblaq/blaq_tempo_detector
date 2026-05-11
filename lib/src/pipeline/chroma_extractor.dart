import 'dart:math';
import 'dart:typed_data';

import 'package:fftea/fftea.dart';

class ChromaExtractor {
  const ChromaExtractor._();

  /// Reference frequency for chroma bin 9 (A4).
  static const _referenceFreq = 440.0;

  /// Log-compression gain. Boosts soft partials so chord changes are visible
  /// even when one note dominates dynamically.
  static const _logGamma = 100.0;

  /// Skip FFT bins below ~A3 (220 Hz). Below this, the bin width at 4096
  /// samples (~10.8 Hz) is too coarse to reliably assign a pitch class, and
  /// accumulated low-frequency leakage distorts the chord-identity bins above.
  static const _minFreqHz = 220.0;

  /// Skip FFT bins above ~5kHz — partials this high are dominated by noise
  /// and percussive content, not the chord identity we want.
  static const _maxFreqHz = 5000.0;

  /// Extracts 12-bin chroma vectors from a sequence of audio frames.
  ///
  /// Each output vector is L2-normalized and log-compressed. Frames with zero
  /// energy produce a zero vector (no NaN from normalization).
  ///
  /// A Hann window is applied before each FFT to suppress spectral leakage,
  /// which is critical for correct pitch-class assignment.
  static List<Float64List> extract(
    Iterable<Float64List> frames, {
    required int frameSize,
    required int sampleRate,
  }) {
    final fft = FFT(frameSize);
    // Pre-compute the Hann window once and reuse across frames.
    final hannWindow = Window.hanning(frameSize);
    final out = <Float64List>[];

    final binFreqStep = sampleRate / frameSize;
    final minBin = (_minFreqHz / binFreqStep).ceil();
    final maxBin = (_maxFreqHz / binFreqStep).floor();

    for (final frame in frames) {
      // Apply Hann window to a copy; realFft needs a List<double> input.
      final windowed = hannWindow.applyWindowReal(frame);

      final spectrum = fft.realFft(windowed);
      final magnitudes = spectrum.discardConjugates().magnitudes();

      final chroma = Float64List(12);
      for (var bin = minBin; bin < magnitudes.length && bin <= maxBin; bin++) {
        final freq = bin * binFreqStep;
        if (freq <= 0) continue;
        // 12 * log2(freq / 440) gives a real-valued pitch class offset from A.
        // Add 9 to put A at bin 9, take mod 12.
        final pitchClass = (12 * (log(freq / _referenceFreq) / ln2) + 9)
            .round() % 12;
        // Robustness for negative mod (Dart preserves sign of dividend).
        final pc = pitchClass < 0 ? pitchClass + 12 : pitchClass;
        chroma[pc] += log(1 + _logGamma * magnitudes[bin]);
      }

      // L2 normalize, skipping zero vectors.
      var norm = 0.0;
      for (var i = 0; i < 12; i++) {
        norm += chroma[i] * chroma[i];
      }
      if (norm > 0) {
        final sqrtNorm = sqrt(norm);
        for (var i = 0; i < 12; i++) {
          chroma[i] /= sqrtNorm;
        }
      }

      out.add(chroma);
    }

    return out;
  }
}
