# Changelog

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
