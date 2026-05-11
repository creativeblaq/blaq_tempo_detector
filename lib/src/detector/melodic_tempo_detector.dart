import 'dart:typed_data';

import 'package:blaq_tempo_detector/src/config/detector_config.dart';
import 'package:blaq_tempo_detector/src/models/confidence.dart';
import 'package:blaq_tempo_detector/src/models/tempo_result.dart';
import 'package:blaq_tempo_detector/src/models/tempo_strategy.dart';
import 'package:blaq_tempo_detector/src/models/undetectable_reason.dart';
import 'package:blaq_tempo_detector/src/pipeline/autocorrelator.dart';
import 'package:blaq_tempo_detector/src/pipeline/beat_tracker.dart';
import 'package:blaq_tempo_detector/src/pipeline/chroma_extractor.dart';
import 'package:blaq_tempo_detector/src/pipeline/chroma_novelty.dart';
import 'package:blaq_tempo_detector/src/pipeline/frame_splitter.dart';
import 'package:blaq_tempo_detector/src/pipeline/mel_flux_detector.dart';
import 'package:blaq_tempo_detector/src/pipeline/novelty_fusion.dart';
import 'package:blaq_tempo_detector/src/pipeline/perceptual_weighting.dart';

/// Melodic fallback tempo detection pipeline. Not exported — designed to be
/// invoked internally by [TempoDetector] when the percussive pipeline returns
/// low confidence or `TempoUndetectable`. The cascade wiring is added by
/// [TempoDetector.analyze] in a subsequent commit.
class MelodicTempoDetector {
  const MelodicTempoDetector._();

  // Confidence normalization: top voted score >= this maps to 1.0.
  static const _votedScoreMax = 0.4;

  /// Same minimum-duration guard as TempoDetector.
  static const _minDurationSeconds = 3.0;

  /// Minimum `topScore / medianScore` ratio for the melodic pipeline to accept
  /// its top candidate as a real tempo. Mirrors TempoDetector's gate but tuned
  /// for the smaller dynamic range of voted scores in multi-center weighting.
  static const _melodicPeakRatioThreshold = 3.0;

  /// Maximum fraction of weighted candidates allowed above half the top score.
  /// Same intent as TempoDetector._maxHalfPeakClutter — noise has a flat
  /// post-weighting distribution; real tempos have a sharp peak.
  static const _melodicMaxHalfPeakClutter = 0.20;

  static TempoResult analyze(
    Float64List samples, {
    required int sampleRate,
    required DetectorConfig config,
  }) {
    final durationSeconds = samples.length / sampleRate;
    if (durationSeconds < _minDurationSeconds) {
      return const TempoUndetectable(reason: UndetectableReason.tooShort);
    }

    // Stage 1: frame split using the chroma window/hop.
    final framesList = FrameSplitter.split(
      samples,
      frameSize: config.chromaFrameSize,
      hopSize: config.chromaHopSize,
    ).toList();

    if (framesList.isEmpty) {
      return const TempoUndetectable(reason: UndetectableReason.tooShort);
    }

    // Stage 2: chroma vectors.
    final chroma = ChromaExtractor.extract(
      framesList,
      frameSize: config.chromaFrameSize,
      sampleRate: sampleRate,
    );

    // Stage 3a: chroma novelty.
    final chromaNov = ChromaNovelty.detect(
      chroma,
      sampleRate: sampleRate,
      hopSize: config.chromaHopSize,
    );

    // Stage 3b: log-mel flux on the same frames/hop.
    final melFlux = MelFluxDetector.detect(
      framesList,
      frameSize: config.chromaFrameSize,
      sampleRate: sampleRate,
      hopSize: config.chromaHopSize,
    );

    // Stage 4: fuse.
    final fused = NoveltyFusion.fuse(
      chromaNov, melFlux, chromaWeight: config.melodicChromaWeight,
    );

    var maxFused = 0.0;
    for (final v in fused) {
      if (v > maxFused) maxFused = v;
    }
    if (maxFused == 0.0) {
      return const TempoUndetectable(reason: UndetectableReason.silence);
    }

    // Stage 5: autocorrelation on fused novelty.
    final rawCandidates = Autocorrelator.correlate(
      fused,
      sampleRate: sampleRate,
      hopSize: config.chromaHopSize,
      bpmMin: config.bpmMin,
      bpmMax: config.bpmMax,
    );
    if (rawCandidates.isEmpty) {
      return const TempoUndetectable(reason: UndetectableReason.noPattern);
    }

    // Stage 6: multi-center voting.
    // applyMultiCenter only returns [] for empty input; rawCandidates was
    // already empty-checked above, so weighted is guaranteed non-empty here.
    final weighted = PerceptualWeighting.applyMultiCenter(
      rawCandidates,
      centers: config.melodicPerceptualCenters,
      sigma: config.melodicPerceptualSigma,
    );
    final top = weighted.first;

    // Noise gates — reject if the top candidate doesn't dominate.
    final scores = weighted.map((c) => c.score).toList()..sort();
    final medianScore = scores[scores.length ~/ 2];
    final peakRatio = medianScore > 0
        ? top.score / medianScore
        : double.infinity;

    final halfPeakThreshold = top.score * 0.5;
    final aboveHalfPeak =
        weighted.where((c) => c.score >= halfPeakThreshold).length;
    final halfPeakClutter = aboveHalfPeak / weighted.length;

    if (peakRatio < _melodicPeakRatioThreshold ||
        halfPeakClutter > _melodicMaxHalfPeakClutter) {
      return const TempoUndetectable(reason: UndetectableReason.noPattern);
    }

    // Confidence score: voted score normalized against an empirical max.
    final confidenceScore = (top.score / _votedScoreMax).clamp(0.0, 1.0);
    final confidence = _classify(
      confidenceScore,
      strongThreshold: config.strongThreshold,
      likelyThreshold: config.likelyThreshold,
    );

    // Stage 7: DP beats on the fused novelty.
    final beats = BeatTracker.track(
      fused, bpm: top.bpm, sampleRate: sampleRate, hopSize: config.chromaHopSize,
    );

    // Keep only the top 10 candidates for UI display.
    final reported = weighted.length > 10 ? weighted.sublist(0, 10) : weighted;

    return TempoDetected(
      bpm: top.bpm,
      confidence: confidence,
      confidenceScore: confidenceScore,
      beats: beats,
      candidates: reported,
      strategy: TempoStrategy.melodic,
    );
  }

  static Confidence _classify(
    double score, {
    required double strongThreshold,
    required double likelyThreshold,
  }) {
    if (score >= strongThreshold) return Confidence.strong;
    if (score >= likelyThreshold) return Confidence.likely;
    return Confidence.uncertain;
  }
}
