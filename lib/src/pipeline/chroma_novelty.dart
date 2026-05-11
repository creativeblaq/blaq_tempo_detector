import 'dart:math';
import 'dart:typed_data';

import 'package:blaq_tempo_detector/src/pipeline/adaptive_threshold.dart';

class ChromaNovelty {
  const ChromaNovelty._();

  /// Returns a novelty curve (one value per input chroma frame) measuring the
  /// cosine distance between consecutive 12-bin chroma vectors. Applies
  /// moving-median subtraction to remove slow drift — same approach as
  /// [OnsetDetector] so the two curves are scale-comparable for fusion.
  static Float64List detect(
    List<Float64List> chromaFrames, {
    required int sampleRate,
    required int hopSize,
  }) {
    if (chromaFrames.isEmpty) return Float64List(0);

    final n = chromaFrames.length;
    final novelty = Float64List(n);
    Float64List? prev;
    for (var i = 0; i < n; i++) {
      final cur = chromaFrames[i];
      if (prev != null) {
        var dot = 0.0;
        var prevNorm = 0.0;
        var curNorm = 0.0;
        for (var k = 0; k < 12; k++) {
          dot += prev[k] * cur[k];
          prevNorm += prev[k] * prev[k];
          curNorm += cur[k] * cur[k];
        }
        if (prevNorm > 0 && curNorm > 0) {
          final cosine = dot / (sqrt(prevNorm) * sqrt(curNorm));
          novelty[i] = (1.0 - cosine).clamp(0.0, 1.0);
        }
      }
      prev = cur;
    }

    AdaptiveThreshold.apply(novelty, sampleRate: sampleRate, hopSize: hopSize);
    return novelty;
  }
}
