/// Representation of constellation boundaries for biodynamic calendar calculations.
final class ConstellationBoundary {
  /// Name of constellation.
  final String name;

  /// Starting ecliptic degree.
  final double startDegree;

  /// Ending ecliptic degree.
  final double endDegree;

  /// Associated element ('Earth', 'Water', 'Air', 'Fire').
  final String element;

  /// Creates a [ConstellationBoundary].
  const ConstellationBoundary({
    required this.name,
    required this.startDegree,
    required this.endDegree,
    required this.element,
  });
}

/// Dornach constellation boundaries.
const List<ConstellationBoundary> dornachBoundaries = [
  ConstellationBoundary(
    name: 'Aries',
    startDegree: 25.0,
    endDegree: 55.0,
    element: 'Fire',
  ),
  ConstellationBoundary(
    name: 'Taurus',
    startDegree: 55.0,
    endDegree: 90.0,
    element: 'Earth',
  ),
  ConstellationBoundary(
    name: 'Gemini',
    startDegree: 90.0,
    endDegree: 110.0,
    element: 'Air',
  ),
  ConstellationBoundary(
    name: 'Cancer',
    startDegree: 110.0,
    endDegree: 138.0,
    element: 'Water',
  ),
  ConstellationBoundary(
    name: 'Leo',
    startDegree: 138.0,
    endDegree: 183.0,
    element: 'Fire',
  ),
  ConstellationBoundary(
    name: 'Virgo',
    startDegree: 183.0,
    endDegree: 228.0,
    element: 'Earth',
  ),
  ConstellationBoundary(
    name: 'Libra',
    startDegree: 228.0,
    endDegree: 243.0,
    element: 'Air',
  ),
  ConstellationBoundary(
    name: 'Scorpio',
    startDegree: 243.0,
    endDegree: 270.0,
    element: 'Water',
  ),
  ConstellationBoundary(
    name: 'Sagittarius',
    startDegree: 270.0,
    endDegree: 303.0,
    element: 'Fire',
  ),
  ConstellationBoundary(
    name: 'Capricorn',
    startDegree: 303.0,
    endDegree: 331.0,
    element: 'Earth',
  ),
  ConstellationBoundary(
    name: 'Aquarius',
    startDegree: 331.0,
    endDegree: 360.0,
    element: 'Air',
  ),
  ConstellationBoundary(
    name: 'Pisces',
    startDegree: 0.0,
    endDegree: 25.0,
    element: 'Water',
  ),
];

/// Custom calendar constellation boundaries.
const List<ConstellationBoundary> customCalendarBoundaries = [
  ConstellationBoundary(
    name: 'Aries',
    startDegree: 25.0,
    endDegree: 55.0,
    element: 'Fire',
  ),
  ConstellationBoundary(
    name: 'Taurus',
    startDegree: 55.0,
    endDegree: 90.0,
    element: 'Earth',
  ),
  ConstellationBoundary(
    name: 'Gemini',
    startDegree: 90.0,
    endDegree: 118.0,
    element: 'Air',
  ),
  ConstellationBoundary(
    name: 'Cancer',
    startDegree: 118.0,
    endDegree: 139.4,
    element: 'Water',
  ),
  ConstellationBoundary(
    name: 'Leo',
    startDegree: 139.4,
    endDegree: 174.4,
    element: 'Fire',
  ),
  ConstellationBoundary(
    name: 'Virgo',
    startDegree: 174.4,
    endDegree: 208.0,
    element: 'Earth',
  ),
  ConstellationBoundary(
    name: 'Libra',
    startDegree: 208.0,
    endDegree: 229.0,
    element: 'Air',
  ),
  ConstellationBoundary(
    name: 'Scorpio',
    startDegree: 229.0,
    endDegree: 257.1,
    element: 'Water',
  ),
  ConstellationBoundary(
    name: 'Sagittarius',
    startDegree: 257.1,
    endDegree: 299.0,
    element: 'Fire',
  ),
  ConstellationBoundary(
    name: 'Capricorn',
    startDegree: 299.0,
    endDegree: 327.0,
    element: 'Earth',
  ),
  ConstellationBoundary(
    name: 'Aquarius',
    startDegree: 327.0,
    endDegree: 360.0,
    element: 'Air',
  ),
  ConstellationBoundary(
    name: 'Pisces',
    startDegree: 0.0,
    endDegree: 25.0,
    element: 'Water',
  ),
];
