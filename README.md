# blaq_tempo_detector

Pure Dart BPM detection from raw PCM audio. No Flutter dependency — works on mobile, web, CLI, and server.

Uses spectral flux onset detection, autocorrelation, and dynamic programming beat tracking to detect tempo with high accuracy.

## Features

- **Single-shot analysis** — pass a complete audio buffer, get BPM + confidence + beat positions
- **Incremental tracking** — feed audio chunks progressively, get estimates as you go
- **Rich output** — BPM, confidence level, beat timestamps, and a full candidate tempo histogram
- **Isolate support** — async convenience API using `Isolate.run()` for background processing
- **Configurable** — tune BPM range, frame size, perceptual weighting, and confidence thresholds

## Installation

```yaml
dependencies:
  blaq_tempo_detector: ^0.1.0
```

## Usage

### Single-shot analysis

```dart
import 'package:blaq_tempo_detector/blaq_tempo_detector.dart';

final result = TempoDetector.analyze(
  samples, // Float64List of PCM audio
  sampleRate: 44100,
);

switch (result) {
  case TempoDetected(:final bpm, :final confidence, :final beats):
    print('$bpm BPM ($confidence), ${beats.length} beats');
  case TempoUndetectable(:final reason):
    print('Could not detect tempo: $reason');
}
```

### Incremental tracking

```dart
final tracker = TempoTracker(sampleRate: 44100);

tracker.addSamples(chunk1);
tracker.addSamples(chunk2);

// Quick estimate (no beat tracking)
final estimate = tracker.currentEstimate;

// Full result with beat positions
final result = tracker.finalize();
```

### Async (isolate)

```dart
import 'package:blaq_tempo_detector/blaq_tempo_detector_isolate.dart';

final result = await TempoDetectorIsolate.analyze(
  samples,
  sampleRate: 44100,
);
```

## How it works

1. **Frame splitting** — audio is chopped into overlapping frames (1024 samples, 512 hop)
2. **Onset detection** — spectral flux measures frequency-domain changes between frames
3. **Autocorrelation** — finds the dominant periodicity in the onset signal
4. **Perceptual weighting** — resolves half/double-time ambiguity (biased toward 80–160 BPM)
5. **Beat tracking** — dynamic programming places beats aligned to onset peaks

## License

MIT
