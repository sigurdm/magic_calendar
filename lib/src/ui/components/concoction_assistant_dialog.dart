import "dart:ui";

import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

/// Unit system for dosage calculations.
enum UnitSystem {
  /// Metric units (square meters, hectares, grams, liters).
  metric,

  /// Imperial units (square feet, acres, ounces, gallons).
  imperial,
}

/// Biodynamic preparation recipe definition.
final class ConcoctionRecipe {
  /// Unique recipe identifier.
  final String id;

  /// Localized Danish title.
  final String titleDa;

  /// Localized English title.
  final String titleEn;

  /// Primary agricultural intention and target pests/diseases.
  final String purpose;

  /// Optimal cosmic timing and lunar rhythm application window.
  final String cosmicTiming;

  /// Base herb / preparation rate per 100 square meters.
  final double herbGramsPer100Sqm;

  /// Base water rate per 100 square meters.
  final double waterLitersPer100Sqm;

  /// Recommended dilution factor after brewing (1 = no dilution, 5 = 1:5, 10 = 1:10).
  final int dilutionRatio;

  /// Detailed preparation steps.
  final List<String> steps;

  /// Creates an immutable [ConcoctionRecipe].
  const ConcoctionRecipe({
    required this.id,
    required this.titleDa,
    required this.titleEn,
    required this.purpose,
    required this.cosmicTiming,
    required this.herbGramsPer100Sqm,
    required this.waterLitersPer100Sqm,
    required this.dilutionRatio,
    required this.steps,
  });

  /// Localized display title.
  String get displayName => "$titleDa ($titleEn)";
}

/// Catalog of classic biodynamic concoctions and spray preparations.
final class ConcoctionCatalog {
  ConcoctionCatalog._();

  /// Curated preparation recipes.
  static const List<ConcoctionRecipe> recipes = [
    ConcoctionRecipe(
      id: "bd508_horsetail",
      titleDa: "BD 508 Agerpadderok (Equisetum)",
      titleEn: "BD 508 Horsetail Decoction",
      purpose: "Natural organic fungicide against mildew, potato blight, rust, and damping-off.",
      cosmicTiming:
          "Apply on sunny mornings during Full Moon or Moon opposite Saturn.",
      herbGramsPer100Sqm: 20.0, // 20g dried per 100 sqm (or 100g per 500 sqm)
      waterLitersPer100Sqm: 2.0, // 2 L base decoction
      dilutionRatio: 5, // Dilute 1:5 with rainwater before spraying
      steps: [
        "1. Harvesting / Weighing: Use dried Equisetum arvense harvested in summer when silica content peaks.",
        "2. Simmering Decoction: Bring water to a boil and simmer gently covered for 20-30 minutes to release soluble silicic acid.",
        "3. Steeping Extraction: Remove from heat and allow to steep for 24 hours.",
        "4. Dynamization & Dilution: Strain liquid, dilute 1:5 with fresh rainwater, and stir vigorously for 15-20 minutes.",
        "5. Field Application: Spray as a fine mist over crop foliage and moist soil on a clear morning.",
      ],
    ),
    ConcoctionRecipe(
      id: "bd500_horn_manure",
      titleDa: "BD 500 Hornkogle / Hornjord",
      titleEn: "BD 500 Horn Manure",
      purpose:
          "Root depth stimulation, soil humus buildup, and microbial vitality.",
      cosmicTiming: "Apply late afternoon / sunset during Descending Moon (Earth Inhalation).",
      herbGramsPer100Sqm: 5.0, // ~50-60g per hectare, ~5g per 100 sqm garden
      waterLitersPer100Sqm: 3.5,
      dilutionRatio: 1, // Ready to spray directly after 1 hour stirring
      steps: [
        "1. Water Preparation: Warm clean rainwater to lukewarm (approx 35-37°C).",
        "2. 1-Hour Dynamization: Stir continuously for 60 minutes, alternating directions each minute to create deep vortex and chaotic crater collapse.",
        "3. Droplet Spraying: Apply within 1-2 hours of stirring using a coarse droplet spray onto bare or mulched soil.",
      ],
    ),
    ConcoctionRecipe(
      id: "cpp_barrel_compost",
      titleDa: "Maria Thun Tøndekompost (CPP)",
      titleEn: "Cow Pat Pit (Maria Thun Barrel Compost)",
      purpose:
          "Universal soil inoculant, humus builder, and microbial booster enriched with preparations BD 502–507, basalt, and eggshells.",
      cosmicTiming:
          "Apply late afternoon / sunset during Descending Moon (Earth Inhalation) on Root or Fruit days.",
      herbGramsPer100Sqm: 35.0, // 35g per 100 sqm
      waterLitersPer100Sqm: 5.0, // 5L lukewarm rainwater per 100 sqm
      dilutionRatio: 1, // Ready to spray directly after 20-min stirring
      steps: [
        "1. Weigh Barrel Compost: Dissolve 35g of mature Cow Pat Pit barrel compost per 100 m² of garden or field.",
        "2. Water Preparation: Warm clean rainwater to lukewarm (approx. 35°C) in a wooden or stoneware vessel.",
        "3. 20-Minute Dynamization: Stir vigorously for 20 minutes (16 cycles of 75 seconds), creating deep vortex funnels and breaking them into dynamic chaos.",
        "4. Coarse Droplet Spraying: Apply immediately within 1-2 hours using a hearth broom or coarse droplet sprayer onto bare soil, mulch, or fresh compost.",
      ],
    ),
    ConcoctionRecipe(
      id: "bd501_horn_silica",
      titleDa: "BD 501 Hornkisel (Kvartsmel)",
      titleEn: "BD 501 Horn Silica",
      purpose: "Enhances photosynthesis, fruit aroma, sugar content, and fungal resistance.",
      cosmicTiming:
          "Apply at sunrise on Ascending Moon during Flower or Fruit days.",
      herbGramsPer100Sqm: 0.1, // ~1-2g per hectare, tiny pinch per 100 sqm
      waterLitersPer100Sqm: 3.0,
      dilutionRatio: 1,
      steps: [
        "1. Precision Measurement: Add a small pinch of horn silica powder to lukewarm rainwater.",
        "2. 1-Hour Dynamization: Stir vigorously for 60 minutes at daybreak, creating alternating deep vortexes.",
        "3. Atomized Mist Spray: Spray as an ultrafine floating mist into the air directly above crop foliage.",
      ],
    ),
    ConcoctionRecipe(
      id: "nettle_ferment",
      titleDa: "Brændenælegødning (Urtica)",
      titleEn: "Fermented Stinging Nettle Tea",
      purpose: "Rich nitrogen & iron liquid fertilizer; activates leaf chlorophyll and strengthens immunity.",
      cosmicTiming:
          "Water on Leaf days (Water element) in the morning or early evening.",
      herbGramsPer100Sqm: 100.0, // Fresh nettles
      waterLitersPer100Sqm: 1.0,
      dilutionRatio: 10, // Dilute 1:10 for watering, 1:20 for foliar spray
      steps: [
        "1. Chop Fresh Nettles: Collect young nettle stems before flowering, pack in non-metallic bucket.",
        "2. Fermentation: Cover with rainwater, stir daily. Ferment outdoors for 10-14 days until bubbling ceases.",
        "3. Filtration: Strain out fermented sludge (add to compost pile).",
        "4. Dilution: Dilute 1:10 with water for soil watering, or 1:20 for leaf spray.",
      ],
    ),
    ConcoctionRecipe(
      id: "bd507_valerian",
      titleDa: "BD 507 Baldrian Varme-spray",
      titleEn: "BD 507 Valerian Warmth Spray",
      purpose: "Frost protection envelope and blossom setting impulse.",
      cosmicTiming: "Apply in the evening before forecasted late spring frost or cold snaps.",
      herbGramsPer100Sqm: 0.05, // 5-10 drops
      waterLitersPer100Sqm: 2.5,
      dilutionRatio: 1,
      steps: [
        "1. Extract Addition: Add 5-10 drops of fermented valerian extract into warm rainwater.",
        "2. Stirring: Stir gently for 10-15 minutes.",
        "3. Protective Mist: Spray delicate blossoms and orchard trees in late afternoon before frost.",
      ],
    ),
  ];
}

/// Interactive modal assistant providing recipe details, step-by-step brewing guidance,
/// and automated Metric / Imperial dosage calculations for biodynamic concoctions.
final class ConcoctionAssistantDialog extends StatefulWidget {
  /// Initial recipe ID to display.
  final String? initialRecipeId;

  /// Creates an immutable [ConcoctionAssistantDialog].
  const ConcoctionAssistantDialog({super.key, this.initialRecipeId});

  /// Shows the concoction assistant modal dialog.
  static Future<void> show(BuildContext context, {String? initialRecipeId}) {
    return showDialog<void>(
      context: context,
      builder: (context) =>
          ConcoctionAssistantDialog(initialRecipeId: initialRecipeId),
    );
  }

  @override
  State<ConcoctionAssistantDialog> createState() =>
      _ConcoctionAssistantDialogState();
}

final class _ConcoctionAssistantDialogState
    extends State<ConcoctionAssistantDialog> {
  late ConcoctionRecipe _selectedRecipe;
  UnitSystem _unitSystem = UnitSystem.metric;
  double _areaValue = 100.0; // 100 sqm or 1000 sq ft

  final TextEditingController _areaController = TextEditingController(
    text: "100",
  );

  @override
  void initState() {
    super.initState();
    _selectedRecipe = ConcoctionCatalog.recipes.firstWhere(
      (r) => r.id == widget.initialRecipeId,
      orElse: () => ConcoctionCatalog.recipes.first,
    );
  }

  @override
  void dispose() {
    _areaController.dispose();
    super.dispose();
  }

  void _onAreaChanged(String text) {
    final parsed = double.tryParse(text);
    if (parsed != null && parsed > 0) {
      setState(() {
        _areaValue = parsed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Metric: _areaValue in m2
    // Imperial: _areaValue in sq ft (1 m2 = 10.7639 sq ft)
    final areaInSqm = _unitSystem == UnitSystem.metric
        ? _areaValue
        : _areaValue / 10.7639;

    final baseHerbGrams =
        (_selectedRecipe.herbGramsPer100Sqm / 100.0) * areaInSqm;
    final baseWaterLiters =
        (_selectedRecipe.waterLitersPer100Sqm / 100.0) * areaInSqm;
    final totalDilutedLiters = baseWaterLiters * _selectedRecipe.dilutionRatio;

    // Imperial conversions: 1 g = 0.035274 oz, 1 L = 0.264172 gal
    final herbDisplay = _unitSystem == UnitSystem.metric
        ? (baseHerbGrams >= 1000
              ? "${(baseHerbGrams / 1000).toStringAsFixed(2)} kg"
              : "${baseHerbGrams.toStringAsFixed(1)} g")
        : (baseHerbGrams * 0.035274 >= 16
              ? "${((baseHerbGrams * 0.035274) / 16).toStringAsFixed(2)} lbs"
              : "${(baseHerbGrams * 0.035274).toStringAsFixed(1)} oz");

    final waterDisplay = _unitSystem == UnitSystem.metric
        ? "${baseWaterLiters.toStringAsFixed(1)} L"
        : "${(baseWaterLiters * 0.264172).toStringAsFixed(1)} gal";

    final totalDisplay = _unitSystem == UnitSystem.metric
        ? "${totalDilutedLiters.toStringAsFixed(1)} L"
        : "${(totalDilutedLiters * 0.264172).toStringAsFixed(1)} gal";

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 540),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.science_outlined,
                              color: Color(0xFF34D399),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Concoction Assistant",
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                "Biodynamic Brews & Field Sprays",
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        child: IconButton(
                          key: const ValueKey('close_concoction_dialog'),
                          tooltip: 'Close',
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Recipe Picker Tabs
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ConcoctionCatalog.recipes
                          .map((r) {
                            final isSelected = r.id == _selectedRecipe.id;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 48,
                                ),
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedRecipe = r;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF10B981)
                                                .withValues(alpha: 0.3)
                                          : Colors.white.withValues(
                                              alpha: 0.05,
                                            ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF10B981)
                                            : Colors.white.withValues(
                                                alpha: 0.1,
                                              ),
                                      ),
                                    ),
                                    child: Text(
                                      r.titleEn,
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.white70,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          })
                          .toList(growable: false),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Recipe Overview Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedRecipe.titleEn,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF34D399),
                          ),
                        ),
                        Text(
                          _selectedRecipe.titleDa,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.white54,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _selectedRecipe.purpose,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(
                              Icons.nightlight_round,
                              size: 14,
                              color: Color(0xFFF59E0B),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _selectedRecipe.cosmicTiming,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: const Color(0xFFFBBF24),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Dosage Calculator Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Dosage Calculator",
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      // Metric / Imperial Toggle
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            _buildUnitButton("Metric", UnitSystem.metric),
                            _buildUnitButton("Imperial", UnitSystem.imperial),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Garden Area Input
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _areaController,
                          keyboardType: TextInputType.number,
                          onChanged: _onAreaChanged,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            labelText: _unitSystem == UnitSystem.metric
                                ? "Garden Area (m²)"
                                : "Garden Area (sq ft)",
                            labelStyle: GoogleFonts.outfit(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.05),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Preset Quick Buttons
                      _buildPresetAreaButton("100"),
                      const SizedBox(width: 6),
                      _buildPresetAreaButton("500"),
                      const SizedBox(width: 6),
                      _buildPresetAreaButton("1000"),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Calculated Dosage Result Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildDosageCard(
                          icon: Icons.grass,
                          label: "Herb / Prep",
                          value: herbDisplay,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildDosageCard(
                          icon: Icons.water_drop,
                          label: "Brew Water",
                          value: waterDisplay,
                          color: const Color(0xFF60A5FA),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildDosageCard(
                          icon: Icons.shower,
                          label: "Spray Volume",
                          value: totalDisplay,
                          color: const Color(0xFF8B5CF6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Step-by-Step Instructions
                  Text(
                    "Step-by-Step Brewing & Application",
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._selectedRecipe.steps.map((step) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 3),
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF34D399),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              step,
                              style: GoogleFonts.outfit(
                                fontSize: 12.5,
                                color: Colors.white.withValues(alpha: 0.85),
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),

                  // Close button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981)
                            .withValues(alpha: 0.3),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFF10B981)),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        "Done",
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetAreaButton(String val) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white70,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: () {
          _areaController.text = val;
          _onAreaChanged(val);
        },
        child: Text(val, style: GoogleFonts.outfit(fontSize: 12)),
      ),
    );
  }

  Widget _buildUnitButton(String title, UnitSystem system) {
    final isSelected = _unitSystem == system;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
      child: InkWell(
        onTap: () {
          setState(() {
            _unitSystem = system;
            _areaController.text = system == UnitSystem.metric ? "100" : "1000";
            _onAreaChanged(_areaController.text);
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF646CFF) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDosageCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
