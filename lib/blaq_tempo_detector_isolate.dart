/// Async/isolate convenience API for BPM detection.
///
/// Re-exports the sync API models plus [TempoDetectorIsolate]
/// which runs detection on a separate isolate via [Isolate.run].
library;

export 'src/config/detector_config.dart';
export 'src/isolate/isolate_runner.dart';
export 'src/models/beat_info.dart';
export 'src/models/confidence.dart';
export 'src/models/tempo_candidate.dart';
export 'src/models/tempo_result.dart';
export 'src/models/tempo_strategy.dart';
export 'src/models/undetectable_reason.dart';
