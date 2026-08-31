import 'package:flutter/widgets.dart';

/// Distinct types of farm and garden tasks within the biodynamic farm organism.
enum AgriculturalTaskType {
  /// Surface soil aeration, weed hoeing, and deep root cultivation.
  soilCultivation,

  /// Fruit tree, berry bush, and grape vine pruning.
  pruning,

  /// Harvesting root crops, fruits, and squash for long cellar storage.
  harvestStorage,

  /// Harvesting leafy greens, herbs, and table fruits for fresh immediate consumption.
  harvestFresh,

  /// Timber felling (Mondholz / Moon Wood) for durable, rot-resistant construction.
  timberFelling,

  /// Weed and pest peppering (Veraschung / ashing) for biodynamic species control.
  peppering,
}

/// Suitability level for agricultural activities based on cosmic and terrestrial factors.
enum TaskSuitability {
  /// Ideal cosmic and terrestrial alignment for peak biodynamic efficacy.
  optimal,

  /// Supportive conditions; work can proceed with good results.
  favorable,

  /// Acceptable conditions without special enhancement.
  neutral,

  /// Suboptimal timing; consider postponing if possible.
  unfavorable,

  /// Prohibited or strictly discouraged due to adverse rhythms (e.g. bleeding sap, compaction, rot).
  restricted,
}

/// Comprehensive advice for an agricultural activity, incorporating cosmic rhythms,
/// terrestrial conditions, and weather synthesis.
final class AgriculturalTaskAdvice {
  /// The specific agricultural task.
  final AgriculturalTaskType task;

  /// User-facing descriptive title.
  final String title;

  /// Calculated suitability level.
  final TaskSuitability suitability;

  /// Explanation of astronomical/cosmic influences (Moon phase, constellation, ascent/descent).
  final String cosmicReasoning;

  /// Explanation of terrestrial/ecological factors (diurnal time, soil biology, sap state).
  final String terrestrialReasoning;

  /// Concrete action recommendation for the gardener or farmer.
  final String practicalAction;

  /// True if current weather conditions conflict with or modify this task.
  final bool hasWeatherConflict;

  /// Optional icon representing the task in the UI.
  final IconData? icon;

  /// Creates an immutable [AgriculturalTaskAdvice].
  const AgriculturalTaskAdvice({
    required this.task,
    required this.title,
    required this.suitability,
    required this.cosmicReasoning,
    required this.terrestrialReasoning,
    required this.practicalAction,
    this.hasWeatherConflict = false,
    this.icon,
  });

  /// True if the task is favorable or optimal to perform.
  bool get isFavorable =>
      suitability == TaskSuitability.optimal ||
      suitability == TaskSuitability.favorable;

  /// True if the task is strictly restricted or prohibited.
  bool get isRestricted => suitability == TaskSuitability.restricted;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgriculturalTaskAdvice &&
          runtimeType == other.runtimeType &&
          task == other.task &&
          title == other.title &&
          suitability == other.suitability &&
          cosmicReasoning == other.cosmicReasoning &&
          terrestrialReasoning == other.terrestrialReasoning &&
          practicalAction == other.practicalAction &&
          hasWeatherConflict == other.hasWeatherConflict &&
          icon == other.icon;

  @override
  int get hashCode => Object.hash(
    task,
    title,
    suitability,
    cosmicReasoning,
    terrestrialReasoning,
    practicalAction,
    hasWeatherConflict,
    icon,
  );

  @override
  String toString() =>
      'AgriculturalTaskAdvice(task: , title: , suitability: , '
      'weatherConflict: )';
}
