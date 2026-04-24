/// Dornach boundaries for the Maria Thun biodynamic calendar.
/// These are unequal constellation sizes.
///
/// Placeholder values for now.
class ConstellationBoundary {
  final String name;
  final double startDegree;
  final double endDegree;
  final String element;

  const ConstellationBoundary({
    required this.name,
    required this.startDegree,
    required this.endDegree,
    required this.element,
  });
}

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
    endDegree: 120.0,
    element: 'Air',
  ),
  ConstellationBoundary(
    name: 'Cancer',
    startDegree: 120.0,
    endDegree: 138.5,
    element: 'Water',
  ),
  ConstellationBoundary(
    name: 'Leo',
    startDegree: 138.5,
    endDegree: 172.5,
    element: 'Fire',
  ),
  ConstellationBoundary(
    name: 'Virgo',
    startDegree: 172.5,
    endDegree: 219.5,
    element: 'Earth',
  ),
  ConstellationBoundary(
    name: 'Libra',
    startDegree: 219.5,
    endDegree: 238.0,
    element: 'Air',
  ),
  ConstellationBoundary(
    name: 'Scorpio',
    startDegree: 238.0,
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
