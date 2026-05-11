# Changelog

## 0.2.2

- Calibrated `MelodicTempoDetector` against real material. The v0.2.1 noise
  gates (peakRatio ≥ 3.0, halfPeakClutter ≤ 0.20) were tuned against
  synthetic chord stabs and rejected real piano+vocal recordings as
  "noPattern" — too crisp a bar. Loosened to (2.0, 0.30).
- Confidence on melodic results is now derived from `peakRatio` (matching
  the percussive pipeline's approach) rather than the multi-center voted
  score directly. Voted-score-based confidence saturated noise to ~0.93;
  peakRatio-based confidence correctly reports noise around 0.06–0.25.
- Net effect: real piano+vocal material now reaches the user as a
  `TempoDetected` (typically `LIKELY` or `UNCERTAIN`) instead of a hard
  `"No rhythmic pattern found"` error. Truly noisy input still surfaces as
  low confidence — no false high-confidence detections.

## 0.2.1

> Released as 0.2.1 because the v0.2.0 git tag was already in use upstream
> for a prior commit; this release ships the melodic fallback work.

**BREAKING**: `TempoDetected.confidenceScore` is now a required constructor
argument. External code that builds `TempoDetected` instances directly (for
mocks, fakes, or testing) must pass `confidenceScore`. Code that only consumes
`TempoDetected` is unaffected.

- Added melodic fallback pipeline (chroma + log-mel novelty fusion,
  multi-center perceptual voting). Engages automatically when the primary
  detector returns low confidence or `TempoUndetectable`. Targets melodic-
  only material (piano+vocals, a cappella, fingerpicked guitar) that the
  percussive pipeline can't handle.
- Added `TempoStrategy` enum (`percussive` | `melodic`) on `TempoDetected`.
- Added `confidenceScore` (normalized 0.0–1.0) on `TempoDetected`.
- New `DetectorConfig` knobs: `melodicFallback` (default true),
  `chromaFrameSize` (4096), `chromaHopSize` (2048), `melodicChromaWeight`
  (0.6), `melodicPerceptualCenters` ([72.0, 100.0, 140.0]),
  `melodicPerceptualSigma` (0.4).
- Extracted shared `AdaptiveThreshold` utility — onset, chroma novelty, and
  mel flux now route through the same two-pass median-subtraction.
- `MelodicTempoDetector` includes peakRatio / halfPeakClutter noise gates
  matching the percussive pipeline's reliability profile.
- `TempoTracker` (incremental/streaming) remains percussive-only in this
  release.

## 0.1.0

- Initial release
- Single-shot tempo detection via `TempoDetector.analyze()`
- Incremental tempo tracking via `TempoTracker`
- Async isolate convenience via `TempoDetectorIsolate.analyze()`
- Spectral flux onset detection with adaptive thresholding
- Autocorrelation periodicity estimation
- Perceptual weighting for half/double-time resolution
- Dynamic programming beat tracking
- Configurable BPM range, frame size, and confidence thresholds
