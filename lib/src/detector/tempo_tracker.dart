import 'dart:typed_data';

import 'package:blaq_tempo_detector/src/config/detector_config.dart';
import 'package:blaq_tempo_detector/src/models/beat_info.dart';
import 'package:blaq_tempo_detector/src/models/confidence.dart';
import 'package:blaq_tempo_detector/src/models/tempo_result.dart';
import 'package:blaq_tempo_detector/src/models/undetectable_reason.dart';
import 'package:blaq_tempo_detector/src/pipeline/autocorrelator.dart';
import 'package:blaq_tempo_detector/src/pipeline/beat_tracker.dart';
import 'package:blaq_tempo_detector/src/pipeline/frame_splitter.dart';
import 'package:blaq_tempo_detector/src/pipeline/onset_detector.dart';
import 'package:blaq_tempo_detector/src/pipeline/perceptual_weighting.dart';

/// Incremental tempo detection that accepts audio in chunks.
///
/// Feed PCM samples via [addSamples] as they become available, query
/// [currentEstimate] for a live BPM estimate (without beat-level timestamps),
/// and call [finalize] when the full recording is available to obtain a
/// complete [TempoResult] that includes beat positions.
///
/// The tracker maintains a sliding window capped at [maxSamples] so it can
/// run indefinitely without unbounded memory growth.
///
/// Note: `TempoTracker` computes `confidenceScore` using a mean-based
/// peakRatio normalization (threshold 10, span 90), distinct from
/// `TempoDetector`'s median-based formula (threshold 5, span 45). The two
/// values are NOT directly comparable across the two entry points; they
/// are coherent within either one. Unifying the formulas is planned for
/// a future release.
class TempoTracker {
  final int sampleRate;
  final int maxSamples;
  final DetectorConfig _config;

  List<double> _buffer = [];
  Float64List _onsetSignal = Float64List(0);
  bool _finalized = false;
  TempoResult? _cachedEstimate;

  static const _minSampleRate = 8000;
  static const _maxSampleRate = 192000;
  static const _minDurationSeconds = 3;

  TempoTracker({
    required this.sampleRate,
    int? maxSamples,
    DetectorConfig? config,
  })  : maxSamples = maxSamples ?? sampleRate * 120,
        _config = config ?? DetectorConfig() {
    if (sampleRate < _minSampleRate || sampleRate > _maxSampleRate) {
      throw ArgumentError.value(
        sampleRate,
        'sampleRate',
        'Must be between $_minSampleRate and $_maxSampleRate',
      );
    }
  }

  /// Appends [chunk] to the internal buffer and recomputes the onset signal.
  ///
  /// Throws [StateError] if called after [finalize].
  void addSamples(Float64List chunk) {
    if (_finalized) {
      throw StateError('Cannot add samples after finalize()');
    }

    _buffer.addAll(chunk);
    _cachedEstimate = null;

    if (_buffer.length > maxSamples) {
      _buffer = _buffer.sublist(_buffer.length - maxSamples);
    }

    _recomputeOnsetSignal();
  }

  /// Returns a live BPM estimate based on buffered samples so far.
  ///
  /// Returns [TempoUndetectable] with [UndetectableReason.tooShort] when fewer
  /// than 3 seconds of audio have been buffered.
  ///
  /// Unlike [finalize], this does NOT run beat tracking, so
  /// [TempoDetected.beats] will always be empty.
  TempoResult get currentEstimate {
    if (_cachedEstimate != null) return _cachedEstimate!;

    if (_buffer.length < sampleRate * _minDurationSeconds) {
      return const TempoUndetectable(reason: UndetectableReason.tooShort);
    }

    final result = _analyzeOnsetSignal(includeBeatTracking: false);
    _cachedEstimate = result;
    return result;
  }

  /// Locks the tracker and returns a complete [TempoResult] including beats.
  ///
  /// After calling this method, any further call to [addSamples] will throw a
  /// [StateError].
  TempoResult finalize() {
    _finalized = true;

    if (_buffer.length < sampleRate * _minDurationSeconds) {
      return const TempoUndetectable(reason: UndetectableReason.tooShort);
    }

    return _analyzeOnsetSignal(includeBeatTracking: true);
  }

  void _recomputeOnsetSignal() {
    final samples = Float64List.fromList(_buffer);
    final frames = FrameSplitter.split(
      samples,
      frameSize: _config.frameSize,
      hopSize: _config.hopSize,
    );
    _onsetSignal = OnsetDetector.detect(
      frames,
      frameSize: _config.frameSize,
      sampleRate: sampleRate,
      hopSize: _config.hopSize,
    );
  }

  TempoResult _analyzeOnsetSignal({required bool includeBeatTracking}) {
    // Check for silence
    var maxOnset = 0.0;
    for (final v in _onsetSignal) {
      if (v > maxOnset) maxOnset = v;
    }
    if (maxOnset == 0.0) {
      return const TempoUndetectable(reason: UndetectableReason.silence);
    }

    final rawCandidates = Autocorrelator.correlate(
      _onsetSignal,
      sampleRate: sampleRate,
      hopSize: _config.hopSize,
      bpmMin: _config.bpmMin,
      bpmMax: _config.bpmMax,
    );

    if (rawCandidates.isEmpty) {
      return const TempoUndetectable(reason: UndetectableReason.noPattern);
    }

    final candidates = PerceptualWeighting.apply(
      rawCandidates,
      center: _config.perceptualCenter,
    );

    if (candidates.isEmpty) {
      return const TempoUndetectable(reason: UndetectableReason.noPattern);
    }

    final topCandidate = candidates.first;

    var scoreSum = 0.0;
    for (final c in candidates) {
      scoreSum += c.score;
    }
    final meanScore = scoreSum / candidates.length;
    final peakRatio = meanScore > 0 ? topCandidate.score / meanScore : 0.0;

    // Same threshold as TempoDetector: noise produces ~4, real rhythm ~100+.
    // A threshold of 10 sits well between them.
    if (peakRatio < 10.0) {
      return const TempoUndetectable(reason: UndetectableReason.noPattern);
    }

    // Normalise over 90-unit span (10–100+) so typical click tracks score ~1.
    final normalized = ((peakRatio - 10.0) / 90.0).clamp(0.0, 1.0);
    final Confidence confidence;
    if (normalized >= _config.strongThreshold) {
      confidence = Confidence.strong;
    } else if (normalized >= _config.likelyThreshold) {
      confidence = Confidence.likely;
    } else {
      confidence = Confidence.uncertain;
    }

    final beats = includeBeatTracking
        ? BeatTracker.track(
            _onsetSignal,
            bpm: topCandidate.bpm,
            sampleRate: sampleRate,
            hopSize: _config.hopSize,
          )
        : <BeatInfo>[];

    return TempoDetected(
      bpm: topCandidate.bpm,
      confidence: confidence,
      confidenceScore: normalized,
      beats: beats,
      candidates: candidates,
    );
  }
}
