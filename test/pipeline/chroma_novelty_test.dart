import 'dart:typed_data';

import 'package:blaq_tempo_detector/src/pipeline/chroma_novelty.dart';
import 'package:test/test.dart';

void main() {
  group('ChromaNovelty', () {
    const sampleRate = 44100;
    const hopSize = 2048;

    Float64List unitVec(int peakBin) {
      final v = Float64List(12);
      v[peakBin] = 1.0;
      return v;
    }

    test('sustained chord produces near-zero novelty after first frame', () {
      final chroma = List.generate(8, (_) => unitVec(0));
      final novelty = ChromaNovelty.detect(
        chroma,
        sampleRate: sampleRate,
        hopSize: hopSize,
      );

      // First entry is 0 by convention (no prior frame to diff against).
      expect(novelty[0], 0.0);
      // Subsequent entries are all zero after adaptive thresholding.
      for (var i = 1; i < novelty.length; i++) {
        expect(novelty[i], closeTo(0.0, 1e-9));
      }
    });

    test('step change from A to C# produces a spike', () {
      final chroma = <Float64List>[
        ...List.generate(4, (_) => unitVec(9)), // A
        ...List.generate(4, (_) => unitVec(1)), // C#
      ];
      final novelty = ChromaNovelty.detect(
        chroma,
        sampleRate: sampleRate,
        hopSize: hopSize,
      );

      // The transition between frame 3 and frame 4 should be the largest.
      var maxIdx = 0;
      for (var i = 1; i < novelty.length; i++) {
        if (novelty[i] > novelty[maxIdx]) maxIdx = i;
      }
      expect(maxIdx, 4);
      expect(novelty[4], greaterThan(0.0));
    });

    test('output length matches input length', () {
      final chroma = List.generate(10, (_) => unitVec(0));
      final novelty = ChromaNovelty.detect(
        chroma,
        sampleRate: sampleRate,
        hopSize: hopSize,
      );
      expect(novelty, hasLength(10));
    });

    test('empty input returns empty output', () {
      final novelty = ChromaNovelty.detect(
        const [],
        sampleRate: sampleRate,
        hopSize: hopSize,
      );
      expect(novelty, isEmpty);
    });
  });
}
