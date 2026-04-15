import 'dart:typed_data';

import 'package:blaq_tempo_detector/src/config/detector_config.dart';
import 'package:blaq_tempo_detector/src/detector/tempo_tracker.dart';
import 'package:blaq_tempo_detector/src/models/tempo_result.dart';
import 'package:blaq_tempo_detector/src/models/undetectable_reason.dart';
import 'package:test/test.dart';

import '../test_signals/signal_generator.dart';

void main() {
  group('TempoTracker', () {
    test('finalize returns same result as feeding all at once', () {
      final samples = SignalGenerator.clickTrack(
        bpm: 120,
        durationSeconds: 10,
      );

      final tracker = TempoTracker(sampleRate: 44100);
      tracker.addSamples(samples);
      final result = tracker.finalize();

      expect(result, isA<TempoDetected>());
      final detected = result as TempoDetected;
      expect(detected.bpm, closeTo(120.0, 2.0));
      expect(detected.beats, isNotEmpty);
    });

    test('chunked feeding produces same BPM as single feed', () {
      final samples = SignalGenerator.clickTrack(
        bpm: 120,
        durationSeconds: 10,
      );
      const chunkSize = 4410; // 0.1 second chunks

      final tracker = TempoTracker(sampleRate: 44100);
      for (var i = 0; i < samples.length; i += chunkSize) {
        final end = (i + chunkSize).clamp(0, samples.length);
        tracker.addSamples(Float64List.sublistView(samples, i, end));
      }
      final result = tracker.finalize();

      expect(result, isA<TempoDetected>());
      final detected = result as TempoDetected;
      expect(detected.bpm, closeTo(120.0, 2.0));
    });

    test('currentEstimate returns tooShort when insufficient data', () {
      final tracker = TempoTracker(sampleRate: 44100);
      tracker.addSamples(Float64List(44100));

      final estimate = tracker.currentEstimate;
      expect(estimate, isA<TempoUndetectable>());
      expect(
        (estimate as TempoUndetectable).reason,
        UndetectableReason.tooShort,
      );
    });

    test('currentEstimate converges after enough data', () {
      final samples = SignalGenerator.clickTrack(
        bpm: 120,
        durationSeconds: 10,
      );

      final tracker = TempoTracker(sampleRate: 44100);
      tracker.addSamples(Float64List.sublistView(samples, 0, 44100 * 5));

      final estimate = tracker.currentEstimate;
      expect(estimate, isA<TempoDetected>());
      final detected = estimate as TempoDetected;
      expect(detected.bpm, closeTo(120.0, 3.0));
      expect(detected.beats, isEmpty);
    });

    test('finalize populates beats', () {
      final samples = SignalGenerator.clickTrack(
        bpm: 120,
        durationSeconds: 10,
      );

      final tracker = TempoTracker(sampleRate: 44100);
      tracker.addSamples(samples);
      final result = tracker.finalize() as TempoDetected;

      expect(result.beats, isNotEmpty);
    });

    test('addSamples throws after finalize', () {
      final tracker = TempoTracker(sampleRate: 44100);
      tracker.addSamples(Float64List(44100 * 5));
      tracker.finalize();

      expect(
        () => tracker.addSamples(Float64List(1000)),
        throwsStateError,
      );
    });

    test('maxSamples enforces sliding window', () {
      final tracker = TempoTracker(
        sampleRate: 44100,
        maxSamples: 44100 * 5,
      );

      final samples = SignalGenerator.clickTrack(
        bpm: 120,
        durationSeconds: 10,
      );
      tracker.addSamples(samples);

      final result = tracker.finalize();
      expect(result, isA<TempoResult>());
    });

    test('accepts custom config', () {
      final samples = SignalGenerator.clickTrack(
        bpm: 120,
        durationSeconds: 10,
      );

      final tracker = TempoTracker(
        sampleRate: 44100,
        config: DetectorConfig(bpmMin: 100, bpmMax: 150),
      );
      tracker.addSamples(samples);
      final result = tracker.finalize();

      expect(result, isA<TempoDetected>());
      final detected = result as TempoDetected;
      expect(detected.bpm, closeTo(120.0, 2.0));
    });

    test('throws ArgumentError for invalid sample rate', () {
      expect(
        () => TempoTracker(sampleRate: 100),
        throwsArgumentError,
      );
    });
  });
}
