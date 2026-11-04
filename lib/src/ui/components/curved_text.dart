import 'dart:collection';
import 'dart:typed_data';

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
/// Per-character [TextPainter] layouts and advance metrics are memoized in a
/// bounded LRU cache keyed by `(text, style, textDirection)`, so cache hits
/// perform zero [TextPainter.layout] passes during repaints.
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
    return RepaintBoundary(
      child: CustomPaint(
        isComplex: true,
        painter: CurvedTextPainter(
          text: text,
          path: path,
          style: style,
          startOffset: startOffset,
          centerText: centerText,
        ),
      ),
    );
  }
}

final class _CachedCurvedGlyphRun {
  final List<TextPainter> painters;
  final Float64List advances;
  final double totalTextWidth;

  const _CachedCurvedGlyphRun({
    required this.painters,
    required this.advances,
    required this.totalTextWidth,
  });
}

/// [CustomPainter] that calculates tangent angles along a [Path] to paint curved text.
///
/// Performance: Glyph layouts are cached in a static LRU map so `paint()`
/// performs zero [TextPainter.layout] calls on cache hits.
final class CurvedTextPainter extends CustomPainter {
  static const int _maxGlyphCacheEntries = 64;
  static final LinkedHashMap<
    (String, TextStyle, double, TextDirection),
    _CachedCurvedGlyphRun
  >
  _glyphCache = LinkedHashMap();

  /// Number of cached glyph runs currently stored in memory.
  static int get cachedGlyphRunCount => _glyphCache.length;

  /// Clears the static glyph layout cache.
  static void clearCache() => _glyphCache.clear();

  static _CachedCurvedGlyphRun _resolveGlyphRun(
    String text,
    TextStyle style,
    TextDirection textDirection,
  ) {
    final rawSpacing = style.letterSpacing ?? 0.0;
    final spacing = rawSpacing.isFinite ? rawSpacing : 0.0;
    final styleWithoutSpacing = rawSpacing == 0.0
        ? style
        : style.copyWith(letterSpacing: 0.0);

    final key = (text, styleWithoutSpacing, spacing, textDirection);
    final existing = _glyphCache.remove(key);
    if (existing != null) {
      _glyphCache[key] = existing;
      return existing;
    }

    final chars = text.characters.toList(growable: false);
    final count = chars.length;
    final painters = List<TextPainter>.generate(count, (i) {
      return TextPainter(
        text: TextSpan(text: chars[i], style: styleWithoutSpacing),
        textDirection: textDirection,
      )..layout();
    }, growable: false);

    final advances = Float64List(count);
    double totalTextWidth = 0.0;
    for (int i = 0; i < count; i++) {
      final advance = painters[i].width + (i < count - 1 ? spacing : 0.0);
      advances[i] = advance;
      totalTextWidth += advance;
    }

    final created = _CachedCurvedGlyphRun(
      painters: painters,
      advances: advances,
      totalTextWidth: totalTextWidth,
    );
    if (_glyphCache.length >= _maxGlyphCacheEntries) {
      _glyphCache.remove(_glyphCache.keys.first);
    }
    _glyphCache[key] = created;
    return created;
  }

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
    if (text.isEmpty ||
        !size.width.isFinite ||
        !size.height.isFinite ||
        size.width < 0 ||
        size.height < 0) {
      return;
    }
    final fontSize = style.fontSize;
    if (fontSize != null && (!fontSize.isFinite || fontSize <= 0)) {
      return;
    }

    final metricsIterator = path.computeMetrics().iterator;
    while (true) {
      if (!metricsIterator.moveNext()) return;
      final candidate = metricsIterator.current;
      if (candidate.length > 0 && candidate.length.isFinite) {
        break;
      }
    }
    final metric = metricsIterator.current;
    final metricLength = metric.length;

    final glyphRun = _resolveGlyphRun(text, style, TextDirection.ltr);
    final painters = glyphRun.painters;
    final advances = glyphRun.advances;
    final totalTextWidth = glyphRun.totalTextWidth;

    double currentDistance = startOffset.isFinite ? startOffset : 0.0;
    if (centerText && totalTextWidth < metricLength) {
      currentDistance += (metricLength - totalTextWidth) / 2.0;
    }

    final count = painters.length;
    for (int i = 0; i < count; i++) {
      final painter = painters[i];
      final glyphWidth = painter.width;
      final advance = advances[i];
      final charCenterDistance = currentDistance + (glyphWidth / 2.0);

      if (charCenterDistance > metricLength) break;
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
