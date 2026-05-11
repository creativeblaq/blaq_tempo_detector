import 'dart:typed_data';

import 'package:blaq_tempo_detector/src/config/detector_config.dart';
import 'package:blaq_tempo_detector/src/detector/melodic_tempo_detector.dart';
import 'package:blaq_tempo_detector/src/models/tempo_result.dart';
import 'package:blaq_tempo_detector/src/models/tempo_strategy.dart';
import 'package:test/test.dart';

import '../test_signals/piano_signal_generator.dart';

void main() {
  group('MelodicTempoDetector', () {
    test('detects 70 BPM piano chord stabs', () {
      final samples = PianoSignalGenerator.chordStabs(
        bpm: 70.0,
        chordsByBeat: [
          [PianoSignalGenerator.c4, PianoSignalGenerator.e4,
           PianoSignalGenerator.g4],
          [PianoSignalGenerator.c4, PianoSignalGenerator.e4,
           PianoSignalGenerator.g4],
          [PianoSignalGenerator.a4, PianoSignalGenerator.cs4,
           PianoSignalGenerator.e4],
          [PianoSignalGenerator.a4, PianoSignalGenerator.cs4,
           PianoSignalGenerator.e4],
        ],
        durationSeconds: 15.0,
      );

      final result = MelodicTempoDetector.analyze(
        samples,
        sampleRate: 44100,
        config: DetectorConfig(),
      );

      expect(result, isA<TempoDetected>());
      final detected = result as TempoDetected;
      expect(detected.bpm, closeTo(70.0, 3.0));
      expect(detected.strategy, TempoStrategy.melodic);
    });

    test('detects 140 BPM piano chord stabs', () {
      final samples = PianoSignalGenerator.chordStabs(
        bpm: 140.0,
        chordsByBeat: [
          [PianoSignalGenerator.c4, PianoSignalGenerator.e4,
           PianoSignalGenerator.g4],
          [PianoSignalGenerator.a4, PianoSignalGenerator.cs4,
           PianoSignalGenerator.e4],
        ],
        durationSeconds: 12.0,
      );

      final result = MelodicTempoDetector.analyze(
        samples,
        sampleRate: 44100,
        config: DetectorConfig(),
      );

      expect(result, isA<TempoDetected>());
      final detected = result as TempoDetected;
      expect(detected.bpm, closeTo(140.0, 4.0));
      expect(detected.strategy, TempoStrategy.melodic);
    });

    test('returns TempoUndetectable on silence', () {
      final samples = Float64List(44100 * 5);
      final result = MelodicTempoDetector.analyze(
        samples, sampleRate: 44100, config: DetectorConfig(),
      );
      expect(result, isA<TempoUndetectable>());
    });
  });
}
