import 'dart:math';
import 'dart:typed_data';

/// Generates synthetic piano-like audio for melodic pipeline tests.
///
/// A "note" is a sum of decaying sinusoidal partials at the fundamental and
/// its first 4 harmonics. A "chord stab" is a small set of notes struck
/// simultaneously. The generator strikes chords on a strict tempo grid.
class PianoSignalGenerator {
  PianoSignalGenerator._();

  /// MIDI-style frequency table for one octave starting at C4 (261.63 Hz).
  static const double c4 = 261.63;
  static const double e4 = 329.63;
  static const double g4 = 392.00;
  static const double a4 = 440.00;
  static const double cs4 = 277.18;

  /// Renders a stream of chord stabs at [bpm] for [durationSeconds].
  /// Each stab is a sum of decaying partials at each frequency in [chord].
  static Float64List chordStabs({
    required double bpm,
    required List<List<double>> chordsByBeat,
    required double durationSeconds,
    int sampleRate = 44100,
    double decaySeconds = 0.4,
  }) {
    final totalSamples = (durationSeconds * sampleRate).round();
    final out = Float64List(totalSamples);

    final beatPeriodSamples = (60.0 * sampleRate / bpm).round();
    final decaySamples = (decaySeconds * sampleRate).round();

    var beatIdx = 0;
    for (var t = 0; t < totalSamples; t += beatPeriodSamples) {
      final chord = chordsByBeat[beatIdx % chordsByBeat.length];
      _stamp(out, t, decaySamples, chord, sampleRate);
      beatIdx++;
    }

    // Normalize to avoid clipping.
    var peak = 0.0;
    for (final s in out) {
      if (s.abs() > peak) peak = s.abs();
    }
    if (peak > 0) {
      for (var i = 0; i < totalSamples; i++) {
        out[i] /= peak;
      }
    }
    return out;
  }

  static void _stamp(
    Float64List out,
    int start,
    int decaySamples,
    List<double> freqs,
    int sampleRate,
  ) {
    for (var i = 0; i < decaySamples; i++) {
      final idx = start + i;
      if (idx >= out.length) break;
      final envelope = exp(-3.0 * i / decaySamples);
      var sample = 0.0;
      for (final f in freqs) {
        // Fundamental + first 4 harmonics, decreasing amplitudes.
        for (var h = 1; h <= 5; h++) {
          sample += (1.0 / h) * sin(2 * pi * f * h * idx / sampleRate);
        }
      }
      out[idx] += envelope * sample;
    }
  }
}
