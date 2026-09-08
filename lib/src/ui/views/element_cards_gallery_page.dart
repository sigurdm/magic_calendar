import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/models.dart';
import '../components/plant_quality_card.dart';

/// Display mode for the watercolor gallery page.
enum GalleryDisplayMode {
  /// Displays the four distinct watercolor texture styles side-by-side on a single element.
  textureComparison,

  /// Displays all four element cards (Earth, Water, Air, Fire) with a chosen texture style.
  elementsGrid,
}

/// Interactive laboratory screen displaying [PlantQualityCard] variants and
/// watercolor texture styles simultaneously.
///
/// Designed for rapid visual comparison of watercolor pigments, lighting, and
/// textural dynamics (Lazure, Granulating, Blooms, Rough Rag) via Flutter hot reload.
final class ElementCardsGalleryPage extends StatefulWidget {
  /// Callback when user wants to return to the main calendar page.
  final VoidCallback? onBackToApp;

  /// Creates an [ElementCardsGalleryPage].
  const ElementCardsGalleryPage({super.key, this.onBackToApp});

  @override
  State<ElementCardsGalleryPage> createState() =>
      _ElementCardsGalleryPageState();
}

final class _ElementCardsGalleryPageState
    extends State<ElementCardsGalleryPage> {
  GalleryDisplayMode _mode = GalleryDisplayMode.textureComparison;
  PlantQuality _comparisonElement = PlantQuality.root;
  WatercolorTextureStyle _activeTextureStyle = WatercolorTextureStyle.lazure;
  bool _animate = true;

  CalendarInfo _buildInfo({
    required PlantQuality quality,
    required String message,
  }) {
    return CalendarInfo(
      quality: quality,
      isSpecial: false,
      isGrayDay: false,
      message: message,
      sapFlow: 'Rising',
      vitality: 'Optimal',
      moonPhase: MoonPhaseInfo(
        phaseAngle: 0.5,
        illuminatedFraction: 0.5,
        isWaxing: true,
      ),
      planets: [],
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    final elementCards = [
      ('EARTH', _buildInfo(quality: PlantQuality.root, message: '')),
      ('WATER', _buildInfo(quality: PlantQuality.leaf, message: '')),
      ('AIR', _buildInfo(quality: PlantQuality.flower, message: '')),
      ('FIRE', _buildInfo(quality: PlantQuality.fruit, message: '')),
    ];

    final textureVariants = [
      (
        WatercolorTextureStyle.lazure,
        'Lazure (Atmospheric Veils)',
        'Ethereal, feather-soft, translucent washes',
      ),
      (
        WatercolorTextureStyle.granulating,
        'Granulating (Mineral Tooth)',
        'Tactile pigment sedimentation in paper tooth',
      ),
      (
        WatercolorTextureStyle.blooms,
        'Blooms (Wet-in-Wet Cauliflowers)',
        'Capillary drying rings & backrun watermarks',
      ),
      (
        WatercolorTextureStyle.roughRag,
        'Rough Rag (Dry-Brush Scumble)',
        'Heavy mould-made paper & skipping crest reserves',
      ),
    ];

    String elementMessage(PlantQuality q) => '';

    return Scaffold(
      backgroundColor: const Color(0xFF14141E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1B2A),
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(
          'Watercolor Texture Laboratory',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            tooltip: _animate ? 'Pause Animation' : 'Resume Animation',
            icon: Icon(
              _animate ? Icons.pause_circle_outline : Icons.play_circle_outline,
              color: Colors.white70,
            ),
            onPressed: () => setState(() => _animate = !_animate),
          ),
          if (widget.onBackToApp != null)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: TextButton.icon(
                onPressed: widget.onBackToApp,
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white70,
                  size: 18,
                ),
                label: Text(
                  'Back to App',
                  style: GoogleFonts.outfit(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Control Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF1B1B2A),
              border: Border(
                bottom: BorderSide(color: Colors.white12, width: 1),
              ),
            ),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                // Mode Toggle
                SegmentedButton<GalleryDisplayMode>(
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: const [
                    ButtonSegment(
                      value: GalleryDisplayMode.textureComparison,
                      icon: Icon(Icons.texture, size: 16),
                      label: Text('Compare 4 Textures'),
                    ),
                    ButtonSegment(
                      value: GalleryDisplayMode.elementsGrid,
                      icon: Icon(Icons.grid_view, size: 16),
                      label: Text('All 4 Elements'),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (newSelection) {
                    setState(() => _mode = newSelection.first);
                  },
                ),

                // Contextual Filter Chips
                if (_mode == GalleryDisplayMode.textureComparison)
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Element: ',
                        style: GoogleFonts.outfit(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      for (final quality in [
                        PlantQuality.root,
                        PlantQuality.leaf,
                        PlantQuality.flower,
                        PlantQuality.fruit,
                      ])
                        ChoiceChip(
                          visualDensity: VisualDensity.compact,
                          label: Text(
                            quality.name.toUpperCase(),
                            style: GoogleFonts.outfit(fontSize: 11),
                          ),
                          selected: _comparisonElement == quality,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _comparisonElement = quality);
                            }
                          },
                        ),
                    ],
                  )
                else
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Texture Style: ',
                        style: GoogleFonts.outfit(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      for (final style in WatercolorTextureStyle.values)
                        ChoiceChip(
                          visualDensity: VisualDensity.compact,
                          label: Text(
                            style.name.toUpperCase(),
                            style: GoogleFonts.outfit(fontSize: 11),
                          ),
                          selected: _activeTextureStyle == style,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _activeTextureStyle = style);
                            }
                          },
                        ),
                    ],
                  ),
              ],
            ),
          ),

          // Main Viewport
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const padV = 12.0;
                const padH = 16.0;
                const gap = 16.0;

                final availH = constraints.maxHeight - padV * 2;
                final availW = constraints.maxWidth - padH * 2;
                final isComparing =
                    _mode == GalleryDisplayMode.textureComparison;

                // Subtract height for badge caption if in texture comparison mode
                final captionHeight = isComparing ? 40.0 : 0.0;
                final rawHeight = (((availH - gap) / 2) - captionHeight).clamp(
                  200.0,
                  350.0,
                );
                final maxCardW = ((availW - gap) / 2).clamp(160.0, 360.0);
                final targetCardWidth = math.min(rawHeight / 1.05, maxCardW);
                final targetCardHeight = targetCardWidth * 1.05;

                final infoForElement = _buildInfo(
                  quality: _comparisonElement,
                  message: elementMessage(_comparisonElement),
                );

                Widget buildCardItem(int index) {
                  final Widget card;
                  String title;
                  String subtitle;

                  if (isComparing) {
                    final variant = textureVariants[index];
                    card = PlantQualityCard(
                      info: infoForElement,
                      selectedTime: now,
                      animate: _animate,
                      textureStyle: variant.$1,
                    );
                    title = variant.$2;
                    subtitle = variant.$3;
                  } else {
                    final item = elementCards[index];
                    card = PlantQualityCard(
                      info: item.$2,
                      selectedTime: now,
                      animate: _animate,
                      textureStyle: _activeTextureStyle,
                    );
                    title = item.$1;
                    subtitle = item.$2.message;
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: targetCardWidth,
                        height: targetCardHeight,
                        child: card,
                      ),
                      if (isComparing) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                subtitle,
                                style: GoogleFonts.outfit(
                                  color: Colors.white60,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: padH,
                    vertical: padV,
                  ),
                  child: Center(
                    child: SizedBox(
                      width: targetCardWidth * 2 + gap,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              buildCardItem(0),
                              const SizedBox(width: gap),
                              buildCardItem(1),
                            ],
                          ),
                          const SizedBox(height: gap),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              buildCardItem(2),
                              const SizedBox(width: gap),
                              buildCardItem(3),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
