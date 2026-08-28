/// Represents lunar phase calculations.
final class MoonPhaseInfo {
  /// Fraction illuminated (0.0 to 1.0).
  final double illuminatedFraction;

  /// True if waxing, false if waning.
  final bool isWaxing;

  /// Phase angle in degrees.
  final double phaseAngle;

  /// Creates [MoonPhaseInfo].
  const MoonPhaseInfo({
    required this.illuminatedFraction,
    required this.isWaxing,
    required this.phaseAngle,
  });

  /// Name of moon phase.
  String get name {
    if (illuminatedFraction > 0.97) {
      return 'Full Moon';
    }
    if (illuminatedFraction < 0.03) {
      return 'New Moon';
    }
    if (illuminatedFraction >= 0.48 && illuminatedFraction <= 0.52) {
      return isWaxing ? 'First Quarter' : 'Last Quarter';
    }
    if (isWaxing) {
      return illuminatedFraction < 0.5 ? 'Waxing Crescent' : 'Waxing Gibbous';
    } else {
      return illuminatedFraction > 0.5 ? 'Waning Gibbous' : 'Waning Crescent';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MoonPhaseInfo &&
          runtimeType == other.runtimeType &&
          illuminatedFraction == other.illuminatedFraction &&
          isWaxing == other.isWaxing &&
          phaseAngle == other.phaseAngle;

  @override
  int get hashCode => Object.hash(illuminatedFraction, isWaxing, phaseAngle);
}
