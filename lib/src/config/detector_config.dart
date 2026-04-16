class DetectorConfig {
  final int frameSize;
  final int hopSize;
  final int bpmMin;
  final int bpmMax;
  final double perceptualCenter;
  final double strongThreshold;
  final double likelyThreshold;

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
  }
}
