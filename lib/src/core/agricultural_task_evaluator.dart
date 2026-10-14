import 'package:flutter/material.dart';

import 'dornach_boundaries.dart';
import 'models/models.dart';

/// Evaluates agricultural farm organism tasks beyond seed sowing.
///
/// Implements Maria Thun and Rudolf Steiner biodynamic guidelines for:
/// 1. Soil cultivation & root aeration (sidereal Plant-Part Day crop impulse + morning shallow hoeing vs afternoon deep cultivation).
/// 2. Fruit tree and vine pruning (descending moon + fruit day optimal; ascending or leaf day prohibited).
/// 3. Harvest for cellar storage (Root day + descending moon for root crops; Fruit/Flower day + ascending moon for above-ground storage crops; Leaf days avoided).
/// 4. Harvest for fresh eating (matching Plant-Part Day + morning exhalation + ascending/descending organ alignment).
/// 5. Timber felling (Mondholz / Moon Wood: waning/descending moon in Capricorn).
/// 6. Weed & pest peppering (ashing in Leo / Scorpio).
abstract final class AgriculturalTaskEvaluator {
  /// Returns the astronomical constellation name corresponding to [longitude].
  static String getConstellationName(
    double longitude, [
    List<ConstellationBoundary> boundaries = dornachBoundaries,
  ]) {
    return findBoundaryForLongitude(longitude, boundaries)?.name ?? '';
  }

  /// Evaluates the suitability of a specific [task] at [time] under [calendarInfo].
  static AgriculturalTaskAdvice evaluateTask({
    required AgriculturalTaskType task,
    required CalendarInfo calendarInfo,
    required DateTime time,
    WeatherDataPoint? weather,
    String? constellation,
    EphemerisService? ephemeris,
    double? moonLongitude,
    double latitude = DefaultLocations.copenhagenLatitude,
  }) {
    if (constellation == null || constellation.isEmpty) {
      if (moonLongitude == null && ephemeris != null) {
        try {
          moonLongitude = ephemeris.getMoonLongitude(time);
        } catch (_) {}
      }
      if (moonLongitude != null) {
        constellation = getConstellationName(moonLongitude);
      }
    }
    final constName = constellation ?? '';
    final constLower = constName.toLowerCase();

    final isDescending = calendarInfo.isMoonDescending;
    final isAscending = calendarInfo.isMoonAscending;
    final isWaxing = calendarInfo.moonPhase.isWaxing;
    final isWaning = !isWaxing;
    final quality = calendarInfo.quality;
    final isGrayDay = calendarInfo.isGrayDay;

    switch (task) {
      case AgriculturalTaskType.soilCultivation:
        return _evaluateSoilCultivation(
          time: time,
          weather: weather,
          quality: quality,
          isDescending: isDescending,
          isGrayDay: isGrayDay,
        );

      case AgriculturalTaskType.pruning:
        return _evaluatePruning(
          weather: weather,
          isDescending: isDescending,
          isAscending: isAscending,
          quality: quality,
          isGrayDay: isGrayDay,
        );

      case AgriculturalTaskType.harvestStorage:
        return _evaluateHarvestStorage(
          weather: weather,
          isDescending: isDescending,
          isAscending: isAscending,
          isWaning: isWaning,
          quality: quality,
          isGrayDay: isGrayDay,
        );

      case AgriculturalTaskType.harvestFresh:
        return _evaluateHarvestFresh(
          time: time,
          quality: quality,
          isAscending: isAscending,
          isWaxing: isWaxing,
          isGrayDay: isGrayDay,
        );

      case AgriculturalTaskType.timberFelling:
        return _evaluateTimberFelling(
          weather: weather,
          isWaning: isWaning,
          quality: quality,
          constLower: constLower,
          isGrayDay: isGrayDay,
        );

      case AgriculturalTaskType.peppering:
        return _evaluatePeppering(
          weather: weather,
          quality: quality,
          constLower: constLower,
          isGrayDay: isGrayDay,
        );
    }
  }

  /// Evaluates all 6 agricultural tasks.
  static List<AgriculturalTaskAdvice> evaluateAllTasks({
    required CalendarInfo calendarInfo,
    required DateTime time,
    WeatherDataPoint? weather,
    String? constellation,
    EphemerisService? ephemeris,
    double? moonLongitude,
    double latitude = DefaultLocations.copenhagenLatitude,
  }) {
    return AgriculturalTaskType.values
        .map(
          (task) => evaluateTask(
            task: task,
            calendarInfo: calendarInfo,
            time: time,
            weather: weather,
            constellation: constellation,
            ephemeris: ephemeris,
            moonLongitude: moonLongitude,
            latitude: latitude,
          ),
        )
        .toList(growable: false);
  }

  static AgriculturalTaskAdvice _evaluateSoilCultivation({
    required DateTime time,
    required WeatherDataPoint? weather,
    required PlantQuality quality,
    required bool isDescending,
    required bool isGrayDay,
  }) {
    final hour = time.hour;
    final isMorning = hour >= 5 && hour < 12;
    final isAfternoon = hour >= 12 && hour <= 19;
    final organTarget = quality != PlantQuality.none
        ? '${quality.displayName}-crop beds'
        : 'garden beds';

    bool weatherConflict = false;
    TaskSuitability suitability;
    String title;
    String cosmic;
    String terrestrial;
    String action;

    if (isGrayDay) {
      suitability = TaskSuitability.restricted;
      title = 'Soil Rest (Cosmic Rest Window)';
      cosmic = 'Cosmic Rest Window: Moon node / perigee interference disrupts soil microorganism vitality.';
      terrestrial = 'Disturbing soil structure now shocks microbial fungi and beneficial worms.';
      action = 'Rest beds. Postpone cultivation until cosmic forces stabilize.';
    } else if (isAfternoon) {
      suitability = isDescending
          ? TaskSuitability.optimal
          : TaskSuitability.favorable;
      title = 'Afternoon Deep Cultivation (Root Aeration)';
      final qualityImpulse = quality != PlantQuality.none
          ? ' ${quality.displayName} Day channels ${quality.name} element into the soil.'
          : '';
      cosmic = isDescending
          ? 'Descending Moon + Afternoon Earth Inhalation: Vitality is pulled down into the subsoil and root sphere.$qualityImpulse'
          : 'Afternoon Inhalation: Earth breathes inward, welcoming atmospheric warmth and nitrogen.$qualityImpulse';
      terrestrial =
          'Deep soil loosening and root aeration stimulates downward mycorrhizal root expansion in $organTarget.';
      action =
          'Deep root aeration and subsoil cultivation of $organTarget with broadfork or deep hoe to oxygenate rhizosphere.';
    } else if (isMorning) {
      suitability = TaskSuitability.optimal;
      title = 'Morning Shallow Hoeing (Weed Scalping)';
      final qualityImpulse = quality != PlantQuality.none
          ? ' Cultivating on a ${quality.displayName} Day simultaneously vitalizes $organTarget.'
          : '';
      cosmic =
          'Morning Exhalation: Vital forces stream upward. Weeds severed at this hour dehydrate quickly under rising sun.$qualityImpulse';
      terrestrial = 'Shallow scalping creates a dry dust mulch that breaks capillary water loss without disturbing root biology.';
      action =
          'Shallow surface hoeing (top 1–2 cm) around $organTarget to scalp weed seedlings and preserve bed moisture.';
    } else {
      suitability = TaskSuitability.neutral;
      title = 'Night Rest (Soil Consolidation)';
      cosmic = 'Night Rest: Earth in subterranean consolidation.';
      terrestrial = 'Avoid nocturnal soil disturbance.';
      action =
          'Observe soil moisture and prepare tools for morning cultivation.';
    }

    // Weather conflicts override cosmic suitability
    if (weather != null && weather.precipitation > 2.0) {
      weatherConflict = true;
      suitability = TaskSuitability.restricted;
      terrestrial =
          'CRITICAL: Soil is waterlogged (${weather.precipitation.toStringAsFixed(1)} mm rain). Tillage will smear soil aggregates, cause compaction, and create anaerobic hardpan.';
      action = 'Cease all tillage and heavy bed traffic immediately. Wait for topsoil to dry to crumbly tilth.';
    } else if (weather?.temperature != null && weather!.temperature! <= 0.0) {
      weatherConflict = true;
      suitability = TaskSuitability.restricted;
      terrestrial =
          'Soil is frozen (${weather.temperature!.toStringAsFixed(1)}°C). Breaking frozen ground destroys soil crumb structure.';
      action = 'Postpone cultivation until ground fully thaws.';
    }

    return AgriculturalTaskAdvice(
      task: AgriculturalTaskType.soilCultivation,
      title: title,
      suitability: suitability,
      cosmicReasoning: cosmic,
      terrestrialReasoning: terrestrial,
      practicalAction: action,
      hasWeatherConflict: weatherConflict,
      icon: Icons.agriculture,
    );
  }

  static AgriculturalTaskAdvice _evaluatePruning({
    required WeatherDataPoint? weather,
    required bool isDescending,
    required bool isAscending,
    required PlantQuality quality,
    required bool isGrayDay,
  }) {
    bool weatherConflict = false;
    TaskSuitability suitability;
    String cosmic;
    String terrestrial;
    String action;

    if (isGrayDay) {
      suitability = TaskSuitability.restricted;
      cosmic = 'Cosmic Rest Window: Gravitational disruption at lunar node causes ragged wound healing and tissue dieback.';
      terrestrial = 'Wounds fail to compartmentalize naturally.';
      action = 'Avoid all pruning, cutting, or pinching back today.';
    } else if (isAscending) {
      suitability = TaskSuitability.restricted;
      cosmic = 'PROHIBITED: Ascending Moon pumps sap upward under high pressure. Pruning now causes severe sap bleeding and weakens tree vitality.';
      terrestrial = 'Open cuts bleed carbohydrates and essential minerals, inviting insect pests.';
      action = 'Postpone pruning until the Moon enters its Descending arc.';
    } else if (quality == PlantQuality.leaf) {
      suitability = TaskSuitability.restricted;
      cosmic = 'PROHIBITED: Leaf/Water Day fosters fungal spore activation and excessive watery vegetation rather than fruit spurs.';
      terrestrial = 'High tissue moisture at cut surfaces invites bacterial canker and silver leaf fungal rot.';
      action = 'Avoid pruning on Leaf/Water days. Wait for Fruit/Warmth days.';
    } else if (isDescending && quality == PlantQuality.fruit) {
      suitability = TaskSuitability.optimal;
      cosmic = 'OPTIMAL: Descending Moon draws sap safely down into root system, while Fruit/Warmth day concentrates fruit bud impulses.';
      terrestrial = 'Cuts seal cleanly without bleeding. Cellular differentiation strongly favors productive fruit spurs.';
      action = 'Prune fruit trees, berry canes, and vines for fruit spur renewal and open canopy light penetration.';
    } else if (isDescending) {
      suitability = TaskSuitability.favorable;
      cosmic = 'Descending Moon: Sap is drawn downward, minimizing bleed risk at cuts.';
      terrestrial = 'Acceptable healing conditions for maintenance cutting.';
      action = 'General tree maintenance and thinning of deadwood.';
    } else {
      suitability = TaskSuitability.neutral;
      cosmic = 'Neutral astronomical timing for pruning.';
      terrestrial = 'Check local bud development and dormant state.';
      action = 'Limit pruning to corrective or emergency sanitization.';
    }

    if (weather?.temperature != null && weather!.temperature! <= 0.0) {
      weatherConflict = true;
      suitability = TaskSuitability.restricted;
      terrestrial =
          'Freezing weather (${weather.temperature!.toStringAsFixed(1)}°C) causes bark splitting and frost necrosis at fresh cuts.';
      action = 'Suspend pruning until frost subsides and wood is pliable.';
    } else if (weather != null && weather.precipitation > 2.0) {
      weatherConflict = true;
      if (suitability != TaskSuitability.restricted) {
        suitability = TaskSuitability.unfavorable;
      }
      terrestrial = 'Wet rain promotes fungal spore dispersal directly into open xylem vessels.';
      action = 'Wait for dry, sunny weather before pruning.';
    }

    return AgriculturalTaskAdvice(
      task: AgriculturalTaskType.pruning,
      title: 'Fruit Tree & Vine Pruning',
      suitability: suitability,
      cosmicReasoning: cosmic,
      terrestrialReasoning: terrestrial,
      practicalAction: action,
      hasWeatherConflict: weatherConflict,
      icon: Icons.content_cut,
    );
  }

  static AgriculturalTaskAdvice _evaluateHarvestStorage({
    required WeatherDataPoint? weather,
    required bool isDescending,
    required bool isAscending,
    required bool isWaning,
    required PlantQuality quality,
    required bool isGrayDay,
  }) {
    bool weatherConflict = false;
    TaskSuitability suitability;
    String cosmic;
    String terrestrial;
    String action;

    final synodicNote = isWaning
        ? ' Waning Moon secondarily reduces residual tissue moisture.'
        : ' (Note: Waxing Moon plays only a minor secondary role compared to constellation and declination.)';

    if (isGrayDay) {
      suitability = TaskSuitability.restricted;
      cosmic = 'Cosmic Rest Window: Harvested crops decay prematurely in cellar storage.';
      terrestrial = 'Cellular integrity is fragile.';
      action = 'Do not harvest crops intended for long winter storage.';
    } else if (quality == PlantQuality.leaf) {
      suitability = TaskSuitability.unfavorable;
      cosmic = 'Leaf/Water Day: Moisture forces dominate, leading to high rot susceptibility in storage.';
      terrestrial = 'High water content invites fungal botrytis and mold in storage crates.';
      action = 'Harvest only for immediate eating; not for cellar storage.';
    } else if (quality == PlantQuality.root) {
      if (isDescending) {
        suitability = TaskSuitability.optimal;
        cosmic =
            'OPTIMAL: Root Day + Descending Moon concentrates dry matter and vitality into subterranean storage organs.$synodicNote';
        terrestrial = 'Root crops have firm cellular structure and maximum winter cellar longevity with strong rot resistance.';
        action = 'Harvest root crops (carrots, beets, potatoes, celeriac, onions) for winter cellar curing.';
      } else {
        suitability = TaskSuitability.favorable;
        cosmic =
            'FAVORABLE: Root Day provides the primary Earth keeping impulse, though Ascending Moon draws some sap upward.$synodicNote';
        terrestrial = 'Good root storage quality; allow extra surface curing before cellar packing.';
        action = 'Harvest root crops if weather requires; cure thoroughly in dry air before storage.';
      }
    } else if (quality == PlantQuality.fruit ||
        quality == PlantQuality.flower) {
      final dayName = quality.displayName;
      if (isAscending) {
        suitability = TaskSuitability.optimal;
        cosmic =
            'OPTIMAL: $dayName Day + Ascending Moon draws sugars, aromatic oils, and ripening forces into above-ground organs for peak storage keeping.$synodicNote';
        terrestrial = 'Fruits, winter squash, seeds, and drying herbs reach maximum dry-matter maturity and shelf longevity.';
        action = quality == PlantQuality.fruit
            ? 'Harvest orchard fruits (apples, pears), winter squash, and seed crops for long storage.'
            : 'Harvest flowers, medicinal herbs, and broccoli/cauliflower for drying or cool storage.';
      } else {
        suitability = TaskSuitability.favorable;
        cosmic =
            'FAVORABLE: $dayName Day supports keeping quality, while Descending Moon draws sap downward.$synodicNote';
        terrestrial =
            'Low tissue moisture and solid skin firmness for cellar curing.';
        action = 'Harvest storage fruits, winter squash, or cabbage heads; cure in a dry, ventilated space.';
      }
    } else {
      suitability = TaskSuitability.neutral;
      cosmic = 'Neutral cosmic impulse for storage harvest.$synodicNote';
      terrestrial = 'Ensure crops are thoroughly cured before packing.';
      action = 'Cure and store in a dark, cool root cellar.';
    }

    if (weather != null && weather.precipitation > 0.5) {
      weatherConflict = true;
      suitability = TaskSuitability.unfavorable;
      terrestrial =
          'Rainfall (${weather.precipitation.toStringAsFixed(1)} mm) soaks crop skins. Packing wet crops guarantees cellar rot.';
      action = 'Harvest only when soil and crop surfaces are completely dry.';
    }

    return AgriculturalTaskAdvice(
      task: AgriculturalTaskType.harvestStorage,
      title: 'Harvest for Cellar Storage',
      suitability: suitability,
      cosmicReasoning: cosmic,
      terrestrialReasoning: terrestrial,
      practicalAction: action,
      hasWeatherConflict: weatherConflict,
      icon: Icons.inventory_2,
    );
  }

  static AgriculturalTaskAdvice _evaluateHarvestFresh({
    required DateTime time,
    required PlantQuality quality,
    required bool isAscending,
    required bool isWaxing,
    required bool isGrayDay,
  }) {
    final hour = time.hour;
    final isMorning = hour >= 6 && hour <= 12;
    final hasOrganQuality = quality != PlantQuality.none;
    final organMatchesDeclination = quality == PlantQuality.root
        ? !isAscending
        : isAscending;

    TaskSuitability suitability;
    String cosmic;
    String terrestrial;
    String action;

    if (isGrayDay) {
      suitability = TaskSuitability.unfavorable;
      cosmic = 'Cosmic Rest Window: Vitality is diminished; flavor lacks aromatic radiance.';
      terrestrial = 'Leaves may taste dull or wilt rapidly after harvest.';
      action = 'Harvest lightly if needed for fresh consumption.';
    } else if (isMorning && hasOrganQuality && organMatchesDeclination) {
      suitability = TaskSuitability.optimal;
      final arcText = isAscending ? 'Ascending Moon' : 'Descending Moon';
      cosmic =
          'OPTIMAL: ${quality.displayName} Day + Morning Exhalation + $arcText concentrates flavor, sugars, and aromatic oils in ${quality.name} crops.';
      terrestrial = 'Peak morning turgor pressure ensures crisp succulence and nutritional vitality.';
      action =
          'Harvest fresh ${quality.name} crops (salad greens, herbs, berries, or tender roots) for immediate kitchen table use.';
    } else if (isMorning && hasOrganQuality) {
      suitability = TaskSuitability.optimal;
      cosmic =
          'OPTIMAL: ${quality.displayName} Day + Morning Exhalation lifts vital forces and turgor into ${quality.name} organs.';
      terrestrial = 'High morning turgor pressure and crisp flavor retention.';
      action =
          'Harvest fresh ${quality.name} crops in the morning cool for same-day eating.';
    } else if (isMorning || hasOrganQuality || isAscending) {
      suitability = TaskSuitability.favorable;
      cosmic = isMorning
          ? 'Morning Exhalation captures morning coolness and turgor.'
          : hasOrganQuality
          ? '${quality.displayName} Day supports organ-specific flavor and aroma.'
          : 'Ascending Moon supports sap vitality in above-ground crops.';
      if (isWaxing) {
        cosmic += ' Waxing Moon adds a minor secondary moisture boost.';
      }
      terrestrial = 'Good freshness and flavor retention.';
      action = 'Harvest for same-day kitchen consumption.';
    } else {
      suitability = TaskSuitability.neutral;
      cosmic = 'Neutral cosmic impulse for fresh harvest.';
      terrestrial = 'Afternoon heat may cause slight wilting.';
      action = 'Harvest as needed; chill or consume promptly.';
    }

    return AgriculturalTaskAdvice(
      task: AgriculturalTaskType.harvestFresh,
      title: 'Harvest for Fresh Eating',
      suitability: suitability,
      cosmicReasoning: cosmic,
      terrestrialReasoning: terrestrial,
      practicalAction: action,
      icon: Icons.restaurant,
    );
  }

  static AgriculturalTaskAdvice _evaluateTimberFelling({
    required WeatherDataPoint? weather,
    required bool isWaning,
    required PlantQuality quality,
    required String constLower,
    required bool isGrayDay,
  }) {
    bool weatherConflict = false;
    TaskSuitability suitability;
    String cosmic;
    String terrestrial;
    String action;

    final isCapricorn =
        constLower == 'capricorn' ||
        (constLower.isEmpty && quality == PlantQuality.root && isWaning);

    if (isGrayDay) {
      suitability = TaskSuitability.restricted;
      cosmic = 'Cosmic Rest Window: Gravitational instability affects cellular drying.';
      terrestrial = 'Timber felled today tends to crack irregularly.';
      action = 'Halt all forestry and timber felling operations.';
    } else if (isWaning && isCapricorn) {
      suitability = TaskSuitability.optimal;
      cosmic = 'OPTIMAL (Mondholz): Waning Moon in Capricorn (Earth/Root). Ancient European standard for moon wood.';
      terrestrial = 'Sap is at its absolute minimum. Wood contracts with maximum fiber density, resisting warp, crack, rot, and wood-boring beetles.';
      action = 'Fell premium construction timber, musical instrument tonewood, and rot-resistant fence posts.';
    } else if (isWaning && quality == PlantQuality.root) {
      suitability = TaskSuitability.favorable;
      cosmic =
          'Waning Moon in Earth Sign (${constLower.isEmpty ? 'Root' : constLower.toUpperCase()}): Low moisture promotes good drying.';
      terrestrial = 'Acceptable wood density and insect resistance.';
      action = 'Good window for firewood and secondary construction lumber.';
    } else if (!isWaning) {
      suitability = TaskSuitability.unfavorable;
      cosmic = 'Waxing Moon: Wood is charged with water and sap, inviting woodworm and rapid warping.';
      terrestrial = 'High sap moisture leads to mold, cracking, and decay.';
      action = 'Do not fell structural timber during Waxing Moon.';
    } else {
      suitability = TaskSuitability.neutral;
      cosmic = 'Moderate drying characteristics.';
      terrestrial = 'Ensure extended curing and seasoning.';
      action = 'Suitable for pulpwood or firewood.';
    }

    if (weather != null && weather.windSpeed > 10.0) {
      weatherConflict = true;
      suitability = TaskSuitability.restricted;
      terrestrial =
          'High wind speeds (${weather.windSpeed.toStringAsFixed(1)} m/s) present severe safety hazards for tree felling.';
      action = 'Wait for calm winds before felling standing trees.';
    }

    return AgriculturalTaskAdvice(
      task: AgriculturalTaskType.timberFelling,
      title: 'Timber Felling (Mondholz)',
      suitability: suitability,
      cosmicReasoning: cosmic,
      terrestrialReasoning: terrestrial,
      practicalAction: action,
      hasWeatherConflict: weatherConflict,
      icon: Icons.forest,
    );
  }

  static AgriculturalTaskAdvice _evaluatePeppering({
    required WeatherDataPoint? weather,
    required PlantQuality quality,
    required String constLower,
    required bool isGrayDay,
  }) {
    bool weatherConflict = false;
    TaskSuitability suitability;
    String title = 'Weed & Pest Peppering (Veraschung)';
    String cosmic;
    String terrestrial;
    String action;

    final isLeo = constLower == 'leo';
    final isScorpio = constLower == 'scorpio';

    if (isGrayDay) {
      suitability = TaskSuitability.restricted;
      cosmic = 'Cosmic Rest Window: Distorts homeopathic potentization and ash forces.';
      terrestrial = 'Avoid burning preparations on Gray Days.';
      action = 'Do not prepare or spread weed/pest ash today.';
    } else if (isLeo) {
      suitability = TaskSuitability.optimal;
      title = 'Weed Peppering (Ashing in Leo)';
      cosmic = 'OPTIMAL FOR WEED SEEDS: Moon in Leo (Fire/Warmth). The solar warmth impulse extinguishes seed reproductive vitality.';
      terrestrial = 'Burning weed seeds in Leo destroys their generative germ force permanently.';
      action = 'Burn collected noxious weed seeds to fine white ash. Potentize to D8 or broadcast thinly over infested beds.';
    } else if (isScorpio) {
      suitability = TaskSuitability.optimal;
      title = 'Pest Peppering (Ashing in Scorpio)';
      cosmic = 'OPTIMAL FOR INSECT PESTS: Moon in Scorpio (Water element governing invertebrate reproductive cycles).';
      terrestrial = 'Ashing insect pests (e.g. flea beetles, aphids) under Scorpio dissolves their reproductive impulse.';
      action = 'Incinerate collected pests on a wood fire. Dynamize ash and spray or dust over crops to deter infestation.';
    } else if (quality == PlantQuality.fruit) {
      suitability = TaskSuitability.favorable;
      title = 'Weed Peppering (Fire Quality)';
      cosmic = 'Fire/Warmth quality supports burning and ashing of weed seeds.';
      terrestrial = 'Effective for general weed seed reduction.';
      action = 'Burn collected weed seeds in outdoor hearth.';
    } else if (quality == PlantQuality.leaf) {
      suitability = TaskSuitability.favorable;
      title = 'Pest Peppering (Water Quality)';
      cosmic = 'Water quality aligns with invertebrate insect management.';
      terrestrial = 'Supports pest ash dynamization.';
      action = 'Prepare insect pest ash for seasonal spray.';
    } else {
      suitability = TaskSuitability.neutral;
      cosmic = 'Neutral cosmic impulse for weed and pest ashing.';
      terrestrial =
          'Collect seeds and pests and store dry until Leo or Scorpio.';
      action = 'Collect specimens; wait for Leo (weeds) or Scorpio (pests).';
    }

    if (weather != null && weather.windSpeed > 5.5) {
      weatherConflict = true;
      // Consistent with the other evaluators: a weather conflict that makes the
      // action unsafe also downgrades suitability, so the headline cannot read
      // "optimal" while the action says to postpone.
      suitability = TaskSuitability.restricted;
      terrestrial =
          'High wind (${weather.windSpeed.toStringAsFixed(1)} m/s) prevents controlled combustion and causes ash drift.';
      action =
          'Postpone open-air burning and ash broadcasting until wind calms.';
    }

    return AgriculturalTaskAdvice(
      task: AgriculturalTaskType.peppering,
      title: title,
      suitability: suitability,
      cosmicReasoning: cosmic,
      terrestrialReasoning: terrestrial,
      practicalAction: action,
      hasWeatherConflict: weatherConflict,
      icon: Icons.local_fire_department,
    );
  }
}
