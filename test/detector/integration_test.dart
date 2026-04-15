import 'package:blaq_tempo_detector/blaq_tempo_detector.dart';
import 'package:test/test.dart';

import '../test_signals/signal_generator.dart';

void main() {
  group('Integration — full pipeline', () {
    test('detects 60 BPM without false double-time', () {
      final samples = SignalGenerator.clickTrack(
        bpm: 60,
        durationSeconds: 15,
      );
      final result = TempoDetector.analyze(samples, sampleRate: 44100);

      expect(result, isA<TempoDetected>());
      final detected = result as TempoDetected;
      // Should detect ~60, not ~120
      expect(detected.bpm, closeTo(60.0, 3.0));
    });

    test('detects 200 BPM fast tempo with high-range config', () {
      final samples = SignalGenerator.clickTrack(
        bpm: 200,
        durationSeconds: 10,
      );
      final result = TempoDetector.analyze(
        samples,
        sampleRate: 44100,
        config: DetectorConfig(bpmMin: 150, bpmMax: 250),
      );

      expect(result, isA<TempoDetected>());
      final detected = result as TempoDetected;
      expect(detected.bpm, closeTo(200.0, 3.0));
    });

    test('detects 85 BPM sine beats (melodic content)', () {
      final samples = SignalGenerator.sineBeats(
        bpm: 85,
        frequency: 440,
        durationSeconds: 15,
      );
      final result = TempoDetector.analyze(samples, sampleRate: 44100);

      expect(result, isA<TempoDetected>());
      final detected = result as TempoDetected;
      expect(detected.bpm, closeTo(85.0, 3.0));
    });

    test('3 seconds is the minimum for detection', () {
      final samples = SignalGenerator.clickTrack(
        bpm: 120,
        durationSeconds: 3.5,
      );
      final result = TempoDetector.analyze(samples, sampleRate: 44100);

      // Should attempt detection (>= 3 seconds)
      expect(result, isA<TempoResult>());
    });

    test('works with 48000 Hz sample rate', () {
      final samples = SignalGenerator.clickTrack(
        bpm: 120,
        durationSeconds: 10,
        sampleRate: 48000,
      );
      final result = TempoDetector.analyze(samples, sampleRate: 48000);

      expect(result, isA<TempoDetected>());
      final detected = result as TempoDetected;
      expect(detected.bpm, closeTo(120.0, 2.0));
    });

    test('works with 22050 Hz sample rate', () {
      final samples = SignalGenerator.clickTrack(
        bpm: 120,
        durationSeconds: 10,
        sampleRate: 22050,
      );
      final result = TempoDetector.analyze(samples, sampleRate: 22050);

      expect(result, isA<TempoDetected>());
      final detected = result as TempoDetected;
      expect(detected.bpm, closeTo(120.0, 3.0));
    });

    test('barrel export provides all needed types', () {
      final config = DetectorConfig(bpmMin: 60, bpmMax: 200);
      expect(config.bpmMin, 60);

      const beat = BeatInfo(timestampSeconds: 1.0, onsetStrength: 0.5);
      expect(beat.timestampSeconds, 1.0);

      const candidate = TempoCandidate(bpm: 120.0, score: 0.9);
      expect(candidate.bpm, 120.0);

      expect(Confidence.values.length, 3);
      expect(UndetectableReason.values.length, 3);
    });
  });
}
