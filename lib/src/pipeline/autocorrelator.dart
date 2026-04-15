import 'dart:typed_data';

import 'package:blaq_tempo_detector/src/models/tempo_candidate.dart';

class Autocorrelator {
  const Autocorrelator._();

  /// Computes autocorrelation of [onsetSignal] and returns tempo candidates
  /// within the [bpmMin]–[bpmMax] range, sorted by score descending.
  static List<TempoCandidate> correlate(
    Float64List onsetSignal, {
    required int sampleRate,
    required int hopSize,
    int bpmMin = 30,
    int bpmMax = 300,
  }) {
    final n = onsetSignal.length;
    if (n < 2) return [];

    // Convert BPM bounds to lag bounds (in onset signal frames)
    final lagMin = (60.0 * sampleRate / (bpmMax * hopSize)).floor();
    final lagMax = (60.0 * sampleRate / (bpmMin * hopSize)).ceil();

    // Compute energy for normalization
    var energy = 0.0;
    for (var i = 0; i < n; i++) {
      energy += onsetSignal[i] * onsetSignal[i];
    }
    if (energy == 0.0) return [];

    final candidates = <TempoCandidate>[];

    for (var lag = lagMin; lag <= lagMax && lag < n; lag++) {
      if (lag <= 0) continue;

      var correlation = 0.0;
      for (var i = 0; i < n - lag; i++) {
        correlation += onsetSignal[i] * onsetSignal[i + lag];
      }

      final normalized = correlation / energy;
      final bpm = 60.0 * sampleRate / (lag * hopSize);

      if (bpm >= bpmMin && bpm <= bpmMax) {
        candidates.add(TempoCandidate(bpm: bpm, score: normalized));
      }
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));
    return candidates;
  }
}
