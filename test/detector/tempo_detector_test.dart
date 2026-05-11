import 'dart:typed_data';

import 'package:blaq_tempo_detector/src/config/detector_config.dart';
import 'package:blaq_tempo_detector/src/detector/tempo_detector.dart';
import 'package:blaq_tempo_detector/src/models/confidence.dart';
import 'package:blaq_tempo_detector/src/models/tempo_result.dart';
import 'package:blaq_tempo_detector/src/models/undetectable_reason.dart';
import 'package:test/test.dart';

import '../test_signals/signal_generator.dart';

void main() {
  group('TempoDetector', () {
    test('detects 120 BPM click track', () {
      final samples = SignalGenerator.clickTrack(
        bpm: 120,
        durationSeconds: 10,
      );

      final result = TempoDetector.analyze(samples, sampleRate: 44100);

      expect(result, isA<TempoDetected>());
      final detected = result as TempoDetected;
      expect(detected.bpm, closeTo(120.0, 2.0));
      expect(detected.confidence, isNot(Confidence.uncertain));
      expect(detected.beats, isNotEmpty);
      expect(detected.candidates, isNotEmpty);
    });

    test('detects 85 BPM sine beats', () {
      final samples = SignalGenerator.sineBeats(
        bpm: 85,
        frequency: 440,
        durationSeconds: 10,
      );

      final result = TempoDetector.analyze(samples, sampleRate: 44100);

      expect(result, isA<TempoDetected>());
      final detected = result as TempoDetected;
      expect(detected.bpm, closeTo(85.0, 3.0));
    });

    test('returns undetectable for silence', () {
      final samples = SignalGenerator.silence(durationSeconds: 5);

      final result = TempoDetector.analyze(samples, sampleRate: 44100);

      expect(result, isA<TempoUndetectable>());
      final undetectable = result as TempoUndetectable;
      expect(undetectable.reason, UndetectableReason.silence);
    });

    test('rejects or low-confidences noise (never high-confidence)', () {
      // The percussive pipeline gates on peakRatio / halfPeakClutter and
      // returns Undetectable on noise. The melodic pipeline's looser gates
      // can accept noise as a *low-confidence* result so the user sees an
      // UNCERTAIN badge instead of a hard error — better UX than "no pattern
      // found" on borderline material. Either outcome is acceptable as long
      // as we never report HIGH confidence on noise.
      final samples = SignalGenerator.noise(durationSeconds: 5);

      final result = TempoDetector.analyze(samples, sampleRate: 44100);

      if (result is TempoDetected) {
        expect(result.confidenceScore, lessThan(0.4),
            reason: 'Noise produced high-confidence detection: $result');
      } else {
        expect(result, isA<TempoUndetectable>());
      }
    });

    test('returns undetectable for audio shorter than 3 seconds', () {
      final samples = SignalGenerator.clickTrack(
        bpm: 120,
        durationSeconds: 1,
      );

      final result = TempoDetector.analyze(samples, sampleRate: 44100);

      expect(result, isA<TempoUndetectable>());
      final undetectable = result as TempoUndetectable;
      expect(undetectable.reason, UndetectableReason.tooShort);
    });

    test('returns undetectable for empty samples', () {
      final result = TempoDetector.analyze(Float64List(0), sampleRate: 44100);

      expect(result, isA<TempoUndetectable>());
      final undetectable = result as TempoUndetectable;
      expect(undetectable.reason, UndetectableReason.tooShort);
    });

    test('throws ArgumentError for invalid sample rate', () {
      final samples = Float64List(44100);
      expect(
        () => TempoDetector.analyze(samples, sampleRate: 100),
        throwsArgumentError,
      );
      expect(
        () => TempoDetector.analyze(samples, sampleRate: 200000),
        throwsArgumentError,
      );
    });

    test('respects startSample and endSample', () {
      // 10 seconds of 120 BPM, analyze only middle 5 seconds
      final samples = SignalGenerator.clickTrack(
        bpm: 120,
        durationSeconds: 10,
      );

      final result = TempoDetector.analyze(
        samples,
        sampleRate: 44100,
        startSample: 44100 * 2,
        endSample: 44100 * 7,
      );

      expect(result, isA<TempoDetected>());
      final detected = result as TempoDetected;
      expect(detected.bpm, closeTo(120.0, 2.0));
    });

    test('throws RangeError when startSample >= endSample', () {
      final samples = Float64List(44100 * 5);
      expect(
        () => TempoDetector.analyze(
          samples,
          sampleRate: 44100,
          startSample: 44100 * 3,
          endSample: 44100 * 2,
        ),
        throwsRangeError,
      );
    });

    test('accepts custom DetectorConfig', () {
      final samples = SignalGenerator.clickTrack(
        bpm: 120,
        durationSeconds: 10,
      );

      final result = TempoDetector.analyze(
        samples,
        sampleRate: 44100,
        config: DetectorConfig(bpmMin: 100, bpmMax: 150),
      );

      expect(result, isA<TempoDetected>());
      final detected = result as TempoDetected;
      expect(detected.bpm, closeTo(120.0, 2.0));
    });

    test('candidates list contains the detected BPM', () {
      final samples = SignalGenerator.clickTrack(
        bpm: 120,
        durationSeconds: 10,
      );
      final result = TempoDetector.analyze(samples, sampleRate: 44100);
      final detected = result as TempoDetected;

      final hasBpm = detected.candidates.any(
        (c) => (c.bpm - detected.bpm).abs() < 1.0,
      );
      expect(hasBpm, isTrue);
    });
  });
}
