import 'dart:typed_data';

import 'package:blaq_tempo_detector/src/pipeline/adaptive_threshold.dart';
import 'package:test/test.dart';

void main() {
  group('AdaptiveThreshold', () {
    test('empty input is a no-op (does not throw)', () {
      final signal = Float64List(0);
      AdaptiveThreshold.apply(signal, sampleRate: 44100, hopSize: 2048);
      expect(signal, isEmpty);
    });

    test('constant signal becomes zero after thresholding', () {
      final signal = Float64List.fromList(List.filled(100, 5.0));
      AdaptiveThreshold.apply(signal, sampleRate: 44100, hopSize: 2048);
      for (final v in signal) {
        expect(v, 0.0);
      }
    });

    test('isolated spike is preserved above zero', () {
      final signal = Float64List(100); // all zeros
      signal[50] = 10.0;
      AdaptiveThreshold.apply(signal, sampleRate: 44100, hopSize: 2048);
      expect(signal[50], greaterThan(0.0));
      // Distant points (window spans ~0.5s ≈ 11 frames at 44100/2048) are zero.
      expect(signal[0], 0.0);
      expect(signal[99], 0.0);
    });

    test('uses two-pass semantics (medians computed from original signal)', () {
      // Construct a signal where one-pass and two-pass would diverge: a
      // ramp where each subtraction would alter the median used for the
      // next position. With two-pass, every median is computed from the
      // ORIGINAL ramp.
      final signal = Float64List.fromList(
        List.generate(20, (i) => i.toDouble()),
      );
      AdaptiveThreshold.apply(signal, sampleRate: 44100, hopSize: 2048);
      // The middle of a monotonic ramp should be close to zero after
      // median subtraction (median ≈ value). The first/last edges may
      // have residual due to boundary handling; we only check the middle.
      for (var i = 5; i < 15; i++) {
        expect(signal[i].abs(), lessThan(2.0),
            reason: 'index $i should be small after median subtraction');
      }
    });
  });
}
