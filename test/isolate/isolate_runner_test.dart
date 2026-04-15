import 'package:blaq_tempo_detector/src/isolate/isolate_runner.dart';
import 'package:blaq_tempo_detector/src/models/tempo_result.dart';
import 'package:test/test.dart';

import '../test_signals/signal_generator.dart';

void main() {
  group('TempoDetectorIsolate', () {
    test('returns same result as sync detector', () async {
      final samples = SignalGenerator.clickTrack(
        bpm: 120,
        durationSeconds: 10,
      );

      final result = await TempoDetectorIsolate.analyze(
        samples,
        sampleRate: 44100,
      );

      expect(result, isA<TempoDetected>());
      final detected = result as TempoDetected;
      expect(detected.bpm, closeTo(120.0, 2.0));
      expect(detected.beats, isNotEmpty);
    });

    test('handles silence correctly', () async {
      final samples = SignalGenerator.silence(durationSeconds: 5);

      final result = await TempoDetectorIsolate.analyze(
        samples,
        sampleRate: 44100,
      );

      expect(result, isA<TempoUndetectable>());
    });

    test('throws ArgumentError for invalid sample rate', () {
      final samples = SignalGenerator.clickTrack(
        bpm: 120,
        durationSeconds: 5,
      );

      expect(
        () => TempoDetectorIsolate.analyze(samples, sampleRate: 100),
        throwsArgumentError,
      );
    });
  });
}
