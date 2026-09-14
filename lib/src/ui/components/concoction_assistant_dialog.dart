import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/concoction_recipe.dart';
import '../theme/biodynamic_icons.dart';

export '../../core/models/concoction_recipe.dart';

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
    text: '100',
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
    final dosage = _selectedRecipe.calculateDosage(_areaValue, _unitSystem);
    final herbDisplay = dosage.herbDisplay;
    final waterDisplay = dosage.waterDisplay;
    final totalDisplay = dosage.totalDilutedDisplay;

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
                            child: const BiodynamicIcon(
                              type: BiodynamicIconType.herbalCauldron,
                              color: Color(0xFF34D399),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Concoction Assistant',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Biodynamic Brews & Field Sprays',
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
                        'Dosage Calculator',
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
                            _buildUnitButton('Metric', UnitSystem.metric),
                            _buildUnitButton('Imperial', UnitSystem.imperial),
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
                                ? 'Garden Area (m²)'
                                : 'Garden Area (sq ft)',
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
                      _buildPresetAreaButton('100'),
                      const SizedBox(width: 6),
                      _buildPresetAreaButton('500'),
                      const SizedBox(width: 6),
                      _buildPresetAreaButton('1000'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Calculated Dosage Result Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildDosageCard(
                          icon: Icons.grass,
                          label: 'Herb / Prep',
                          value: herbDisplay,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildDosageCard(
                          icon: Icons.water_drop,
                          label: 'Brew Water',
                          value: waterDisplay,
                          color: const Color(0xFF60A5FA),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildDosageCard(
                          icon: Icons.shower,
                          label: 'Spray Volume',
                          value: totalDisplay,
                          color: const Color(0xFF8B5CF6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Step-by-Step Instructions
                  Text(
                    'Step-by-Step Brewing & Application',
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
                        'Done',
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
            _areaController.text = system == UnitSystem.metric ? '100' : '1000';
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
