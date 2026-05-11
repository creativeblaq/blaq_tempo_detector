import 'package:blaq_tempo_detector/src/models/tempo_candidate.dart';
import 'package:blaq_tempo_detector/src/pipeline/perceptual_weighting.dart';
import 'package:test/test.dart';

void main() {
  group('PerceptualWeighting.applyMultiCenter', () {
    const centers = [72.0, 100.0, 140.0];
    const sigma = 0.4;

    test('ballad candidate at 70 BPM beats double at 140 with equal raw peaks', () {
      final candidates = [
        const TempoCandidate(bpm: 70.0, score: 1.0),
        const TempoCandidate(bpm: 140.0, score: 1.0),
      ];
      final result = PerceptualWeighting.applyMultiCenter(
        candidates, centers: centers, sigma: sigma,
      );
      expect(result.first.bpm, 70.0);
    });

    test('fast candidate at 140 beats double at 280 with equal raw peaks', () {
      final candidates = [
        const TempoCandidate(bpm: 140.0, score: 1.0),
        const TempoCandidate(bpm: 280.0, score: 1.0),
      ];
      final result = PerceptualWeighting.applyMultiCenter(
        candidates, centers: centers, sigma: sigma,
      );
      expect(result.first.bpm, 140.0);
    });

    test('half/double rescue: prefers candidate closer to a center', () {
      // 70 sits right on the slow center; 140 sits right on the fast center.
      // Voted scores will be very close; rescue should NOT change the winner
      // here because both are equally on-center. We verify it doesn't break
      // the obvious winner.
      final candidates = [
        const TempoCandidate(bpm: 70.0, score: 1.05),
        const TempoCandidate(bpm: 140.0, score: 1.00),
      ];
      final result = PerceptualWeighting.applyMultiCenter(
        candidates, centers: centers, sigma: sigma,
      );
      expect(result.first.bpm, 70.0);
    });

    test('half/double rescue triggers when raw peaks are within 10%', () {
      // 65 BPM is closer to the 72 center than 130 is to either 100 or 140.
      // With near-equal raw peaks, the rescue should pick 65.
      final candidates = [
        const TempoCandidate(bpm: 130.0, score: 1.00),
        const TempoCandidate(bpm: 65.0, score: 0.95),
      ];
      final result = PerceptualWeighting.applyMultiCenter(
        candidates, centers: centers, sigma: sigma,
      );
      expect(result.first.bpm, 65.0);
    });

    test('empty input returns empty output', () {
      final result = PerceptualWeighting.applyMultiCenter(
        const [], centers: centers, sigma: sigma,
      );
      expect(result, isEmpty);
    });

    test('empty centers throws ArgumentError', () {
      expect(
        () => PerceptualWeighting.applyMultiCenter(
          [const TempoCandidate(bpm: 120.0, score: 1.0)],
          centers: [],
          sigma: 0.4,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('output sorted by voted score descending', () {
      final candidates = [
        const TempoCandidate(bpm: 200.0, score: 0.2),
        const TempoCandidate(bpm: 100.0, score: 0.5),
        const TempoCandidate(bpm: 50.0, score: 0.4),
      ];
      final result = PerceptualWeighting.applyMultiCenter(
        candidates, centers: centers, sigma: sigma,
      );
      for (var i = 1; i < result.length; i++) {
        expect(result[i - 1].score, greaterThanOrEqualTo(result[i].score));
      }
    });
  });
}
