import 'package:blaq_tempo_detector/src/pipeline/frame_splitter.dart';
import 'package:blaq_tempo_detector/src/pipeline/onset_detector.dart';
import 'package:test/test.dart';

import '../test_signals/signal_generator.dart';

void main() {
  group('OnsetDetector', () {
    test('produces one value per frame', () {
      final samples = SignalGenerator.clickTrack(
        bpm: 120,
        durationSeconds: 5,
      );
      final frames = FrameSplitter.split(
        samples,
        frameSize: 1024,
        hopSize: 512,
      );
      final frameCount = frames.length;
      final onsets = OnsetDetector.detect(
        frames,
        frameSize: 1024,
        sampleRate: 44100,
        hopSize: 512,
      );
      expect(onsets.length, frameCount);
    });

    test('click track produces spikes at beat positions', () {
      final samples = SignalGenerator.clickTrack(
        bpm: 120,
        durationSeconds: 5,
      );
      final frames = FrameSplitter.split(
        samples,
        frameSize: 1024,
        hopSize: 512,
      );
      final onsets = OnsetDetector.detect(
        frames,
        frameSize: 1024,
        sampleRate: 44100,
        hopSize: 512,
      );

      // Find peaks in onset signal
      final maxOnset = onsets.reduce((a, b) => a > b ? a : b);
      expect(maxOnset, greaterThan(0.0), reason: 'Should detect onsets');

      // Count peaks above 50% of max
      final threshold = maxOnset * 0.5;
      var peakCount = 0;
      for (var i = 1; i < onsets.length - 1; i++) {
        if (onsets[i] > threshold &&
            onsets[i] >= onsets[i - 1] &&
            onsets[i] >= onsets[i + 1]) {
          peakCount++;
        }
      }
      // 120 BPM for 5 seconds = 10 beats. Allow some tolerance.
      expect(peakCount, inInclusiveRange(8, 12));
    });

    test('silence produces all-zero onset signal', () {
      final samples = SignalGenerator.silence(durationSeconds: 3);
      final frames = FrameSplitter.split(
        samples,
        frameSize: 1024,
        hopSize: 512,
      );
      final onsets = OnsetDetector.detect(
        frames,
        frameSize: 1024,
        sampleRate: 44100,
        hopSize: 512,
      );
      final maxOnset = onsets.reduce((a, b) => a > b ? a : b);
      expect(maxOnset, 0.0);
    });

    test('onset values are non-negative after adaptive threshold', () {
      final samples = SignalGenerator.clickTrack(
        bpm: 100,
        durationSeconds: 5,
      );
      final frames = FrameSplitter.split(
        samples,
        frameSize: 1024,
        hopSize: 512,
      );
      final onsets = OnsetDetector.detect(
        frames,
        frameSize: 1024,
        sampleRate: 44100,
        hopSize: 512,
      );
      for (final value in onsets) {
        expect(value, greaterThanOrEqualTo(0.0));
      }
    });
  });
}
