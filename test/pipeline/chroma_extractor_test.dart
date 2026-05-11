import 'dart:math';
import 'dart:typed_data';

import 'package:blaq_tempo_detector/src/pipeline/chroma_extractor.dart';
import 'package:test/test.dart';

void main() {
  group('ChromaExtractor', () {
    const sampleRate = 44100;
    const frameSize = 4096;

    Float64List sineFrame(double frequencyHz) {
      final frame = Float64List(frameSize);
      for (var i = 0; i < frameSize; i++) {
        frame[i] = sin(2 * pi * frequencyHz * i / sampleRate);
      }
      return frame;
    }

    int argMax(List<double> v) {
      var best = 0;
      for (var i = 1; i < v.length; i++) {
        if (v[i] > v[best]) best = i;
      }
      return best;
    }

    test('440Hz sine peaks at chroma bin 9 (A)', () {
      final frames = [sineFrame(440.0)];
      final chroma = ChromaExtractor.extract(
        frames,
        frameSize: frameSize,
        sampleRate: sampleRate,
      );

      expect(chroma, hasLength(1));
      expect(chroma.first, hasLength(12));
      expect(argMax(chroma.first), 9);
    });

    test('C-major chord (C4+E4+G4 sines) peaks at bins 0, 4, 7', () {
      const c4 = 261.63;
      const e4 = 329.63;
      const g4 = 392.00;

      final mixed = Float64List(frameSize);
      for (var i = 0; i < frameSize; i++) {
        mixed[i] = (sin(2 * pi * c4 * i / sampleRate) +
                sin(2 * pi * e4 * i / sampleRate) +
                sin(2 * pi * g4 * i / sampleRate)) /
            3.0;
      }

      final chroma = ChromaExtractor.extract(
        [mixed],
        frameSize: frameSize,
        sampleRate: sampleRate,
      ).first;

      final cBin = chroma[0];
      final eBin = chroma[4];
      final gBin = chroma[7];
      for (var i = 0; i < 12; i++) {
        if (i == 0 || i == 4 || i == 7) continue;
        expect(cBin, greaterThan(chroma[i]));
        expect(eBin, greaterThan(chroma[i]));
        expect(gBin, greaterThan(chroma[i]));
      }
    });

    test('all-zero input yields all-zero chroma, no NaN', () {
      final zero = Float64List(frameSize);
      final chroma = ChromaExtractor.extract(
        [zero],
        frameSize: frameSize,
        sampleRate: sampleRate,
      ).first;

      for (var i = 0; i < 12; i++) {
        expect(chroma[i], 0.0);
        expect(chroma[i].isNaN, isFalse);
      }
    });

    test('output length matches input frame count', () {
      final frames = List.generate(5, (_) => sineFrame(440.0));
      final chroma = ChromaExtractor.extract(
        frames,
        frameSize: frameSize,
        sampleRate: sampleRate,
      );
      expect(chroma, hasLength(5));
    });
  });
}
