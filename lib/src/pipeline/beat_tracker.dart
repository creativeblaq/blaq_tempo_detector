import 'dart:math';
import 'dart:typed_data';

import 'package:blaq_tempo_detector/src/models/beat_info.dart';

class BeatTracker {
  const BeatTracker._();

  /// Places beat positions on the onset signal using dynamic programming.
  ///
  /// Finds the globally optimal grid of evenly-spaced beats aligned to
  /// onset peaks, penalizing deviations from the expected [bpm] spacing.
  static List<BeatInfo> track(
    Float64List onsetSignal, {
    required double bpm,
    required int sampleRate,
    required int hopSize,
  }) {
    final n = onsetSignal.length;
    if (n == 0) return [];

    final period = 60.0 * sampleRate / (bpm * hopSize);
    final periodInt = period.round();
    if (periodInt <= 0) return [];

    final tolerance = max(1, (period * 0.2).round());

    // DP: scores[i] = best cumulative score ending with a beat at frame i
    final scores = Float64List(n);
    final predecessors = List<int>.filled(n, -1);

    // Timing deviation penalty weight
    const alpha = 50.0;

    // Initialize: any frame in the first period can be the first beat
    final initEnd = min(periodInt + tolerance, n);
    for (var i = 0; i < initEnd; i++) {
      scores[i] = onsetSignal[i];
    }

    // Fill DP table
    for (var i = 1; i < n; i++) {
      final searchStart = max(0, i - periodInt - tolerance);
      final searchEnd = max(0, min(i - 1, i - periodInt + tolerance));

      if (searchStart > searchEnd) continue;

      var bestScore = double.negativeInfinity;
      var bestPred = -1;

      for (var j = searchStart; j <= searchEnd; j++) {
        final spacing = (i - j).toDouble();
        final deviation = (spacing - period) / period;
        final penalty = alpha * deviation * deviation;
        final candidate = scores[j] - penalty;
        if (candidate > bestScore) {
          bestScore = candidate;
          bestPred = j;
        }
      }

      if (bestPred >= 0) {
        final total = bestScore + onsetSignal[i];
        if (total > scores[i]) {
          scores[i] = total;
          predecessors[i] = bestPred;
        }
      }
    }

    // Find best ending position (search last period)
    var bestEnd = n - 1;
    final searchFrom = max(0, n - periodInt - tolerance);
    for (var i = searchFrom; i < n; i++) {
      if (scores[i] > scores[bestEnd]) {
        bestEnd = i;
      }
    }

    // Backtrack
    final beatFrames = <int>[];
    var current = bestEnd;
    while (current >= 0) {
      beatFrames.add(current);
      current = predecessors[current];
    }

    // Reverse to chronological order and convert to BeatInfo
    return beatFrames.reversed
        .map(
          (frame) => BeatInfo(
            timestampSeconds: frame * hopSize / sampleRate,
            onsetStrength: onsetSignal[frame],
          ),
        )
        .toList();
  }
}
