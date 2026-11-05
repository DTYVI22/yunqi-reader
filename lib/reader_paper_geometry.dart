import 'dart:typed_data';
import 'dart:ui';

/// One textured paper face. The public snapshot omits the curved-page mesh
/// builder, so every face is a flat quad: identical texture mapping, zero lift.
class ReaderPaperMesh {
  ReaderPaperMesh({
    required this.positions,
    required this.normals,
    required this.indices,
    required this.uv,
    required this.outline,
  });

  final Float32List positions;
  final List<double> normals;
  final Uint16List indices;
  final Float32List uv;
  final Path outline;

  factory ReaderPaperMesh.rect(Rect rect) => ReaderPaperMesh(
    positions: Float32List.fromList([
      rect.left, rect.top,
      rect.right, rect.top,
      rect.right, rect.bottom,
      rect.left, rect.bottom,
    ]),
    normals: List<double>.filled(4, 0),
    indices: Uint16List.fromList([0, 1, 2, 0, 2, 3]),
    uv: Float32List.fromList([0, 0, 1, 0, 1, 1, 0, 1]),
    outline: Path()..addRect(rect),
  );
}

/// Per-frame page geometry shared by every leaf of one turn.
class ReaderPaperGeometry {
  ReaderPaperGeometry({
    required this.size,
    required this.gap,
    required this.progress,
    this.touchY = 0.5,
  });

  final Size size;
  final double gap;
  final double progress;
  final double touchY;

  Rect get _rect => Offset.zero & size;

  /// Area already covered by the turning page.
  Path get sheet => Path()
    ..addRect(
      Rect.fromLTRB(
        _rect.left,
        _rect.top,
        _rect.left + _rect.width * progress,
        _rect.bottom,
      ),
    );

  ReaderPaperMesh get front => ReaderPaperMesh.rect(_rect);

  ReaderPaperMesh get back => ReaderPaperMesh.rect(_rect);

  ReaderPaperMesh get frontInk => ReaderPaperMesh.rect(_rect);

  ReaderPaperMesh get backInk => ReaderPaperMesh.rect(_rect);

  /// No curved lift in the flat fallback.
  double get lift => 0;
}
