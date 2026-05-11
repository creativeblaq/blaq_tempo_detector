import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:blaq_tempo_detector/blaq_tempo_detector.dart';
import 'package:test/test.dart';

void main() {
  final shouldRun = Platform.environment['BLAQ_RUN_CORPUS'] == '1';
  if (!shouldRun) {
    test('corpus skipped (set BLAQ_RUN_CORPUS=1 to run)', () {});
    return;
  }

  final fixturesDir = Directory('test/fixtures/melodic_corpus');
  if (!fixturesDir.existsSync()) {
    test('corpus directory missing', () => fail('Create test/fixtures/melodic_corpus/'));
    return;
  }

  final clips = fixturesDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.wav'))
      .toList();

  group('melodic corpus', () {
    for (final clip in clips) {
      final expectedFile = File('${clip.path.replaceAll('.wav', '')}.expected.json');
      if (!expectedFile.existsSync()) continue;
      final expected = jsonDecode(expectedFile.readAsStringSync()) as Map;
      final expectedBpm = (expected['bpm'] as num).toDouble();
      final tolerance = (expected['tolerance'] as num?)?.toDouble() ?? 1.0;

      test('${clip.uri.pathSegments.last} → $expectedBpm BPM ± $tolerance', () {
        final samples = _loadWavMono44k(clip);
        final result = TempoDetector.analyze(samples, sampleRate: 44100);
        expect(result, isA<TempoDetected>(),
            reason: 'Got $result for ${clip.path}');
        final detected = result as TempoDetected;
        expect(detected.bpm, closeTo(expectedBpm, tolerance),
            reason: 'Strategy used: ${detected.strategy}');
      });
    }
  });
}

/// Minimal WAV loader for PCM mono 16-bit @ 44.1kHz. Replace with a proper
/// wav package later if needed (currently keeps zero deps).
Float64List _loadWavMono44k(File file) {
  final bytes = file.readAsBytesSync();
  // Validate RIFF/WAVE header.
  if (String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF' ||
      String.fromCharCodes(bytes.sublist(8, 12)) != 'WAVE') {
    throw FormatException('Not a WAV file: ${file.path}');
  }
  // Find 'data' chunk.
  var i = 12;
  while (i < bytes.length - 8) {
    final id = String.fromCharCodes(bytes.sublist(i, i + 4));
    final size = ByteData.sublistView(Uint8List.fromList(bytes), i + 4, i + 8)
        .getUint32(0, Endian.little);
    if (id == 'data') {
      final dataStart = i + 8;
      final dataEnd = dataStart + size;
      final pcm = ByteData.sublistView(
        Uint8List.fromList(bytes), dataStart, dataEnd,
      );
      final samples = Float64List(size ~/ 2);
      for (var j = 0; j < samples.length; j++) {
        samples[j] = pcm.getInt16(j * 2, Endian.little) / 32768.0;
      }
      return samples;
    }
    i += 8 + size;
  }
  throw FormatException('No data chunk in ${file.path}');
}
