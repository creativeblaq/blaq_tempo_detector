class TempoCandidate {
  final double bpm;
  final double score;

  const TempoCandidate({required this.bpm, required this.score});

  @override
  String toString() => 'TempoCandidate(bpm: $bpm, score: $score)';
}
