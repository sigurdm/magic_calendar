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
        expect(crop.harvestMonths.every((m) => m >= 1 && m <= 12), isTrue);
      }
    });

    test(
      'getVegetablesForMonth filters crops correctly and enforces valid month',
      () {
        final aprilCrops = VegetableDatabase.getVegetablesForMonth(4);
        expect(aprilCrops.isNotEmpty, isTrue);

        final aprilRootCrops = VegetableDatabase.getVegetablesForMonth(
          4,
          quality: PlantQuality.root,
        );
        expect(
          aprilRootCrops.every((c) => c.quality == PlantQuality.root),
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
      },
    );

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
