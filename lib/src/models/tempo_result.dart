import 'package:blaq_tempo_detector/src/models/beat_info.dart';
import 'package:blaq_tempo_detector/src/models/confidence.dart';
import 'package:blaq_tempo_detector/src/models/tempo_candidate.dart';
import 'package:blaq_tempo_detector/src/models/undetectable_reason.dart';

sealed class TempoResult {
  const TempoResult();
}

class TempoDetected extends TempoResult {
  final double bpm;
  final Confidence confidence;
  final List<BeatInfo> beats;
  final List<TempoCandidate> candidates;

  const TempoDetected({
    required this.bpm,
    required this.confidence,
    required this.beats,
    required this.candidates,
  });

  @override
  String toString() =>
      'TempoDetected(bpm: $bpm, confidence: $confidence, '
      'beats: ${beats.length}, candidates: ${candidates.length})';
}

class TempoUndetectable extends TempoResult {
  final UndetectableReason reason;

  const TempoUndetectable({required this.reason});

  @override
  String toString() => 'TempoUndetectable(reason: $reason)';
}
