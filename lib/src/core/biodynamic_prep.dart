import '../services/ephemeris_service.dart';
import 'algorithm.dart' as algo;

/// Categories of biodynamic preparations.
enum PrepCategory { fieldSpray, compostPrep }

/// Individual biodynamic preparations (BD 500 to BD 508).
enum BiodynamicPrepType {
  bd500(
    'BD 500',
    'Horn Manure',
    PrepCategory.fieldSpray,
    'Promotes root depth, soil humus, microbial activity, and earth vitality.',
    60,
  ),
  bd501(
    'BD 501',
    'Horn Silica',
    PrepCategory.fieldSpray,
    'Enhances photosynthesis, cellular structure, flowering, and fruit ripening.',
    60,
  ),
  bd502(
    'BD 502',
    'Yarrow',
    PrepCategory.compostPrep,
    'Connects compost with sulfur and potassium to vitalize plant nutrition.',
    0,
  ),
  bd503(
    'BD 503',
    'Chamomile',
    PrepCategory.compostPrep,
    'Stabilizes nitrogen and calcium, preventing protein loss during breakdown.',
    0,
  ),
  bd504(
    'BD 504',
    'Stinging Nettle',
    PrepCategory.compostPrep,
    'Enriches soil intelligence, iron balance, and structural humification.',
    0,
  ),
  bd505(
    'BD 505',
    'Oak Bark',
    PrepCategory.compostPrep,
    'Provides calcium and natural resistance against plant diseases and fungi.',
    0,
  ),
  bd506(
    'BD 506',
    'Dandelion',
    PrepCategory.compostPrep,
    'Attracts silicic acid forces to regulate phosphorus and light uptake.',
    0,
  ),
  bd507(
    'BD 507',
    'Valerian',
    PrepCategory.compostPrep,
    'Forms a protective warmth blanket over compost and regulates phosphorus.',
    0,
  ),
  bd508(
    'BD 508',
    'Horsetail',
    PrepCategory.fieldSpray,
    'Prevents fungal blights and balances excessive watery forces in damp conditions.',
    20,
  );

  final String code;
  final String commonName;
  final PrepCategory category;
  final String description;
  final int stirringMinutes;

  const BiodynamicPrepType(
    this.code,
    this.commonName,
    this.category,
    this.description,
    this.stirringMinutes,
  );
}

/// Rating of current conditions for applying or preparing a preparation.
enum PrepSuitabilityLevel { optimal, moderate, unfavorable }

/// Detailed evaluation result for a field spray.
final class PrepSuitability {
  final PrepSuitabilityLevel level;
  final List<String> positiveFactors;
  final List<String> negativeFactors;
  final bool weatherSuitable;
  final bool astronomicalSuitable;

  const PrepSuitability({
    required this.level,
    required this.positiveFactors,
    required this.negativeFactors,
    required this.weatherSuitable,
    required this.astronomicalSuitable,
  });

  /// Returns whether conditions are favorable (optimal or moderate).
  bool get isFavorable =>
      level == PrepSuitabilityLevel.optimal ||
      level == PrepSuitabilityLevel.moderate;

  /// Returns numeric score between 0.0 and 1.0.
  double get score {
    switch (level) {
      case PrepSuitabilityLevel.optimal:
        return 1.0;
      case PrepSuitabilityLevel.moderate:
        return 0.5;
      case PrepSuitabilityLevel.unfavorable:
        return 0.0;
    }
  }

  String get summary {
    switch (level) {
      case PrepSuitabilityLevel.optimal:
        return 'Optimal Conditions for Spraying';
      case PrepSuitabilityLevel.moderate:
        return 'Acceptable Conditions';
      case PrepSuitabilityLevel.unfavorable:
        return 'Unfavorable Conditions';
    }
  }
}

/// Information regarding seasonal concoction, burial, and retrieval.
final class BurialStageInfo {
  final String stage;
  final String description;
  final String recommendedAction;
  final bool isActiveWindow;

  const BurialStageInfo({
    required this.stage,
    required this.description,
    required this.recommendedAction,
    required this.isActiveWindow,
  });
}

/// Utility for calculating biodynamic preparation timing and burial stages.
abstract final class BiodynamicPrepEvaluator {
  /// Evaluates the spray suitability for [prep] at [time] given [calendarInfo] and optional weather parameters.
  static PrepSuitability evaluateSpray({
    required BiodynamicPrepType prep,
    required DateTime time,
    required CalendarInfo calendarInfo,
    double? windSpeed,
    double? precipitation,
    double? cloudCover,
    double? temperature,
    double? humidity,
  }) {
    if (prep.category != PrepCategory.fieldSpray) {
      return const PrepSuitability(
        level: PrepSuitabilityLevel.unfavorable,
        positiveFactors: [],
        negativeFactors: [
          'Compost preparations are inserted directly into compost piles.',
        ],
        weatherSuitable: false,
        astronomicalSuitable: false,
      );
    }

    final positive = <String>[];
    final negative = <String>[];

    bool astroOk = true;
    bool weatherOk = true;

    final isDescending = calendarInfo.sapFlow.contains('Descending');
    final isAscending = calendarInfo.sapFlow.contains('Ascending');
    final hour = time.hour;

    switch (prep) {
      case BiodynamicPrepType.bd500:
        if (isDescending) {
          positive.add(
            'Descending Moon (Earth Inhalation draws vitality into soil)',
          );
        } else {
          negative.add('Ascending Moon (Sap rising away from soil)');
          astroOk = false;
        }

        if (calendarInfo.quality == PlantQuality.root) {
          positive.add(
            'Root Day (Earth impulse optimizes soil microbial activity)',
          );
        }

        if (hour >= 15 && hour <= 20) {
          positive.add('Late Afternoon / Evening window (15:00–20:00, Sun setting)');
        } else {
          negative.add('Best applied in late afternoon or early evening (15:00–20:00)');
        }

        if (windSpeed != null) {
          if (windSpeed <= 5.0) {
            positive.add('Calm wind (${windSpeed.toStringAsFixed(1)} m/s)');
          } else {
            negative.add(
              'Wind speed too high for soil spray (${windSpeed.toStringAsFixed(1)} m/s)',
            );
            weatherOk = false;
          }
        }

        if (precipitation != null && precipitation > 1.0) {
          negative.add(
            'Rain likely (${precipitation.toStringAsFixed(1)} mm) - spray may wash away',
          );
          weatherOk = false;
        }
        break;

      case BiodynamicPrepType.bd501:
        if (isAscending) {
          positive.add(
            'Ascending Moon (Earth Exhalation pushes forces to foliage)',
          );
        } else {
          negative.add('Descending Moon (Sap receding towards root system)');
          astroOk = false;
        }

        if (calendarInfo.quality == PlantQuality.flower ||
            calendarInfo.quality == PlantQuality.fruit) {
          positive.add(
            '${calendarInfo.quality.name[0].toUpperCase()}${calendarInfo.quality.name.substring(1)} Day boosts photosynthesis and ripening',
          );
        }

        if (hour >= 5 && hour <= 9) {
          positive.add('Early Morning / Sunrise window (05:00–09:00)');
        } else {
          negative.add('Best applied at sunrise or early morning fine mist (05:00–09:00)');
        }

        if (cloudCover != null) {
          if (cloudCover <= 50.0) {
            positive.add('Sunny / Low cloud cover (${cloudCover.round()}%)');
          } else {
            negative.add(
              'Heavy cloud cover (${cloudCover.round()}%) reduces light activation',
            );
          }
        }

        if (windSpeed != null && windSpeed > 6.0) {
          negative.add(
            'Wind too high for fine mist spray (${windSpeed.toStringAsFixed(1)} m/s)',
          );
          weatherOk = false;
        }
        break;

      case BiodynamicPrepType.bd508:
        if (calendarInfo.isGrayDay) {
          negative.add('Gray Day: Avoid spraying during cosmic blackout.');
          astroOk = false;
        }

        if (calendarInfo.moonPhase.isWaxing) {
          positive.add('Waxing Moon / High moisture / lunar vitality window');
        }

        if (calendarInfo.quality == PlantQuality.leaf) {
          positive.add(
            'Leaf Day aligns with fungal prevention on leafy growth',
          );
        }

        if (temperature != null) {
          if (temperature >= 10.0 && temperature <= 28.0) {
            positive.add(
              'Favorable temperature range (10–28°C: ${temperature.round()}°C)',
            );
          } else if (temperature < 5.0) {
            negative.add('Cold temperature (< 5°C) inhibits effectiveness');
            weatherOk = false;
          } else if (temperature > 30.0) {
            negative.add('High temperature (> 30°C) causes rapid evaporation');
            weatherOk = false;
          }
        }

        if (windSpeed != null) {
          if (windSpeed <= 6.0) {
            positive.add('Calm / light wind (<= 6 m/s)');
          } else if (windSpeed > 8.0) {
            negative.add(
              'Wind too high for spray application (> 8 m/s: ${windSpeed.toStringAsFixed(1)} m/s)',
            );
            weatherOk = false;
          } else {
            negative.add(
              'Moderate wind speed (${windSpeed.toStringAsFixed(1)} m/s)',
            );
          }
        }

        if (precipitation != null) {
          if (precipitation > 0.1 && precipitation < 5.0) {
            positive.add(
              'Moist atmospheric conditions enhance BD 508 effectiveness',
            );
          } else if (precipitation >= 5.0) {
            negative.add('Heavy rain washes away spray');
            weatherOk = false;
          }
        }

        if (time.hour < 5 || time.hour > 20) {
          negative.add('Night hours: Spray during daylight for photosynthesis');
          astroOk = false;
        }
        break;

      default:
        break;
    }

    PrepSuitabilityLevel level;
    if (astroOk && weatherOk && negative.isEmpty) {
      level = PrepSuitabilityLevel.optimal;
    } else if (astroOk && weatherOk) {
      level = PrepSuitabilityLevel.moderate;
    } else {
      level = PrepSuitabilityLevel.unfavorable;
    }

    return PrepSuitability(
      level: level,
      positiveFactors: positive,
      negativeFactors: negative,
      weatherSuitable: weatherOk,
      astronomicalSuitable: astroOk,
    );
  }

  /// Returns seasonal concoction, burial, and retrieval status for [prep] at [date] and [latitude].
  static BurialStageInfo getBurialStatus({
    required BiodynamicPrepType prep,
    required DateTime date,
    required double latitude,
  }) {
    final isNorthern = latitude >= 0;
    // Normalize month index for Southern Hemisphere if applicable (shift by 6 months)
    int month = date.month;
    if (!isNorthern) {
      month = ((month + 5) % 12) + 1;
    }

    final hemisphereText = isNorthern
        ? 'Northern Hemisphere'
        : 'Southern Hemisphere';

    switch (prep) {
      case BiodynamicPrepType.bd500:
        if (month >= 9 && month <= 11) {
          return BurialStageInfo(
            stage: 'Burial Window (Autumn)',
            description:
                'Pack manure into cow horns and bury 30-50cm in fertile soil ($hemisphereText).',
            recommendedAction:
                'Bury BD 500 horns during Descending Moon in Autumn.',
            isActiveWindow: true,
          );
        } else if (month >= 12 || month <= 2) {
          return BurialStageInfo(
            stage: 'Underground Fermentation (Winter)',
            description: 'Horns absorb earth forces and cosmic magnetism during cold months.',
            recommendedAction: 'Allow horns to rest undisturbed in soil.',
            isActiveWindow: false,
          );
        } else if (month >= 3 && month <= 5) {
          return BurialStageInfo(
            stage: 'Retrieval Window (Spring)',
            description: 'Unearth horns. Manure should be transformed into dark, sweet-smelling humus.',
            recommendedAction: 'Retrieve BD 500 horns and store in wooden boxes surrounded by peat/coir.',
            isActiveWindow: true,
          );
        } else {
          return BurialStageInfo(
            stage: 'Storage / Usage Season (Summer)',
            description: 'Prep stored in dark container ready for spring/autumn soil applications.',
            recommendedAction: 'Keep moist in cool storage.',
            isActiveWindow: false,
          );
        }

      case BiodynamicPrepType.bd501:
        if (month >= 3 && month <= 5) {
          return BurialStageInfo(
            stage: 'Burial Window (Spring)',
            description:
                'Pack fine quartz paste into horns and bury in sunny ground ($hemisphereText).',
            recommendedAction:
                'Bury BD 501 horns to capture summer sun forces.',
            isActiveWindow: true,
          );
        } else if (month >= 6 && month <= 8) {
          return BurialStageInfo(
            stage: 'Summer Sun Absorption',
            description: 'Quartz captures intense solar light and summer astral impulses.',
            recommendedAction: 'Maintain clean, unshaded burial plot.',
            isActiveWindow: false,
          );
        } else if (month >= 9 && month <= 11) {
          return BurialStageInfo(
            stage: 'Retrieval Window (Autumn)',
            description: 'Unearth silica horns before heavy winter frost.',
            recommendedAction:
                'Retrieve BD 501 and store in glass jars in direct sunlight.',
            isActiveWindow: true,
          );
        } else {
          return BurialStageInfo(
            stage: 'Storage / Solar Exposure (Winter)',
            description: 'Stored in clear glass in window sill receiving direct sunlight.',
            recommendedAction: 'Ready for early morning spring spray.',
            isActiveWindow: false,
          );
        }

      case BiodynamicPrepType.bd502:
      case BiodynamicPrepType.bd503:
      case BiodynamicPrepType.bd504:
      case BiodynamicPrepType.bd505:
      case BiodynamicPrepType.bd506:
      case BiodynamicPrepType.bd507:
        if (month >= 9 || month <= 2) {
          return BurialStageInfo(
            stage: 'Compost Insertion & Winter Ripening',
            description:
                '${prep.commonName} herbal preparation active in compost heap ($hemisphereText).',
            recommendedAction:
                'Insert small portion into 50cm deep hole in compost pile.',
            isActiveWindow: true,
          );
        } else {
          return BurialStageInfo(
            stage: 'Humification & Soil Integration',
            description:
                'Compost preps transforming organic heap into rich humus.',
            recommendedAction: 'Keep compost pile moist and covered.',
            isActiveWindow: false,
          );
        }

      case BiodynamicPrepType.bd508:
        return const BurialStageInfo(
          stage: 'Fresh Tea / Decoction Preparation',
          description: 'Boil dried horsetail (Equisetum arvense) for 20-60 mins to extract silica.',
          recommendedAction:
              'Stir for 20 mins and spray during humid/fungal periods.',
          isActiveWindow: true,
        );
    }
  }

  /// Searches forward or backward from [startTime] for the next/previous optimal spray window for [prep],
  /// skipping past any contiguous optimal window [startTime] is currently within.
  static DateTime? findOptimalWindow({
    required BiodynamicPrepType prep,
    required DateTime startTime,
    required EphemerisService ephemeris,
    required bool searchForward,
    int maxDaysSearch = 60,
  }) {
    if (prep.category != PrepCategory.fieldSpray) {
      return null;
    }

    final step = searchForward
        ? const Duration(hours: 1)
        : const Duration(hours: -1);
    DateTime current = startTime;
    final limit = startTime.add(
      Duration(days: searchForward ? maxDaysSearch : -maxDaysSearch),
    );

    // Evaluate initial suitability of startTime
    final startInfo = algo.getCalendarInfo(
      current,
      ephemeris,
      includePlanets: true,
    );
    final startSuitability = evaluateSpray(
      prep: prep,
      time: current,
      calendarInfo: startInfo,
    );
    final bool startIsOptimal = _isOptimalWindow(startSuitability);

    // If starting inside an optimal window, advance until exiting current contiguous window
    if (startIsOptimal) {
      while (searchForward ? current.isBefore(limit) : current.isAfter(limit)) {
        final nextTime = current.add(step);
        final info = algo.getCalendarInfo(
          nextTime,
          ephemeris,
          includePlanets: true,
        );
        final suitability = evaluateSpray(
          prep: prep,
          time: nextTime,
          calendarInfo: info,
        );

        current = nextTime;
        if (!_isOptimalWindow(suitability)) {
          break;
        }
      }
    } else {
      current = current.add(step);
    }

    // Search for the next/previous distinct optimal window
    while (searchForward ? current.isBefore(limit) : current.isAfter(limit)) {
      final info = algo.getCalendarInfo(
        current,
        ephemeris,
        includePlanets: true,
      );
      final suitability = evaluateSpray(
        prep: prep,
        time: current,
        calendarInfo: info,
      );

      if (_isOptimalWindow(suitability)) {
        return current;
      }

      current = current.add(step);
    }

    return null;
  }

  static bool _isOptimalWindow(PrepSuitability suitability) {
    if (suitability.level == PrepSuitabilityLevel.optimal) {
      return true;
    }
    return suitability.astronomicalSuitable &&
        suitability.negativeFactors.isEmpty;
  }
}
