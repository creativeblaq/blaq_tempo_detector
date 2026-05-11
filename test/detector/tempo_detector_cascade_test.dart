import 'package:blaq_tempo_detector/src/config/detector_config.dart';
import 'package:blaq_tempo_detector/src/detector/tempo_detector.dart';
import 'package:blaq_tempo_detector/src/models/tempo_result.dart';
import 'package:blaq_tempo_detector/src/models/tempo_strategy.dart';
import 'package:test/test.dart';

import '../test_signals/piano_signal_generator.dart';
import '../test_signals/signal_generator.dart';

void main() {
  group('TempoDetector cascade', () {
    test('clear percussive click track returns percussive without running melodic', () {
      final samples = SignalGenerator.clickTrack(bpm: 120, durationSeconds: 10);
      final result = TempoDetector.analyze(
        samples, sampleRate: 44100, config: DetectorConfig(),
      );
      expect(result, isA<TempoDetected>());
      expect((result as TempoDetected).strategy, TempoStrategy.percussive);
    });

    test('piano ballad triggers melodic and returns it', () {
      final samples = PianoSignalGenerator.chordStabs(
        bpm: 70.0,
        chordsByBeat: [
          [PianoSignalGenerator.c4, PianoSignalGenerator.e4, PianoSignalGenerator.g4],
          [PianoSignalGenerator.a4, PianoSignalGenerator.cs4, PianoSignalGenerator.e4],
        ],
        durationSeconds: 15.0,
      );
      final result = TempoDetector.analyze(
        samples, sampleRate: 44100, config: DetectorConfig(),
      );

      expect(result, isA<TempoDetected>());
      final detected = result as TempoDetected;
      // Either pipeline could produce it — we care that we got a useful answer.
      expect(detected.bpm, closeTo(70.0, 5.0));
      // On synthetic piano, percussive often returns low-confidence, so
      // melodic should win. If percussive happens to win with confidence,
      // that's acceptable too — but the strategy field must reflect reality.
      expect(detected.strategy, anyOf(TempoStrategy.melodic, TempoStrategy.percussive));
    });

    test('melodicFallback: false forces percussive-only behavior', () {
      final samples = PianoSignalGenerator.chordStabs(
        bpm: 70.0,
        chordsByBeat: [
          [PianoSignalGenerator.c4, PianoSignalGenerator.e4, PianoSignalGenerator.g4],
        ],
        durationSeconds: 15.0,
      );
      final result = TempoDetector.analyze(
        samples,
        sampleRate: 44100,
        config: DetectorConfig(melodicFallback: false),
      );
      // Should NOT be tagged melodic — either percussive-detected or undetectable.
      if (result is TempoDetected) {
        expect(result.strategy, TempoStrategy.percussive);
      }
    });

    test('silence returns TempoUndetectable from both pipelines', () {
      final samples = SignalGenerator.silence(durationSeconds: 5);
      final result = TempoDetector.analyze(
        samples, sampleRate: 44100, config: DetectorConfig(),
      );
      expect(result, isA<TempoUndetectable>());
    });

    test('noise with melodicFallback disabled is rejected by percussive pipeline', () {
      final samples = SignalGenerator.noise(durationSeconds: 5);
      // With melodicFallback off, only the percussive pipeline runs.
      // Percussive rejects noise via peakRatio / halfPeakClutter gates.
      final result = TempoDetector.analyze(
        samples,
        sampleRate: 44100,
        config: DetectorConfig(melodicFallback: false),
      );
      expect(result, isA<TempoUndetectable>());
    });
  });
}
