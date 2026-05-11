import 'package:blaq_tempo_detector/src/models/beat_info.dart';
import 'package:blaq_tempo_detector/src/models/confidence.dart';
import 'package:blaq_tempo_detector/src/models/tempo_candidate.dart';
import 'package:blaq_tempo_detector/src/models/tempo_strategy.dart';
import 'package:blaq_tempo_detector/src/models/undetectable_reason.dart';

sealed class TempoResult {
  const TempoResult();
}

class TempoDetected extends TempoResult {
  final double bpm;
  final Confidence confidence;

  /// Normalized confidence in [0.0, 1.0]. Derived from `peakRatio` in the
  /// percussive pipeline; from the winning candidate's voted score in the
  /// melodic pipeline. Used internally by the cascade to compare two
  /// `TempoDetected` results when both pipelines run.
  final double confidenceScore;

  final List<BeatInfo> beats;
  final List<TempoCandidate> candidates;

  /// Which internal pipeline produced this result.
  final TempoStrategy strategy;

  const TempoDetected({
    required this.bpm,
    required this.confidence,
    required this.confidenceScore,
    required this.beats,
    required this.candidates,
    this.strategy = TempoStrategy.percussive,
  });

  @override
  String toString() =>
      'TempoDetected(bpm: $bpm, confidence: $confidence, '
      'score: ${confidenceScore.toStringAsFixed(2)}, '
      'beats: ${beats.length}, candidates: ${candidates.length}, '
      'strategy: $strategy)';
}

class TempoUndetectable extends TempoResult {
  final UndetectableReason reason;

  const TempoUndetectable({required this.reason});

  @override
  String toString() => 'TempoUndetectable(reason: $reason)';
}
