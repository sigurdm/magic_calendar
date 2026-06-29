import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Full help and reference screen explaining calendar usage, concepts, and history.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      appBar: AppBar(
        title: Text(
          'Magic Calendar Guide & Reference',
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
            _buildSectionHeader(context, 'How to Use the Calendar', Icons.touch_app),
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

            _buildSectionHeader(context, 'Core Concepts & Plant Qualities', Icons.eco),
            const SizedBox(height: 8),
            _buildCard(
              context,
              children: [
                _buildQualityItem(
                  'Root (Earth)',
                  const Color(0xFF8D6E63),
                  'Triggered by Taurus, Virgo, and Capricorn. Focuses energy into roots and tubers. Ideal for carrots, potatoes, radishes, beets, and soil preparation.',
                ),
                _buildQualityItem(
                  'Leaf (Water)',
                  const Color(0xFF66BB6A),
                  'Triggered by Cancer, Scorpio, and Pisces. Stimulates leafy biomass and sap flow. Ideal for lettuce, spinach, cabbage, leafy herbs, and lawn watering.',
                ),
                _buildQualityItem(
                  'Flower (Air / Light)',
                  const Color(0xFFAB47BC),
                  'Triggered by Gemini, Libra, and Aquarius. Enhances fragrance and inflorescence. Ideal for flowers, broccoli, medicinal herbs, and essential oil harvesting.',
                ),
                _buildQualityItem(
                  'Fruit / Seed (Fire / Warmth)',
                  const Color(0xFFFFA726),
                  'Triggered by Aries, Leo, and Sagittarius. Concentrates sugars and seed vitality. Ideal for tomatoes, peppers, squash, grains, and fruit trees.',
                ),
              ],
            ),
            const SizedBox(height: 24),

            _buildSectionHeader(context, 'Special & Gray Days', Icons.stars),
            const SizedBox(height: 8),
            _buildCard(
              context,
              children: [
                _buildHelpItem(
                  'Special Days (Aspekt-gunstig / Ag-)',
                  'Highlighted with a glowing gold border and star icon. Occur when major planets (such as Jupiter, Venus, or Saturn) form harmonious 120° trine aspects with the Moon while transiting matching elemental constellations. These brief windows transfer extra-concentrated cosmic energy to the corresponding plant organ.',
                  badgeColor: const Color(0xFFFFD700),
                ),
                _buildHelpItem(
                  'Gray Days (Unfavorable Windows)',
                  'Marked with a gray hatched background and warning symbol. Occur during Moon Node crossings (when the Moon crosses the ecliptic plane) and Moon Perigee (when the Moon is closest to Earth). Gravitational and cosmic interference during these hours causes erratic germination, rot, and weak growth. Avoid sowing or grafting during Gray Days.',
                  badgeColor: Colors.grey[400],
                ),
                _buildHelpItem(
                  'Sap Flow & Vitality Rhythms',
                  'Reflects lunar ascent/descent and waxing/waning cycles. Ascending/Waxing moon pulls sap into upper stems and foliage (best for grafting and harvesting above-ground crops). Descending/Waning moon directs sap downward into root systems and soil (best for transplanting and root cultivation).',
                ),
              ],
            ),
            const SizedBox(height: 24),

            _buildSectionHeader(context, 'Historical Context & References', Icons.menu_book),
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

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildHelpItem(String title, String description, {Color? badgeColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
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
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white70,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityItem(String title, Color color, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
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
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                    height: 1.4,
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
