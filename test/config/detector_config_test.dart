import 'package:blaq_tempo_detector/src/config/detector_config.dart';
import 'package:test/test.dart';

void main() {
  group('DetectorConfig', () {
    test('has sensible defaults', () {
      final config = DetectorConfig();
      expect(config.frameSize, 1024);
      expect(config.hopSize, 512);
      expect(config.bpmMin, 30);
      expect(config.bpmMax, 300);
      expect(config.perceptualCenter, 120.0);
      expect(config.strongThreshold, 0.7);
      expect(config.likelyThreshold, 0.4);
    });

    test('accepts custom values', () {
      final config = DetectorConfig(
        frameSize: 2048,
        hopSize: 1024,
        bpmMin: 60,
        bpmMax: 200,
        perceptualCenter: 100.0,
        strongThreshold: 0.8,
        likelyThreshold: 0.5,
      );
      expect(config.frameSize, 2048);
      expect(config.hopSize, 1024);
      expect(config.bpmMin, 60);
      expect(config.bpmMax, 200);
    });

    test('throws ArgumentError when bpmMin >= bpmMax', () {
      expect(
        () => DetectorConfig(bpmMin: 200, bpmMax: 100),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError when bpmMin equals bpmMax', () {
      expect(
        () => DetectorConfig(bpmMin: 120, bpmMax: 120),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError when frameSize is not positive', () {
      expect(() => DetectorConfig(frameSize: 0), throwsArgumentError);
    });

    test('throws ArgumentError when hopSize is not positive', () {
      expect(() => DetectorConfig(hopSize: 0), throwsArgumentError);
    });

    test('throws ArgumentError when hopSize > frameSize', () {
      expect(
        () => DetectorConfig(frameSize: 512, hopSize: 1024),
        throwsArgumentError,
      );
    });
  });

  group('DetectorConfig melodic fields', () {
    test('defaults match spec', () {
      final config = DetectorConfig();
      expect(config.melodicFallback, isTrue);
      expect(config.chromaFrameSize, 4096);
      expect(config.chromaHopSize, 2048);
      expect(config.melodicChromaWeight, 0.6);
      expect(config.melodicPerceptualCenters, [72.0, 100.0, 140.0]);
      expect(config.melodicPerceptualSigma, 0.4);
    });

    test('rejects non-positive chromaFrameSize', () {
      expect(() => DetectorConfig(chromaFrameSize: 0), throwsArgumentError);
      expect(() => DetectorConfig(chromaFrameSize: -1), throwsArgumentError);
    });

    test('rejects chromaHopSize > chromaFrameSize', () {
      expect(
        () => DetectorConfig(chromaFrameSize: 1024, chromaHopSize: 2048),
        throwsArgumentError,
      );
    });

    test('rejects melodicChromaWeight outside [0, 1]', () {
      expect(() => DetectorConfig(melodicChromaWeight: -0.1), throwsArgumentError);
      expect(() => DetectorConfig(melodicChromaWeight: 1.1), throwsArgumentError);
    });

    test('rejects empty melodicPerceptualCenters', () {
      expect(
        () => DetectorConfig(melodicPerceptualCenters: const []),
        throwsArgumentError,
      );
    });

    test('rejects non-positive melodicPerceptualSigma', () {
      expect(() => DetectorConfig(melodicPerceptualSigma: 0.0), throwsArgumentError);
      expect(() => DetectorConfig(melodicPerceptualSigma: -1.0), throwsArgumentError);
    });
  });
}
