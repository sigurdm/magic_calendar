import "../dornach_boundaries.dart";
import "plant_quality.dart";

/// Model representing a cusp transition envelope between two constellation qualities.
final class TransitionEnvelope {
  /// Whether the Moon's longitude falls within a transition window (~0.75° of boundary).
  final bool isTransition;

  /// The quality of the preceding or departing constellation.
  final PlantQuality fromQuality;

  /// The quality of the succeeding or arriving constellation.
  final PlantQuality toQuality;

  /// Progress through the transition envelope from 0.0 (entry) to 1.0 (exit).
  final double progress;

  /// Human-readable description of the transition state.
  final String description;

  /// Absolute distance in degrees from the nearest boundary.
  final double distanceToBoundary;

  /// Creates a [TransitionEnvelope].
  const TransitionEnvelope({
    required this.isTransition,
    required this.fromQuality,
    required this.toQuality,
    required this.progress,
    required this.description,
    this.distanceToBoundary = 0.0,
  });

  /// Static constant when no transition envelope is active.
  static const none = TransitionEnvelope(
    isTransition: false,
    fromQuality: PlantQuality.none,
    toQuality: PlantQuality.none,
    progress: 0.0,
    description: "Stable quality impulse",
    distanceToBoundary: 0.0,
  );

  /// Calculates the [TransitionEnvelope] for a given Moon [longitude] against [boundaries].
  factory TransitionEnvelope.fromLongitude(
    double longitude, [
    List<ConstellationBoundary> boundaries = dornachBoundaries,
    double thresholdDegrees = 0.75,
  ]) {
    double normLon = longitude % 360.0;
    if (normLon < 0) {
      normLon += 360.0;
    }

    for (int i = 0; i < boundaries.length; i++) {
      final prevBoundary = boundaries[i];
      final nextBoundary = boundaries[(i + 1) % boundaries.length];
      final cuspDegree = prevBoundary.endDegree % 360.0;

      double delta = (normLon - cuspDegree) % 360.0;
      if (delta > 180.0) {
        delta -= 360.0;
      }

      if (delta.abs() <= thresholdDegrees) {
        final fromQuality = elementToQuality(prevBoundary.element);
        final toQuality = elementToQuality(nextBoundary.element);
        final progress = ((delta + thresholdDegrees) / (2.0 * thresholdDegrees))
            .clamp(0.0, 1.0);
        final percent = (progress * 100).round();
        final description =
            "Cusp transition from ${qualityLabel(fromQuality)} to ${qualityLabel(toQuality)} ($percent% complete)";

        return TransitionEnvelope(
          isTransition: true,
          fromQuality: fromQuality,
          toQuality: toQuality,
          progress: progress,
          description: description,
          distanceToBoundary: delta.abs(),
        );
      }
    }

    // Outside any transition envelope: determine current stable quality
    final currentQuality = _getQualityFromLongitudeInternal(
      normLon,
      boundaries,
    );
    return TransitionEnvelope(
      isTransition: false,
      fromQuality: currentQuality,
      toQuality: currentQuality,
      progress: 0.0,
      description: "Stable ${qualityLabel(currentQuality)} impulse",
      distanceToBoundary: 0.0,
    );
  }

  @override
  String toString() =>
      "TransitionEnvelope(isTransition: $isTransition, from: $fromQuality, to: $toQuality, progress: ${(progress * 100).toStringAsFixed(1)}%)";
}

/// Converts a constellation element string to [PlantQuality].
PlantQuality elementToQuality(String element) {
  switch (element) {
    case "Earth":
      return PlantQuality.root;
    case "Water":
      return PlantQuality.leaf;
    case "Air":
      return PlantQuality.flower;
    case "Fire":
      return PlantQuality.fruit;
    default:
      return PlantQuality.none;
  }
}

/// Formats a [PlantQuality] into a capitalized human-readable name.
String qualityLabel(PlantQuality quality) {
  switch (quality) {
    case PlantQuality.root:
      return "Root";
    case PlantQuality.leaf:
      return "Leaf";
    case PlantQuality.flower:
      return "Flower";
    case PlantQuality.fruit:
      return "Fruit";
    case PlantQuality.none:
      return "None";
  }
}

PlantQuality _getQualityFromLongitudeInternal(
  double normLon,
  List<ConstellationBoundary> boundaries,
) {
  for (final boundary in boundaries) {
    if (boundary.startDegree <= boundary.endDegree) {
      if (normLon >= boundary.startDegree && normLon < boundary.endDegree) {
        return elementToQuality(boundary.element);
      }
    } else {
      if (normLon >= boundary.startDegree || normLon < boundary.endDegree) {
        return elementToQuality(boundary.element);
      }
    }
  }
  return PlantQuality.none;
}
