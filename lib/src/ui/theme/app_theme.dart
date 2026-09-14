import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Builds the shared dark [ThemeData] used by both application entrypoints.
///
/// Previously duplicated verbatim in `lib/main.dart` and `lib/gallery_main.dart`,
/// which meant the gallery preview could silently drift from the real app.
ThemeData buildAppTheme() {
  final base = ThemeData.dark();
  return base.copyWith(
    scaffoldBackgroundColor: const Color(0xFF121212),
    textTheme: GoogleFonts.outfitTextTheme(base.textTheme),
  );
}
