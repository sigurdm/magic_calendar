import 'package:flutter/material.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:google_fonts/google_fonts.dart';

import 'src/ui/views/element_cards_gallery_page.dart';

/// Standalone entrypoint for rapidly previewing and hot-reloading all 4
/// Goethean watercolor element cards in an all-in-one grid.
void main() {
  enableFlutterDriverExtension();
  runApp(const ElementGalleryApp());
}

/// Standalone application host for [ElementCardsGalleryPage].
final class ElementGalleryApp extends StatelessWidget {
  /// Creates an [ElementGalleryApp].
  const ElementGalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Goethean Elements Gallery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
      ),
      home: const ElementCardsGalleryPage(),
    );
  }
}
