import 'dart:math';
import 'dart:typed_data';

class NoveltyFusion {
  const NoveltyFusion._();

  /// Linear blend of two novelty curves. Output length equals the shorter
  /// input length.
  ///
  /// `chromaWeight` (α) ∈ [0, 1]: result = α·chroma + (1−α)·mel.
  static Float64List fuse(
    Float64List chroma,
    Float64List mel, {
    required double chromaWeight,
  }) {
    final n = min(chroma.length, mel.length);
    final out = Float64List(n);
    final melWeight = 1.0 - chromaWeight;
    for (var i = 0; i < n; i++) {
      out[i] = chromaWeight * chroma[i] + melWeight * mel[i];
    }
    return out;
  }
}
