import 'package:flutter/material.dart';

import 'src/ui/theme/app_theme.dart';
import 'src/ui/views/element_cards_gallery_page.dart';

/// Standalone entrypoint for rapidly previewing and hot-reloading all 4
/// Goethean watercolor element cards in an all-in-one grid.
void main() {
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
      theme: buildAppTheme(),
      home: const ElementCardsGalleryPage(),
    );
  }
}
