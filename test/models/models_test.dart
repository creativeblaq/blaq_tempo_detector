import 'package:blaq_tempo_detector/src/models/beat_info.dart';
import 'package:blaq_tempo_detector/src/models/confidence.dart';
import 'package:blaq_tempo_detector/src/models/tempo_candidate.dart';
import 'package:blaq_tempo_detector/src/models/tempo_result.dart';
import 'package:blaq_tempo_detector/src/models/undetectable_reason.dart';
import 'package:test/test.dart';

void main() {
  group('Confidence', () {
    test('has three values', () {
      expect(Confidence.values.length, 3);
      expect(Confidence.values, contains(Confidence.strong));
      expect(Confidence.values, contains(Confidence.likely));
      expect(Confidence.values, contains(Confidence.uncertain));
    });
  });

  group('UndetectableReason', () {
    test('has three values', () {
      expect(UndetectableReason.values.length, 3);
      expect(UndetectableReason.values, contains(UndetectableReason.tooShort));
      expect(UndetectableReason.values, contains(UndetectableReason.silence));
      expect(
        UndetectableReason.values,
        contains(UndetectableReason.noPattern),
      );
    });
  });

  group('BeatInfo', () {
    test('stores timestamp and onset strength', () {
      const beat = BeatInfo(timestampSeconds: 1.5, onsetStrength: 0.8);
      expect(beat.timestampSeconds, 1.5);
      expect(beat.onsetStrength, 0.8);
    });

    test('toString includes values', () {
      const beat = BeatInfo(timestampSeconds: 1.5, onsetStrength: 0.8);
      expect(beat.toString(), contains('1.5'));
      expect(beat.toString(), contains('0.8'));
    });
  });

  group('TempoCandidate', () {
    test('stores bpm and score', () {
      const candidate = TempoCandidate(bpm: 120.0, score: 0.9);
      expect(candidate.bpm, 120.0);
      expect(candidate.score, 0.9);
    });

    test('toString includes values', () {
      const candidate = TempoCandidate(bpm: 120.0, score: 0.9);
      expect(candidate.toString(), contains('120'));
      expect(candidate.toString(), contains('0.9'));
    });
  });

  group('TempoResult', () {
    test('TempoDetected holds all fields', () {
      const result = TempoDetected(
        bpm: 120.0,
        confidence: Confidence.strong,
        beats: [BeatInfo(timestampSeconds: 0.5, onsetStrength: 0.9)],
        candidates: [TempoCandidate(bpm: 120.0, score: 0.85)],
      );
      expect(result.bpm, 120.0);
      expect(result.confidence, Confidence.strong);
      expect(result.beats.length, 1);
      expect(result.candidates.length, 1);
    });

    test('TempoUndetectable holds reason', () {
      const result = TempoUndetectable(reason: UndetectableReason.silence);
      expect(result.reason, UndetectableReason.silence);
    });

    test('sealed class exhaustive switch works', () {
      const TempoResult result = TempoDetected(
        bpm: 120.0,
        confidence: Confidence.strong,
        beats: [],
        candidates: [],
      );
      final description = switch (result) {
        TempoDetected(:final bpm) => 'Detected: $bpm BPM',
        TempoUndetectable(:final reason) => 'Undetectable: $reason',
      };
      expect(description, 'Detected: 120.0 BPM');
    });
  });
}
