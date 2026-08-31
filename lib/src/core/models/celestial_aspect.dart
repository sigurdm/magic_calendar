/// Types of celestial planetary aspects in biodynamic astronomy.
enum AspectType {
  conjunction(0.0),
  square(90.0),
  trine(120.0),
  opposition(180.0);

  /// Nominal separation in degrees for this aspect type.
  final double angleDegrees;

  const AspectType(this.angleDegrees);
}

/// Represents an angular aspect between two celestial bodies.
final class PlanetaryAspect {
  /// First celestial body name (e.g. 'Moon', 'Sun', 'Saturn').
  final String body1;

  /// Second celestial body name (e.g. 'Jupiter', 'Mars').
  final String body2;

  /// The type of angular aspect.
  final AspectType type;

  /// Exact angular separation in degrees (0..180).
  final double separationDegrees;

  /// Deviation from exact aspect angle in degrees.
  final double orbDegrees;

  /// True if the aspect promotes harmonious agricultural forces; false if stress/pause.
  final bool isFavorable;

  /// Biodynamic agricultural interpretation of the aspect.
  final String agriculturalEffect;

  /// Creates a [PlanetaryAspect].
  const PlanetaryAspect({
    required this.body1,
    required this.body2,
    required this.type,
    required this.separationDegrees,
    required this.orbDegrees,
    required this.isFavorable,
    required this.agriculturalEffect,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlanetaryAspect &&
          runtimeType == other.runtimeType &&
          body1 == other.body1 &&
          body2 == other.body2 &&
          type == other.type &&
          (separationDegrees - other.separationDegrees).abs() < 1e-6 &&
          (orbDegrees - other.orbDegrees).abs() < 1e-6 &&
          isFavorable == other.isFavorable &&
          agriculturalEffect == other.agriculturalEffect;

  @override
  int get hashCode => Object.hash(
        body1,
        body2,
        type,
        separationDegrees,
        orbDegrees,
        isFavorable,
        agriculturalEffect,
      );

  @override
  String toString() =>
      'PlanetaryAspect($body1-$body2 $type, separation: ${separationDegrees.toStringAsFixed(1)}°, orb: ${orbDegrees.toStringAsFixed(1)}°, favorable: $isFavorable)';
}
