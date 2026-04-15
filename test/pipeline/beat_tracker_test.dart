import 'dart:typed_data';

import 'package:blaq_tempo_detector/src/pipeline/beat_tracker.dart';
import 'package:test/test.dart';

void main() {
  group('BeatTracker', () {
    // At 120 BPM, sampleRate=44100, hopSize=256:
    //   period = 60 * 44100 / (120 * 256) ≈ 86.13 frames
    // The test signal has peaks every 86 frames, matching this period.
    const testSampleRate = 44100;
    const testHopSize = 256;
    const testBpm = 120.0;
    const period = 86;

    test('places beats at onset peaks for evenly spaced signal', () {
      const length = period * 10; // 10 beats
      final onset = Float64List(length);
      for (var i = 0; i < length; i += period) {
        onset[i] = 1.0;
      }

      final beats = BeatTracker.track(
        onset,
        bpm: testBpm,
        sampleRate: testSampleRate,
        hopSize: testHopSize,
      );

      expect(beats.length, inInclusiveRange(8, 11));

      // Beats should be roughly evenly spaced
      for (var i = 1; i < beats.length; i++) {
        final spacing =
            beats[i].timestampSeconds - beats[i - 1].timestampSeconds;
        // At 120 BPM, beat spacing should be ~0.5s
        expect(spacing, closeTo(0.5, 0.1));
      }
    });

    test('beats have positive onset strength at onset positions', () {
      const length = period * 10;
      final onset = Float64List(length);
      for (var i = 0; i < length; i += period) {
        onset[i] = 1.0;
      }

      final beats = BeatTracker.track(
        onset,
        bpm: testBpm,
        sampleRate: testSampleRate,
        hopSize: testHopSize,
      );

      // Most beats should land on or near high onset strength
      final strongBeats = beats.where((b) => b.onsetStrength > 0.5).length;
      expect(strongBeats, greaterThan(beats.length ~/ 2));
    });

    test('returns empty list for empty onset signal', () {
      final beats = BeatTracker.track(
        Float64List(0),
        bpm: testBpm,
        sampleRate: testSampleRate,
        hopSize: testHopSize,
      );
      expect(beats, isEmpty);
    });

    test('handles very short onset signal', () {
      final onset = Float64List(10);
      onset[0] = 1.0;
      onset[5] = 1.0;

      final beats = BeatTracker.track(
        onset,
        bpm: testBpm,
        sampleRate: testSampleRate,
        hopSize: testHopSize,
      );
      // Should return at least some beats without crashing
      expect(beats, isNotNull);
    });

    test('timestamps are in ascending order', () {
      const length = period * 10;
      final onset = Float64List(length);
      for (var i = 0; i < length; i += period) {
        onset[i] = 1.0;
      }

      final beats = BeatTracker.track(
        onset,
        bpm: testBpm,
        sampleRate: testSampleRate,
        hopSize: testHopSize,
      );

      for (var i = 1; i < beats.length; i++) {
        expect(
          beats[i].timestampSeconds,
          greaterThan(beats[i - 1].timestampSeconds),
        );
      }
    });
  });
}
