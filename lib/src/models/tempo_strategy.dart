/// Which internal pipeline produced a [TempoDetected] result.
enum TempoStrategy {
  /// Primary pipeline: spectral flux onset + autocorrelation + single-center
  /// perceptual weighting. Best for percussive/rhythmic material.
  percussive,

  /// Fallback pipeline: chroma novelty + log-mel flux fusion + multi-center
  /// perceptual voting. Engages when the percussive pipeline returns low
  /// numeric confidence or `TempoUndetectable`. Best for melodic-only material
  /// (piano+vocals, a cappella, fingerpicked guitar).
  melodic,
}
