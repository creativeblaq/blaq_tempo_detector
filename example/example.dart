// ignore_for_file: avoid_print
import 'dart:math';
import 'dart:typed_data';

import 'package:blaq_tempo_detector/blaq_tempo_detector.dart';

void main() {
  // Generate a synthetic 120 BPM click track for demonstration
  const sampleRate = 44100;
  const bpm = 120.0;
  const durationSeconds = 10.0;
  final totalSamples = (durationSeconds * sampleRate).round();
  final samples = Float64List(totalSamples);
  final beatInterval = (60.0 / bpm * sampleRate).round();

  for (var i = 0; i < totalSamples; i += beatInterval) {
    samples[i] = 1.0;
  }

  // Analyze
  final result = TempoDetector.analyze(samples, sampleRate: sampleRate);

  switch (result) {
    case TempoDetected(:final bpm, :final confidence, :final beats, :final candidates):
      print('Detected: ${bpm.toStringAsFixed(1)} BPM');
      print('Confidence: $confidence');
      print('Beats found: ${beats.length}');
      print('Top 3 candidates:');
      for (final c in candidates.take(min(3, candidates.length))) {
        print('  ${c.bpm.toStringAsFixed(1)} BPM (score: ${c.score.toStringAsFixed(3)})');
      }
    case TempoUndetectable(:final reason):
      print('Could not detect tempo: $reason');
  }
}
