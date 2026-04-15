import 'dart:math';
import 'dart:typed_data';

class SignalGenerator {
  /// Generates impulses at exact beat positions.
  /// Each beat is a single-sample impulse of amplitude 1.0.
  static Float64List clickTrack({
    required double bpm,
    required double durationSeconds,
    int sampleRate = 44100,
  }) {
    final totalSamples = (durationSeconds * sampleRate).round();
    final samples = Float64List(totalSamples);
    final beatInterval = 60.0 / bpm * sampleRate;

    var position = 0.0;
    while (position.round() < totalSamples) {
      final index = position.round();
      if (index < totalSamples) {
        samples[index] = 1.0;
      }
      position += beatInterval;
    }
    return samples;
  }

  /// Generates all-zero samples.
  static Float64List silence({
    required double durationSeconds,
    int sampleRate = 44100,
  }) =>
      Float64List((durationSeconds * sampleRate).round());

  /// Generates uniformly distributed random noise in [-1, 1].
  /// Uses a fixed seed for deterministic tests.
  static Float64List noise({
    required double durationSeconds,
    int sampleRate = 44100,
    int seed = 42,
  }) {
    final random = Random(seed);
    final totalSamples = (durationSeconds * sampleRate).round();
    final samples = Float64List(totalSamples);
    for (var i = 0; i < totalSamples; i++) {
      samples[i] = random.nextDouble() * 2.0 - 1.0;
    }
    return samples;
  }

  /// Generates short sine wave pulses at beat positions.
  /// Each pulse is 50ms of a sine wave at [frequency] Hz.
  static Float64List sineBeats({
    required double bpm,
    required double frequency,
    required double durationSeconds,
    int sampleRate = 44100,
  }) {
    final totalSamples = (durationSeconds * sampleRate).round();
    final samples = Float64List(totalSamples);
    final beatInterval = 60.0 / bpm * sampleRate;
    final pulseSamples = (0.05 * sampleRate).round();

    var position = 0.0;
    while (position.round() < totalSamples) {
      final beatStart = position.round();
      for (var i = 0; i < pulseSamples && beatStart + i < totalSamples; i++) {
        samples[beatStart + i] = sin(2.0 * pi * frequency * i / sampleRate);
      }
      position += beatInterval;
    }
    return samples;
  }

  /// Generates a click track that ramps linearly from [startBpm] to [endBpm].
  static Float64List variableTempo({
    required double startBpm,
    required double endBpm,
    required double durationSeconds,
    int sampleRate = 44100,
  }) {
    final totalSamples = (durationSeconds * sampleRate).round();
    final samples = Float64List(totalSamples);

    var sampleIndex = 0.0;
    while (sampleIndex.round() < totalSamples) {
      final index = sampleIndex.round();
      if (index < totalSamples) {
        samples[index] = 1.0;
      }
      final progress = sampleIndex / totalSamples;
      final currentBpm = startBpm + (endBpm - startBpm) * progress;
      final interval = 60.0 / currentBpm * sampleRate;
      sampleIndex += interval;
    }
    return samples;
  }
}
