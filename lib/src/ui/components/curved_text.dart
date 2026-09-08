import 'package:flutter/material.dart';

/// Widget that renders typography along an arbitrary 2D geometric [Path].
///
/// {@example example/curved_text_example.dart}
///
/// Each character glyph is laid out and rotated according to the tangent
/// vector calculated at its corresponding distance along [path].
///
/// Preconditions:
/// * [text] must not be empty. It is an error if [text] is empty (throws [ArgumentError]).
/// * [path] must contain at least one valid sub-path.
///
/// Performance considerations:
/// Rendering complexity is $O(N)$ where $N$ is the length of [text]. Tangent
/// evaluations leverage [Path.computeMetrics], which caches arc-length data.
final class CurvedText extends StatelessWidget {
  /// The string to render along [path].
  final String text;

  /// The geometric path to follow.
  final Path path;

  /// Typographic styling for the glyphs.
  final TextStyle style;

  /// Starting distance offset along [path] in logical pixels.
  final double startOffset;

  /// Whether to center the rendered string along the total arc length of [path].
  final bool centerText;

  /// Creates a [CurvedText] widget.
  ///
  /// It is an error if [text] is empty.
  CurvedText({
    super.key,
    required this.text,
    required this.path,
    required this.style,
    this.startOffset = 0.0,
    this.centerText = true,
  }) {
    if (text.isEmpty) {
      throw ArgumentError.value(text, 'text', 'Must not be empty');
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: CurvedTextPainter(
        text: text,
        path: path,
        style: style,
        startOffset: startOffset,
        centerText: centerText,
      ),
    );
  }
}

/// [CustomPainter] that calculates tangent angles along a [Path] to paint curved text.
///
/// Performance: $O(N)$ layout and paint passes per repaint cycle, where $N$
/// is character count.
final class CurvedTextPainter extends CustomPainter {
  /// Text to render.
  final String text;

  /// Path to traverse.
  final Path path;

  /// Text style.
  final TextStyle style;

  /// Distance offset along the path.
  final double startOffset;

  /// Whether to center text on the path.
  final bool centerText;

  /// Creates a [CurvedTextPainter].
  const CurvedTextPainter({
    required this.text,
    required this.path,
    required this.style,
    this.startOffset = 0.0,
    this.centerText = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (text.isEmpty) return;

    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final metric = metrics.first;
    if (metric.length <= 0) return;

    final spacing = style.letterSpacing ?? 0.0;
    final styleWithoutSpacing = style.copyWith(letterSpacing: 0.0);

    final chars = text.characters.toList();
    final painters = <TextPainter>[];
    final advances = <double>[];
    double totalTextWidth = 0.0;

    for (int i = 0; i < chars.length; i++) {
      final char = chars[i];
      final painter = TextPainter(
        text: TextSpan(text: char, style: styleWithoutSpacing),
        textDirection: TextDirection.ltr,
      )..layout();
      painters.add(painter);

      final advance = painter.width + (i < chars.length - 1 ? spacing : 0.0);
      advances.add(advance);
      totalTextWidth += advance;
    }

    double currentDistance = startOffset;
    if (centerText && totalTextWidth < metric.length) {
      currentDistance += (metric.length - totalTextWidth) / 2.0;
    }

    for (int i = 0; i < chars.length; i++) {
      final painter = painters[i];
      final glyphWidth = painter.width;
      final advance = advances[i];
      final charCenterDistance = currentDistance + (glyphWidth / 2.0);

      if (charCenterDistance > metric.length) break;
      if (charCenterDistance >= 0.0) {
        final tangent = metric.getTangentForOffset(charCenterDistance);
        if (tangent != null) {
          canvas.save();
          canvas.translate(tangent.position.dx, tangent.position.dy);
          // Note: Flutter's `tangent.angle` flips the sign (`-math.atan2(dy, dx)`),
          // which is inverted relative to `canvas.rotate` in canvas screen space.
          // Rotating by `-tangent.angle` aligns the glyph with the actual path tangent.
          canvas.rotate(-tangent.angle);
          painter.paint(
            canvas,
            Offset(-glyphWidth / 2.0, -painter.height / 2.0),
          );
          canvas.restore();
        }
      }

      currentDistance += advance;
    }
  }

  @override
  bool shouldRepaint(covariant CurvedTextPainter oldDelegate) {
    return oldDelegate.text != text ||
        oldDelegate.path != path ||
        oldDelegate.style != style ||
        oldDelegate.startOffset != startOffset ||
        oldDelegate.centerText != centerText;
  }
}
