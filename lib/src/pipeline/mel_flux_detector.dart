import 'dart:math';
import 'dart:typed_data';

import 'package:fftea/fftea.dart';

class MelFluxDetector {
  const MelFluxDetector._();

  static const _melBands = 40;
  static const _melFreqMin = 27.5; // ~A0
  static const _melFreqMax = 8000.0;

  static Float64List detect(
    Iterable<Float64List> frames, {
    required int frameSize,
    required int sampleRate,
    required int hopSize,
  }) {
    final fft = FFT(frameSize);
    final melFilters = _buildMelFilterbank(
      frameSize: frameSize,
      sampleRate: sampleRate,
    );
    Float64List? prevMel;
    final fluxValues = <double>[];

    for (final frame in frames) {
      final spectrum = fft.realFft(frame);
      final magnitudes = spectrum.discardConjugates().magnitudes();
      final mel = _applyMelFilterbank(magnitudes, melFilters);
      // Log compression.
      for (var i = 0; i < mel.length; i++) {
        mel[i] = log(1 + mel[i]);
      }

      if (prevMel != null) {
        var flux = 0.0;
        for (var i = 0; i < _melBands; i++) {
          final diff = mel[i] - prevMel[i];
          if (diff > 0) flux += diff;
        }
        fluxValues.add(flux);
      } else {
        fluxValues.add(0.0);
      }

      prevMel = mel;
    }

    final result = Float64List.fromList(fluxValues);
    _adaptiveThreshold(result, sampleRate: sampleRate, hopSize: hopSize);
    return result;
  }

  // Triangular mel filterbank. Each filter is a list of (binIndex, weight).
  static List<List<(int, double)>> _buildMelFilterbank({
    required int frameSize,
    required int sampleRate,
  }) {
    double hzToMel(double hz) => 2595.0 * (log(1 + hz / 700.0) / ln10);
    double melToHz(double mel) => 700.0 * (pow(10.0, mel / 2595.0) - 1);

    final melMin = hzToMel(_melFreqMin);
    final melMax = hzToMel(_melFreqMax);
    final melPoints = List<double>.generate(
      _melBands + 2,
      (i) => melMin + (melMax - melMin) * i / (_melBands + 1),
    );
    final hzPoints = melPoints.map(melToHz).toList();
    final binPoints = hzPoints
        .map((hz) => (hz * frameSize / sampleRate).floor())
        .toList();

    final numBins = frameSize ~/ 2 + 1;
    final filters = <List<(int, double)>>[];
    for (var m = 1; m <= _melBands; m++) {
      final lo = binPoints[m - 1];
      final mid = binPoints[m];
      final hi = binPoints[m + 1];
      final filter = <(int, double)>[];
      for (var k = lo; k < mid && k < numBins; k++) {
        if (mid == lo) continue;
        filter.add((k, (k - lo) / (mid - lo)));
      }
      for (var k = mid; k < hi && k < numBins; k++) {
        if (hi == mid) continue;
        filter.add((k, (hi - k) / (hi - mid)));
      }
      filters.add(filter);
    }
    return filters;
  }

  static Float64List _applyMelFilterbank(
    Float64List magnitudes,
    List<List<(int, double)>> filterbank,
  ) {
    final out = Float64List(_melBands);
    for (var m = 0; m < _melBands; m++) {
      var sum = 0.0;
      for (final (bin, weight) in filterbank[m]) {
        sum += magnitudes[bin] * weight;
      }
      out[m] = sum;
    }
    return out;
  }

  static void _adaptiveThreshold(
    Float64List signal, {
    required int sampleRate,
    required int hopSize,
  }) {
    if (signal.isEmpty) return;
    final windowSize = max(3, (0.5 * sampleRate / hopSize).round());
    final half = windowSize ~/ 2;
    for (var i = 0; i < signal.length; i++) {
      final start = max(0, i - half);
      final end = min(signal.length, i + half + 1);
      final window = signal.sublist(start, end).toList()..sort();
      final median = window[window.length ~/ 2];
      signal[i] = max(0.0, signal[i] - median);
    }
  }
}
