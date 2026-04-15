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
}
