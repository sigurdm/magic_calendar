import 'package:flutter_test/flutter_test.dart';
import 'package:magic_calendar/src/core/vegetable_database.dart';
import 'package:magic_calendar/src/services/ephemeris_service.dart';

void main() {
  group('VegetableDatabase tests', () {
    test('allEntries contains valid crops for all plant qualities', () {
      final all = VegetableDatabase.allEntries;
      expect(all.isNotEmpty, isTrue);

      final rootCrops = VegetableDatabase.getVegetablesForQuality(
        PlantQuality.root,
      );
      final leafCrops = VegetableDatabase.getVegetablesForQuality(
        PlantQuality.leaf,
      );
      final flowerCrops = VegetableDatabase.getVegetablesForQuality(
        PlantQuality.flower,
      );
      final fruitCrops = VegetableDatabase.getVegetablesForQuality(
        PlantQuality.fruit,
      );

      expect(rootCrops.isNotEmpty, isTrue);
      expect(leafCrops.isNotEmpty, isTrue);
      expect(flowerCrops.isNotEmpty, isTrue);
      expect(fruitCrops.isNotEmpty, isTrue);

      for (final crop in all) {
        expect(crop.id.isNotEmpty, isTrue);
        expect(crop.nameDa.isNotEmpty, isTrue);
        expect(crop.nameEn.isNotEmpty, isTrue);
        expect(crop.scientificName.isNotEmpty, isTrue);
        expect(crop.localizedDisplayName, contains(crop.nameDa));
        expect(crop.localizedDisplayName, contains(crop.nameEn));
        expect(crop.sowingMonths.every((m) => m >= 1 && m <= 12), isTrue);
        expect(crop.indoorSowingMonths.every((m) => m >= 1 && m <= 12), isTrue);
        expect(crop.transplantMonths.every((m) => m >= 1 && m <= 12), isTrue);
        expect(crop.cuttingMonths.every((m) => m >= 1 && m <= 12), isTrue);
        expect(crop.graftingMonths.every((m) => m >= 1 && m <= 12), isTrue);
        expect(crop.divisionMonths.every((m) => m >= 1 && m <= 12), isTrue);
        expect(crop.pruningMonths.every((m) => m >= 1 && m <= 12), isTrue);
        expect(crop.harvestMonths.every((m) => m >= 1 && m <= 12), isTrue);
        expect(
          crop.sowingMonths.isNotEmpty ||
              crop.indoorSowingMonths.isNotEmpty ||
              crop.transplantMonths.isNotEmpty ||
              crop.cuttingMonths.isNotEmpty ||
              crop.graftingMonths.isNotEmpty ||
              crop.divisionMonths.isNotEmpty ||
              crop.pruningMonths.isNotEmpty ||
              crop.harvestMonths.isNotEmpty,
          isTrue,
          reason:
              'Crop ${crop.id} must have at least one actionable month list populated.',
        );
      }
    });

    test('getVegetablesForMonth filters crops correctly across direct, indoor, transplant, cutting, grafting, and division windows', () {
      final aprilCrops = VegetableDatabase.getVegetablesForMonth(4);
      expect(aprilCrops.isNotEmpty, isTrue);

      // Tomato is indoor-sown in March/April and transplanted in May/June.
      final marchFruitCrops = VegetableDatabase.getVegetablesForMonth(
        3,
        quality: PlantQuality.fruit,
      );
      expect(marchFruitCrops.any((c) => c.id == 'tomato'), isTrue);

      final mayFruitCrops = VegetableDatabase.getVegetablesForMonth(
        5,
        quality: PlantQuality.fruit,
      );
      expect(mayFruitCrops.any((c) => c.id == 'tomato'), isTrue);

      final aprilRootCrops = VegetableDatabase.getVegetablesForMonth(
        4,
        quality: PlantQuality.root,
      );
      expect(
        aprilRootCrops.every(
          (c) =>
              c.quality == PlantQuality.root ||
              c.supportsQuality(PlantQuality.root),
        ),
        isTrue,
      );

      expect(
        () => VegetableDatabase.getVegetablesForMonth(0),
        throwsArgumentError,
      );
      expect(
        () => VegetableDatabase.getVegetablesForMonth(13),
        throwsArgumentError,
      );
    });

    test('findById retrieves specific entry or null if absent', () {
      final carrot = VegetableDatabase.findById('carrot');
      expect(carrot, isNotNull);
      expect(carrot!.nameEn, equals('Carrot'));
      expect(carrot.nameDa, equals('Gulerod'));
      expect(carrot.quality, equals(PlantQuality.root));

      final absent = VegetableDatabase.findById('non_existent_crop');
      expect(absent, isNull);
    });
  });
}
