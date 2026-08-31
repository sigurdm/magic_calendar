import 'package:flutter/material.dart';

import '../../core/models/plant_quality.dart';

/// Goethean Nature Palette based on Rudolf Steiner and Johann Wolfgang von Goethe's
/// colour theory (*Zur Farbenlehre*).
///
/// Replaces artificial digital neon values with warm, living nature tones
/// reflecting the four biodynamic plant organs and living compost soil.
abstract final class GoetheanPalette {
  /// Earth / Root organ: Warm Terracotta & Burnt Sienna (#C86D51).
  static const Color rootEarth = Color(0xFFC86D51);

  /// Water / Leaf organ: Living Sap Green (#5B8A4E).
  static const Color leafWater = Color(0xFF5B8A4E);

  /// Air-Light / Flower organ: Radiant Morning Lavender (#A594C4).
  static const Color flowerAir = Color(0xFFA594C4);

  /// Warmth-Fire / Fruit organ: Sun Gold & Ochre (#E5A93C).
  static const Color fruitWarmth = Color(0xFFE5A93C);

  /// Deep organic compost dark background (#191715).
  static const Color compostDark = Color(0xFF191715);

  /// Warm topsoil / humus secondary background (#221F1B).
  static const Color topsoilWarm = Color(0xFF221F1B);

  /// Organic neutral compost gray for rest and node blackout windows (#8C857B).
  static const Color neutralRest = Color(0xFF8C857B);

  /// Favorable star gold for special aspect trines (#E6BA55).
  static const Color aspectGold = Color(0xFFE6BA55);

  /// Returns the corresponding Goethean nature color for [quality].
  static Color getColor(PlantQuality quality) {
    switch (quality) {
      case PlantQuality.root:
        return rootEarth;
      case PlantQuality.leaf:
        return leafWater;
      case PlantQuality.flower:
        return flowerAir;
      case PlantQuality.fruit:
        return fruitWarmth;
      case PlantQuality.none:
        return neutralRest;
    }
  }

  /// Returns the organ name with its Goethean elemental harmony.
  static String getHarmoniousName(PlantQuality quality) {
    switch (quality) {
      case PlantQuality.root:
        return 'Root (Earth / Warm Terracotta)';
      case PlantQuality.leaf:
        return 'Leaf (Water / Sap Green)';
      case PlantQuality.flower:
        return 'Flower (Air / Radiant Lavender)';
      case PlantQuality.fruit:
        return 'Fruit (Warmth / Sun Gold)';
      case PlantQuality.none:
        return 'Cosmic Rest (Compost Gray)';
    }
  }
}
