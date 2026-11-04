import 'package:flutter/material.dart';

import '../../core/models/moon_phase_info.dart';
import '../painters/moon_painter.dart';

/// Renders a graphical representation of the moon phase.
final class MoonPhaseWidget extends StatelessWidget {
  /// Moon phase information.
  final MoonPhaseInfo info;

  /// Diameter of the rendered moon circle.
  final double size;

  /// Creates a [MoonPhaseWidget].
  const MoonPhaseWidget({super.key, required this.info, this.size = 60});

  @override
  Widget build(BuildContext context) {
    final safeSize = size.isFinite && size > 0 ? size : 0.0;
    return RepaintBoundary(
      child: CustomPaint(
        isComplex: true,
        size: Size(safeSize, safeSize),
        painter: MoonPainter(info: info),
      ),
    );
  }
}
