import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Full help and reference screen explaining calendar usage, concepts, practical applications,
/// prioritization rules, biodynamic preparations, and historical context.
final class HelpScreen extends StatelessWidget {
  /// Creates an immutable [HelpScreen].
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      appBar: AppBar(
        title: Text(
          'Magic Calendar Guide & Practice',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF11111B),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              context,
              'How to Use the Calendar',
              Icons.touch_app,
            ),
            const SizedBox(height: 8),
            _buildCard(
              context,
              children: [
                _buildHelpItem(
                  'Timeline Scroll & Zoom',
                  'Drag horizontally across the timeline to browse past and future dates. Pinch or use the mouse wheel to zoom in (for hourly detail) or zoom out (for daily midday/midnight summaries).',
                ),
                _buildHelpItem(
                  'Center Selected Indicator',
                  'The vertical line in the center of the screen indicates your selected inspection hour. The top card instantly updates with detailed plant guidance, weather predictions, and sap flow vitality for that exact moment.',
                ),
                _buildHelpItem(
                  'NOW & Calendar Jump',
                  'Tap the "NOW" button at any time to immediately center back on current local time. Use the calendar icon in the header to jump directly to any date between 2000 and 2100.',
                ),
              ],
            ),
            const SizedBox(height: 24),

            _buildSectionHeader(
              context,
              'Plant Qualities & Practical Application',
              Icons.eco,
            ),
            const SizedBox(height: 8),
            _buildCard(
              context,
              children: [
                _buildQualityItem(
                  'Root (Earth)',
                  const Color(0xFF8D6E63),
                  'Triggered by Taurus, Virgo, and Capricorn. Focuses energy into roots and tubers.',
                  practical: 'Sow, plant, and cultivate carrots, potatoes, radishes, beets, onions, and celeriac. Deep hoeing and soil aeration on Root days encourages downward root penetration. Harvest root crops on Root days for long winter storage without rotting.',
                ),
                _buildQualityItem(
                  'Leaf (Water)',
                  const Color(0xFF66BB6A),
                  'Triggered by Cancer, Scorpio, and Pisces. Stimulates leafy biomass and sap flow.',
                  practical: 'Sow and transplant lettuce, spinach, cabbage, kale, swiss chard, and celery. Water lawns, crops, and houseplants on Leaf days as plants absorb water most efficiently. Avoid harvesting crops for long cellar storage on Leaf days, as high moisture content invites mold.',
                ),
                _buildQualityItem(
                  'Flower (Air / Light)',
                  const Color(0xFFAB47BC),
                  'Triggered by Gemini, Libra, and Aquarius. Enhances fragrance and inflorescence.',
                  practical: 'Sow and cultivate annual/perennial flowers, broccoli, cauliflower, and artichokes. Cut fresh flowers on Flower days for vibrant colors and longer vase life. Harvest medicinal herbs (chamomile, lavender) mid-morning on Flower days for peak essential oil potency.',
                ),
                _buildQualityItem(
                  'Fruit / Seed (Fire / Warmth)',
                  const Color(0xFFFFA726),
                  'Triggered by Aries, Leo, and Sagittarius. Concentrates natural sugars and seed vitality.',
                  practical: 'Sow and prick out tomatoes, peppers, squash, cucumbers, beans, peas, corn, and fruit trees. Prune fruit trees and vines to stimulate fruit buds. Harvest grains, berries, fruits, and seeds on Fruit days for maximum sweetness, aroma, and seed germination viability.',
                ),
              ],
            ),
            const SizedBox(height: 24),

            _buildSectionHeader(
              context,
              'Special Days & Sap Rhythms',
              Icons.stars,
            ),
            const SizedBox(height: 8),
            _buildCard(
              context,
              children: [
                _buildHelpItem(
                  'Special Days (Aspekt-günstig / Ag-)',
                  'Highlighted with a glowing gold border and star icon. Occur when major planets (Jupiter, Venus, Saturn) form harmonious 120° trines with the Moon in matching elemental constellations.',
                  badgeColor: const Color(0xFFFFD700),
                  practical: 'Treat as "Prime Execution Hours". Reserve delicate sowings, high-value grafting, taking cuttings, or harvesting medicinal herbs for these 4-to-12 hour windows for extra-strong plant vigor.',
                ),
                _buildHelpItem(
                  'Multi-Organ Crops & Dual Purposes',
                  'Many plants have multiple edible parts. Apply the calendar according to the specific organ you intend to harvest.',
                  practical: 'Grow celery for stalks on Leaf days, but celeriac for roots on Root days. Sow broccoli on Flower days for compact heads, but silage corn on Leaf days for foliage biomass.',
                ),
                _buildHelpItem(
                  'Sap Flow & Vitality Rhythms',
                  'Reflects lunar ascent/descent and waxing/waning cycles governing plant sap pressure.',
                  practical: 'Ascending/Waxing Moon: Sap rises into foliage (ideal for taking greenwood cuttings, grafting, and harvesting above-ground fruits). Descending/Waning Moon: Sap drops into roots and soil (ideal for transplanting seedlings as roots establish rapidly, root pruning, and spreading compost).',
                ),
              ],
            ),
            const SizedBox(height: 24),

            _buildSectionHeader(
              context,
              'Biodynamic Field Preparations',
              Icons.science_outlined,
            ),
            const SizedBox(height: 8),
            _buildCard(
              context,
              children: [
                _buildHelpItem(
                  'BD 500 (Horn Manure) & Soil Humus',
                  'Steiner foundation preparation for subterranean biological life, mycorrhizal fungal symbiosis, and deep root anchorage.',
                  practical: 'Stir 1 hour with alternating vortex/chaos rhythms. Spray in late afternoon / sunset during Descending Moon (Earth Inhalation) as large coarse droplets on moist soil.',
                ),
                _buildHelpItem(
                  'BD 501 (Horn Silica) & Light / Warmth Forces',
                  'Enhances chlorophyll photosynthetic capacity, starch-to-sugar conversion, and natural fungal resilience.',
                  practical: 'Stir 1 hour at daybreak. Spray at sunrise during Ascending Moon on Flower or Fruit days as an atomized fine mist floating into the foliage canopy.',
                ),
                _buildHelpItem(
                  'BD 508 (Equisetum Horsetail) Fungal Shield',
                  'Rich in organic bio-available silica. Natural fungicide preventing mildew, potato blight, rust, and damping-off.',
                  practical: 'Simmer dried horsetail for 20-30 minutes, steep 24 hours, dilute 1:5, dynamize 15-20 minutes, and spray on clear sunny mornings around Full Moon.',
                ),
              ],
            ),
            const SizedBox(height: 24),

            _buildSectionHeader(
              context,
              'Prioritization & Gray Day Consequences',
              Icons.warning_amber,
            ),
            const SizedBox(height: 8),
            _buildCard(
              context,
              children: [
                _buildHelpItem(
                  'Real-World Prioritization Hierarchy',
                  'Maria Thun stresses that weather conditions and soil moisture take physical precedence. Working wet soil on a "perfect" calendar day causes soil compaction damage. When timing is constrained, follow this hierarchy:',
                  practical: '1. Avoid Gray Days (Highest Rule): Moving work to ANY clear day is better than working on a Gray Day.\n2. Prioritize Sowing & Planting: Aligning initial seed contact or transplanting gives the strongest lifelong impulse.\n3. Leverage Moon Ascent/Descent: If you miss the exact constellation quality, align with Ascending/Descending moon rhythms.\n4. Secondary Cultivation: Hoeing, weeding, and harvesting can be caught up on subsequent matching days.',
                ),
                _buildHelpItem(
                  'Consequences of Working on a Gray Day',
                  'Gray Days mark Moon Node crossings and Moon Perigee, where gravitational and cosmic interference disrupts plant cell division and sap pressure.',
                  badgeColor: Colors.grey[400],
                  practical: '• Poor & Erratic Germination: Seeds sown on Gray Days show delayed, uneven, or failed sprouting.\n• Structural Weakness: Young plants tend to grow leggy, structurally weak stems and bolt prematurely.\n• Rot & Mold Vulnerability: Crops harvested or pruned during Gray Days retain erratic moisture, causing rapid storage decay and slow pruning wound healing.',
                ),
              ],
            ),
            const SizedBox(height: 24),

            _buildSectionHeader(
              context,
              'Historical Context & References',
              Icons.menu_book,
            ),
            const SizedBox(height: 8),
            _buildCard(
              context,
              children: [
                _buildHelpItem(
                  'Rudolf Steiner (1924)',
                  'Delivered the foundational eight-lecture "Agriculture Course" in Koberwitz, establishing biodynamic agriculture as a holistic farming system connecting soil biology with cosmic planetary rhythms.',
                ),
                _buildHelpItem(
                  'Maria & Matthias K. Thun (1950s–2010s)',
                  'Conducted over 60 years of continuous controlled field trials in Darmstadt, Germany. Maria Thun scientifically established that plant organs respond to the Moon\'s passage through real astronomical sidereal constellations rather than traditional astrological tropical signs, creating the annual Maria Thun Sædekalender (Sowing Calendar).',
                ),
                _buildHelpItem(
                  'Deterministic Ephemeris Calculations',
                  'This application uses high-precision Swiss Ephemeris calculations combined with Maria Thun\'s exact constellation boundaries to calculate plant qualities, aspect transfers, and unfavorable windows deterministically for any date past or future.',
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF646CFF), size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildCard(BuildContext context, {required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildHelpItem(
    String title,
    String description, {
    Color? badgeColor,
    String? practical,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (badgeColor != null) ...[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFE2E8F0),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: GoogleFonts.outfit(
              fontSize: 11.5,
              color: Colors.white70,
              height: 1.4,
            ),
          ),
          if (practical != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.build, size: 13, color: Color(0xFFFFD700)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'In Practice: $practical',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: const Color(0xFFFFD700),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQualityItem(
    String title,
    Color color,
    String description, {
    required String practical,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.build,
                        size: 13,
                        color: Color(0xFF818CF8),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'In Practice: $practical',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: const Color(0xFFC7D2FE),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
