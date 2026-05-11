/// Pure Dart BPM detection from raw PCM audio.
///
/// Provides synchronous tempo detection via [TempoDetector] (single-shot)
/// and [TempoTracker] (incremental/streaming).
///
/// For async/isolate convenience, use `blaq_tempo_detector_isolate.dart`.
library;

export 'src/config/detector_config.dart';
export 'src/detector/tempo_detector.dart';
export 'src/detector/tempo_tracker.dart';
export 'src/models/beat_info.dart';
export 'src/models/confidence.dart';
export 'src/models/tempo_candidate.dart';
export 'src/models/tempo_result.dart';
export 'src/models/tempo_strategy.dart';
export 'src/models/undetectable_reason.dart';
