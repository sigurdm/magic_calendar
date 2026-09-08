import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/models.dart';
import '../theme/goethean_palette.dart';
import 'curved_text.dart';

/// Cached [ui.FragmentProgram] for the Steiner Goetheanum frame shader.
ui.FragmentProgram? _steinerFrameProgram;

/// Asynchronously loads the Steiner Goetheanum frame shader program from assets.
///
/// Throws a [FlutterError] if asset loading fails in an unexpected environment.
Future<ui.FragmentProgram?> loadSteinerShader() async {
  if (_steinerFrameProgram != null) return _steinerFrameProgram;
  try {
    _steinerFrameProgram = await ui.FragmentProgram.fromAsset(
      'shaders/steiner_frame.frag',
    );
    return _steinerFrameProgram;
  } catch (e) {
    debugPrint(
      'Could not load steiner_frame.frag (using fallback painter): $e',
    );
    return null;
  }
}

/// Computed directional solar lighting vector and diurnal atmospheric factors.
///
/// Models the sun's spherical trajectory across the sky from sunrise (East) to
/// solar noon (Zenith) to sunset (West), or cool nocturnal moonlight.
final class DiurnalSolarLighting {
  /// X component of normalized light direction (negative = East/left, positive = West/right).
  final double lx;

  /// Y component of normalized light direction (negative = overhead/zenith, positive = nadir).
  final double ly;

  /// Z component of normalized light direction (positive = out-of-screen towards viewer).
  final double lz;

  /// Solar altitude above horizon (-1.0 = deep night nadir, 0.0 = horizon, 1.0 = solar noon zenith).
  final double sunAltitude;

  /// Daylight factor (0.0 = nocturnal darkness, 1.0 = full daylight).
  final double daylightFactor;

  /// Creates a [DiurnalSolarLighting].
  const DiurnalSolarLighting({
    required this.lx,
    required this.ly,
    required this.lz,
    required this.sunAltitude,
    required this.daylightFactor,
  });

  /// Computes directional solar lighting and diurnal factors for [time] and [info].
  ///
  /// Preconditions:
  /// * [time] must not be null. It is an error if [time] is null.
  /// * [info] must not be null. It is an error if [info] is null.
  ///
  /// Performance considerations:
  /// Evaluates in $O(1)$ time using trigonometric projections.
  factory DiurnalSolarLighting.compute(DateTime time, CalendarInfo info) {
    final diurnal = info.diurnalRhythm;
    final solarNoon =
        diurnal?.solarNoon ?? DateTime(time.year, time.month, time.day, 12, 30);
    final sunrise =
        diurnal?.sunrise ??
        solarNoon.subtract(const Duration(hours: 6, minutes: 15));
    final sunset =
        diurnal?.sunset ?? solarNoon.add(const Duration(hours: 7, minutes: 15));

    final isDay = time.isAfter(sunrise) && time.isBefore(sunset);

    if (isDay) {
      final totalMinutes = sunset.difference(sunrise).inMinutes;
      final progress = totalMinutes > 0
          ? (time.difference(sunrise).inMinutes / totalMinutes).clamp(0.0, 1.0)
          : 0.5;

      // Solar angle theta: -pi/2 at sunrise, 0.0 at noon, +pi/2 at sunset
      final theta = math.pi * (progress - 0.5);

      final rawLx = math.sin(theta);
      final rawLy = -(0.32 + 0.63 * math.cos(theta));
      final rawLz = 0.35 + 0.25 * math.cos(theta);
      final len = math.sqrt(rawLx * rawLx + rawLy * rawLy + rawLz * rawLz);

      final lx = len > 0 ? rawLx / len : 0.0;
      final ly = len > 0 ? rawLy / len : -1.0;
      final lz = len > 0 ? rawLz / len : 0.5;

      final minFromRise = time.difference(sunrise).inMinutes;
      final minToSet = sunset.difference(time).inMinutes;
      final minEdge = math.min(minFromRise, minToSet);
      final daylightFactor = (minEdge / 45.0).clamp(0.18, 1.0);
      final sunAltitude = math.cos(theta);

      return DiurnalSolarLighting(
        lx: lx,
        ly: ly,
        lz: lz,
        sunAltitude: sunAltitude,
        daylightFactor: daylightFactor,
      );
    } else {
      // Night illumination: Soft cool moonlight angled from high upper-left
      const rawLx = -0.32;
      const rawLy = -0.62;
      const rawLz = 0.65;
      const len = 0.95205; // sqrt(0.32^2 + 0.62^2 + 0.65^2)

      return const DiurnalSolarLighting(
        lx: rawLx / len,
        ly: rawLy / len,
        lz: rawLz / len,
        sunAltitude: -0.80,
        daylightFactor: 0.0,
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiurnalSolarLighting &&
          runtimeType == other.runtimeType &&
          lx == other.lx &&
          ly == other.ly &&
          lz == other.lz &&
          sunAltitude == other.sunAltitude &&
          daylightFactor == other.daylightFactor;

  @override
  int get hashCode => Object.hash(lx, ly, lz, sunAltitude, daylightFactor);

  @override
  String toString() =>
      'DiurnalSolarLighting(dir: (${lx.toStringAsFixed(2)}, ${ly.toStringAsFixed(2)}, ${lz.toStringAsFixed(2)}), '
      'alt: ${sunAltitude.toStringAsFixed(2)}, day: ${daylightFactor.toStringAsFixed(2)})';
}

/// Card presenting the predominant agricultural plant quality for the selected date.
///
/// Designed with Anthroposophic architecture inspired by Rudolf Steiner's second
/// Goetheanum in Dornach, Switzerland ("Beyond Straight Lines"). Built as a
/// single monolithic polygon frame with continuous 3D volumetric bevels, an
/// upward-facing luminous sill shelf, an asymmetric lintel arch, and procedural
/// GLSL watercolor lazure shader modeling.
///
/// Preconditions:
/// * [info] must not be null. It is an error if [info] is null.
///
/// Performance considerations:
/// Geometry is rendered using lightweight vector Bézier paths in $O(1)$ time
/// per layout pass. Curved typography is laid out along the upper sloping
/// lintel in $O(N)$ time where $N$ is character count. When the GLSL fragment
/// shader is compiled, it executes on the GPU in $O(1)$ time per frame.
///
/// {@example example/plant_quality_card_example.dart}

/// Represents the tactile watercolor textural style variant.
enum WatercolorTextureStyle {
  /// Steiner Lazure: soft, luminous, feathered atmospheric veils with smooth paper tooth.
  lazure,

  /// Granulating Mineral: pigment sedimentation, stippled particles settling into rough paper tooth.
  granulating,

  /// Wet-in-Wet Blooms: expressive drying tide lines, cauliflowers, and water puddle rims.
  blooms,

  /// Rough Rag: heavy mould-made paper, dry-brush crest reserves, and deep crease pooling.
  roughRag,
}

/// Represents typographic font suites for the Goetheanum frame and inner window.
enum CardTypographyStyle {
  /// Dornach Lapidary & Garamond: Chiseled inscriptional Cinzel on the stone lintel,
  /// dignified Cormorant Garamond for the day title, and lyrical Cormorant for the advice.
  dornachGaramond,

  /// Flared Humanist: Flared Roman Marcellus on the stone lintel, expressive
  /// warm artisanal Fraunces for the title, and literary Alegreya for the advice.
  humanistArtisanal,

  /// Classical Codex: Antique Castoro Titling on the stone lintel, historical
  /// EB Garamond for the title, and clear literary Spectral for the advice.
  classicalCodex,

  /// Architectural Modern: Chiseled Cinzel on the stone lintel and title,
  /// paired with clean modern Outfit for high-contrast crispness.
  architecturalModern,
}

/// Anthroposophic Goetheanum-style organic card presenting biodynamic advice.
///
/// Encased in an architectural stone frame inspired by Rudolf Steiner's First
/// and Second Goetheanum in Dornach, Switzerland. Features:
/// * Single manifold organic curved silhouette (no sharp 90° Cartesian corners)
/// * Recessed central aperture framing full-bleed plant organ artwork
/// * Flowing inscription along the curved upper stone lintel
/// * Multi-chromatic wet-on-wet Goethean watercolor lazure with living mottling
/// * Directional solar ray modeling synchronized with the day/night cycle
/// * Deep sunken velvety inner shadow cavity
final class PlantQualityCard extends StatefulWidget {
  /// Calendar advice information.
  final CalendarInfo info;

  /// Currently selected time on the calendar or timeline.
  ///
  /// Used to drive directional solar ray angle, shadow projection, and
  /// diurnal chromatic warmth (sunrise, noon, golden hour, night rest).
  /// If omitted, defaults to [DateTime.now].
  final DateTime? selectedTime;

  /// Whether the watercolor texture subtly mottles and breathes over time.
  ///
  /// Defaults to `true`. When set to `false`, the texture remains static.
  final bool animate;

  /// The watercolor texture style variant.
  ///
  /// Defaults to [WatercolorTextureStyle.lazure].
  final WatercolorTextureStyle textureStyle;

  /// The typographic font pairing style for inscriptions and descriptions.
  ///
  /// Defaults to [CardTypographyStyle.dornachGaramond].
  final CardTypographyStyle typographyStyle;

  /// Creates a [PlantQualityCard].
  ///
  /// Preconditions:
  /// * [info] must not be null. It is an error if [info] is null.
  const PlantQualityCard({
    super.key,
    required this.info,
    this.selectedTime,
    this.animate = false,
    this.textureStyle = WatercolorTextureStyle.lazure,
    this.typographyStyle = CardTypographyStyle.dornachGaramond,
  });

  @override
  State<PlantQualityCard> createState() => _PlantQualityCardState();
}

final class _PlantQualityCardState extends State<PlantQualityCard>
    with SingleTickerProviderStateMixin {
  ui.FragmentProgram? _program;
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    );
    _initShader();
  }

  @override
  void didUpdateWidget(covariant PlantQualityCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate != oldWidget.animate) {
      if (widget.animate && _program != null) {
        _animController.repeat();
      } else {
        _animController.stop();
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  bool get _isTestEnvironment =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  void _initShader() async {
    if (_steinerFrameProgram != null) {
      _program = _steinerFrameProgram;
      if (mounted && widget.animate && !_isTestEnvironment) {
        _animController.repeat();
      }
      return;
    }
    final prog = await loadSteinerShader();
    if (mounted && prog != null) {
      setState(() {
        _program = prog;
      });
      if (widget.animate && !_isTestEnvironment) {
        _animController.repeat();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String title = 'Unknown';
    String desc = '';
    String bannerText = 'COSMIC RHYTHM';

    final info = widget.info;
    final quality = info.quality;
    final color = GoetheanPalette.getColor(quality);

    if (info.isGrayDay) {
      title = 'Gray Day';
      desc = info.message;
      bannerText = 'REST';
    } else if (info.message.startsWith('Special')) {
      title = info.message.split(':').first;
      bannerText = 'SPECIAL ALIGNMENT';
      switch (quality) {
        case PlantQuality.flower:
          desc =
              'Exceptional cosmic energy for flowering plants, medicinal herbs & essential oils.';
          break;
        case PlantQuality.fruit:
          desc =
              'Exceptional warmth energy for seed formation, fruit ripening & long storage.';
          break;
        case PlantQuality.leaf:
          desc =
              'Exceptional moisture impulse for lush leafy greens, spinach & herbs.';
          break;
        case PlantQuality.root:
          desc =
              'Exceptional gravitational earth focus for carrots, beets & root vegetables.';
          break;
        case PlantQuality.none:
          desc =
              'Special planetary alignment boosting elemental plant development.';
          break;
      }
    } else {
      switch (quality) {
        case PlantQuality.root:
          title = 'Root Day';
          bannerText = 'EARTH';
          break;
        case PlantQuality.leaf:
          title = 'Leaf Day';
          bannerText = 'WATER';
          break;
        case PlantQuality.flower:
          title = 'Flower Day';
          bannerText = 'AIR';
          break;
        case PlantQuality.fruit:
          title = 'Fruit Day';
          bannerText = 'FIRE';
          break;
        case PlantQuality.none:
          title = 'No Specific Quality';
          bannerText = 'REST';
          break;
      }
    }

    final accentColor = info.isSpecial ? GoetheanPalette.aspectGold : color;

    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 600;
          final maxCardWidth = isDesktop ? 260.0 : 380.0;
          final cardWidth = constraints.maxWidth.clamp(240.0, maxCardWidth);
          // Proportional height matching compact Steiner Goetheanum window ratio (~1.05)
          final cardHeight = cardWidth * 1.05;

          // Curved text path running along the exact anatomical midline of the thick stone lintel
          final textPath = Path()
            ..moveTo(cardWidth * 0.16, cardHeight * 0.088)
            ..cubicTo(
              cardWidth * 0.38,
              cardHeight * 0.055,
              cardWidth * 0.65,
              cardHeight * 0.046,
              cardWidth * 0.85,
              cardHeight * 0.082,
            );

          final isNarrow = cardWidth < 340;

          final selectedTime = widget.selectedTime ?? DateTime.now();
          final lighting = DiurnalSolarLighting.compute(selectedTime, info);

          final innerContent = SizedBox(
            width: cardWidth,
            height: cardHeight,
            child: Stack(
              children: [
                // Inscription carved directly onto the thick upper stone lintel
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: cardHeight * 0.24,
                  child: CurvedText(
                    text: bannerText,
                    path: textPath,
                    style: _buildInscriptionStyle(
                      isNarrow: isNarrow,
                      text: bannerText,
                      color: _getInscriptionColor(
                        quality,
                        info.isSpecial,
                        info.isGrayDay,
                      ),
                    ),
                  ),
                ),
                // 1. Full-bleed artwork taking up the entire window opening underneath the text
                Positioned.fill(
                  child: ClipPath(
                    clipper: const SteinerInnerWindowClipper(),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Opacity(
                          opacity: 0.28,
                          child: Image.asset(
                            _getQualityAssetPath(quality, info.isGrayDay),
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                          ),
                        ),
                        // Soft vignette scrim to ensure supreme typographic legibility
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: Alignment.center,
                              radius: 0.85,
                              colors: [
                                Colors.black.withValues(alpha: 0.20),
                                Colors.black.withValues(alpha: 0.04),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // 2. Recessed inner window typography centered directly over the artwork
                Positioned(
                  left: cardWidth * 0.12,
                  right: cardWidth * 0.12,
                  top: cardHeight * 0.14,
                  bottom: cardHeight * 0.16,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: cardWidth * 0.76),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: _buildTitleStyle(isNarrow: isNarrow),
                            ),
                            if (desc.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6.0,
                                ),
                                child: Text(
                                  desc,
                                  textAlign: TextAlign.center,
                                  style: _buildDescriptionStyle(
                                    isNarrow: isNarrow,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );

          return AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              final timeSeconds = _animController.value * 60.0;
              ui.FragmentShader? shader;
              if (_program != null) {
                shader = _program!.fragmentShader();
                _configureShader(
                  shader,
                  cardWidth,
                  cardHeight,
                  quality,
                  info,
                  lighting,
                  timeSeconds,
                  widget.textureStyle,
                );
              }

              return CustomPaint(
                size: Size(cardWidth, cardHeight),
                painter: SteinerFramePainter(
                  quality: quality,
                  elementColor: accentColor,
                  isSpecial: info.isSpecial,
                  isGrayDay: info.isGrayDay,
                  shader: shader,
                  lighting: lighting,
                  time: timeSeconds,
                ),
                child: child,
              );
            },
            child: innerContent,
          );
        },
      ),
    );
  }

  static const _inscriptionShadows = [
    Shadow(color: Color(0x60FFFFFF), offset: Offset(0, 1), blurRadius: 1.0),
    Shadow(color: Color(0x40000000), offset: Offset(0, -0.5), blurRadius: 0.5),
  ];

  static const _titleShadows = [
    Shadow(color: Color(0xE0000000), offset: Offset(0, 2), blurRadius: 5.0),
    Shadow(color: Color(0x90000000), offset: Offset(0, 0), blurRadius: 10.0),
  ];

  static const _descShadows = [
    Shadow(color: Color(0xE0000000), offset: Offset(0, 1.5), blurRadius: 3.0),
    Shadow(color: Color(0x90000000), offset: Offset(0, 0), blurRadius: 8.0),
  ];

  TextStyle _buildInscriptionStyle({
    required bool isNarrow,
    required String text,
    required Color color,
  }) {
    final textLength = text.length;
    switch (widget.typographyStyle) {
      case CardTypographyStyle.dornachGaramond:
        return GoogleFonts.cinzel(
          fontSize: textLength <= 8
              ? (isNarrow ? 15.0 : 16.5)
              : (textLength > 25
                    ? (isNarrow ? 11.5 : 13.5)
                    : (isNarrow ? 13.5 : 15.0)),
          fontWeight: FontWeight.w700,
          letterSpacing: textLength <= 8
              ? (isNarrow ? 4.5 : 5.8)
              : (textLength > 25
                    ? (isNarrow ? 1.4 : 1.8)
                    : (isNarrow ? 2.4 : 3.2)),
          color: color,
          shadows: _inscriptionShadows,
        );
      case CardTypographyStyle.humanistArtisanal:
        return GoogleFonts.marcellus(
          fontSize: textLength <= 8
              ? (isNarrow ? 15.0 : 17.0)
              : (textLength > 25
                    ? (isNarrow ? 11.5 : 13.5)
                    : (isNarrow ? 13.5 : 15.5)),
          letterSpacing: textLength <= 8
              ? (isNarrow ? 4.2 : 5.5)
              : (textLength > 25
                    ? (isNarrow ? 1.3 : 1.8)
                    : (isNarrow ? 2.2 : 3.0)),
          color: color,
          shadows: _inscriptionShadows,
        );
      case CardTypographyStyle.classicalCodex:
        return GoogleFonts.castoroTitling(
          fontSize: textLength <= 8
              ? (isNarrow ? 14.5 : 16.0)
              : (textLength > 25
                    ? (isNarrow ? 11.0 : 13.0)
                    : (isNarrow ? 13.0 : 14.5)),
          letterSpacing: textLength <= 8
              ? (isNarrow ? 4.0 : 5.2)
              : (textLength > 25
                    ? (isNarrow ? 1.2 : 1.6)
                    : (isNarrow ? 2.0 : 2.8)),
          color: color,
          shadows: _inscriptionShadows,
        );
      case CardTypographyStyle.architecturalModern:
        return GoogleFonts.cinzel(
          fontSize: textLength <= 8
              ? (isNarrow ? 15.0 : 16.5)
              : (textLength > 25
                    ? (isNarrow ? 11.5 : 13.5)
                    : (isNarrow ? 13.5 : 15.0)),
          fontWeight: FontWeight.w800,
          letterSpacing: textLength <= 8
              ? (isNarrow ? 4.8 : 6.0)
              : (textLength > 25
                    ? (isNarrow ? 1.5 : 2.0)
                    : (isNarrow ? 2.6 : 3.4)),
          color: color,
          shadows: _inscriptionShadows,
        );
    }
  }

  TextStyle _buildTitleStyle({required bool isNarrow}) {
    switch (widget.typographyStyle) {
      case CardTypographyStyle.dornachGaramond:
        return GoogleFonts.cormorantGaramond(
          fontSize: isNarrow ? 24.0 : 28.0,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.2,
          color: const Color(0xFFFDFBF7),
          shadows: _titleShadows,
        );
      case CardTypographyStyle.humanistArtisanal:
        return GoogleFonts.fraunces(
          fontSize: isNarrow ? 22.0 : 26.0,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.8,
          color: const Color(0xFFFDFBF7),
          shadows: _titleShadows,
        );
      case CardTypographyStyle.classicalCodex:
        return GoogleFonts.ebGaramond(
          fontSize: isNarrow ? 23.0 : 27.0,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.0,
          color: const Color(0xFFFDFBF7),
          shadows: _titleShadows,
        );
      case CardTypographyStyle.architecturalModern:
        return GoogleFonts.cinzel(
          fontSize: isNarrow ? 21.0 : 25.0,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.5,
          color: const Color(0xFFFDFBF7),
          shadows: _titleShadows,
        );
    }
  }

  TextStyle _buildDescriptionStyle({required bool isNarrow}) {
    switch (widget.typographyStyle) {
      case CardTypographyStyle.dornachGaramond:
        return GoogleFonts.cormorantGaramond(
          fontSize: isNarrow ? 14.5 : 16.0,
          height: 1.30,
          fontWeight: FontWeight.w600,
          fontStyle: FontStyle.italic,
          letterSpacing: 0.2,
          color: const Color(0xF2F7EFE6),
          shadows: _descShadows,
        );
      case CardTypographyStyle.humanistArtisanal:
        return GoogleFonts.alegreya(
          fontSize: isNarrow ? 12.5 : 14.0,
          height: 1.35,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
          color: const Color(0xF0F4ECE2),
          shadows: _descShadows,
        );
      case CardTypographyStyle.classicalCodex:
        return GoogleFonts.spectral(
          fontSize: isNarrow ? 12.5 : 13.5,
          height: 1.35,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
          color: const Color(0xF0F4ECE2),
          shadows: _descShadows,
        );
      case CardTypographyStyle.architecturalModern:
        return GoogleFonts.outfit(
          fontSize: isNarrow ? 12.0 : 13.0,
          height: 1.38,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
          color: const Color(0xF0F4ECE2),
          shadows: _descShadows,
        );
    }
  }

  void _configureShader(
    ui.FragmentShader shader,
    double width,
    double height,
    PlantQuality quality,
    CalendarInfo info,
    DiurnalSolarLighting lighting,
    double time,
    WatercolorTextureStyle textureStyle,
  ) {
    // 0..1: uResolution
    shader.setFloat(0, width);
    shader.setFloat(1, height);

    // Get color palette for active quality
    final highlight = _getShaderColorHighlight(
      quality,
      info.isSpecial,
      info.isGrayDay,
    );
    final body = _getShaderColorBody(quality, info.isSpecial, info.isGrayDay);
    final shadow = _getShaderColorShadow(
      quality,
      info.isSpecial,
      info.isGrayDay,
    );
    final shelf = _getShaderColorShelf(quality, info.isSpecial, info.isGrayDay);
    final glaze = _getShaderColorGlaze(quality, info.isSpecial, info.isGrayDay);

    // 2..5: uColorHighlight
    shader.setFloat(2, highlight.r);
    shader.setFloat(3, highlight.g);
    shader.setFloat(4, highlight.b);
    shader.setFloat(5, highlight.a);

    // 6..9: uColorBody
    shader.setFloat(6, body.r);
    shader.setFloat(7, body.g);
    shader.setFloat(8, body.b);
    shader.setFloat(9, body.a);

    // 10..13: uColorShadow
    shader.setFloat(10, shadow.r);
    shader.setFloat(11, shadow.g);
    shader.setFloat(12, shadow.b);
    shader.setFloat(13, shadow.a);

    // 14..17: uColorShelf
    shader.setFloat(14, shelf.r);
    shader.setFloat(15, shelf.g);
    shader.setFloat(16, shelf.b);
    shader.setFloat(17, shelf.a);

    // 18..21: uColorGlaze
    shader.setFloat(18, glaze.r);
    shader.setFloat(19, glaze.g);
    shader.setFloat(20, glaze.b);
    shader.setFloat(21, glaze.a);

    // 22: uQuality index
    double qIndex = 0.0;
    if (info.isGrayDay) {
      qIndex = 5.0;
    } else if (info.isSpecial) {
      qIndex = 4.0;
    } else {
      switch (quality) {
        case PlantQuality.leaf:
          qIndex = 0.0;
          break;
        case PlantQuality.root:
          qIndex = 1.0;
          break;
        case PlantQuality.flower:
          qIndex = 2.0;
          break;
        case PlantQuality.fruit:
          qIndex = 3.0;
          break;
        case PlantQuality.none:
          qIndex = 5.0;
          break;
      }
    }
    shader.setFloat(22, qIndex);

    // 23: uSeed
    shader.setFloat(23, 42.0 + qIndex * 17.3);

    // 24..26: uLightDir (vec3 normalized light direction)
    shader.setFloat(24, lighting.lx);
    shader.setFloat(25, lighting.ly);
    shader.setFloat(26, lighting.lz);

    // 27: uSunAltitude (float: -1.0 nadir night to +1.0 noon zenith)
    shader.setFloat(27, lighting.sunAltitude);

    // 28: uDaylightFactor (float: 0.0 night darkness to 1.0 full daylight)
    shader.setFloat(28, lighting.daylightFactor);

    // 29: uTime (float: elapsed animation time in seconds)
    shader.setFloat(29, time);

    // 30: uTextureStyle (float: 0.0 = lazure, 1.0 = granulating, 2.0 = blooms, 3.0 = roughRag)
    shader.setFloat(30, textureStyle.index.toDouble());
  }

  Color _getShaderColorHighlight(PlantQuality q, bool special, bool gray) {
    if (gray) return const Color(0xFFE8E4DA);
    if (special) return const Color(0xFFFDECB0);
    switch (q) {
      case PlantQuality.leaf:
        return const Color(
          0xFFD2ECC8,
        ); // Pale fresh spring leaf green highlight
      case PlantQuality.root:
        return const Color(0xFFF6D6C2); // Soft warm terracotta cream highlight
      case PlantQuality.flower:
        return const Color(0xFFEAE2F8); // Gentle wisteria lavender highlight
      case PlantQuality.fruit:
        return const Color(0xFFFEE4B8); // Soft sunlit apricot highlight
      case PlantQuality.none:
        return const Color(0xFFE8E4DA);
    }
  }

  Color _getShaderColorBody(PlantQuality q, bool special, bool gray) {
    if (gray) return const Color(0xFFA69E90);
    if (special) return const Color(0xFFDCA420);
    switch (q) {
      case PlantQuality.leaf:
        return const Color(0xFF5C9450); // Natural English sap green wash
      case PlantQuality.root:
        return const Color(0xFFB86E4C); // Warm terracotta earthen red clay wash
      case PlantQuality.flower:
        return const Color(0xFF8870B6); // Soft airy wisteria / iris wash
      case PlantQuality.fruit:
        return const Color(0xFFDA7C24); // Warm glowing apricot / amber wash
      case PlantQuality.none:
        return const Color(0xFFA69E90);
    }
  }

  Color _getShaderColorShadow(PlantQuality q, bool special, bool gray) {
    if (gray) return const Color(0xFF4E463A);
    if (special) return const Color(0xFF7A4A0A);
    switch (q) {
      case PlantQuality.leaf:
        return const Color(0xFF285624); // Soft deep forest shade
      case PlantQuality.root:
        return const Color(0xFF742E1A); // Burnt terracotta sienna
      case PlantQuality.flower:
        return const Color(0xFF4C2A74); // Wisteria amethyst shadow
      case PlantQuality.fruit:
        return const Color(0xFF863412); // Warm cinnamon ember shadow
      case PlantQuality.none:
        return const Color(0xFF4E463A);
    }
  }

  Color _getShaderColorShelf(PlantQuality q, bool special, bool gray) {
    if (gray) return const Color(0xFFCDC6B8);
    if (special) return const Color(0xFFFFEE88);
    switch (q) {
      case PlantQuality.leaf:
        return const Color(0xFF8EAC4C); // Olive chartreuse glaze
      case PlantQuality.root:
        return const Color(0xFFD69A3C); // Raw sienna / ochre glaze
      case PlantQuality.flower:
        return const Color(0xFFE8C858); // Pale primrose sunlight glaze
      case PlantQuality.fruit:
        return const Color(0xFFF2A62C); // Warm honey amber glaze
      case PlantQuality.none:
        return const Color(0xFFCDC6B8);
    }
  }

  Color _getShaderColorGlaze(PlantQuality q, bool special, bool gray) {
    if (gray) return const Color(0xFF8A8276);
    if (special) return const Color(0xFFD6901E);
    switch (q) {
      case PlantQuality.leaf:
        return const Color(0xFF449E90); // Soft sea-pine turquoise glaze
      case PlantQuality.root:
        return const Color(0xFFC04E60); // Delicate rose madder glaze
      case PlantQuality.flower:
        return const Color(0xFF5872C4); // Soft periwinkle glaze
      case PlantQuality.fruit:
        return const Color(0xFFD84A36); // Warm coral vermilion glaze
      case PlantQuality.none:
        return const Color(0xFF8A8276);
    }
  }

  Color _getInscriptionColor(
    PlantQuality quality,
    bool isSpecial,
    bool isGrayDay,
  ) {
    if (isGrayDay) return const Color(0xFF26231E);
    if (isSpecial) return const Color(0xFF3D2A02);
    switch (quality) {
      case PlantQuality.leaf:
        return const Color(0xFF142914);
      case PlantQuality.root:
        return const Color(0xFF38150B);
      case PlantQuality.flower:
        return const Color(0xFF241242);
      case PlantQuality.fruit:
        return const Color(0xFF3D2102);
      case PlantQuality.none:
        return const Color(0xFF26231E);
    }
  }

  String _getQualityAssetPath(PlantQuality quality, bool isGrayDay) {
    if (isGrayDay) return 'assets/icons/gray_day.png';
    switch (quality) {
      case PlantQuality.root:
        return 'assets/icons/root.png';
      case PlantQuality.leaf:
        return 'assets/icons/leaf.png';
      case PlantQuality.flower:
        return 'assets/icons/flower.png';
      case PlantQuality.fruit:
        return 'assets/icons/fruit.png';
      case PlantQuality.none:
        return 'assets/icons/none.png';
    }
  }
}

/// Custom clipper generating an Anthroposophic Goetheanum window silhouette.
///
/// Features smooth, organic curved contours, a sloping asymmetrical upper
/// lintel, and rounded corner transitions, completely eliminating rigid
/// Cartesian 90° right angles.
final class SteinerWindowCardClipper extends CustomClipper<Path> {
  /// Elapsed animation time in seconds for subtle breathing metamorphosis.
  final double time;

  /// Creates a [SteinerWindowCardClipper].
  const SteinerWindowCardClipper([this.time = 0.0]);

  @override
  Path getClip(Size size) => getOuterPath(size, time);

  /// Calculates the outer sculpted Goetheanum silhouette path, optionally
  /// breathing with [time].
  static Path getOuterPath(Size size, [double time = 0.0]) {
    final w = size.width;
    final h = size.height;
    final path = Path();

    // Subtle organic respiration / metamorphosis of the outer Goetheanum silhouette
    final breathY =
        math.sin(time * 0.35) * 0.005 + math.sin(time * 0.22) * 0.002;
    final breathX =
        math.cos(time * 0.32) * 0.004 + math.cos(time * 0.50) * 0.002;
    final archMod = math.sin(time * 0.35) * 0.003;
    final bottomMod = math.sin(time * 0.30) * 0.0025;

    // Wonky anthroposophic hand-carved Steiner outer frame silhouette
    path.moveTo(w * (0.019 - breathX), h * 0.500);
    // Left flank sweeping upward into top-left corner
    path.cubicTo(
      w * (0.021 - breathX),
      h * (0.384 - breathY * 0.5),
      w * (0.034 - breathX * 0.8),
      h * (0.258 - breathY * 0.7),
      w * (0.064 - breathX * 0.8),
      h * (0.160 - breathY),
    );
    path.cubicTo(
      w * (0.078 - breathX * 0.6),
      h * (0.112 - breathY),
      w * (0.112 - breathX * 0.5),
      h * (0.078 - breathY - archMod * 0.5),
      w * 0.170,
      h * (0.059 - breathY - archMod * 0.8),
    );
    // Top rail crowning organically toward the right (~65-73% width)
    path.cubicTo(
      w * 0.248,
      h * (0.036 - breathY - archMod),
      w * 0.384,
      h * (0.025 - breathY - archMod),
      w * 0.519,
      h * (0.021 - breathY - archMod),
    );
    path.cubicTo(
      w * 0.597,
      h * (0.017 - breathY - archMod),
      w * 0.675,
      h * (0.013 - breathY - archMod),
      w * 0.733,
      h * (0.020 - breathY - archMod),
    );
    path.cubicTo(
      w * 0.810,
      h * (0.030 - breathY - archMod * 0.8),
      w * 0.869,
      h * (0.049 - breathY - archMod * 0.5),
      w * (0.917 + breathX * 0.6),
      h * (0.088 - breathY),
    );
    // Top-right sculpted corner into right flank
    path.cubicTo(
      w * (0.946 + breathX * 0.8),
      h * (0.122 - breathY * 0.6),
      w * (0.958 + breathX * 0.9),
      h * 0.190,
      w * (0.958 + breathX),
      h * 0.287,
    );
    // Right flank with living S-curve undulation and lower architectural swell
    path.cubicTo(
      w * (0.958 + breathX),
      h * 0.384,
      w * (0.964 + breathX),
      h * 0.481,
      w * (0.968 + breathX),
      h * 0.578,
    );
    path.cubicTo(
      w * (0.973 + breathX),
      h * 0.655,
      w * (0.985 + breathX),
      h * 0.713,
      w * (0.983 + breathX),
      h * 0.762,
    );
    path.cubicTo(
      w * (0.980 + breathX),
      h * (0.820 + breathY * 0.5),
      w * (0.961 + breathX * 0.8),
      h * (0.873 + breathY * 0.7),
      w * (0.922 + breathX * 0.6),
      h * (0.922 + breathY + bottomMod * 0.5),
    );
    // Bottom rail with lively undulating wave: lifting in center-right, dipping deep on left
    path.cubicTo(
      w * 0.869,
      h * (0.927 + breathY + bottomMod * 0.6),
      w * 0.772,
      h * (0.917 + breathY + bottomMod * 0.7),
      w * 0.675,
      h * (0.912 + breathY + bottomMod * 0.8),
    );
    path.cubicTo(
      w * 0.558,
      h * (0.909 + breathY + bottomMod * 0.85),
      w * 0.442,
      h * (0.912 + breathY + bottomMod * 0.9),
      w * 0.345,
      h * (0.922 + breathY + bottomMod),
    );
    path.cubicTo(
      w * 0.248,
      h * (0.935 + breathY + bottomMod),
      w * (0.180 - breathX * 0.5),
      h * (0.966 + breathY + bottomMod),
      w * (0.131 - breathX * 0.6),
      h * (0.980 + breathY + bottomMod),
    );
    // Flared bottom-left architectural foot
    path.cubicTo(
      w * (0.083 - breathX * 0.7),
      h * (0.985 + breathY + bottomMod),
      w * (0.044 - breathX * 0.8),
      h * (0.966 + breathY + bottomMod * 0.8),
      w * (0.030 - breathX),
      h * (0.907 + breathY * 0.7),
    );
    path.cubicTo(
      w * (0.015 - breathX),
      h * 0.830,
      w * (0.013 - breathX),
      h * 0.713,
      w * (0.019 - breathX),
      h * 0.500,
    );
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant SteinerWindowCardClipper oldClipper) =>
      oldClipper.time != time;

  /// Calculates the inner cutout path for the recessed window.
  static Path getInnerClip(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();

    // Sculpted organic Goetheanum inner window opening (matching Steiner carved wood opening)
    path.moveTo(w * 0.106, h * 0.500);
    path.cubicTo(
      w * 0.104,
      h * 0.384,
      w * 0.110,
      h * 0.287,
      w * 0.131,
      h * 0.209,
    );
    path.cubicTo(
      w * 0.151,
      h * 0.151,
      w * 0.190,
      h * 0.122,
      w * 0.248,
      h * 0.107,
    );
    path.cubicTo(
      w * 0.345,
      h * 0.095,
      w * 0.481,
      h * 0.091,
      w * 0.597,
      h * 0.091,
    );
    path.cubicTo(
      w * 0.694,
      h * 0.093,
      w * 0.781,
      h * 0.107,
      w * 0.830,
      h * 0.136,
    );
    path.cubicTo(
      w * 0.869,
      h * 0.165,
      w * 0.886,
      h * 0.228,
      w * 0.888,
      h * 0.325,
    );
    path.cubicTo(
      w * 0.890,
      h * 0.422,
      w * 0.892,
      h * 0.519,
      w * 0.892,
      h * 0.597,
    );
    path.cubicTo(
      w * 0.892,
      h * 0.675,
      w * 0.888,
      h * 0.733,
      w * 0.869,
      h * 0.776,
    );
    path.cubicTo(
      w * 0.840,
      h * 0.810,
      w * 0.772,
      h * 0.801,
      w * 0.694,
      h * 0.794,
    );
    path.cubicTo(
      w * 0.597,
      h * 0.789,
      w * 0.500,
      h * 0.801,
      w * 0.403,
      h * 0.815,
    );
    path.cubicTo(
      w * 0.306,
      h * 0.828,
      w * 0.228,
      h * 0.844,
      w * 0.160,
      h * 0.854,
    );
    path.cubicTo(
      w * 0.127,
      h * 0.844,
      w * 0.110,
      h * 0.791,
      w * 0.106,
      h * 0.713,
    );
    path.cubicTo(
      w * 0.102,
      h * 0.645,
      w * 0.104,
      h * 0.578,
      w * 0.106,
      h * 0.500,
    );
    path.close();

    return path;
  }
}

/// Custom clipper generating the recessed inner window opening silhouette.
final class SteinerInnerWindowClipper extends CustomClipper<Path> {
  /// Creates a [SteinerInnerWindowClipper].
  const SteinerInnerWindowClipper();

  @override
  Path getClip(Size size) => SteinerWindowCardClipper.getInnerClip(size);

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Custom painter for the sculptural, single-piece Goetheanum 3D stone frame.
///
/// Built as a single monolithic manifold polygon ([framePath]) combining the outer
/// silhouette and inner cutout, rendered with:
/// 1. Physical floating drop shadow behind the frame polygon
/// 2. GLSL runtime fragment shader for continuous 3D normal lighting,
///    fluid domain-warped watercolor lazure washes, and mineral stone tooth
/// 3. Procedural multi-stop watercolor gradient fallback when shader is uninitialized
/// 4. Deeply recessed velvety inner window cavity with physical inset shadow
/// 5. Chiseled specular rim highlights
final class SteinerFramePainter extends CustomPainter {
  /// Active plant quality determining the frame color palette.
  final PlantQuality quality;

  /// Primary elemental accent color.
  final Color elementColor;

  /// Whether the card represents a special planetary alignment.
  final bool isSpecial;

  /// Whether the date falls on a gray blackout day.
  final bool isGrayDay;

  /// Optional hardware-accelerated GLSL fragment shader.
  final ui.FragmentShader? shader;

  /// Optional precomputed diurnal solar lighting.
  final DiurnalSolarLighting? lighting;

  /// Optional elapsed animation time in seconds driving fluid watercolor mottling.
  final double time;

  /// Creates a [SteinerFramePainter].
  const SteinerFramePainter({
    required this.quality,
    required this.elementColor,
    this.isSpecial = false,
    this.isGrayDay = false,
    this.shader,
    this.lighting,
    this.time = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final outerPath = SteinerWindowCardClipper.getOuterPath(size, time);
    final innerPath = SteinerWindowCardClipper.getInnerClip(size);

    // The entire frame is constructed as a SINGLE MANIFOLD POLYGON
    final framePath = Path.combine(
      PathOperation.difference,
      outerPath,
      innerPath,
    );

    // 1. Physical drop shadow behind the entire single stone frame polygon
    final dropShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.72)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26);
    canvas.save();
    canvas.translate(0, 13);
    canvas.drawPath(framePath, dropShadowPaint);
    canvas.restore();

    // 2. Recessed Inner Window Cavity (deeply sunken behind the frame)
    final innerRecessBg = Paint()
      ..shader = ui.Gradient.radial(
        Offset(w * 0.5, h * 0.52),
        w * 0.52,
        _getInnerRecessColors(quality, isSpecial, isGrayDay),
        const [0.0, 0.60, 1.0],
      );
    canvas.drawPath(innerPath, innerRecessBg);

    // 3. RENDER THE FRAME AS A SINGLE PIECE
    if (shader != null) {
      // GPU Fragment Shader magic: Continuous 3D normals, domain-warped lazure & stone tooth
      final framePaint = Paint()..shader = shader;
      canvas.drawPath(framePath, framePaint);
    } else {
      // Fallback procedural single-piece frame painter
      _paintFallbackSinglePieceFrame(
        canvas,
        size,
        framePath,
        outerPath,
        innerPath,
      );
    }

    // 5. Chiseled Rim Highlights (only for fallback when shader is null)
    if (shader == null) {
      _paintRimHighlights(canvas, size, outerPath, innerPath);
    }
  }

  void _paintRimHighlights(
    Canvas canvas,
    Size size,
    Path outerPath,
    Path innerPath,
  ) {
    final w = size.width;
    final h = size.height;

    // Directional light catch based on sun trajectory (morning left vs evening right)
    final lightX = lighting?.lx ?? -0.35;
    final isLeftLight = lightX < 0;

    // Outer edge light catch (pale ivory specular rim)
    final outerHighlight = Paint()
      ..shader = ui.Gradient.linear(
        Offset(isLeftLight ? w * 0.1 : w * 0.9, 0),
        Offset(isLeftLight ? w * 0.9 : w * 0.1, h),
        [
          const Color(0xD8FFFFFF),
          const Color(0x66FFFFFF),
          const Color(0x00FFFFFF),
        ],
        const [0.0, 0.45, 0.80],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(outerPath, outerHighlight);

    // Inner cutout rim: catches crisp specular light along the bottom shelf
    final innerShelfRim = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, h * 0.3),
        Offset(0, h * 0.82),
        [
          const Color(0x00FFFFFF),
          const Color(0x20FFFFFF),
          const Color(0xEEFFFFFF),
        ],
        const [0.0, 0.6, 1.0],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawPath(innerPath, innerShelfRim);
  }

  void _paintFallbackSinglePieceFrame(
    Canvas canvas,
    Size size,
    Path framePath,
    Path outerPath,
    Path innerPath,
  ) {
    final w = size.width;
    final h = size.height;

    canvas.save();
    canvas.clipPath(framePath);

    // Base thick frame fill: Multi-stop stone & lazure gradient
    final baseGradient = Paint()
      ..shader = ui.Gradient.linear(
        Offset(w * 0.15, h * 0.05),
        Offset(w * 0.85, h * 0.95),
        _getFrameColors(quality, isSpecial, isGrayDay),
        const [0.0, 0.22, 0.50, 0.78, 1.0],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), baseGradient);

    // Structure A: Organic lazure washes (layered plant dye pools)
    _paintLazureWashes(canvas, size);

    // Structure B: 3D Volumetric bevels (luminous shelf & directional shading)
    _paint3DVolumetricBevels(canvas, size);

    // Structure C: Soft ambient frame darkening approaching inner arch
    final innerArchGlow = Paint()
      ..color = Colors.black.withValues(alpha: 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(innerPath, innerArchGlow);

    // Structure D: Mineral grain / watercolor paper tooth
    _paintMineralGrain(canvas, size);

    canvas.restore();
  }

  List<Color> _getFrameColors(PlantQuality q, bool special, bool gray) {
    if (gray) {
      return const [
        Color(0xFFE5E0D7),
        Color(0xFFC9C2B6),
        Color(0xFFA1998C),
        Color(0xFF736B5E),
        Color(0xFF453E35),
      ];
    }
    if (special) {
      return const [
        Color(0xFFFDE47A),
        Color(0xFFF4C442),
        Color(0xFFE2A818),
        Color(0xFFA86C06),
        Color(0xFF6A3E02),
      ];
    }
    switch (q) {
      case PlantQuality.leaf:
        return const [
          Color(0xFFB5E8A8),
          Color(0xFF7DC868),
          Color(0xFF4C9E38),
          Color(0xFF2E7525),
          Color(0xFF1D5422),
        ];
      case PlantQuality.root:
        return const [
          Color(0xFFF6BC9E),
          Color(0xFFE88A68),
          Color(0xFFD6562E),
          Color(0xFFA03818),
          Color(0xFF761F0D),
        ];
      case PlantQuality.flower:
        return const [
          Color(0xFFD6BEF5),
          Color(0xFFB48EE5),
          Color(0xFF905DD2),
          Color(0xFF6436A8),
          Color(0xFF421A76),
        ];
      case PlantQuality.fruit:
        return const [
          Color(0xFFFDCE6E),
          Color(0xFFF6A438),
          Color(0xFFE67810),
          Color(0xFFB04808),
          Color(0xFF821C04),
        ];
      case PlantQuality.none:
        return const [
          Color(0xFFD8D2C6),
          Color(0xFFB5ADA0),
          Color(0xFF968D7E),
          Color(0xFF5E564B),
          Color(0xFF3B352C),
        ];
    }
  }

  Color _getShelfHighlightColor(PlantQuality q, bool special, bool gray) {
    if (gray) return const Color(0xFFE2DDD3);
    if (special) return const Color(0xFFFFEA74);
    switch (q) {
      case PlantQuality.leaf:
        return const Color(0xFFC8F0BC);
      case PlantQuality.root:
        return const Color(0xFFFBD2C0);
      case PlantQuality.flower:
        return const Color(0xFFE6D6FA);
      case PlantQuality.fruit:
        return const Color(0xFFFEE29A);
      case PlantQuality.none:
        return const Color(0xFFE2DDD3);
    }
  }

  List<Color> _getInnerRecessColors(PlantQuality q, bool special, bool gray) {
    if (gray) {
      return const [Color(0xFF1B1A19), Color(0xFF121110), Color(0xFF0A0909)];
    }
    if (special) {
      return const [Color(0xFF221D12), Color(0xFF16130A), Color(0xFF0C0A05)];
    }
    switch (q) {
      case PlantQuality.leaf:
        return const [Color(0xFF161E15), Color(0xFF0E140D), Color(0xFF070A06)];
      case PlantQuality.root:
        return const [Color(0xFF221612), Color(0xFF160E0B), Color(0xFF0D0705)];
      case PlantQuality.flower:
        return const [Color(0xFF1C1624), Color(0xFF120D18), Color(0xFF0A060E)];
      case PlantQuality.fruit:
        return const [Color(0xFF221A0F), Color(0xFF151008), Color(0xFF0B0803)];
      case PlantQuality.none:
        return const [Color(0xFF1B1A19), Color(0xFF121110), Color(0xFF0A0909)];
    }
  }

  void _paintLazureWashes(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Organic pool 1: Warm sunlight sheen on upper-left lintel
    final wash1 = Paint()
      ..shader = ui.Gradient.radial(Offset(w * 0.28, h * 0.10), w * 0.42, [
        const Color(0x68FFFFFF),
        const Color(0x00FFFFFF),
      ]);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), wash1);

    // Organic pool 2: Translucent mineral glaze on left jamb
    final wash2 = Paint()
      ..shader = ui.Gradient.radial(Offset(w * 0.12, h * 0.45), w * 0.35, [
        elementColor.withValues(alpha: 0.35),
        Colors.transparent,
      ]);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), wash2);

    // Organic pool 3: Gentle sunlight catch along right jamb
    final wash3 = Paint()
      ..shader = ui.Gradient.radial(Offset(w * 0.88, h * 0.45), w * 0.30, [
        const Color(0x22FFFFFF),
        const Color(0x00FFFFFF),
      ]);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), wash3);
  }

  void _paint3DVolumetricBevels(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // A. 3D UPWARD-FACING LUMINOUS BOTTOM SILL SHELF:
    final shelfColor = _getShelfHighlightColor(quality, isSpecial, isGrayDay);
    final shelfPath = Path()
      ..moveTo(w * 0.15, h * 0.780)
      ..cubicTo(w * 0.24, h * 0.840, w * 0.34, h * 0.852, w * 0.50, h * 0.862)
      ..cubicTo(w * 0.66, h * 0.852, w * 0.76, h * 0.840, w * 0.85, h * 0.780)
      ..cubicTo(w * 0.90, h * 0.860, w * 0.78, h * 0.940, w * 0.50, h * 0.984)
      ..cubicTo(w * 0.22, h * 0.940, w * 0.10, h * 0.860, w * 0.15, h * 0.780)
      ..close();

    final shelfGradient = Paint()
      ..shader = ui.Gradient.linear(
        Offset(w * 0.5, h * 0.82),
        Offset(w * 0.5, h * 0.98),
        [
          shelfColor.withValues(alpha: 0.95),
          shelfColor.withValues(alpha: 0.60),
          _getFrameColors(
            quality,
            isSpecial,
            isGrayDay,
          )[2].withValues(alpha: 0.30),
          Colors.transparent,
        ],
        const [0.0, 0.45, 0.85, 1.0],
      );
    canvas.drawPath(shelfPath, shelfGradient);

    // B. SCULPTURAL CORNER FACET CREASES (soft-chiseled planes):
    final creaseLight = Paint()
      ..color = const Color(0x44FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

    final creaseShadow = Paint()
      ..color = const Color(0x28000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

    // Top-left corner facet
    canvas.drawLine(
      Offset(w * 0.12, h * 0.15),
      Offset(w * 0.22, h * 0.25),
      creaseLight,
    );

    // Top-right corner facet
    canvas.drawLine(
      Offset(w * 0.84, h * 0.078),
      Offset(w * 0.77, h * 0.230),
      creaseShadow,
    );

    // Bottom-right corner facet
    canvas.drawLine(
      Offset(w * 0.800, h * 0.90),
      Offset(w * 0.795, h * 0.760),
      creaseShadow,
    );

    // Bottom-left corner facet
    canvas.drawLine(
      Offset(w * 0.200, h * 0.90),
      Offset(w * 0.200, h * 0.760),
      creaseLight,
    );

    // C. Soft directional sunlight wash across entire frame
    final directionalShading = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(w, h),
        [
          const Color(0x22FFFFFF),
          const Color(0x00000000),
          const Color(0x18000000),
        ],
        const [0.0, 0.50, 1.0],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), directionalShading);
  }

  void _paintMineralGrain(Canvas canvas, Size size) {
    final dotPaintLight = Paint()..color = const Color(0x18FFFFFF);
    final dotPaintDark = Paint()..color = const Color(0x14000000);

    final w = size.width;
    final h = size.height;

    int seed = 1337;
    int nextRand() {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed;
    }

    for (int i = 0; i < 260; i++) {
      final rx = (nextRand() % 1000) / 1000.0 * w;
      final ry = (nextRand() % 1000) / 1000.0 * h;
      final r = 0.5 + ((nextRand() % 100) / 100.0) * 1.0;
      final isLight = (nextRand() % 2) == 0;

      canvas.drawCircle(
        Offset(rx, ry),
        r,
        isLight ? dotPaintLight : dotPaintDark,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SteinerFramePainter oldDelegate) {
    return oldDelegate.quality != quality ||
        oldDelegate.elementColor != elementColor ||
        oldDelegate.isSpecial != isSpecial ||
        oldDelegate.isGrayDay != isGrayDay ||
        oldDelegate.shader != shader ||
        oldDelegate.lighting != lighting ||
        (shader != null && oldDelegate.time != time);
  }
}
