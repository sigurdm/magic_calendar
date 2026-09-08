import 'package:flutter_test/flutter_test.dart';
import 'package:magic_calendar/src/core/plant_recommendations.dart';
import 'package:magic_calendar/src/core/vegetable_database.dart';
import 'package:magic_calendar/src/services/ephemeris_service.dart';

void main() {
  group('ISO 8601 Week Number Calculation', () {
    test('calculates week numbers accurately across standard years', () {
      // 2026-01-01 is a Thursday (Week 1)
      expect(
        PlantRecommendations.computeWeekNumber(DateTime.utc(2026, 1, 1)),
        1,
      );
      // 2026-01-04 is a Sunday (Week 1)
      expect(
        PlantRecommendations.computeWeekNumber(DateTime.utc(2026, 1, 4)),
        1,
      );
      // 2026-01-05 is a Monday (Week 2)
      expect(
        PlantRecommendations.computeWeekNumber(DateTime.utc(2026, 1, 5)),
        2,
      );
      // Mid-year: 2026-06-15 (Monday, Week 25)
      expect(
        PlantRecommendations.computeWeekNumber(DateTime.utc(2026, 6, 15)),
        25,
      );
    });

    test(
      'correctly identifies week 53 in 53-week years without clamping to 52',
      () {
        // 2020 has 53 ISO weeks; 2020-12-31 is Thursday of week 53
        expect(
          PlantRecommendations.computeWeekNumber(DateTime.utc(2020, 12, 31)),
          53,
        );
        // 2021-01-01 is Friday belonging to week 53 of 2020
        expect(
          PlantRecommendations.computeWeekNumber(DateTime.utc(2021, 1, 1)),
          53,
        );
        // 2021-01-04 is Monday of week 1 of 2021
        expect(
          PlantRecommendations.computeWeekNumber(DateTime.utc(2021, 1, 4)),
          1,
        );
      },
    );
  });

  group('Southern Hemisphere Agricultural Inversion', () {
    test('evaluates season and 26-week shift for Southern Hemisphere', () {
      final springDate = DateTime.utc(
        2026,
        10,
        5,
      ); // October = Autumn in North, Spring in South

      final northEval = PlantRecommendations.evaluate(
        quality: PlantQuality.root,
        isDescending: true,
        isWaxing: false,
        isGrayDay: false,
        selectedTime: springDate,
        latitude: 55.6761,
      );
      expect(northEval.season, GardenSeason.autumn);

      final southEval = PlantRecommendations.evaluate(
        quality: PlantQuality.root,
        isDescending: true,
        isWaxing: false,
        isGrayDay: false,
        selectedTime: springDate,
        latitude: -37.8136,
      );
      expect(southEval.season, GardenSeason.spring);
    });

    test(
      'recommends spring vegetables for Southern Hemisphere spring with mock DB',
      () {
        final mockVegs = [
          const VegetableEntry(
            id: 'carrot',
            nameDa: 'Gulerod',
            nameEn: 'Carrot',
            scientificName: 'Daucus carota',
            quality: PlantQuality.root,
            sowingMonths: [3, 4, 5, 6], // Spring (March-June in North)
            harvestMonths: [8, 9, 10, 11], // Autumn
            descriptionDa: 'Gulerod beskrivelse',
            descriptionEn: 'Carrot description',
            companionPlants: ['Løg'],
          ),
        ];

        // October (Month 10 in North -> Month 4 in South, which is April/Spring in South)
        final octoberDate = DateTime.utc(2026, 10, 5);

        final southEval = PlantRecommendations.evaluate(
          quality: PlantQuality.root,
          isDescending: true,
          isWaxing: false,
          isGrayDay: false,
          selectedTime: octoberDate,
          latitude: -33.8688, // Sydney, Australia
          dbEntries: mockVegs,
        );

        expect(southEval.season, GardenSeason.spring);
        expect(southEval.sowOutdoorPlants, contains('Gulerod (Carrot)'));
        expect(southEval.harvestActions, isEmpty);
      },
    );

    test('suppresses recommendations on Gray Days', () {
      final grayEval = PlantRecommendations.evaluate(
        quality: PlantQuality.root,
        isDescending: true,
        isWaxing: false,
        isGrayDay: true,
        selectedTime: DateTime.utc(2026, 5, 1),
        latitude: 55.6761,
      );

      expect(grayEval.sowIndoorPlants, isEmpty);
      expect(grayEval.sowOutdoorPlants, isEmpty);
      expect(grayEval.generalAdvice, contains('Gray Day'));
    });
  });
}
