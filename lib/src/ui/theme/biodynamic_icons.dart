import 'package:flutter/material.dart';

import '../../core/models/agricultural_tasks.dart';

/// Supported types of custom biodynamic vector icons.
enum BiodynamicIconType {
  /// Broadfork (Grelinette) for living soil cultivation and root aeration.
  broadfork,

  /// Bypass pruning shears (secateurs) for fruit tree and vine pruning.
  pruningShears,

  /// Wooden root cellar harvest crate for long-term winter storage.
  cellarCrate,

  /// Garden harvest trug / woven basket for fresh eating.
  harvestTrug,

  /// Forestry felling axe in timber log for lunar timber felling (Mondholz).
  timberFelling,

  /// Alchemical mortar, pestle and potentizing ash embers for peppering (Veraschung).
  peppering,

  /// The Farm as a Living Organism emblem uniting cosmic rhythms and living soil.
  farmOrganism,

  /// Herbal brewing cauldron for biodynamic teas, decoctions, and field sprays.
  herbalCauldron,

  /// Dynamization vortex funnel with foaming chaos reversal.
  dynamizationVortex,
}

/// A crisp, vector-rendered biodynamic icon widget.
final class BiodynamicIcon extends StatelessWidget {
  /// The type of biodynamic icon to render.
  final BiodynamicIconType type;

  /// Width and height of the icon.
  final double size;

  /// Tint color for the icon strokes and fills.
  final Color? color;

  /// Creates a [BiodynamicIcon].
  const BiodynamicIcon({
    super.key,
    required this.type,
    this.size = 20,
    this.color,
  });

  /// Factory constructor for farm organism task icons.
  factory BiodynamicIcon.fromTask(
    AgriculturalTaskType task, {
    double size = 20,
    Color? color,
  }) {
    final type = switch (task) {
      AgriculturalTaskType.soilCultivation => BiodynamicIconType.broadfork,
      AgriculturalTaskType.pruning => BiodynamicIconType.pruningShears,
      AgriculturalTaskType.harvestStorage => BiodynamicIconType.cellarCrate,
      AgriculturalTaskType.harvestFresh => BiodynamicIconType.harvestTrug,
      AgriculturalTaskType.timberFelling => BiodynamicIconType.timberFelling,
      AgriculturalTaskType.peppering => BiodynamicIconType.peppering,
    };
    return BiodynamicIcon(type: type, size: size, color: color);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? IconTheme.of(context).color ?? Colors.white;
    final safeSize = size.isFinite && size > 0 ? size : 0.0;
    return SizedBox(
      width: safeSize,
      height: safeSize,
      child: CustomPaint(
        size: Size(safeSize, safeSize),
        painter: _BiodynamicIconPainter(type: type, color: effectiveColor),
      ),
    );
  }
}

final class _BiodynamicIconPainter extends CustomPainter {
  static final Paint _blackPivotPaint = Paint()..color = Colors.black;

  static final Path _broadforkTinesPath = _buildBroadforkTinesPath();
  static Path _buildBroadforkTinesPath() {
    final path = Path();
    const tineXs = [4.5, 8.25, 12.0, 15.75, 19.5];
    for (final x in tineXs) {
      path
        ..moveTo(x, 13)
        ..quadraticBezierTo(x + 0.2, 18, x - 0.6, 22);
    }
    return path;
  }

  static final Path _shearsBladePath = Path()
    ..moveTo(12, 10.5)
    ..cubicTo(12, 6.5, 15, 3.5, 20.5, 2.5)
    ..cubicTo(18.5, 6, 16.5, 9, 12, 10.5);

  static final Path _shearsAnvilPath = Path()
    ..moveTo(12, 10.5)
    ..cubicTo(14.5, 8.5, 18.5, 7.5, 21.5, 6.5)
    ..cubicTo(18.5, 9.5, 15.5, 12.5, 12, 12.5);

  static final Path _shearsSpringPath = Path()
    ..moveTo(9.5, 12.5)
    ..quadraticBezierTo(9, 14.5, 10, 15.5)
    ..quadraticBezierTo(8.5, 16.5, 9.5, 17.5);

  static final Path _shearsHandlesPath = Path()
    ..moveTo(12, 10.5)
    ..cubicTo(9.5, 13.5, 6.5, 17, 3.5, 21.5)
    ..moveTo(12, 12.5)
    ..cubicTo(11, 15.5, 10, 18.5, 9, 22);

  static final RRect _crateOuterRRect = RRect.fromRectAndRadius(
    const Rect.fromLTWH(3, 9, 18, 12),
    const Radius.circular(1.5),
  );

  static final Path _crateRootsPath = Path()
    ..moveTo(7, 9)
    ..quadraticBezierTo(6, 5, 4, 3)
    ..moveTo(7, 9)
    ..quadraticBezierTo(7, 4, 7, 2)
    ..moveTo(7, 9)
    ..quadraticBezierTo(8, 5, 9, 3)
    ..moveTo(15, 9)
    ..quadraticBezierTo(14, 5, 12, 3)
    ..moveTo(15, 9)
    ..quadraticBezierTo(16, 4, 16, 2)
    ..moveTo(15, 9)
    ..quadraticBezierTo(17, 5, 19, 3);

  static final Path _trugHandlePath = Path()
    ..moveTo(5, 12)
    ..cubicTo(5, 3.5, 19, 3.5, 19, 12);

  static final Path _trugBowlPath = Path()
    ..moveTo(2, 12)
    ..cubicTo(3, 20.5, 21, 20.5, 22, 12)
    ..close();

  static final Path _trugRibPath = Path()
    ..moveTo(3, 15)
    ..cubicTo(4, 19, 20, 19, 21, 15);

  static final Path _trugLeavesPath = Path()
    ..moveTo(6, 12)
    ..quadraticBezierTo(5, 7, 3, 6)
    ..quadraticBezierTo(7, 7, 8, 12)
    ..moveTo(11, 12)
    ..quadraticBezierTo(12, 6, 9.5, 4.5)
    ..quadraticBezierTo(14, 6, 13.5, 12)
    ..moveTo(15, 12)
    ..quadraticBezierTo(17, 7, 20.5, 6)
    ..quadraticBezierTo(18.5, 9, 17, 12);

  static final Path _timberLogPath = Path()
    ..moveTo(3, 16)
    ..lineTo(21, 16)
    ..cubicTo(22.5, 18, 22.5, 21, 21, 22)
    ..lineTo(3, 22)
    ..cubicTo(1.5, 21, 1.5, 18, 3, 16)
    ..close();

  static final Path _timberAxeHeadPath = Path()
    ..moveTo(12, 16)
    ..lineTo(16.5, 12.5)
    ..lineTo(17.5, 9)
    ..lineTo(13.5, 9)
    ..close();

  static final Path _timberHandlePath = Path()
    ..moveTo(15.5, 9)
    ..cubicTo(14.5, 5, 12, 2.5, 8.5, 1.5);

  static final Path _pepperingBowlPath = Path()
    ..moveTo(4, 13)
    ..cubicTo(4, 20.5, 20, 20.5, 20, 13)
    ..close();

  static final Path _pepperingPestlePath = Path()
    ..moveTo(8, 17)
    ..lineTo(18.5, 6.5)
    ..lineTo(20.5, 8)
    ..lineTo(10, 18)
    ..close();

  static final Path _pepperingEmbersPath = Path()
    ..moveTo(7, 11)
    ..quadraticBezierTo(6, 7.5, 8, 4.5)
    ..quadraticBezierTo(9, 2.5, 8, 1.5)
    ..moveTo(13, 11)
    ..quadraticBezierTo(14, 6.5, 12, 3.5);

  static final Path _farmSoilPath = Path()
    ..moveTo(3, 16)
    ..quadraticBezierTo(7, 14.5, 12, 16)
    ..quadraticBezierTo(17, 17.5, 21, 16);

  static final Path _farmLeavesPath = Path()
    ..moveTo(12, 11)
    ..quadraticBezierTo(8, 10, 7, 7)
    ..quadraticBezierTo(10, 8, 12, 10)
    ..moveTo(12, 9)
    ..quadraticBezierTo(16, 8, 17, 5)
    ..quadraticBezierTo(14, 6, 12, 8);

  static final Path _cauldronBellyPath = Path()
    ..moveTo(4, 10)
    ..cubicTo(3, 19, 21, 19, 20, 10)
    ..close();

  static final Path _cauldronHandlesPath = Path()
    ..moveTo(3.5, 12)
    ..cubicTo(1.5, 12, 1.5, 15, 3.5, 15)
    ..moveTo(20.5, 12)
    ..cubicTo(22.5, 12, 22.5, 15, 20.5, 15);

  static final Path _cauldronSteamPath = Path()
    ..moveTo(8, 8)
    ..quadraticBezierTo(7, 5, 9, 2.5)
    ..moveTo(13, 8)
    ..quadraticBezierTo(14, 5, 12, 2)
    ..moveTo(17, 8)
    ..quadraticBezierTo(18, 5, 16, 2.5);

  static final Path _vortexSpiralPath = Path()
    ..moveTo(12, 12)
    ..cubicTo(10, 10, 8, 8, 7, 5)
    ..cubicTo(6, 3, 9, 2, 12, 2)
    ..cubicTo(17, 2, 21, 6, 21, 12)
    ..cubicTo(21, 18, 16, 21, 11, 21)
    ..cubicTo(7, 21, 3, 17, 3, 13);

  final BiodynamicIconType type;
  final Color color;

  const _BiodynamicIconPainter({required this.type, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 ||
        size.height <= 0 ||
        !size.width.isFinite ||
        !size.height.isFinite) {
      return;
    }
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    // One Paint is shared by every draw call in the selected icon and mutated
    // in place via `stroke..strokeWidth = n`. Each call site must therefore set
    // its own strokeWidth: omitting it silently inherits whatever the previous
    // call left behind, which makes the drawing order load-bearing.
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (type) {
      case BiodynamicIconType.broadfork:
        _drawBroadfork(canvas, strokePaint);
      case BiodynamicIconType.pruningShears:
        _drawPruningShears(canvas, strokePaint, fillPaint);
      case BiodynamicIconType.cellarCrate:
        _drawCellarCrate(canvas, strokePaint, fillPaint);
      case BiodynamicIconType.harvestTrug:
        _drawHarvestTrug(canvas, strokePaint, fillPaint);
      case BiodynamicIconType.timberFelling:
        _drawTimberFelling(canvas, strokePaint, fillPaint);
      case BiodynamicIconType.peppering:
        _drawPeppering(canvas, strokePaint, fillPaint);
      case BiodynamicIconType.farmOrganism:
        _drawFarmOrganism(canvas, strokePaint, fillPaint);
      case BiodynamicIconType.herbalCauldron:
        _drawHerbalCauldron(canvas, strokePaint);
      case BiodynamicIconType.dynamizationVortex:
        _drawDynamizationVortex(canvas, strokePaint, fillPaint);
    }

    canvas.restore();
  }

  /// Draws a traditional biodynamic broadfork (grelinette).
  void _drawBroadfork(Canvas canvas, Paint stroke) {
    // Top horizontal ergonomic wooden handle bar
    canvas.drawLine(
      const Offset(4, 3),
      const Offset(20, 3),
      stroke..strokeWidth = 2.0,
    );

    // Two vertical ash shaft uprights
    canvas.drawLine(
      const Offset(7, 3),
      const Offset(7, 13),
      stroke..strokeWidth = 1.7,
    );
    canvas.drawLine(
      const Offset(17, 3),
      const Offset(17, 13),
      stroke..strokeWidth = 1.7,
    );

    // Heavy forged steel lower cross-beam
    canvas.drawLine(
      const Offset(3.5, 13),
      const Offset(20.5, 13),
      stroke..strokeWidth = 2.4,
    );

    // 5 tapered curved aerating tines
    canvas.drawPath(_broadforkTinesPath, stroke..strokeWidth = 1.5);
  }

  /// Draws authentic bypass pruning shears (secateurs).
  void _drawPruningShears(Canvas canvas, Paint stroke, Paint fill) {
    // Upper curved cutting blade (sharpened bypass hook)
    canvas.drawPath(_shearsBladePath, fill);

    // Lower hooked counter-blade / anvil jaw
    canvas.drawPath(_shearsAnvilPath, stroke..strokeWidth = 1.6);

    // Pivot bolt (brass screw)
    canvas.drawCircle(const Offset(12, 10.5), 2.0, fill);
    canvas.drawCircle(const Offset(12, 10.5), 0.8, _blackPivotPaint);

    // Volute spring between handles
    canvas.drawPath(_shearsSpringPath, stroke..strokeWidth = 1.1);

    // Upper & lower handles
    canvas.drawPath(_shearsHandlesPath, stroke..strokeWidth = 2.4);
  }

  /// Draws a wooden slatted root cellar harvest crate with stored roots.
  void _drawCellarCrate(Canvas canvas, Paint stroke, Paint fill) {
    // Crate outer rectangular frame
    canvas.drawRRect(_crateOuterRRect, stroke..strokeWidth = 1.7);

    // Horizontal wooden slats
    canvas.drawLine(
      const Offset(3, 13),
      const Offset(21, 13),
      stroke..strokeWidth = 1.2,
    );
    canvas.drawLine(
      const Offset(3, 17),
      const Offset(21, 17),
      stroke..strokeWidth = 1.2,
    );

    // Wooden vertical corner braces
    canvas.drawLine(
      const Offset(6.5, 9),
      const Offset(6.5, 21),
      stroke..strokeWidth = 1.3,
    );
    canvas.drawLine(
      const Offset(17.5, 9),
      const Offset(17.5, 21),
      stroke..strokeWidth = 1.3,
    );

    // Root crops peeking out (carrot tops with feathery greens)
    canvas.drawPath(_crateRootsPath, stroke..strokeWidth = 1.2);

    // Root crowns nestled in crate
    canvas.drawCircle(const Offset(8, 11), 1.6, fill);
    canvas.drawCircle(const Offset(16, 11), 1.6, fill);
    canvas.drawCircle(const Offset(12, 11), 1.4, fill);
  }

  /// Draws a traditional woven garden harvest trug / wicker basket.
  void _drawHarvestTrug(Canvas canvas, Paint stroke, Paint fill) {
    // Tall arched overhead carrying handle
    canvas.drawPath(_trugHandlePath, stroke..strokeWidth = 1.6);

    // Trug curved boat-like basket bowl
    canvas.drawPath(_trugBowlPath, stroke..strokeWidth = 1.7);

    // Inner horizontal rib band
    canvas.drawPath(_trugRibPath, stroke..strokeWidth = 1.1);

    // Fresh leafy greens & fruit inside basket
    canvas.drawPath(_trugLeavesPath, fill);

    // Vine fruit / tomato in center
    canvas.drawCircle(const Offset(12, 14), 2.2, fill);
  }

  /// Draws a traditional forestry felling axe embedded in a felled timber round.
  void _drawTimberFelling(Canvas canvas, Paint stroke, Paint fill) {
    // Felled timber log / trunk on ground
    canvas.drawPath(_timberLogPath, stroke..strokeWidth = 1.7);

    // Tree growth rings on left trunk end
    canvas.drawOval(
      const Rect.fromLTWH(2.5, 16.5, 2.5, 5),
      stroke..strokeWidth = 1.1,
    );

    // Felling Axe head (embedded into undercut wedge notch)
    canvas.drawPath(_timberAxeHeadPath, fill);

    // Curved wooden hickory handle
    canvas.drawPath(_timberHandlePath, stroke..strokeWidth = 2.2);

    // Undercut notch cut in timber
    canvas.drawLine(
      const Offset(11, 16),
      const Offset(13.5, 13.5),
      stroke..strokeWidth = 1.2,
    );
  }

  /// Draws an alchemical mortar & pestle with rising potentizing embers (peppering).
  void _drawPeppering(Canvas canvas, Paint stroke, Paint fill) {
    // Mortar bowl
    canvas.drawPath(_pepperingBowlPath, stroke..strokeWidth = 1.7);

    // Mortar pedestal foot
    canvas.drawLine(
      const Offset(8, 21),
      const Offset(16, 21),
      stroke..strokeWidth = 2.2,
    );

    // Diagonal pestle
    canvas.drawPath(_pepperingPestlePath, fill);

    // Ascending potentizing etheric ash embers / smoke
    canvas.drawPath(_pepperingEmbersPath, stroke..strokeWidth = 1.2);

    // Ash spark stars
    canvas.drawCircle(const Offset(9, 1.5), 0.9, fill);
    canvas.drawCircle(const Offset(14, 2.5), 0.9, fill);
    canvas.drawCircle(const Offset(16, 6), 0.7, fill);
  }

  /// Draws the Farm Organism emblem (terrestrial soil furrow, living sprout, cosmic arc).
  void _drawFarmOrganism(Canvas canvas, Paint stroke, Paint fill) {
    // Outer cosmic aura circle (delicate)
    canvas.drawCircle(const Offset(12, 12), 10.5, stroke..strokeWidth = 1.3);

    // Lower soil furrow horizon (undulating Earth)
    canvas.drawPath(_farmSoilPath, stroke..strokeWidth = 1.5);

    // Living central germinating sprout with leaves
    canvas.drawLine(
      const Offset(12, 16),
      const Offset(12, 8),
      stroke..strokeWidth = 1.9,
    );

    // Left & right leaves
    canvas.drawPath(_farmLeavesPath, fill);

    // Cosmic warmth sun/star radiant dot above
    canvas.drawCircle(const Offset(12, 4.5), 1.3, fill);
  }

  /// Draws a copper/earthenware brewing cauldron for herbal sprays and decoctions.
  void _drawHerbalCauldron(Canvas canvas, Paint stroke) {
    // Cauldron belly
    canvas.drawPath(_cauldronBellyPath, stroke..strokeWidth = 1.7);

    // Rim collar
    canvas.drawLine(
      const Offset(3, 10),
      const Offset(21, 10),
      stroke..strokeWidth = 2.2,
    );

    // Two side lifting loop ear handles
    canvas.drawPath(_cauldronHandlesPath, stroke..strokeWidth = 1.4);

    // Tripod feet
    canvas.drawLine(
      const Offset(6, 18),
      const Offset(4.5, 22),
      stroke..strokeWidth = 2.0,
    );
    canvas.drawLine(
      const Offset(12, 19),
      const Offset(12, 22),
      stroke..strokeWidth = 2.0,
    );
    canvas.drawLine(
      const Offset(18, 18),
      const Offset(19.5, 22),
      stroke..strokeWidth = 2.0,
    );

    // Wisps of medicinal steam
    canvas.drawPath(_cauldronSteamPath, stroke..strokeWidth = 1.2);
  }

  /// Draws dynamization vortex funnels with rhythmic spiral motion.
  void _drawDynamizationVortex(Canvas canvas, Paint stroke, Paint fill) {
    // Clockwise vortex spiral
    canvas.drawPath(_vortexSpiralPath, stroke..strokeWidth = 1.7);

    // Deep central vortex funnel center
    canvas.drawCircle(const Offset(12, 12), 2.2, fill);

    // Chaotic reversal droplet sparks
    canvas.drawCircle(const Offset(16, 7), 1.0, fill);
    canvas.drawCircle(const Offset(8, 16), 1.1, fill);
    canvas.drawCircle(const Offset(17, 16), 0.9, fill);
  }

  @override
  bool shouldRepaint(covariant _BiodynamicIconPainter oldDelegate) {
    return oldDelegate.type != type || oldDelegate.color != color;
  }
}
