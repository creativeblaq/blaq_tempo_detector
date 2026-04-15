import 'dart:typed_data';

import 'package:blaq_tempo_detector/src/pipeline/frame_splitter.dart';
import 'package:test/test.dart';

void main() {
  group('FrameSplitter', () {
    test('splits exact multiple into correct number of frames', () {
      // 2048 samples, frameSize=1024, hopSize=512
      // Frames start at: 0, 512, 1024 → 3 frames
      final samples = Float64List(2048);
      final frames = FrameSplitter.split(samples, frameSize: 1024, hopSize: 512).toList();
      expect(frames.length, 3);
    });

    test('each frame has correct length', () {
      final samples = Float64List(2048);
      final frames = FrameSplitter.split(samples, frameSize: 1024, hopSize: 512).toList();
      for (final frame in frames) {
        expect(frame.length, 1024);
      }
    });

    test('frames contain correct data', () {
      final samples = Float64List(2048);
      for (var i = 0; i < 2048; i++) {
        samples[i] = i.toDouble();
      }
      final frames = FrameSplitter.split(samples, frameSize: 1024, hopSize: 512).toList();

      // First frame: samples[0..1023]
      expect(frames[0][0], 0.0);
      expect(frames[0][1023], 1023.0);

      // Second frame: samples[512..1535]
      expect(frames[1][0], 512.0);
      expect(frames[1][511], 1023.0);

      // Third frame: samples[1024..2047]
      expect(frames[2][0], 1024.0);
      expect(frames[2][1023], 2047.0);
    });

    test('zero-pads final frame when samples do not fill it', () {
      // 1500 samples, frameSize=1024, hopSize=512
      // Frame at 0: samples[0..1023] (full)
      // Frame at 512: samples[512..1499] + zeros (zero-padded, only 988 real samples)
      final samples = Float64List(1500);
      for (var i = 0; i < 1500; i++) {
        samples[i] = 1.0;
      }
      final frames = FrameSplitter.split(samples, frameSize: 1024, hopSize: 512).toList();
      final lastFrame = frames.last;
      expect(lastFrame.length, 1024);

      // First 988 samples should be 1.0 (1500 - 512 = 988)
      expect(lastFrame[987], 1.0);
      // Remaining should be zero-padded
      expect(lastFrame[988], 0.0);
      expect(lastFrame[1023], 0.0);
    });

    test('handles samples shorter than frameSize', () {
      final samples = Float64List(500);
      for (var i = 0; i < 500; i++) {
        samples[i] = 1.0;
      }
      final frames = FrameSplitter.split(samples, frameSize: 1024, hopSize: 512).toList();
      expect(frames.length, 1);
      expect(frames[0].length, 1024);
      expect(frames[0][499], 1.0);
      expect(frames[0][500], 0.0);
    });

    test('returns empty iterable for empty input', () {
      final samples = Float64List(0);
      final frames = FrameSplitter.split(samples, frameSize: 1024, hopSize: 512).toList();
      expect(frames, isEmpty);
    });
  });
}
