import 'package:blaq_tempo_detector/src/models/tempo_candidate.dart';
import 'package:blaq_tempo_detector/src/pipeline/perceptual_weighting.dart';
import 'package:test/test.dart';

void main() {
  group('PerceptualWeighting', () {
    test('120 BPM beats 60 BPM when raw scores are equal', () {
      final candidates = [
        const TempoCandidate(bpm: 60.0, score: 1.0),
        const TempoCandidate(bpm: 120.0, score: 1.0),
        const TempoCandidate(bpm: 240.0, score: 1.0),
      ];

      final weighted = PerceptualWeighting.apply(candidates, center: 120.0);
      expect(weighted.first.bpm, 120.0);
    });

    test('90 BPM beats 180 BPM when raw scores are equal', () {
      final candidates = [
        const TempoCandidate(bpm: 180.0, score: 1.0),
        const TempoCandidate(bpm: 90.0, score: 1.0),
      ];

      final weighted = PerceptualWeighting.apply(candidates, center: 120.0);
      expect(weighted.first.bpm, 90.0);
    });

    test('result is sorted by weighted score descending', () {
      final candidates = [
        const TempoCandidate(bpm: 60.0, score: 0.9),
        const TempoCandidate(bpm: 120.0, score: 0.8),
        const TempoCandidate(bpm: 200.0, score: 0.7),
      ];

      final weighted = PerceptualWeighting.apply(candidates, center: 120.0);
      for (var i = 1; i < weighted.length; i++) {
        expect(
          weighted[i].score,
          lessThanOrEqualTo(weighted[i - 1].score),
        );
      }
    });

    test('does not remove any candidates', () {
      final candidates = [
        const TempoCandidate(bpm: 40.0, score: 0.5),
        const TempoCandidate(bpm: 120.0, score: 0.5),
        const TempoCandidate(bpm: 280.0, score: 0.5),
      ];

      final weighted = PerceptualWeighting.apply(candidates, center: 120.0);
      expect(weighted.length, candidates.length);
    });

    test('custom center shifts the preference', () {
      final candidates = [
        const TempoCandidate(bpm: 80.0, score: 1.0),
        const TempoCandidate(bpm: 160.0, score: 1.0),
      ];

      final weighted = PerceptualWeighting.apply(candidates, center: 80.0);
      expect(weighted.first.bpm, 80.0);
    });

    test('returns empty list for empty input', () {
      final weighted = PerceptualWeighting.apply([], center: 120.0);
      expect(weighted, isEmpty);
    });
  });
}
