import 'dart:typed_data';

import 'package:blaq_tempo_detector/src/pipeline/frame_splitter.dart';
import 'package:blaq_tempo_detector/src/pipeline/mel_flux_detector.dart';
import 'package:test/test.dart';

void main() {
  group('MelFluxDetector', () {
    const sampleRate = 44100;
    const frameSize = 4096;
    const hopSize = 2048;

    test('silence produces zero flux', () {
      final samples = Float64List(frameSize * 5);
      final frames = FrameSplitter.split(
        samples, frameSize: frameSize, hopSize: hopSize,
      );
      final flux = MelFluxDetector.detect(
        frames,
        frameSize: frameSize,
        sampleRate: sampleRate,
        hopSize: hopSize,
      );
      for (final v in flux) {
        expect(v, 0.0);
      }
    });

    test('single click produces a spike at the right hop', () {
      final samples = Float64List(frameSize * 6);
      // Place an impulse at sample index = 3 * hopSize so it lands in frame 3.
      samples[3 * hopSize] = 1.0;

      final frames = FrameSplitter.split(
        samples, frameSize: frameSize, hopSize: hopSize,
      );
      final flux = MelFluxDetector.detect(
        frames,
        frameSize: frameSize,
        sampleRate: sampleRate,
        hopSize: hopSize,
      );

      var maxIdx = 0;
      for (var i = 1; i < flux.length; i++) {
        if (flux[i] > flux[maxIdx]) maxIdx = i;
      }
      // The impulse-bearing frame index is approximately 3 (allow ±1).
      expect(maxIdx, inInclusiveRange(2, 4));
      expect(flux[maxIdx], greaterThan(0.0));
    });

    test('output length matches frame count', () {
      final samples = Float64List(frameSize * 4);
      final frames = FrameSplitter.split(
        samples, frameSize: frameSize, hopSize: hopSize,
      ).toList();
      final flux = MelFluxDetector.detect(
        frames,
        frameSize: frameSize,
        sampleRate: sampleRate,
        hopSize: hopSize,
      );
      expect(flux, hasLength(frames.length));
    });
  });
}
