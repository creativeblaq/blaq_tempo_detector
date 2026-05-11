class DetectorConfig {
  final int frameSize;
  final int hopSize;
  final int bpmMin;
  final int bpmMax;
  final double perceptualCenter;
  final double strongThreshold;
  final double likelyThreshold;

  /// Enables the melodic fallback pipeline when the primary detector returns
  /// low numeric confidence or `TempoUndetectable`. Default: true.
  ///
  /// Set to false to force percussive-only behavior (matches v0.1 semantics).
  final bool melodicFallback;

  /// FFT window size for the chroma extractor in the melodic pipeline.
  /// Larger windows give better low-frequency pitch resolution but coarser
  /// time resolution. Default: 4096.
  final int chromaFrameSize;

  /// Hop size for the chroma extractor. Also the hop used by the log-mel
  /// flux stage so the two novelty curves align. Default: 2048 (50% overlap).
  final int chromaHopSize;

  /// Fusion weight for chroma novelty (vs log-mel flux) in [0.0, 1.0].
  /// 1.0 = chroma only, 0.0 = log-mel only. Default: 0.6.
  final double melodicChromaWeight;

  /// Perceptual centers (BPM) used by multi-center voting in the melodic
  /// pipeline. Default: [72.0, 100.0, 140.0] — slow ballad / mid / uptempo.
  final List<double> melodicPerceptualCenters;

  /// σ (in log2-BPM units) of the log-Gaussian weighting around each center.
  /// Default: 0.4.
  final double melodicPerceptualSigma;

  /// When true, [TempoDetector.analyze] emits `developer.log` entries at each
  /// pipeline stage (frames, onset signal stats, autocorrelation candidates,
  /// weighted candidates, peak ratio). Off by default.
  final bool verbose;

  DetectorConfig({
    this.frameSize = 1024,
    this.hopSize = 512,
    this.bpmMin = 30,
    this.bpmMax = 300,
    this.perceptualCenter = 120.0,
    this.strongThreshold = 0.7,
    this.likelyThreshold = 0.4,
    this.melodicFallback = true,
    this.chromaFrameSize = 4096,
    this.chromaHopSize = 2048,
    this.melodicChromaWeight = 0.6,
    this.melodicPerceptualCenters = const [72.0, 100.0, 140.0],
    this.melodicPerceptualSigma = 0.4,
    this.verbose = false,
  }) {
    if (frameSize <= 0) {
      throw ArgumentError.value(frameSize, 'frameSize', 'Must be positive');
    }
    if (hopSize <= 0) {
      throw ArgumentError.value(hopSize, 'hopSize', 'Must be positive');
    }
    if (hopSize > frameSize) {
      throw ArgumentError.value(
        hopSize,
        'hopSize',
        'Must not exceed frameSize ($frameSize)',
      );
    }
    if (bpmMin >= bpmMax) {
      throw ArgumentError(
        'bpmMin ($bpmMin) must be less than bpmMax ($bpmMax)',
      );
    }
    if (chromaFrameSize <= 0) {
      throw ArgumentError.value(
        chromaFrameSize, 'chromaFrameSize', 'Must be positive',
      );
    }
    if (chromaHopSize <= 0 || chromaHopSize > chromaFrameSize) {
      throw ArgumentError.value(
        chromaHopSize, 'chromaHopSize',
        'Must be positive and not exceed chromaFrameSize ($chromaFrameSize)',
      );
    }
    if (melodicChromaWeight < 0.0 || melodicChromaWeight > 1.0) {
      throw ArgumentError.value(
        melodicChromaWeight, 'melodicChromaWeight', 'Must be in [0.0, 1.0]',
      );
    }
    if (melodicPerceptualCenters.isEmpty) {
      throw ArgumentError.value(
        melodicPerceptualCenters, 'melodicPerceptualCenters',
        'Must contain at least one center',
      );
    }
    if (melodicPerceptualSigma <= 0.0) {
      throw ArgumentError.value(
        melodicPerceptualSigma, 'melodicPerceptualSigma', 'Must be positive',
      );
    }
  }
}
