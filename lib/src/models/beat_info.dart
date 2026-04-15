class BeatInfo {
  final double timestampSeconds;
  final double onsetStrength;

  const BeatInfo({
    required this.timestampSeconds,
    required this.onsetStrength,
  });

  @override
  String toString() =>
      'BeatInfo(t: ${timestampSeconds}s, strength: $onsetStrength)';
}
