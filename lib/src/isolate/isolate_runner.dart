import 'dart:isolate';
import 'dart:typed_data';

import 'package:blaq_tempo_detector/src/config/detector_config.dart';
import 'package:blaq_tempo_detector/src/detector/tempo_detector.dart';
import 'package:blaq_tempo_detector/src/models/tempo_result.dart';

class TempoDetectorIsolate {
  const TempoDetectorIsolate._();

  /// Runs [TempoDetector.analyze] on a separate isolate.
  ///
  /// Same API as [TempoDetector.analyze] but returns a [Future].
  /// Validates [sampleRate] eagerly before spawning the isolate.
  static Future<TempoResult> analyze(
    Float64List samples, {
    required int sampleRate,
    DetectorConfig? config,
    int startSample = 0,
    int? endSample,
  }) {
    // Validate eagerly so errors are thrown on the calling isolate
    if (sampleRate < 8000 || sampleRate > 192000) {
      throw ArgumentError.value(
        sampleRate,
        'sampleRate',
        'Must be between 8000 and 192000',
      );
    }

    return Isolate.run(
      () => TempoDetector.analyze(
        samples,
        sampleRate: sampleRate,
        config: config,
        startSample: startSample,
        endSample: endSample,
      ),
    );
  }
}
