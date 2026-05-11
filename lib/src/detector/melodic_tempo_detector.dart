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

  /// Upper end of the `peakRatio` range used for confidence normalization.
  /// Ratios at or above this map to confidenceScore 1.0. Empirically tuned
  /// for the smaller dynamic range of multi-center voted scores — crisp
  /// material produces peakRatio ~8–15, noise sits near the gate at ~2.
  static const _peakRatioConfidenceMax = 10.0;

  /// Same minimum-duration guard as TempoDetector.
  static const _minDurationSeconds = 3.0;

  /// Minimum `topScore / medianScore` ratio for the melodic pipeline to accept
  /// its top candidate as a real tempo. Mirrors TempoDetector's gate but tuned
  /// for the smaller dynamic range of voted scores in multi-center weighting.
  ///
  /// Loosened from 3.0 → 2.0 in v0.2.2: real piano+vocal recordings produce
  /// shallower peaks than synthetic chord stabs (sustain, legato, vocal
  /// continuity blur the novelty curve). Pure white noise still produces a
  /// peakRatio below 2.0 in our test signals, so 2.0 remains a meaningful gate.
  static const _melodicPeakRatioThreshold = 2.0;

  /// Maximum fraction of weighted candidates allowed above half the top score.
  /// Same intent as TempoDetector._maxHalfPeakClutter — noise has a flat
  /// post-weighting distribution; real tempos have a sharp peak.
  ///
  /// Loosened from 0.20 → 0.30 in v0.2.2 alongside the peakRatio gate.
  static const _melodicMaxHalfPeakClutter = 0.30;

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

    // Confidence score: peakRatio-normalized (mirrors percussive pipeline).
    // Voted-score-based confidence saturates too aggressively — noise with a
    // shallow peak still produces voted score ~0.4 and would saturate to 1.0.
    // peakRatio is the better discriminator: noise sits near the gate (~2),
    // real melodic material spans 3–15.
    const span = _peakRatioConfidenceMax - _melodicPeakRatioThreshold;
    final confidenceScore = ((peakRatio - _melodicPeakRatioThreshold) / span)
        .clamp(0.0, 1.0);
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
