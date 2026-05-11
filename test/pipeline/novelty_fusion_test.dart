import 'dart:typed_data';

import 'package:blaq_tempo_detector/src/pipeline/novelty_fusion.dart';
import 'package:test/test.dart';

void main() {
  group('NoveltyFusion', () {
    Float64List f(List<double> v) => Float64List.fromList(v);

    test('alpha = 1.0 returns chroma novelty unchanged', () {
      final a = f([0.0, 0.5, 1.0, 0.5, 0.0]);
      final b = f([0.0, 0.0, 0.0, 0.0, 0.0]);
      final fused = NoveltyFusion.fuse(a, b, chromaWeight: 1.0);
      expect(fused, orderedEquals(a));
    });

    test('alpha = 0.0 returns mel flux unchanged', () {
      final a = f([0.0, 0.0, 0.0, 0.0, 0.0]);
      final b = f([0.1, 0.2, 0.3, 0.2, 0.1]);
      final fused = NoveltyFusion.fuse(a, b, chromaWeight: 0.0);
      expect(fused, orderedEquals(b));
    });

    test('alpha = 0.5 returns simple mean', () {
      final a = f([0.0, 0.4, 0.0]);
      final b = f([0.2, 0.0, 0.6]);
      final fused = NoveltyFusion.fuse(a, b, chromaWeight: 0.5);
      expect(fused[0], closeTo(0.1, 1e-9));
      expect(fused[1], closeTo(0.2, 1e-9));
      expect(fused[2], closeTo(0.3, 1e-9));
    });

    test('length matches the shorter of the two inputs', () {
      final a = f([1.0, 2.0, 3.0, 4.0, 5.0]);
      final b = f([10.0, 20.0, 30.0]);
      final fused = NoveltyFusion.fuse(a, b, chromaWeight: 0.5);
      expect(fused, hasLength(3));
    });
  });
}
