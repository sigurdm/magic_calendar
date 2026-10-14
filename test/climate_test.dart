import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:magic_calendar/src/core/biodynamic_prep.dart';
import 'package:magic_calendar/src/core/ecological_synthesis.dart';
import 'package:magic_calendar/src/core/models/models.dart';
import 'package:magic_calendar/src/core/plant_recommendations.dart';
import 'package:magic_calendar/src/core/task_window_planner.dart';
import 'package:magic_calendar/src/core/vegetable_database.dart';
import 'package:magic_calendar/src/repository/open_meteo_client.dart';
import 'package:magic_calendar/src/services/climate_service.dart';
import 'package:magic_calendar/src/ui/components/climate_details_sheet.dart';
import 'package:magic_calendar/src/ui/components/home_header.dart';

import 'support/fakes.dart';

DailyClimateSeries _buildSyntheticSeries({
  required double meanTempC,
  required double amplitudeC,
  required int warmestDayOfYear,
  required double diurnalHalfRangeC,
  required double dailyPrecipMm,
  int firstYear = 2011,
  int lastYear = 2020,
}) {
  final dates = <DateTime>[];
  final tMean = <double?>[];
  final tMin = <double?>[];
  final precip = <double?>[];

  var day = DateTime.utc(firstYear, 1, 1);
  final end = DateTime.utc(lastYear, 12, 31);
  while (!day.isAfter(end)) {
    final doy = climateDayOfYear(day);
    final angle = 2 * math.pi * (doy - warmestDayOfYear) / climateYearLength;
    final mean = meanTempC + amplitudeC * math.cos(angle);
    dates.add(day);
    tMean.add(mean);
    tMin.add(mean - diurnalHalfRangeC);
    precip.add(dailyPrecipMm);
    day = day.add(const Duration(days: 1));
  }

  return DailyClimateSeries(
    dates: dates,
    meanTemperature: tMean,
    minimumTemperature: tMin,
    precipitation: precip,
    elevation: 50,
  );
}

void main() {
  group('MonthlyClimateNormals', () {
    test('validates month counts and finite values', () {
      expect(
        () => MonthlyClimateNormals(
          temperature: List<double>.filled(11, 10),
          precipitation: List<double>.filled(12, 50),
        ),
        throwsArgumentError,
      );
      expect(
        () => MonthlyClimateNormals(
          temperature: List<double>.filled(12, 10),
          precipitation: List<double>.filled(11, 50),
        ),
        throwsArgumentError,
      );
      expect(
        () => MonthlyClimateNormals(
          temperature: [double.nan, ...List<double>.filled(11, 10)],
          precipitation: List<double>.filled(12, 50),
        ),
        throwsArgumentError,
      );
      expect(
        () => MonthlyClimateNormals(
          temperature: List<double>.filled(12, 10),
          precipitation: [-1, ...List<double>.filled(11, 50)],
        ),
        throwsArgumentError,
      );
    });

    test('defensively copies input lists and round-trips JSON', () {
      final temps = List<double>.generate(12, (i) => i.toDouble());
      final precip = List<double>.generate(12, (i) => (i + 1) * 10.0);
      final normals = MonthlyClimateNormals(
        temperature: temps,
        precipitation: precip,
      );
      temps[0] = 999;
      precip[0] = 999;
      expect(normals.temperature[0], 0);
      expect(normals.precipitation[0], 10);

      final roundTripped = MonthlyClimateNormals.fromJson(normals.toJson());
      expect(roundTripped.temperature, normals.temperature);
      expect(roundTripped.precipitation, normals.precipitation);
    });
  });

  group('KoppenClass.classify', () {
    test('classifies 1991-2020 reference cities accurately', () {
      // Funen DK
      expect(
        KoppenClass.classify(
          MonthlyClimateNormals(
            temperature: const [
              2.3,
              2.2,
              3.7,
              7.1,
              11.5,
              15.1,
              17.6,
              17.9,
              14.8,
              10.8,
              6.7,
              3.6,
            ],
            precipitation: const [
              65,
              49,
              48,
              35,
              50,
              62,
              64,
              73,
              64,
              70,
              62,
              68,
            ],
          ),
        ),
        KoppenClass.cfb,
      );

      // Dornach CH
      expect(
        KoppenClass.classify(
          MonthlyClimateNormals(
            temperature: const [
              1.4,
              2.2,
              5.9,
              9.7,
              13.8,
              17.4,
              19.4,
              19.3,
              15.0,
              10.6,
              5.3,
              2.1,
            ],
            precipitation: const [
              79,
              73,
              83,
              91,
              128,
              116,
              121,
              122,
              94,
              98,
              94,
              101,
            ],
          ),
        ),
        KoppenClass.cfb,
      );

      // Oslo NO
      expect(
        KoppenClass.classify(
          MonthlyClimateNormals(
            temperature: const [
              -3.9,
              -3.2,
              0.4,
              5.6,
              11.2,
              15.3,
              17.7,
              16.5,
              12.3,
              6.8,
              2.1,
              -2.3,
            ],
            precipitation: const [
              71,
              51,
              53,
              55,
              78,
              94,
              100,
              108,
              87,
              93,
              90,
              69,
            ],
          ),
        ),
        KoppenClass.dfb,
      );

      // Tromsø NO
      expect(
        KoppenClass.classify(
          MonthlyClimateNormals(
            temperature: const [
              -8.2,
              -7.9,
              -4.8,
              -0.1,
              4.6,
              9.5,
              13.5,
              12.3,
              8.1,
              1.7,
              -3.7,
              -6.4,
            ],
            precipitation: const [
              108,
              94,
              103,
              86,
              91,
              92,
              91,
              102,
              124,
              129,
              96,
              106,
            ],
          ),
        ),
        KoppenClass.dfc,
      );

      // Seville ES
      expect(
        KoppenClass.classify(
          MonthlyClimateNormals(
            temperature: const [
              10.3,
              11.7,
              14.4,
              16.6,
              20.5,
              25.1,
              28.1,
              28.1,
              24.3,
              19.6,
              14.3,
              11.4,
            ],
            precipitation: const [49, 46, 55, 49, 34, 8, 2, 2, 27, 67, 63, 76],
          ),
        ),
        KoppenClass.csa,
      );

      // Cairo EG
      expect(
        KoppenClass.classify(
          MonthlyClimateNormals(
            temperature: const [
              13.4,
              14.6,
              17.5,
              21.4,
              25.3,
              28.0,
              29.1,
              29.2,
              27.4,
              24.2,
              19.3,
              15.0,
            ],
            precipitation: const [4, 4, 4, 1, 0, 0, 0, 0, 0, 1, 2, 2],
          ),
        ),
        KoppenClass.bwh,
      );

      // Nairobi KE (ERA5 1991-2020)
      expect(
        KoppenClass.classify(
          MonthlyClimateNormals(
            temperature: const [
              19.7,
              20.6,
              20.5,
              19.4,
              18.6,
              17.7,
              17.0,
              17.3,
              18.5,
              19.3,
              18.3,
              18.6,
            ],
            precipitation: const [
              39,
              36,
              62,
              122,
              95,
              40,
              15,
              22,
              19,
              55,
              97,
              53,
            ],
          ),
        ),
        KoppenClass.csb,
      );

      // Singapore
      expect(
        KoppenClass.classify(
          MonthlyClimateNormals(
            temperature: const [
              25.5,
              26.0,
              26.5,
              26.8,
              27.1,
              27.1,
              26.8,
              26.7,
              26.7,
              26.5,
              25.9,
              25.6,
            ],
            precipitation: const [
              203,
              133,
              213,
              255,
              232,
              185,
              169,
              171,
              171,
              252,
              334,
              323,
            ],
          ),
        ),
        KoppenClass.af,
      );

      // Melbourne AU
      expect(
        KoppenClass.classify(
          MonthlyClimateNormals(
            temperature: const [
              20.0,
              19.9,
              18.1,
              15.1,
              12.3,
              10.1,
              9.5,
              10.1,
              11.9,
              14.1,
              16.2,
              18.1,
            ],
            precipitation: const [
              50,
              45,
              35,
              48,
              44,
              51,
              45,
              53,
              61,
              60,
              65,
              59,
            ],
          ),
        ),
        KoppenClass.cfb,
      );

      // Denver US (ERA5 grid Dfa vs station BSk)
      expect(
        KoppenClass.classify(
          MonthlyClimateNormals(
            temperature: const [
              -3.0,
              -1.8,
              3.0,
              7.2,
              13.0,
              19.2,
              22.6,
              21.3,
              17.0,
              9.4,
              1.8,
              -3.3,
            ],
            precipitation: const [
              22,
              22,
              47,
              69,
              79,
              50,
              40,
              39,
              35,
              39,
              30,
              20,
            ],
          ),
        ),
        KoppenClass.dfa,
      );
      expect(
        KoppenClass.classify(
          MonthlyClimateNormals(
            temperature: const [
              -0.2,
              0.9,
              5.3,
              8.9,
              14.3,
              20.3,
              23.8,
              22.7,
              17.9,
              10.6,
              4.1,
              -0.6,
            ],
            precipitation: const [
              10,
              11,
              23,
              43,
              59,
              42,
              50,
              41,
              28,
              23,
              16,
              10,
            ],
          ),
        ),
        KoppenClass.bsk,
      );
    });

    test('resolves Peel et al. (2007) Table 2 Herberton PO s/w tie-break', () {
      // Herberton Post Office, Australia (-17.38°): qualifies for both Cs and Cw;
      // summer wettest month (238.4 mm) > winter wettest month (86.0 mm) -> Cwa.
      final herberton = MonthlyClimateNormals(
        temperature: const [
          23.2,
          22.8,
          21.9,
          20.0,
          17.9,
          16.0,
          15.5,
          16.5,
          18.6,
          21.0,
          22.4,
          23.3,
        ],
        precipitation: const [
          238.4,
          229.7,
          214.4,
          86.0,
          46.9,
          33.3,
          22.0,
          18.2,
          16.5,
          25.3,
          77.3,
          137.9,
        ],
      );
      expect(KoppenClass.classify(herberton), KoppenClass.cwa);
    });

    test('covers remaining Köppen branches and tryParse', () {
      // Am: Tmin >= 18, Pdry < 60, Pdry >= 100 - MAP/25
      expect(
        KoppenClass.classify(
          MonthlyClimateNormals(
            temperature: List<double>.filled(12, 26),
            precipitation: const [
              40,
              200,
              200,
              200,
              200,
              200,
              200,
              200,
              200,
              200,
              200,
              200,
            ],
          ),
        ),
        KoppenClass.am,
      );
      // Aw: Tmin >= 18, Pdry < 100 - MAP/25
      expect(
        KoppenClass.classify(
          MonthlyClimateNormals(
            temperature: List<double>.filled(12, 26),
            precipitation: const [
              10,
              10,
              10,
              100,
              150,
              200,
              200,
              150,
              100,
              50,
              20,
              10,
            ],
          ),
        ),
        KoppenClass.aw,
      );
      // BWk & BSh
      expect(
        KoppenClass.classify(
          MonthlyClimateNormals(
            temperature: const [-5, -2, 4, 10, 16, 21, 24, 22, 16, 9, 2, -3],
            precipitation: List<double>.filled(12, 5),
          ),
        ),
        KoppenClass.bwk,
      );
      expect(
        KoppenClass.classify(
          MonthlyClimateNormals(
            temperature: List<double>.filled(12, 22),
            precipitation: List<double>.filled(12, 30),
          ),
        ),
        KoppenClass.bsh,
      );
      // Cfc, Csc, Cwb, Cwc
      expect(
        KoppenClass.classify(
          MonthlyClimateNormals(
            temperature: const [1, 1, 2, 4, 7, 10, 11, 10, 8, 5, 3, 1],
            precipitation: List<double>.filled(12, 100),
          ),
        ),
        KoppenClass.cfc,
      );
      expect(
        KoppenClass.classify(
          MonthlyClimateNormals(
            temperature: const [1, 1, 2, 4, 7, 10, 11, 10, 8, 5, 3, 1],
            precipitation: const [
              120,
              120,
              100,
              50,
              40,
              20,
              15,
              25,
              40,
              90,
              110,
              120,
            ],
          ),
        ),
        KoppenClass.csc,
      );
      expect(
        KoppenClass.classify(
          MonthlyClimateNormals(
            temperature: const [8, 9, 11, 13, 15, 17, 18, 17, 15, 13, 10, 8],
            precipitation: const [
              10,
              12,
              20,
              60,
              120,
              180,
              200,
              190,
              110,
              40,
              15,
              10,
            ],
          ),
        ),
        KoppenClass.cwb,
      );
      expect(
        KoppenClass.classify(
          MonthlyClimateNormals(
            temperature: const [2, 3, 5, 7, 9, 11, 12, 11, 9, 7, 4, 2],
            precipitation: const [
              5,
              8,
              15,
              50,
              100,
              150,
              180,
              160,
              90,
              30,
              10,
              5,
            ],
          ),
        ),
        KoppenClass.cwc,
      );
      // Dfd
      expect(
        KoppenClass.classify(
          MonthlyClimateNormals(
            temperature: const [
              -42,
              -38,
              -25,
              -10,
              2,
              12,
              16,
              13,
              4,
              -10,
              -28,
              -40,
            ],
            precipitation: List<double>.filled(12, 40),
          ),
        ),
        KoppenClass.dfd,
      );
      // ET & EF
      expect(
        KoppenClass.classify(
          MonthlyClimateNormals(
            temperature: const [-15, -14, -10, -5, 0, 4, 6, 5, 1, -4, -10, -13],
            precipitation: List<double>.filled(12, 30),
          ),
        ),
        KoppenClass.et,
      );
      expect(
        KoppenClass.classify(
          MonthlyClimateNormals(
            temperature: List<double>.filled(12, -10),
            precipitation: List<double>.filled(12, 10),
          ),
        ),
        KoppenClass.ef,
      );

      for (final c in KoppenClass.values) {
        expect(KoppenClass.tryParse(c.code), c);
        expect(KoppenClass.tryParse(c.code.toLowerCase()), isNull);
      }
      expect(KoppenClass.tryParse('XYZ'), isNull);
    });
  });

  group('HardinessZone', () {
    test('maps extreme minimum temperatures to USDA 1a-13b half-zones', () {
      expect(HardinessZone.fromMeanAnnualExtremeMinimum(-55.0).label, '1a');
      expect(HardinessZone.fromMeanAnnualExtremeMinimum(-8.35).label, '8b');
      expect(HardinessZone.fromMeanAnnualExtremeMinimum(-5.4).label, '9a');
      expect(HardinessZone.fromMeanAnnualExtremeMinimum(22.0).label, '13b');

      final z8b = HardinessZone.tryParse('8b')!;
      final z9a = HardinessZone.tryParse('9a')!;
      expect(HardinessZone.tryParse('9A'), isNull);
      expect(z9a.halfZonesWarmerThan(z8b), 1);
      expect(z8b.compareTo(z9a), lessThan(0));
      expect(z8b.lowerBoundCelsius, closeTo(-9.44, 0.05));
      expect(z8b.upperBoundCelsius, closeTo(-6.67, 0.05));
      expect(HardinessZone.tryParse('14a'), isNull);
      expect(HardinessZone.tryParse('0b'), isNull);
      expect(HardinessZone.tryParse('bad'), isNull);
    });
  });

  group('ClimateProfile & DanishReferenceClimate', () {
    test('DanishReferenceClimate has expected Cfb / 8b normals and JSON round-trip', () {
      final ref = DanishReferenceClimate.profile;
      expect(ref.koppen, KoppenClass.cfb);
      expect(ref.hardinessZone.label, '8b');
      expect(ref.frost.medianFrostFreeDays, 201);
      expect(ref.thermalSeason(5).start, 56);
      expect(ref.thermalSeason(10).start, 91);

      final json = ref.toJson();
      final decoded = ClimateProfile.fromJson(json);
      expect(decoded.koppen, ref.koppen);
      expect(decoded.hardinessZone, ref.hardinessZone);
      expect(decoded.frost.medianFrostFreeDays, ref.frost.medianFrostFreeDays);
      expect(decoded.thermalSeason(5).start, ref.thermalSeason(5).start);

      final badVersion = Map<String, Object?>.from(json)..['version'] = 99;
      expect(() => ClimateProfile.fromJson(badVersion), throwsFormatException);
    });

    test(
      'computes ClimateProfile from synthetic northern and southern series',
      () {
        final northSeries = _buildSyntheticSeries(
          meanTempC: 9.5,
          amplitudeC: 8.0,
          warmestDayOfYear: 205,
          diurnalHalfRangeC: 4.5,
          dailyPrecipMm: 2.0,
        );
        final northProfile = ClimateProfile.fromDailySeries(
          northSeries,
          latitude: 55.3,
          longitude: 10.5,
        );
        expect(northProfile.koppen, KoppenClass.cfb);
        expect(
          northProfile.frost.seasonsWithFrost,
          northProfile.frost.seasonCount,
        );
        expect(northProfile.frost.medianLastSpringFrost, isNotNull);
        expect(northProfile.frost.medianFirstAutumnFrost, isNotNull);
        expect(northProfile.thermalSeason(5).isBounded, isTrue);

        final southSeries = _buildSyntheticSeries(
          meanTempC: 11.0,
          amplitudeC: 8.0,
          warmestDayOfYear: 20,
          diurnalHalfRangeC: 5.5,
          dailyPrecipMm: 1.8,
        );
        final southProfile = ClimateProfile.fromDailySeries(
          southSeries,
          latitude: -37.8,
          longitude: 145.0,
        );
        expect(southProfile.koppen, KoppenClass.cfb);
        expect(southProfile.coldestDay, inInclusiveRange(190, 215));
        expect(southProfile.warmestDay, inInclusiveRange(10, 30));
      },
    );

    test('throws FormatException on gaps or insufficient days', () {
      expect(
        () => ClimateProfile.fromDailySeries(
          DailyClimateSeries(
            dates: [DateTime.utc(2020, 1, 1)],
            meanTemperature: const [5],
            minimumTemperature: const [1],
            precipitation: const [0],
          ),
          latitude: 55,
          longitude: 10,
        ),
        throwsFormatException,
      );
    });
  });

  group('SeasonAlignment & Phase 2 Integrations', () {
    test('ClimateSeasonAlignment is identity when local equals reference', () {
      final alignment = ClimateSeasonAlignment(
        local: DanishReferenceClimate.profile,
      );
      expect(alignment.transferability, CalendarTransferability.transfers);
      expect(alignment.caveats, isEmpty);

      for (var day = 0; day < climateYearLength; day++) {
        final date = climateDateOfDay(day);
        for (final anchor in SeasonalAnchor.values) {
          expect(
            climateDayOfYear(alignment.referenceDate(date, anchor: anchor)),
            day,
          );
          expect(alignment.referenceMonth(date, anchor: anchor), date.month);
        }
      }
    });

    test(
      'Southern Hemisphere ClimateSeasonAlignment flips seasons by ~6 months',
      () {
        final southProfile = ClimateProfile.fromDailySeries(
          _buildSyntheticSeries(
            meanTempC: 9.5,
            amplitudeC: 8.0,
            warmestDayOfYear: 23, // mid-Jan warmest, mid-Jul coldest
            diurnalHalfRangeC: 4.5,
            dailyPrecipMm: 2.0,
          ),
          latitude: -42.0,
          longitude: 172.0,
        );
        final alignment = ClimateSeasonAlignment(local: southProfile);

        // Mid-October in Southern Hemisphere should map to mid-April (month 4) in Denmark
        final oct15 = DateTime(2026, 10, 15);
        expect(
          alignment.referenceMonth(oct15, anchor: SeasonalAnchor.thermal),
          inInclusiveRange(4, 5),
        );

        // Mid-July in Southern Hemisphere should map to mid-January (month 1) in Denmark
        final jul15 = DateTime(2026, 7, 15);
        expect(
          alignment.referenceMonth(jul15, anchor: SeasonalAnchor.dormancy),
          inInclusiveRange(1, 2),
        );

        // Biodynamic BD 500 should be in winter underground burial during July in SH
        final bd500Status = BiodynamicPrepEvaluator.getBurialStatus(
          prep: BiodynamicPrepType.bd500,
          date: jul15,
          latitude: -42.0,
          seasons: alignment,
        );
        expect(bd500Status.stage, 'Underground Fermentation (Winter)');

        final burialProgress =
            BiodynamicPrepEvaluator.getSeasonalBurialProgress(
              jul15,
              seasons: alignment,
            );
        expect(burialProgress.isUndergroundBurial, isTrue);
      },
    );

    test('Frost-tender vs hardy crops adapt to local frost dates and tropical non-transferability', () {
      // Subarctic profile with late spring frost (late May)
      final coldProfile = ClimateProfile.fromDailySeries(
        _buildSyntheticSeries(
          meanTempC: 2.5,
          amplitudeC: 13.0,
          warmestDayOfYear: 202,
          diurnalHalfRangeC: 5.5,
          dailyPrecipMm: 2.0,
        ),
        latitude: 64.0,
        longitude: 20.0,
      );
      final coldAlignment = ClimateSeasonAlignment(local: coldProfile);
      expect(coldProfile.koppen, KoppenClass.dfc);
      expect(coldProfile.frost.lastSpringFrost90, greaterThan(100));

      // On May 5 on a Fruit day: in Denmark May is tomato transplant month (5),
      // but in the cold profile frost-tender anchor is still before last spring frost (ref month <= 4).
      final may5 = DateTime(2026, 5, 5, 10);
      final coldRecs = PlantRecommendations.evaluate(
        quality: PlantQuality.fruit,
        isDescending: true,
        isWaxing: true,
        isGrayDay: false,
        selectedTime: may5,
        latitude: 64.0,
        seasons: coldAlignment,
      );
      expect(
        coldRecs.transplantActions.any((name) => name.contains('Tomato')),
        isFalse,
      );

      // Tropical rainforest profile (Af): seasonal lists suppressed, caveats shown
      final tropicalProfile = ClimateProfile.fromDailySeries(
        _buildSyntheticSeries(
          meanTempC: 26.5,
          amplitudeC: 0.8,
          warmestDayOfYear: 150,
          diurnalHalfRangeC: 3.0,
          dailyPrecipMm: 7.0,
        ),
        latitude: 1.35,
        longitude: 103.8,
      );
      final tropicalAlignment = ClimateSeasonAlignment(local: tropicalProfile);
      expect(
        tropicalAlignment.transferability,
        CalendarTransferability.doesNotTransfer,
      );
      final tropicalRecs = PlantRecommendations.evaluate(
        quality: PlantQuality.fruit,
        isDescending: true,
        isWaxing: true,
        isGrayDay: false,
        selectedTime: may5,
        latitude: 1.35,
        seasons: tropicalAlignment,
      );
      expect(tropicalRecs.sowIndoorPlants, isEmpty);
      expect(tropicalRecs.sowOutdoorPlants, isEmpty);
      expect(tropicalRecs.transplantActions, isEmpty);
      expect(tropicalRecs.generalAdvice, contains('Tropical climate:'));
    });

    test(
      'TaskWindowPlanner and EcologicalSynthesis respect SeasonAlignment',
      () {
        final southProfile = ClimateProfile.fromDailySeries(
          _buildSyntheticSeries(
            meanTempC: 9.5,
            amplitudeC: 8.0,
            warmestDayOfYear: 23,
            diurnalHalfRangeC: 4.5,
            dailyPrecipMm: 2.0,
          ),
          latitude: -42.0,
          longitude: 172.0,
        );
        final southAlignment = ClimateSeasonAlignment(local: southProfile);
        final fakeEphemeris = FakeEphemerisService(
          moonLongitude: 120, // Fruit
          declinationAt: (t) => -t.hour.toDouble(), // descending
          sunTimesAt: plainDaylight,
        );

        // Grapevine cuttings (traditional Nov-Feb) should be in season in July in SH
        final grapevine = VegetableDatabase.findById('grapevine')!;
        final resultInJuly = TaskWindowPlanner.findUpcomingWindows(
          action: TaskActionType.takeCuttings,
          targetQuality: PlantQuality.fruit,
          crop: grapevine,
          startTime: DateTime(2026, 7, 10, 9),
          ephemeris: fakeEphemeris,
          latitude: -42.0,
          longitude: 172.0,
          seasons: southAlignment,
          searchDays: 5,
        );
        expect(resultInJuly.isCurrentlyInSeason, isTrue);

        // EcologicalSynthesis detects unseasonal spring frost in October in SH
        final info = CalendarInfo(
          quality: PlantQuality.fruit,
          isGrayDay: false,
          message: 'Fruit day',
          sapFlow: 'Ascending',
          isMoonAscending: true,
          vitality: 'High',
          moonPhase: const MoonPhaseInfo(
            illuminatedFraction: 0.5,
            isWaxing: true,
            phaseAngle: 90,
          ),
          planets: const [],
        );
        final synthesis = EcologicalSynthesis.synthesize(
          calendarInfo: info,
          time: DateTime(2026, 10, 15, 10),
          weather: WeatherDataPoint(
            time: DateTime(2026, 10, 15, 10),
            temperature: 0.5,
            windSpeed: 2.0,
            windDirection: 180.0,
            cloudCover: 20.0,
            precipitation: 0.0,
          ),
          latitude: -42.0,
          seasons: southAlignment,
        );
        expect(
          synthesis.alerts.any(
            (a) => a.title.contains('Spring Frost Risk (< 2°C)'),
          ),
          isTrue,
        );
      },
    );
  });

  group(
    'OpenMeteoClient, OpenMeteoClimateService & FileClimateProfileStore',
    () {
      test('parses daily climate series, deduplicates 0.1° grid requests, and persists to disk', () async {
        final synthetic = _buildSyntheticSeries(
          meanTempC: 9.5,
          amplitudeC: 8.0,
          warmestDayOfYear: 205,
          diurnalHalfRangeC: 4.5,
          dailyPrecipMm: 2.0,
          firstYear: 2019,
          lastYear: 2020,
        );
        final payload = jsonEncode({
          'latitude': 55.3,
          'longitude': 10.5,
          'elevation': 50.0,
          'daily': {
            'time': synthetic.dates
                .map(
                  (d) =>
                      '${d.year.toString().padLeft(4, '0')}-'
                      '${d.month.toString().padLeft(2, '0')}-'
                      '${d.day.toString().padLeft(2, '0')}',
                )
                .toList(),
            'temperature_2m_mean': synthetic.meanTemperature,
            'temperature_2m_min': synthetic.minimumTemperature,
            'precipitation_sum': synthetic.precipitation,
          },
        });

        var httpCalls = 0;
        var failFirst = true;
        final mockHttp = MockClient((request) async {
          httpCalls++;
          if (failFirst) {
            failFirst = false;
            return http.Response('Server Error', 500);
          }
          expect(request.url.host, 'archive-api.open-meteo.com');
          return http.Response(payload, 200);
        });

        final tempDir = await Directory.systemTemp.createTemp('climate_test_');
        addTearDown(() => tempDir.delete(recursive: true));

        final fileStore = createFileClimateProfileStore(tempDir.path)!;
        final service = OpenMeteoClimateService(
          client: OpenMeteoClient(client: mockHttp),
          store: fileStore,
          firstYear: 2019,
          lastYear: 2020,
        );

        // First call fails and is evicted from in-flight cache
        await expectLater(
          service.profileFor(55.31, 10.49),
          throwsA(isA<http.ClientException>()),
        );
        expect(httpCalls, 1);

        // Second call succeeds, and concurrent rounded coordinate shares the same Future
        final futures = await Future.wait([
          service.profileFor(55.31, 10.49),
          service.profileFor(55.34, 10.46),
        ]);
        expect(httpCalls, 2);
        expect(futures[0].koppen, KoppenClass.cfb);
        expect(futures[1].koppen, KoppenClass.cfb);

        // New service reading from the same FileClimateProfileStore hits disk without HTTP
        final secondService = OpenMeteoClimateService(
          client: OpenMeteoClient(
            client: MockClient(
              (_) async => throw StateError('No HTTP expected'),
            ),
          ),
          store: fileStore,
          firstYear: 2019,
          lastYear: 2020,
        );
        final cached = await secondService.profileFor(55.32, 10.51);
        expect(cached.koppen, KoppenClass.cfb);
      });
    },
  );

  group('HomeHeader climate zone chip & ClimateDetailsSheet', () {
    testWidgets(
      'displays Köppen + USDA badge and opens ClimateDetailsSheet on tap',
      (tester) async {
        final latNotifier = ValueNotifier<double>(55.31);
        final lonNotifier = ValueNotifier<double>(10.45);
        final dateNotifier = ValueNotifier<DateTime>(DateTime(2026, 5, 15));
        final climateNotifier = ValueNotifier<ClimateProfile?>(
          DanishReferenceClimate.profile,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HomeHeader(
                latNotifier: latNotifier,
                lonNotifier: lonNotifier,
                selectedDateNotifier: dateNotifier,
                climateNotifier: climateNotifier,
                onNowPressed: () {},
                onDateSelected: (_) {},
              ),
            ),
          ),
        );

        final chipFinder = find.byKey(const ValueKey('climate_zone_chip'));
        expect(chipFinder, findsOneWidget);
        expect(find.text('Cfb · 8b'), findsOneWidget);

        await tester.tap(chipFinder);
        await tester.pumpAndSettle();

        expect(find.byType(ClimateDetailsSheet), findsOneWidget);
        expect(
          find.textContaining('Temperate, no dry season, warm summer'),
          findsOneWidget,
        );
        expect(find.textContaining('Zone 8b'), findsOneWidget);
      },
    );
  });

  group('CropClimateEvaluation, localMonthsFor, & Climate-Aware Planting/Planning', () {
    test('SeasonAlignment.localMonthsFor translates Danish months to local calendar months', () {
      final dkAlignment = ClimateSeasonAlignment(
        local: DanishReferenceClimate.profile,
      );
      expect(dkAlignment.localProfile, DanishReferenceClimate.profile);
      expect(dkAlignment.localMonthsFor(const [3, 4, 5]), const [3, 4, 5]);

      final shHemisphere = const HemisphereSeasonAlignment(latitude: -37.8);
      expect(shHemisphere.localProfile, isNull);
      expect(shHemisphere.localMonthsFor(const [3, 4]), const [9, 10]);

      final southProfile = ClimateProfile.fromDailySeries(
        _buildSyntheticSeries(
          meanTempC: 11.0,
          amplitudeC: 7.5,
          warmestDayOfYear: 23,
          diurnalHalfRangeC: 4.5,
          dailyPrecipMm: 2.0,
        ),
        latitude: -42.0,
        longitude: 172.0,
      );
      final southAlignment = ClimateSeasonAlignment(local: southProfile);
      final translatedSpring = southAlignment.localMonthsFor(const [4]);
      expect(translatedSpring, isNotEmpty);
      expect(
        translatedSpring.any((m) => m >= 9 && m <= 11),
        isTrue,
        reason:
            'April in Denmark should map to Southern Hemisphere spring (Sep-Nov), got $translatedSpring',
      );
    });

    test(
      'CropClimateEvaluation classifies crops across all 6 suitability ratings',
      () {
        final dk = DanishReferenceClimate.profile; // Cfb, Zone 8b

        // 1. wellSuited: apple_tree (Zone 4a+) in Denmark (Zone 8b)
        final apple = VegetableDatabase.findById('apple_tree')!;
        final appleEval = CropClimateEvaluation.evaluate(apple, dk);
        expect(appleEval.rating, CropClimateRating.wellSuited);
        expect(appleEval.needsAttention, isFalse);
        expect(appleEval.hardinessNote, contains('Zone 4a'));

        // 2. needsWarmthProtection: tomato (requiresWarmSummer) in Denmark (warmest month 17.9 °C < 18.5 °C)
        final tomato = VegetableDatabase.findById('tomato')!;
        final tomatoEval = CropClimateEvaluation.evaluate(tomato, dk);
        expect(tomatoEval.rating, CropClimateRating.needsWarmthProtection);
        expect(tomatoEval.needsAttention, isTrue);
        expect(tomatoEval.badgeLabel, 'Greenhouse / Warm Wall');

        // 3. needsWinterProtection: rosemary (minHardinessZone 8a) in Denmark (Zone 8b, margin = 1 half-zone)
        final rosemary = VegetableDatabase.findById('rosemary')!;
        final rosemaryEval = CropClimateEvaluation.evaluate(rosemary, dk);
        expect(rosemaryEval.rating, CropClimateRating.needsWinterProtection);
        expect(rosemaryEval.badgeLabel, contains('Winter Mulch'));

        // 4. overwinterIndoors: lemon_verbena (minHardinessZone 9a) in Denmark (Zone 8b < 9a)
        final lemonVerbena = VegetableDatabase.findById('lemon_verbena')!;
        final verbenaEval = CropClimateEvaluation.evaluate(lemonVerbena, dk);
        expect(verbenaEval.rating, CropClimateRating.overwinterIndoors);
        expect(verbenaEval.badgeLabel, 'Overwinter Frost-Free');

        // 5. boltRiskInSummer: spinach (isBoltProneInHeat) in hot-summer Csa climate
        final hotProfile = ClimateProfile.fromDailySeries(
          _buildSyntheticSeries(
            meanTempC: 18.0,
            amplitudeC: 9.0,
            warmestDayOfYear: 200,
            diurnalHalfRangeC: 5.0,
            dailyPrecipMm: 1.2,
          ),
          latitude: 37.4,
          longitude: -6.0,
        );
        final spinach = VegetableDatabase.findById('spinach')!;
        final spinachEval = CropClimateEvaluation.evaluate(spinach, hotProfile);
        expect(spinachEval.rating, CropClimateRating.boltRiskInSummer);
        expect(spinachEval.badgeLabel, contains('Heat Bolt'));

        // 6. seasonTooShortOutdoors: bell_pepper (minFrostFreeDays 140) in subarctic Dfc climate
        final subarcticProfile = ClimateProfile.fromDailySeries(
          _buildSyntheticSeries(
            meanTempC: 0.0,
            amplitudeC: 12.0,
            warmestDayOfYear: 200,
            diurnalHalfRangeC: 5.5,
            dailyPrecipMm: 2.0,
          ),
          latitude: 65.0,
          longitude: 20.0,
        );
        final bellPepper = VegetableDatabase.findById('bell_pepper')!;
        final pepperEval = CropClimateEvaluation.evaluate(
          bellPepper,
          subarcticProfile,
        );
        expect(pepperEval.rating, CropClimateRating.seasonTooShortOutdoors);
        expect(pepperEval.badgeLabel, 'Greenhouse Required');
      },
    );

    test('PlantRecommendations populates cropClimateEvaluations, localClimateNote, and filters short-season outdoor crops', () {
      final subarcticProfile = ClimateProfile.fromDailySeries(
        _buildSyntheticSeries(
          meanTempC: 2.0,
          amplitudeC: 12.0,
          warmestDayOfYear: 200,
          diurnalHalfRangeC: 5.0,
          dailyPrecipMm: 2.0,
        ),
        latitude: 65.0,
        longitude: 20.0,
      );
      final alignment = ClimateSeasonAlignment(local: subarcticProfile);

      // Construct a custom crop with sowingMonths [1..12] that requires 160 frost-free days
      const longSeasonCrop = VegetableEntry(
        id: 'test_melon',
        nameDa: 'Testmelon',
        nameEn: 'Test Melon',
        scientificName: 'Cucumis melo',
        quality: PlantQuality.fruit,
        sowingMonths: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
        indoorSowingMonths: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
        harvestMonths: [8, 9],
        descriptionDa: 'Test',
        descriptionEn: 'Test',
        companionPlants: [],
        isFrostTender: true,
        minFrostFreeDays: 160,
      );

      final recs = PlantRecommendations.evaluate(
        quality: PlantQuality.fruit,
        isDescending: true,
        isWaxing: true,
        isGrayDay: false,
        selectedTime: DateTime(2026, 6, 15, 10),
        latitude: 65.0,
        seasons: alignment,
        dbEntries: const [longSeasonCrop],
      );

      expect(recs.localClimateNote, isNotNull);
      expect(recs.localClimateNote, contains('USDA Zone'));
      expect(
        recs.cropClimateEvaluations['test_melon']?.rating,
        CropClimateRating.seasonTooShortOutdoors,
      );
      // Outdoor sowing is filtered out because the local frost-free season is < 160 days,
      // while indoor sowing remains available.
      expect(recs.sowOutdoorPlants, isEmpty);
      expect(recs.sowIndoorPlants, isNotEmpty);
    });

    test('TaskWindowPlanner computes cropClimate, localSeasonSummary, and per-window climate risk notes', () {
      final dkAlignment = ClimateSeasonAlignment(
        local: DanishReferenceClimate.profile,
      );
      final fakeEphemeris = FakeEphemerisService(
        moonLongitude: 150, // Leo (Fire / Fruit)
        declinationAt: (t) => -t.hour.toDouble(), // descending
        sunTimesAt: plainDaylight,
      );
      final tomato = VegetableDatabase.findById('tomato')!;

      // Search in early April (before Denmark's 90% last spring frost date)
      final aprilResult = TaskWindowPlanner.findUpcomingWindows(
        action: TaskActionType.transplant,
        targetQuality: PlantQuality.fruit,
        crop: tomato,
        startTime: DateTime(2026, 4, 5, 9),
        ephemeris: fakeEphemeris,
        seasons: dkAlignment,
        searchDays: 5,
      );

      expect(aprilResult.cropClimate, isNotNull);
      expect(
        aprilResult.cropClimate!.rating,
        CropClimateRating.needsWarmthProtection,
      );
      expect(aprilResult.localSeasonSummary, isNotNull);
      expect(
        aprilResult.localSeasonSummary,
        contains('Local frost-safe window (90% confidence)'),
      );
      expect(aprilResult.windows, isNotEmpty);
      expect(aprilResult.windows.first.hasClimateRisk, isTrue);
      expect(
        aprilResult.windows.first.climateNote,
        contains('before the local 90% frost-free date'),
      );
    });
  });
}
