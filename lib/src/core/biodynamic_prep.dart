import '../services/ephemeris_service.dart';
import 'algorithm.dart' as algo;
import 'seasonal_calendar.dart';

/// Categories of biodynamic preparations.
enum PrepCategory { fieldSpray, compostPrep }

/// Individual biodynamic preparations (BD 500 to BD 508, plus CPP).
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
  ),
  cpp(
    'CPP',
    'Cow Pat Pit (Maria Thun Barrel Compost)',
    PrepCategory.fieldSpray,
    'Concentrated barrel compost inoculating soil with all compost preparations, basalt, and eggshell forces.',
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

  /// Traditional sheath organ or container used during fermentation and seasonal burial.
  String get sheathOrgan {
    switch (this) {
      case BiodynamicPrepType.bd500:
        return 'Cow horn (Bovine cornu)';
      case BiodynamicPrepType.bd501:
        return 'Cow horn (Bovine cornu)';
      case BiodynamicPrepType.bd502:
        return "Stag's bladder (Cervus elaphus urinary bladder)";
      case BiodynamicPrepType.bd503:
        return 'Bovine small intestine (Cow intestine)';
      case BiodynamicPrepType.bd504:
        return 'Soil & peat mantle (organ-free, full 1-year burial)';
      case BiodynamicPrepType.bd505:
        return 'Domestic animal skull (Bovine or sheep cranium)';
      case BiodynamicPrepType.bd506:
        return 'Bovine mesentery (Cow peritoneum / caul)';
      case BiodynamicPrepType.bd507:
        return 'Amber glass bottle (Liquid flower fermentation)';
      case BiodynamicPrepType.bd508:
        return 'None (Fresh or dried herb decoction)';
      case BiodynamicPrepType.cpp:
        return 'Sunken oak barrel / earthen pit';
    }
  }
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
  final String? sheathOrgan;

  const BurialStageInfo({
    required this.stage,
    required this.description,
    required this.recommendedAction,
    required this.isActiveWindow,
    this.sheathOrgan,
  });
}

/// Seasonal cycle progress tracking Michaelmas (Sept 29) to Easter burial rhythms.
final class BurialCycleProgress {
  final String seasonName;
  final String stageDescription;
  final double progressFraction;
  final bool isUndergroundBurial;
  final DateTime michaelmas;
  final DateTime easter;

  const BurialCycleProgress({
    required this.seasonName,
    required this.stageDescription,
    required this.progressFraction,
    required this.isUndergroundBurial,
    required this.michaelmas,
    required this.easter,
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
          positive.add(
            'Late Afternoon / Evening window (15:00–20:00, Sun setting)',
          );
        } else {
          negative.add(
            'Best applied in late afternoon or early evening (15:00–20:00)',
          );
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
          negative.add(
            'Best applied at sunrise or early morning fine mist (05:00–09:00)',
          );
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

      case BiodynamicPrepType.cpp:
        if (calendarInfo.isGrayDay) {
          negative.add('Gray Day: Avoid spraying during cosmic blackout.');
          astroOk = false;
        }

        if (isDescending) {
          positive.add(
            'Descending Moon (Earth Inhalation draws barrel compost vitality into soil)',
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
          positive.add(
            'Late Afternoon / Evening window (15:00–20:00, Earth Inhalation)',
          );
        } else {
          negative.add(
            'Best applied in late afternoon or early evening during Earth Inhalation (15:00–20:00)',
          );
        }

        if (temperature != null) {
          if (temperature >= 8.0) {
            positive.add(
              'Favorable temperature (>= 8°C: ${temperature.round()}°C)',
            );
          } else {
            negative.add(
              'Cold temperature (< 8°C: ${temperature.round()}°C) inhibits soil biological activity',
            );
            weatherOk = false;
          }
        }

        if (windSpeed != null) {
          if (windSpeed <= 5.0) {
            positive.add(
              'Calm wind (<= 5 m/s: ${windSpeed.toStringAsFixed(1)} m/s)',
            );
          } else {
            negative.add(
              'Wind speed too high for soil spray (> 5 m/s: ${windSpeed.toStringAsFixed(1)} m/s)',
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
      month = southernHemisphereMonth(month);
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
            sheathOrgan: prep.sheathOrgan,
          );
        } else if (month >= 12 || month <= 2) {
          return BurialStageInfo(
            stage: 'Underground Fermentation (Winter)',
            description:
                'Horns absorb earth forces and cosmic magnetism during cold months.',
            recommendedAction: 'Allow horns to rest undisturbed in soil.',
            isActiveWindow: false,
            sheathOrgan: prep.sheathOrgan,
          );
        } else if (month >= 3 && month <= 5) {
          return BurialStageInfo(
            stage: 'Retrieval Window (Spring)',
            description:
                'Unearth horns. Manure should be transformed into dark, sweet-smelling humus.',
            recommendedAction:
                'Retrieve BD 500 horns and store in wooden boxes surrounded by peat/coir.',
            isActiveWindow: true,
            sheathOrgan: prep.sheathOrgan,
          );
        } else {
          return BurialStageInfo(
            stage: 'Storage / Usage Season (Summer)',
            description:
                'Prep stored in dark container ready for spring/autumn soil applications.',
            recommendedAction: 'Keep moist in cool storage.',
            isActiveWindow: false,
            sheathOrgan: prep.sheathOrgan,
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
            sheathOrgan: prep.sheathOrgan,
          );
        } else if (month >= 6 && month <= 8) {
          return BurialStageInfo(
            stage: 'Summer Sun Absorption',
            description:
                'Quartz captures intense solar light and summer astral impulses.',
            recommendedAction: 'Maintain clean, unshaded burial plot.',
            isActiveWindow: false,
            sheathOrgan: prep.sheathOrgan,
          );
        } else if (month >= 9 && month <= 11) {
          return BurialStageInfo(
            stage: 'Retrieval Window (Autumn)',
            description: 'Unearth silica horns before heavy winter frost.',
            recommendedAction:
                'Retrieve BD 501 and store in glass jars in direct sunlight.',
            isActiveWindow: true,
            sheathOrgan: prep.sheathOrgan,
          );
        } else {
          return BurialStageInfo(
            stage: 'Storage / Solar Exposure (Winter)',
            description:
                'Stored in clear glass in window sill receiving direct sunlight.',
            recommendedAction: 'Ready for early morning spring spray.',
            isActiveWindow: false,
            sheathOrgan: prep.sheathOrgan,
          );
        }

      case BiodynamicPrepType.bd502:
        final organ502 = prep.sheathOrgan;
        if (month == 9 || month == 10) {
          return BurialStageInfo(
            stage: 'Michaelmas Burial Window (Autumn)',
            description:
                'Pack yarrow blossoms into stag’s bladder and bury 30cm deep in topsoil at Michaelmas ($hemisphereText).',
            recommendedAction:
                'Bury BD 502 stag’s bladder in fertile soil around Michaelmas (Sept 29).',
            isActiveWindow: true,
            sheathOrgan: organ502,
          );
        } else if (month >= 11 || month <= 2) {
          return BurialStageInfo(
            stage: 'Subterranean Winter Ripening (Winter)',
            description:
                'Yarrow stag’s bladder absorbs sulfur and potassium forces in winter soil ($hemisphereText).',
            recommendedAction:
                'Allow yarrow preparation to rest undisturbed underground.',
            isActiveWindow: false,
            sheathOrgan: organ502,
          );
        } else if (month == 3 || month == 4) {
          return BurialStageInfo(
            stage: 'Easter Retrieval Window (Spring)',
            description:
                'Unearth BD 502 around Easter; blossoms have transformed into dark humified substance ($hemisphereText).',
            recommendedAction:
                'Retrieve BD 502 from bladder and store in crocks lined with moist peat moss.',
            isActiveWindow: true,
            sheathOrgan: organ502,
          );
        } else {
          return BurialStageInfo(
            stage: 'Compost Inoculation & Summer Sun (Summer)',
            description:
                'Store mature BD 502 in peat or hang fresh blossoms in stag’s bladder in summer sunlight ($hemisphereText).',
            recommendedAction:
                'Inoculate compost heaps (1-2g per pile) or hang newly gathered blossoms in sun.',
            isActiveWindow: false,
            sheathOrgan: organ502,
          );
        }

      case BiodynamicPrepType.bd503:
        final organ503 = prep.sheathOrgan;
        if (month == 9 || month == 10) {
          return BurialStageInfo(
            stage: 'Michaelmas Burial Window (Autumn)',
            description:
                'Pack dried chamomile flowers into bovine small intestine casings and bury at Michaelmas ($hemisphereText).',
            recommendedAction:
                'Bury BD 503 chamomile sausages in fertile soil around Michaelmas (Sept 29).',
            isActiveWindow: true,
            sheathOrgan: organ503,
          );
        } else if (month >= 11 || month <= 2) {
          return BurialStageInfo(
            stage: 'Subterranean Winter Ripening (Winter)',
            description:
                'Chamomile intestines absorb winter calcium and nitrogen forces in cold soil ($hemisphereText).',
            recommendedAction:
                'Rest undisturbed beneath winter frost and snow.',
            isActiveWindow: false,
            sheathOrgan: organ503,
          );
        } else if (month == 3 || month == 4) {
          return BurialStageInfo(
            stage: 'Easter Retrieval Window (Spring)',
            description:
                'Unearth BD 503 around Easter; transformed into fragrant, living compost inoculum ($hemisphereText).',
            recommendedAction:
                'Harvest fermented chamomile from casings and store in glazed crocks with peat.',
            isActiveWindow: true,
            sheathOrgan: organ503,
          );
        } else {
          return BurialStageInfo(
            stage: 'Compost Inoculation & Storage (Summer)',
            description:
                'BD 503 stabilized to regulate nitrogen and calcium breakdown in compost ($hemisphereText).',
            recommendedAction:
                'Insert small portions into compost heaps or cow pat pit.',
            isActiveWindow: false,
            sheathOrgan: organ503,
          );
        }

      case BiodynamicPrepType.bd504:
        final organ504 = prep.sheathOrgan;
        if (month == 9 || month == 10) {
          return BurialStageInfo(
            stage: 'Michaelmas Burial Window (Autumn)',
            description:
                'Pack whole stinging nettle plants into an earthen trench encased in peat mantle ($hemisphereText).',
            recommendedAction:
                'Bury fresh nettle plants surrounded by 5cm peat mantle around Michaelmas for full year.',
            isActiveWindow: true,
            sheathOrgan: organ504,
          );
        } else if (month >= 11 || month <= 2) {
          return BurialStageInfo(
            stage: 'Subterranean Humification (Winter)',
            description:
                'Nettle decomposes slowly underground, structuring iron balance and soil intelligence ($hemisphereText).',
            recommendedAction:
                'Maintain peat layer and undisturbed soil cover.',
            isActiveWindow: false,
            sheathOrgan: organ504,
          );
        } else if (month == 3 || month == 4) {
          return BurialStageInfo(
            stage: 'Spring Earth Fermentation (Spring)',
            description:
                'Nettle continuing its year-long subterranean transformation ($hemisphereText).',
            recommendedAction:
                'Keep covered; full year burial concludes the following Michaelmas.',
            isActiveWindow: false,
            sheathOrgan: organ504,
          );
        } else {
          return BurialStageInfo(
            stage: 'Summer Maturation (Summer)',
            description:
                'Nettle transforms into rich, black humic substance in summer warmth ($hemisphereText).',
            recommendedAction:
                'Prepare storage crocks for Michaelmas unearthing.',
            isActiveWindow: false,
            sheathOrgan: organ504,
          );
        }

      case BiodynamicPrepType.bd505:
        final organ505 = prep.sheathOrgan;
        if (month == 9 || month == 10) {
          return BurialStageInfo(
            stage: 'Michaelmas Burial Window (Autumn)',
            description:
                'Pack scraped oak bark into skull cavity and bury in a marshy ditch or wet mud ($hemisphereText).',
            recommendedAction:
                'Bury filled skull in water runoff or boggy ground around Michaelmas (Sept 29).',
            isActiveWindow: true,
            sheathOrgan: organ505,
          );
        } else if (month >= 11 || month <= 2) {
          return BurialStageInfo(
            stage: 'Watery Winter Ripening (Winter)',
            description:
                'Oak bark absorbs watery calcium forces in swampy, freezing environment ($hemisphereText).',
            recommendedAction:
                'Keep skull submerged in moist/marshy conditions.',
            isActiveWindow: false,
            sheathOrgan: organ505,
          );
        } else if (month == 3 || month == 4) {
          return BurialStageInfo(
            stage: 'Easter Retrieval Window (Spring)',
            description:
                'Unearth BD 505 skull around Easter; calcium forces transformed to prevent plant rot ($hemisphereText).',
            recommendedAction:
                'Retrieve oak bark humus from skull cavity and store in peat-lined earthenware.',
            isActiveWindow: true,
            sheathOrgan: organ505,
          );
        } else {
          return BurialStageInfo(
            stage: 'Compost Inoculation & Storage (Summer)',
            description:
                'BD 505 oak bark ready to buffer fungal proliferation and regulate calcium ($hemisphereText).',
            recommendedAction:
                'Insert into compost piles or barrel compost to resist plant diseases.',
            isActiveWindow: false,
            sheathOrgan: organ505,
          );
        }

      case BiodynamicPrepType.bd506:
        final organ506 = prep.sheathOrgan;
        if (month == 9 || month == 10) {
          return BurialStageInfo(
            stage: 'Michaelmas Burial Window (Autumn)',
            description:
                'Enfold dried dandelion flowers in bovine mesentery (cow caul) and stitch closed ($hemisphereText).',
            recommendedAction:
                'Bury BD 506 mesentery parcels in fertile topsoil at Michaelmas (Sept 29).',
            isActiveWindow: true,
            sheathOrgan: organ506,
          );
        } else if (month >= 11 || month <= 2) {
          return BurialStageInfo(
            stage: 'Subterranean Winter Ripening (Winter)',
            description:
                'Dandelion mesentery gathers planetary forces and silica affinity during winter ($hemisphereText).',
            recommendedAction: 'Rest undisturbed in cold earth.',
            isActiveWindow: false,
            sheathOrgan: organ506,
          );
        } else if (month == 3 || month == 4) {
          return BurialStageInfo(
            stage: 'Easter Retrieval Window (Spring)',
            description:
                'Unearth BD 506 around Easter; flowers transformed into light-sensitive humus ($hemisphereText).',
            recommendedAction:
                'Retrieve decomposed dandelion from mesentery and store in glass jar with peat.',
            isActiveWindow: true,
            sheathOrgan: organ506,
          );
        } else {
          return BurialStageInfo(
            stage: 'Compost Inoculation & Harvest (Summer)',
            description:
                'Harvest fresh dandelion blossoms on sunny mornings and store previous year’s prep ($hemisphereText).',
            recommendedAction:
                'Pick yellow flower heads on sunny spring/summer mornings for autumn burial.',
            isActiveWindow: false,
            sheathOrgan: organ506,
          );
        }

      case BiodynamicPrepType.bd507:
        final organ507 = prep.sheathOrgan;
        if (month == 9 || month == 10) {
          return BurialStageInfo(
            stage: 'Autumn Compost Finishing',
            description:
                'Valerian fermented blossom juice stored in amber glass; warmth mantle over compost ($hemisphereText).',
            recommendedAction:
                'Dilute a few drops in warm water, stir 10 mins, spray over completed compost pile.',
            isActiveWindow: true,
            sheathOrgan: organ507,
          );
        } else if (month >= 11 || month <= 2) {
          return BurialStageInfo(
            stage: 'Winter Warmth Mantle',
            description:
                'Protective warmth envelope preserving inner heat of compost heaps against freezing ($hemisphereText).',
            recommendedAction:
                'Spray over compost heaps or delicate orchard branches before severe frost.',
            isActiveWindow: false,
            sheathOrgan: organ507,
          );
        } else if (month == 3 || month == 4) {
          return BurialStageInfo(
            stage: 'Spring Blossom Protection',
            description:
                'Warmth radiation buffering early fruit tree blossoms against spring frost ($hemisphereText).',
            recommendedAction:
                'Spray fine mist over evening blossoms when frost threatens.',
            isActiveWindow: true,
            sheathOrgan: organ507,
          );
        } else {
          return BurialStageInfo(
            stage: 'Blossom Extraction Season (Summer)',
            description:
                'Harvest fragrant valerian blossoms in summer evening; press and ferment flower juice ($hemisphereText).',
            recommendedAction:
                'Bottle fermented juice in dark amber glass; keeps for years.',
            isActiveWindow: true,
            sheathOrgan: organ507,
          );
        }

      case BiodynamicPrepType.bd508:
        return const BurialStageInfo(
          stage: 'Fresh Tea / Decoction Preparation',
          description:
              'Boil dried horsetail (Equisetum arvense) for 20-60 mins to extract silica.',
          recommendedAction:
              'Stir for 20 mins and spray during humid/fungal periods.',
          isActiveWindow: true,
          sheathOrgan: 'None (Fresh or dried herb decoction)',
        );

      case BiodynamicPrepType.cpp:
        final organCpp = prep.sheathOrgan;
        if (month == 9 || month == 10) {
          return BurialStageInfo(
            stage: 'Autumn Barrel Inoculation',
            description:
                'Mix fresh cow manure with basalt and eggshells; inoculate with BD 502–507 in sunken oak barrel ($hemisphereText).',
            recommendedAction:
                'Stir 1 hour initially, place into half-sunken wooden barrel, insert preps 502–507.',
            isActiveWindow: true,
            sheathOrgan: organCpp,
          );
        } else if (month >= 11 || month <= 2) {
          return BurialStageInfo(
            stage: 'Subterranean Barrel Humification (Winter)',
            description:
                'Barrel compost matures underground for 2–3 months into colloidal humus ($hemisphereText).',
            recommendedAction:
                'Keep covered with wooden lid or moist sacking; protect from drying.',
            isActiveWindow: false,
            sheathOrgan: organCpp,
          );
        } else if (month == 3 || month == 4) {
          return BurialStageInfo(
            stage: 'Spring Soil Application Window',
            description:
                'Mature Maria Thun Barrel Compost ready to energize spring soil microbiology ($hemisphereText).',
            recommendedAction:
                'Dynamize 35g/100m² in lukewarm water for 20 minutes; apply to soil in late afternoon.',
            isActiveWindow: true,
            sheathOrgan: organCpp,
          );
        } else {
          return BurialStageInfo(
            stage: 'Summer Compost & Soil Maintenance',
            description:
                'Use mature CPP as starter inoculant for summer compost piles or liquid manure teas ($hemisphereText).',
            recommendedAction:
                'Apply during Descending Moon evenings or add to summer heaps.',
            isActiveWindow: false,
            sheathOrgan: organCpp,
          );
        }
    }
  }

  /// Computes the seasonal burial cycle progress between Michaelmas (Sept 29) and Easter (~April 5).
  /// Returns a [BurialCycleProgress] representing progress and current stage.
  static BurialCycleProgress getSeasonalBurialProgress(
    DateTime date, {
    double latitude = 50.0,
  }) {
    final isNorthern = latitude >= 0;
    // Normalize date for southern hemisphere (shift 6 months) if needed.
    final effectiveDate = toNorthernSeasonEquivalent(
      date,
      isNorthern: isNorthern,
    );

    final year = effectiveDate.year;
    final thisYearMichaelmas = DateTime(year, 9, 29);
    final thisYearEaster = gregorianEaster(year);

    bool isUnderground;
    double progress;
    String seasonName;
    String stageDescription;
    DateTime michaelmas;
    DateTime easter;

    if (effectiveDate.isBefore(thisYearEaster)) {
      michaelmas = DateTime(year - 1, 9, 29);
      easter = thisYearEaster;
      isUnderground = true;
      final totalDays = easter.difference(michaelmas).inDays;
      final elapsed = effectiveDate.difference(michaelmas).inDays;
      progress = (elapsed / totalDays).clamp(0.0, 1.0);
      seasonName = 'Winter Subterranean Ripening';
      stageDescription =
          'Preparations resting underground from Michaelmas (Sept 29) to Easter (${(progress * 100).round()}% through winter burial).';
    } else if (effectiveDate.isBefore(thisYearMichaelmas)) {
      easter = thisYearEaster;
      michaelmas = thisYearMichaelmas;
      isUnderground = false;
      final totalDays = michaelmas.difference(easter).inDays;
      final elapsed = effectiveDate.difference(easter).inDays;
      progress = (elapsed / totalDays).clamp(0.0, 1.0);
      seasonName = 'Summer Compost & Maturation Season';
      stageDescription =
          'Preparations unburied at Easter and active in compost & summer sun (${(progress * 100).round()}% to next Michaelmas).';
    } else {
      michaelmas = thisYearMichaelmas;
      easter = gregorianEaster(year + 1);
      isUnderground = true;
      final totalDays = easter.difference(michaelmas).inDays;
      final elapsed = effectiveDate.difference(michaelmas).inDays;
      progress = (elapsed / totalDays).clamp(0.0, 1.0);
      seasonName = 'Michaelmas Burial Window';
      stageDescription =
          'Preparations sheathed in organs and buried around Michaelmas (Sept 29) (${(progress * 100).round()}% into winter burial).';
    }

    return BurialCycleProgress(
      seasonName: seasonName,
      stageDescription: stageDescription,
      progressFraction: progress,
      isUndergroundBurial: isUnderground,
      michaelmas: michaelmas,
      easter: easter,
    );
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
