import 'dart:math';
import 'dart:typed_data';

import 'package:blaq_tempo_detector/src/pipeline/autocorrelator.dart';
import 'package:test/test.dart';

void main() {
  group('Autocorrelator', () {
    test('finds correct period for synthetic periodic signal', () {
      const sampleRate = 44100;
      const hopSize = 512;
      const targetBpm = 120.0;
      final periodFrames = (60.0 * sampleRate / (targetBpm * hopSize)).round();

      // Create onset signal with periodic spikes
      final length = periodFrames * 20; // 20 beats worth
      final onset = Float64List(length);
      for (var i = 0; i < length; i += periodFrames) {
        onset[i] = 1.0;
      }

      final candidates = Autocorrelator.correlate(
        onset,
        sampleRate: sampleRate,
        hopSize: hopSize,
      );

      expect(candidates, isNotEmpty);
      // Top candidate should be close to 120 BPM
      final topBpm = candidates.first.bpm;
      expect(topBpm, closeTo(targetBpm, 2.0));
    });

    test('returns candidates sorted by score descending', () {
      const sampleRate = 44100;
      const hopSize = 512;
      final periodFrames = (60.0 * sampleRate / (100.0 * hopSize)).round();
      final length = periodFrames * 15;
      final onset = Float64List(length);
      for (var i = 0; i < length; i += periodFrames) {
        onset[i] = 1.0;
      }

      final candidates = Autocorrelator.correlate(
        onset,
        sampleRate: sampleRate,
        hopSize: hopSize,
      );

      for (var i = 1; i < candidates.length; i++) {
        expect(
          candidates[i].score,
          lessThanOrEqualTo(candidates[i - 1].score),
        );
      }
    });

    test('all candidates are within bpm range', () {
      const sampleRate = 44100;
      const hopSize = 512;
      final onset = Float64List(500);
      final random = Random(42);
      for (var i = 0; i < 500; i++) {
        onset[i] = random.nextDouble();
      }

      final candidates = Autocorrelator.correlate(
        onset,
        sampleRate: sampleRate,
        hopSize: hopSize,
        bpmMin: 60,
        bpmMax: 200,
      );

      for (final c in candidates) {
        expect(c.bpm, greaterThanOrEqualTo(60.0));
        expect(c.bpm, lessThanOrEqualTo(200.0));
      }
    });

    test('flat signal produces low scores', () {
      final onset = Float64List(500);
      for (var i = 0; i < 500; i++) {
        onset[i] = 1.0; // constant — no periodicity
      }

      final candidates = Autocorrelator.correlate(
        onset,
        sampleRate: 44100,
        hopSize: 512,
      );

      // All candidates should have similar scores — no dominant peak
      if (candidates.length > 1) {
        final topScore = candidates.first.score;
        final secondScore = candidates[1].score;
        // Ratio between top two should be close to 1 (no clear winner)
        expect(topScore / secondScore, lessThan(1.5));
      }
    });
  });
}
