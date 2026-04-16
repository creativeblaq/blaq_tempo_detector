import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:blaq_tempo_detector/src/config/detector_config.dart';
import 'package:blaq_tempo_detector/src/models/confidence.dart';
import 'package:blaq_tempo_detector/src/models/tempo_result.dart';
import 'package:blaq_tempo_detector/src/models/undetectable_reason.dart';
import 'package:blaq_tempo_detector/src/pipeline/autocorrelator.dart';
import 'package:blaq_tempo_detector/src/pipeline/beat_tracker.dart';
import 'package:blaq_tempo_detector/src/pipeline/frame_splitter.dart';
import 'package:blaq_tempo_detector/src/pipeline/onset_detector.dart';
import 'package:blaq_tempo_detector/src/pipeline/perceptual_weighting.dart';

class TempoDetector {
  const TempoDetector._();

  static const _minSampleRate = 8000;
  static const _maxSampleRate = 192000;
  static const _minDurationSeconds = 3.0;

  /// Minimum `topScore / medianScore` ratio required to accept a candidate
  /// as a real tempo. Empirically: noise sits around 5–7, real music around
  /// 5–50+, solo click tracks can exceed 100.
  static const _peakRatioThreshold = 5.0;

  /// Upper end of the `peakRatio` range used for confidence normalization.
  /// Ratios at or above this map to confidence 1.0.
  static const _peakRatioConfidenceMax = 50.0;

  /// Maximum fraction of candidates allowed to score above half the top
  /// score. Noise has a flat post-weighting distribution (~15–25% cluster
  /// above half-peak), while rhythmic content has a sharp peak (≤ 10%).
  static const _maxHalfPeakClutter = 0.12;

  /// Upper limit on the number of candidates returned in [TempoDetected].
  /// The full candidate list from autocorrelation is ~150 entries; anything
  /// past the top few is noise not worth surfacing to the UI.
  static const _maxReportedCandidates = 10;

  /// Analyzes [samples] and returns a [TempoResult].
  ///
  /// [sampleRate] must be between 8000 and 192000.
  /// [startSample] and [endSample] optionally restrict the analysis window.
  static TempoResult analyze(
    Float64List samples, {
    required int sampleRate,
    DetectorConfig? config,
    int startSample = 0,
    int? endSample,
  }) {
    config ??= DetectorConfig();
    // Validate sample rate
    if (sampleRate < _minSampleRate || sampleRate > _maxSampleRate) {
      throw ArgumentError.value(
        sampleRate,
        'sampleRate',
        'Must be between $_minSampleRate and $_maxSampleRate',
      );
    }

    // Validate and apply sample range
    final effectiveEnd = endSample ?? samples.length;

    // Empty or too-short samples — caught below by duration check, but we must
    // avoid the startSample >= effectiveEnd guard firing on empty input.
    if (samples.isEmpty || effectiveEnd == 0) {
      return const TempoUndetectable(reason: UndetectableReason.tooShort);
    }

    if (startSample >= effectiveEnd) {
      throw RangeError.range(
        startSample,
        0,
        effectiveEnd - 1,
        'startSample',
        'Must be less than endSample ($effectiveEnd)',
      );
    }
    if (startSample < 0 || effectiveEnd > samples.length) {
      throw RangeError.range(
        startSample < 0 ? startSample : effectiveEnd,
        0,
        samples.length,
        startSample < 0 ? 'startSample' : 'endSample',
      );
    }

    final segment = Float64List.sublistView(samples, startSample, effectiveEnd);

    // Check minimum duration
    final durationSeconds = segment.length / sampleRate;
    if (durationSeconds < _minDurationSeconds) {
      return const TempoUndetectable(reason: UndetectableReason.tooShort);
    }

    _log(
      config,
      'analyze: ${segment.length} samples @ ${sampleRate}Hz '
      '(${durationSeconds.toStringAsFixed(2)}s), '
      'frameSize=${config.frameSize} hopSize=${config.hopSize} '
      'bpmRange=${config.bpmMin}-${config.bpmMax}',
    );

    // Pipeline stage 1: Frame splitting
    final frames = FrameSplitter.split(
      segment,
      frameSize: config.frameSize,
      hopSize: config.hopSize,
    );

    _log(config, 'stage1 frames: ${frames.length}');

    // Pipeline stage 2: Onset detection
    final onsetSignal = OnsetDetector.detect(
      frames,
      frameSize: config.frameSize,
      sampleRate: sampleRate,
      hopSize: config.hopSize,
    );

    // Check for silence
    var maxOnset = 0.0;
    var sumOnset = 0.0;
    var nonzeroCount = 0;
    for (final v in onsetSignal) {
      if (v > maxOnset) maxOnset = v;
      sumOnset += v;
      if (v > 0) nonzeroCount++;
    }
    final meanOnset = onsetSignal.isEmpty ? 0.0 : sumOnset / onsetSignal.length;
    _log(
      config,
      'stage2 onsetSignal: length=${onsetSignal.length} '
      'max=${maxOnset.toStringAsFixed(6)} '
      'mean=${meanOnset.toStringAsFixed(6)} '
      'nonzero=$nonzeroCount/${onsetSignal.length}',
    );

    if (maxOnset == 0.0) {
      return const TempoUndetectable(reason: UndetectableReason.silence);
    }

    // Pipeline stage 3: Autocorrelation
    final rawCandidates = Autocorrelator.correlate(
      onsetSignal,
      sampleRate: sampleRate,
      hopSize: config.hopSize,
      bpmMin: config.bpmMin,
      bpmMax: config.bpmMax,
    );

    _log(
      config,
      'stage3 rawCandidates: ${rawCandidates.length} '
      'top=${_formatTopCandidates(rawCandidates, 5)}',
    );

    if (rawCandidates.isEmpty) {
      return const TempoUndetectable(reason: UndetectableReason.noPattern);
    }

    // Pipeline stage 4: Perceptual weighting
    final candidates = PerceptualWeighting.apply(
      rawCandidates,
      center: config.perceptualCenter,
    );

    _log(
      config,
      'stage4 weightedCandidates: ${candidates.length} '
      'top=${_formatTopCandidates(candidates, 5)}',
    );

    if (candidates.isEmpty) {
      return const TempoUndetectable(reason: UndetectableReason.noPattern);
    }

    final topCandidate = candidates.first;

    // Compare top score to the median score (noise floor). Median is used
    // instead of mean because real music has many harmonically-related
    // peaks (½-time, double-time, triplet sub-beats) that inflate the mean
    // even when the true tempo dominates. Median reflects the actual
    // between-peak correlation level.
    final sortedScores = candidates.map((c) => c.score).toList()..sort();
    final medianScore = sortedScores[sortedScores.length ~/ 2];
    final peakRatio = medianScore > 0
        ? topCandidate.score / medianScore
        : double.infinity;

    // Count of candidates with score >= half of the top. Noise has a flat
    // distribution (many candidates near the peak); real tempos have a
    // sharp peak with few neighbours near its height.
    final halfPeakThreshold = topCandidate.score * 0.5;
    final aboveHalfPeak =
        candidates.where((c) => c.score >= halfPeakThreshold).length;
    final halfPeakClutter = aboveHalfPeak / candidates.length;

    _log(
      config,
      'stage5 peakRatio=${peakRatio.toStringAsFixed(2)} '
      '(topScore=${topCandidate.score.toStringAsFixed(4)}, '
      'medianScore=${medianScore.toStringAsFixed(4)}, '
      'aboveHalfPeak=$aboveHalfPeak/${candidates.length} '
      '= ${(halfPeakClutter * 100).toStringAsFixed(1)}%, '
      'thresholds: peakRatio>=$_peakRatioThreshold, '
      'clutter<=${(_maxHalfPeakClutter * 100).toStringAsFixed(0)}%)',
    );

    // Reject if no single candidate dominates (clutter gate) or the peak is
    // barely above the noise floor (peakRatio gate).
    if (halfPeakClutter > _maxHalfPeakClutter ||
        peakRatio < _peakRatioThreshold) {
      return const TempoUndetectable(reason: UndetectableReason.noPattern);
    }

    // Pipeline stage 5: Beat tracking
    final beats = BeatTracker.track(
      onsetSignal,
      bpm: topCandidate.bpm,
      sampleRate: sampleRate,
      hopSize: config.hopSize,
    );

    // Determine confidence
    final confidence = _classifyConfidence(
      peakRatio,
      strongThreshold: config.strongThreshold,
      likelyThreshold: config.likelyThreshold,
    );

    // Keep only the strongest candidates for display. Beyond the top 10,
    // scores are effectively noise and only clutter the UI.
    final topCandidates = candidates.length > _maxReportedCandidates
        ? candidates.sublist(0, _maxReportedCandidates)
        : candidates;

    return TempoDetected(
      bpm: topCandidate.bpm,
      confidence: confidence,
      beats: beats,
      candidates: topCandidates,
    );
  }

  static Confidence _classifyConfidence(
    double peakRatio, {
    required double strongThreshold,
    required double likelyThreshold,
  }) {
    // Scale peakRatio to a 0–1 confidence score. Valid rhythmic ratios range
    // from [_peakRatioThreshold] up to [_peakRatioConfidenceMax] — typical
    // music spans 5–50, click tracks clip to 1.0.
    const span = _peakRatioConfidenceMax - _peakRatioThreshold;
    final normalized =
        ((peakRatio - _peakRatioThreshold) / span).clamp(0.0, 1.0);
    if (normalized >= strongThreshold) return Confidence.strong;
    if (normalized >= likelyThreshold) return Confidence.likely;
    return Confidence.uncertain;
  }

  static void _log(DetectorConfig config, String message) {
    if (!config.verbose) return;
    // ignore: avoid_print
    print('[TempoDetector] $message');
    developer.log(message, name: 'TempoDetector');
  }

  static String _formatTopCandidates(List<dynamic> candidates, int take) {
    if (candidates.isEmpty) return '[]';
    final count = take < candidates.length ? take : candidates.length;
    final buf = StringBuffer('[');
    for (var i = 0; i < count; i++) {
      final c = candidates[i];
      final bpm = (c.bpm as double).toStringAsFixed(2);
      final score = (c.score as double).toStringAsFixed(4);
      if (i > 0) buf.write(', ');
      buf.write('${bpm}bpm:$score');
    }
    if (candidates.length > count) buf.write(', …');
    buf.write(']');
    return buf.toString();
  }
}
