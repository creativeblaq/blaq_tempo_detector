import 'dart:math';

import 'package:blaq_tempo_detector/src/models/tempo_candidate.dart';

class PerceptualWeighting {
  const PerceptualWeighting._();

  /// Applies a Gaussian weighting centered at [center] BPM (sigma = 40)
  /// to bias toward the perceptually natural tempo range.
  ///
  /// Returns a new list of candidates with adjusted scores, sorted descending.
  static List<TempoCandidate> apply(
    List<TempoCandidate> candidates, {
    double center = 120.0,
    double sigma = 40.0,
  }) {
    if (candidates.isEmpty) return [];

    final weighted = candidates.map((c) {
      final diff = c.bpm - center;
      final weight = exp(-(diff * diff) / (2.0 * sigma * sigma));
      return TempoCandidate(bpm: c.bpm, score: c.score * weight);
    }).toList();

    weighted.sort((a, b) => b.score.compareTo(a.score));
    return weighted;
  }
}
