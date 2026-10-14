import 'dart:math' as math;

import 'monthly_climate_normals.dart';

/// The five main Köppen–Geiger climate groups.
enum KoppenGroup {
  /// Tropical: every month averages at least 18 °C.
  tropical('A', 'Tropical'),

  /// Arid: precipitation falls short of the dryness threshold.
  arid('B', 'Arid'),

  /// Temperate: the coldest month averages between 0 °C and 18 °C.
  temperate('C', 'Temperate'),

  /// Cold (continental): the coldest month averages 0 °C or below.
  cold('D', 'Cold'),

  /// Polar: no month averages above 10 °C.
  polar('E', 'Polar');

  /// The capital letter that starts every class code in this group.
  final String letter;

  /// English name of the group.
  final String displayName;

  const KoppenGroup(this.letter, this.displayName);
}

/// The 30 Köppen–Geiger climate classes of Beck et al. (2018).
///
/// Enum value names are the lower-cased class codes, so `KoppenClass.cfb`
/// has [code] `Cfb`.
///
/// See: Beck, H.E. et al. (2018), "Present and future Köppen-Geiger climate
/// classification maps at 1-km resolution", *Scientific Data* 5, 180214,
/// <https://doi.org/10.1038/sdata.2018.214>.
enum KoppenClass {
  /// Tropical rainforest.
  af('Af', KoppenGroup.tropical, 'Tropical, rainforest'),

  /// Tropical monsoon.
  am('Am', KoppenGroup.tropical, 'Tropical, monsoon'),

  /// Tropical savannah.
  aw('Aw', KoppenGroup.tropical, 'Tropical, savannah'),

  /// Hot desert.
  bwh('BWh', KoppenGroup.arid, 'Arid, desert, hot'),

  /// Cold desert.
  bwk('BWk', KoppenGroup.arid, 'Arid, desert, cold'),

  /// Hot steppe.
  bsh('BSh', KoppenGroup.arid, 'Arid, steppe, hot'),

  /// Cold steppe.
  bsk('BSk', KoppenGroup.arid, 'Arid, steppe, cold'),

  /// Mediterranean, hot summer.
  csa('Csa', KoppenGroup.temperate, 'Temperate, dry summer, hot summer'),

  /// Mediterranean, warm summer.
  csb('Csb', KoppenGroup.temperate, 'Temperate, dry summer, warm summer'),

  /// Mediterranean, cold summer.
  csc('Csc', KoppenGroup.temperate, 'Temperate, dry summer, cold summer'),

  /// Monsoon-influenced humid subtropical.
  cwa('Cwa', KoppenGroup.temperate, 'Temperate, dry winter, hot summer'),

  /// Subtropical highland.
  cwb('Cwb', KoppenGroup.temperate, 'Temperate, dry winter, warm summer'),

  /// Cold subtropical highland.
  cwc('Cwc', KoppenGroup.temperate, 'Temperate, dry winter, cold summer'),

  /// Humid subtropical.
  cfa('Cfa', KoppenGroup.temperate, 'Temperate, no dry season, hot summer'),

  /// Temperate oceanic.
  cfb('Cfb', KoppenGroup.temperate, 'Temperate, no dry season, warm summer'),

  /// Subpolar oceanic.
  cfc('Cfc', KoppenGroup.temperate, 'Temperate, no dry season, cold summer'),

  /// Continental, dry hot summer.
  dsa('Dsa', KoppenGroup.cold, 'Cold, dry summer, hot summer'),

  /// Continental, dry warm summer.
  dsb('Dsb', KoppenGroup.cold, 'Cold, dry summer, warm summer'),

  /// Continental, dry cold summer.
  dsc('Dsc', KoppenGroup.cold, 'Cold, dry summer, cold summer'),

  /// Continental, dry summer, very cold winter.
  dsd('Dsd', KoppenGroup.cold, 'Cold, dry summer, very cold winter'),

  /// Continental, dry winter, hot summer.
  dwa('Dwa', KoppenGroup.cold, 'Cold, dry winter, hot summer'),

  /// Continental, dry winter, warm summer.
  dwb('Dwb', KoppenGroup.cold, 'Cold, dry winter, warm summer'),

  /// Continental, dry winter, cold summer.
  dwc('Dwc', KoppenGroup.cold, 'Cold, dry winter, cold summer'),

  /// Continental, dry and very cold winter.
  dwd('Dwd', KoppenGroup.cold, 'Cold, dry winter, very cold winter'),

  /// Humid continental, hot summer.
  dfa('Dfa', KoppenGroup.cold, 'Cold, no dry season, hot summer'),

  /// Humid continental, warm summer.
  dfb('Dfb', KoppenGroup.cold, 'Cold, no dry season, warm summer'),

  /// Subarctic.
  dfc('Dfc', KoppenGroup.cold, 'Cold, no dry season, cold summer'),

  /// Subarctic, very cold winter.
  dfd('Dfd', KoppenGroup.cold, 'Cold, no dry season, very cold winter'),

  /// Tundra.
  et('ET', KoppenGroup.polar, 'Polar, tundra'),

  /// Ice cap.
  ef('EF', KoppenGroup.polar, 'Polar, frost');

  /// The conventional class code, e.g. `Cfb`.
  final String code;

  /// The main group this class belongs to.
  final KoppenGroup group;

  /// English description in the wording of Beck et al. (2018), Table 1.
  final String description;

  const KoppenClass(this.code, this.group, this.description);

  /// Whether the second letter is `s`: the summer half-year is dry.
  bool get hasDrySummer => code.length == 3 && code[1] == 's';

  /// Whether the second letter is `w`: the winter half-year is dry.
  bool get hasDryWinter => code.length == 3 && code[1] == 'w';

  /// Whether the third letter is `a`: the warmest month averages at least
  /// 22 °C.
  bool get hasHotSummer =>
      group != KoppenGroup.arid && code.length == 3 && code[2] == 'a';

  /// Whether the third letter is `d`: the coldest month averages below
  /// −38 °C.
  bool get hasVeryColdWinter => code.length == 3 && code[2] == 'd';

  /// The class whose [code] is [code], or null if there is none.
  ///
  /// The match is exact, so `cfb` and `CFB` are not recognised.
  static KoppenClass? tryParse(String code) {
    for (final value in values) {
      if (value.code == code) return value;
    }
    return null;
  }

  /// Classifies [normals] with the criteria of Beck et al. (2018), Table 2.
  ///
  /// Summer is whichever of April–September and October–March is warmer.
  /// When both the dry-summer (`s`) and the dry-winter (`w`) criteria hold,
  /// the half-year with more precipitation is taken to be the wet one, as
  /// in Peel et al. (2007).
  ///
  /// See: Peel, M.C., Finlayson, B.L. and McMahon, T.A. (2007), "Updated
  /// world map of the Köppen-Geiger climate classification", *Hydrology and
  /// Earth System Sciences* 11, 1633–1644,
  /// <https://doi.org/10.5194/hess-11-1633-2007>.
  static KoppenClass classify(MonthlyClimateNormals normals) {
    final t = normals.temperature;
    final p = normals.precipitation;
    final meanTemperature = normals.meanAnnualTemperature;
    final annualPrecipitation = normals.annualPrecipitation;
    final coldest = normals.coldestMonthTemperature;
    final warmest = normals.warmestMonthTemperature;

    final summer = normals.summerMonthIndexes;
    final winter = normals.winterMonthIndexes;
    final summerPrecipitation = summer.fold(0.0, (sum, m) => sum + p[m]);
    final winterPrecipitation = winter.fold(0.0, (sum, m) => sum + p[m]);

    final double dryThreshold;
    if (winterPrecipitation > 0.7 * annualPrecipitation) {
      dryThreshold = 2 * meanTemperature;
    } else if (summerPrecipitation > 0.7 * annualPrecipitation) {
      dryThreshold = 2 * meanTemperature + 28;
    } else {
      dryThreshold = 2 * meanTemperature + 14;
    }

    if (annualPrecipitation < 10 * dryThreshold) {
      final isDesert = annualPrecipitation < 5 * dryThreshold;
      final isHot = meanTemperature >= 18;
      return switch ((isDesert, isHot)) {
        (true, true) => bwh,
        (true, false) => bwk,
        (false, true) => bsh,
        (false, false) => bsk,
      };
    }

    if (coldest >= 18) {
      final driest = p.reduce(math.min);
      if (driest >= 60) return af;
      return driest >= 100 - annualPrecipitation / 25 ? am : aw;
    }

    if (warmest <= 10) return warmest > 0 ? et : ef;

    final summerDriest = summer.map((m) => p[m]).reduce(math.min);
    final summerWettest = summer.map((m) => p[m]).reduce(math.max);
    final winterDriest = winter.map((m) => p[m]).reduce(math.min);
    final winterWettest = winter.map((m) => p[m]).reduce(math.max);
    final drySummer = summerDriest < 40 && summerDriest < winterWettest / 3;
    final dryWinter = winterDriest < summerWettest / 10;
    final precipitationLetter = switch ((drySummer, dryWinter)) {
      (true, true) => summerPrecipitation > winterPrecipitation ? 'w' : 's',
      (true, false) => 's',
      (false, true) => 'w',
      (false, false) => 'f',
    };

    final isTemperate = coldest > 0;
    final String heatLetter;
    if (warmest >= 22) {
      heatLetter = 'a';
    } else if (t.where((value) => value > 10).length >= 4) {
      heatLetter = 'b';
    } else if (!isTemperate && coldest < -38) {
      heatLetter = 'd';
    } else {
      heatLetter = 'c';
    }

    final code = '${isTemperate ? 'C' : 'D'}$precipitationLetter$heatLetter';
    return tryParse(code) ??
        (throw StateError('Unreachable: no Köppen class for $code'));
  }
}
