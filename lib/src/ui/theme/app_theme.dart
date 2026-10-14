import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'goethean_palette.dart';

/// Builds the shared dark [ThemeData] used by both application entrypoints.
///
/// Grounded in the warm humus and parchment tones of [GoetheanPalette] with
/// classical Dornach display headers and clean modern body metrics.
ThemeData buildAppTheme() {
  final base = ThemeData.dark();
  return base.copyWith(
    scaffoldBackgroundColor: GoetheanPalette.compostDark,
    cardColor: GoetheanPalette.topsoilWarm,
    colorScheme: base.colorScheme.copyWith(
      primary: GoetheanPalette.aspectGold,
      secondary: GoetheanPalette.leafWater,
      surface: GoetheanPalette.topsoilWarm,
    ),
    textTheme: GoogleFonts.outfitTextTheme(base.textTheme).copyWith(
      headlineSmall: GoogleFonts.cinzel(
        color: const Color(0xFFF6ECD8),
        fontWeight: FontWeight.w700,
      ),
      titleLarge: GoogleFonts.cormorantGaramond(
        color: const Color(0xFFF6ECD8),
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
