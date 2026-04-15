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

    // Pipeline stage 1: Frame splitting
    final frames = FrameSplitter.split(
      segment,
      frameSize: config.frameSize,
      hopSize: config.hopSize,
    );

    // Pipeline stage 2: Onset detection
    final onsetSignal = OnsetDetector.detect(
      frames,
      frameSize: config.frameSize,
      sampleRate: sampleRate,
      hopSize: config.hopSize,
    );

    // Check for silence
    var maxOnset = 0.0;
    for (final v in onsetSignal) {
      if (v > maxOnset) maxOnset = v;
    }
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

    if (rawCandidates.isEmpty) {
      return const TempoUndetectable(reason: UndetectableReason.noPattern);
    }

    // Pipeline stage 4: Perceptual weighting
    final candidates = PerceptualWeighting.apply(
      rawCandidates,
      center: config.perceptualCenter,
    );

    if (candidates.isEmpty) {
      return const TempoUndetectable(reason: UndetectableReason.noPattern);
    }

    final topCandidate = candidates.first;

    // Compare top score to mean score — if ratio is low, no clear pattern
    var scoreSum = 0.0;
    for (final c in candidates) {
      scoreSum += c.score;
    }
    final meanScore = scoreSum / candidates.length;
    final peakRatio = meanScore > 0 ? topCandidate.score / meanScore : 0.0;

    // Noise produces a peakRatio ~4; real rhythmic content produces ~100+.
    // A threshold of 10 sits well between them.
    if (peakRatio < 10.0) {
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

    return TempoDetected(
      bpm: topCandidate.bpm,
      confidence: confidence,
      beats: beats,
      candidates: candidates,
    );
  }

  static Confidence _classifyConfidence(
    double peakRatio, {
    required double strongThreshold,
    required double likelyThreshold,
  }) {
    // Scale peakRatio to a 0–1 confidence score.
    // Valid rhythmic ratios range from ~10 (noPattern threshold) up to ~100+.
    // Normalise over a 90-unit span so typical click tracks score near 1.0.
    final normalized = ((peakRatio - 10.0) / 90.0).clamp(0.0, 1.0);
    if (normalized >= strongThreshold) return Confidence.strong;
    if (normalized >= likelyThreshold) return Confidence.likely;
    return Confidence.uncertain;
  }
}
