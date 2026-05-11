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

  /// Multi-center variant for the melodic pipeline. Each candidate's score
  /// is multiplied by the *maximum* log-Gaussian weight across [centers]
  /// (so a candidate sitting inside one center wins outright instead of
  /// being smeared across centers). [sigma] is in log2-BPM units.
  ///
  /// Includes a half-speed rescue: after picking the top candidate, if there
  /// is a peak at T/2 whose voted score is ≥ 90% of the winner's AND whose
  /// distance to its nearest center is within 0.2 log2 octaves, prefer that
  /// half-speed candidate. This targets the classic "ballad at 70 detected as
  /// 140" failure mode — the rescue only ever promotes the slower candidate,
  /// never the faster one.
  static List<TempoCandidate> applyMultiCenter(
    List<TempoCandidate> candidates, {
    required List<double> centers,
    required double sigma,
  }) {
    if (candidates.isEmpty) return [];
    if (centers.isEmpty) {
      throw ArgumentError.value(centers, 'centers', 'Must not be empty');
    }

    double weightFor(double bpm) {
      var best = 0.0;
      for (final c in centers) {
        // Distance in log2 octaves between bpm and this center.
        final distLog2 = log(bpm / c) / ln2;
        final w = exp(-(distLog2 * distLog2) / (2.0 * sigma * sigma));
        if (w > best) best = w;
      }
      return best;
    }

    double centerDist(double bpm) {
      var best = double.infinity;
      for (final c in centers) {
        final d = (log(bpm / c) / ln2).abs();
        if (d < best) best = d;
      }
      return best;
    }

    final weighted = candidates
        .map((c) => TempoCandidate(bpm: c.bpm, score: c.score * weightFor(c.bpm)))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    // Half-speed rescue: only promotes a slower candidate (ratio ~0.5),
    // never the faster direction, to avoid swapping a correct slow winner
    // for its double.
    const rescoreThreshold = 0.9;
    const halfRescueCenterDist = 0.2; // log2 octaves
    final top = weighted.first;
    TempoCandidate? rescueCandidate;
    for (final c in weighted.skip(1)) {
      if (c.score < rescoreThreshold * top.score) break;
      final ratio = c.bpm / top.bpm;
      final isHalf = (ratio - 0.5).abs() < 0.05;
      if (isHalf && centerDist(c.bpm) < halfRescueCenterDist) {
        rescueCandidate = c;
        break;
      }
    }

    if (rescueCandidate != null) {
      // Swap the rescue candidate into the top slot. Keep the rest as-is.
      weighted
        ..remove(rescueCandidate)
        ..insert(0, rescueCandidate);
    }

    return weighted;
  }
}
