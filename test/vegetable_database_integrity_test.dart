import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:magic_calendar/src/core/models/models.dart';
import 'package:magic_calendar/src/core/task_window_planner.dart';
import 'package:magic_calendar/src/core/vegetable_database.dart';

import 'support/fakes.dart';

/// Builds a deterministic [FakeEphemerisService] whose Moon advances ~13.2 degrees/day
/// along the ecliptic and oscillates in declination over a 27.21-day tropical cycle.
FakeEphemerisService _buildOrbitingFakeEphemeris(DateTime epoch) {
  return FakeEphemerisService(
    longitudeAt: (time) {
      final hours = time.difference(epoch).inMinutes / 60.0;
      return (hours * (360.0 / (27.32 * 24.0))) % 360.0;
    },
    declinationAt: (time) {
      final hours = time.difference(epoch).inMinutes / 60.0;
      return 23.4 * math.cos(2 * math.pi * hours / (27.21 * 24.0));
    },
  );
}

void main() {
  group('R4 Tier 1 — Catalog Scale & Domain Coverage', () {
    test('VegetableDatabase.allEntries contains at least 185 entries', () {
      expect(
        VegetableDatabase.allEntries.length,
        greaterThanOrEqualTo(185),
        reason: 'Catalog must contain at least 185 distinct Nordic biodynamic plant entries.',
      );
    });

    test('every PlantCategory domain meets its minimum entry threshold', () {
      final vegetables = VegetableDatabase.getVegetablesForCategory(
        PlantCategory.vegetable,
      );
      final culinaryHerbs = VegetableDatabase.getVegetablesForCategory(
        PlantCategory.culinaryHerb,
      );
      final medicinalHerbs = VegetableDatabase.getVegetablesForCategory(
        PlantCategory.medicinalHerb,
      );
      final fruitTrees = VegetableDatabase.getVegetablesForCategory(
        PlantCategory.fruitTree,
      );
      final berryShrubs = VegetableDatabase.getVegetablesForCategory(
        PlantCategory.berryShrub,
      );
      final vines = VegetableDatabase.getVegetablesForCategory(
        PlantCategory.vine,
      );
      final flowers = VegetableDatabase.getVegetablesForCategory(
        PlantCategory.flower,
      );
      final greenManures = VegetableDatabase.getVegetablesForCategory(
        PlantCategory.greenManure,
      );
      final grains = VegetableDatabase.getVegetablesForCategory(
        PlantCategory.grain,
      );

      expect(
        vegetables.length,
        greaterThanOrEqualTo(70),
        reason: 'Must have >= 70 kitchen vegetable entries.',
      );
      expect(
        culinaryHerbs.length + medicinalHerbs.length,
        greaterThanOrEqualTo(40),
        reason: 'Must have >= 40 culinary + medicinal herb entries.',
      );
      expect(
        medicinalHerbs.length,
        greaterThanOrEqualTo(20),
        reason: 'Must have >= 20 medicinal herb entries.',
      );
      expect(
        fruitTrees.length + berryShrubs.length + vines.length,
        greaterThanOrEqualTo(35),
        reason: 'Must have >= 35 fruit tree, berry shrub, and vine entries.',
      );
      expect(
        flowers.length + greenManures.length,
        greaterThanOrEqualTo(25),
        reason: 'Must have >= 25 flower and green manure entries.',
      );
      expect(
        grains.length,
        greaterThanOrEqualTo(12),
        reason: 'Must have >= 12 grain and arable crop entries.',
      );
    });

    test('every PlantQuality (root, leaf, flower, fruit) has at least 25 entries', () {
      for (final quality in const [
        PlantQuality.root,
        PlantQuality.leaf,
        PlantQuality.flower,
        PlantQuality.fruit,
      ]) {
        final matching = VegetableDatabase.getVegetablesForQuality(quality);
        expect(
          matching.length,
          greaterThanOrEqualTo(25),
          reason:
              'PlantQuality.${quality.name} must have >= 25 entries, found ${matching.length}.',
        );
      }
    });

    test(
      'all 26 pre-existing entry IDs remain present for backward compatibility',
      () {
        const legacyIds = <String>[
          'carrot',
          'beetroot',
          'potato',
          'onion',
          'radish',
          'celeriac',
          'marshmallow_root',
          'lettuce',
          'spinach',
          'kale',
          'swiss_chard',
          'leek',
          'broccoli',
          'cauliflower',
          'artichoke',
          'chamomile',
          'sunflower',
          'rose',
          'tomato',
          'bell_pepper',
          'cucumber',
          'bush_bean',
          'squash',
          'grapevine',
          'apple_tree',
          'berry_bush',
        ];

        for (final id in legacyIds) {
          final entry = VegetableDatabase.findById(id);
          expect(
            entry,
            isNotNull,
            reason: 'Pre-existing crop ID "$id" must remain present.',
          );
        }
      },
    );

    test('all 7 classic Steiner/Thun biodynamic preparation plants (BD 502–508) are present and searchable', () {
      const preparationPlants =
          <({String code, String id, String scientificGenus})>[
            (code: '502', id: 'yarrow', scientificGenus: 'Achillea'),
            (code: '503', id: 'chamomile', scientificGenus: 'Matricaria'),
            (code: '504', id: 'stinging_nettle', scientificGenus: 'Urtica'),
            (code: '505', id: 'oak_bark', scientificGenus: 'Quercus'),
            (code: '506', id: 'dandelion', scientificGenus: 'Taraxacum'),
            (code: '507', id: 'valerian', scientificGenus: 'Valeriana'),
            (code: '508', id: 'field_horsetail', scientificGenus: 'Equisetum'),
          ];

      for (final prep in preparationPlants) {
        final byId = VegetableDatabase.findById(prep.id);
        final byGenus = VegetableDatabase.search(prep.scientificGenus);
        final byCode = VegetableDatabase.search(prep.code);

        expect(
          byId != null || byGenus.isNotEmpty,
          isTrue,
          reason:
              'Biodynamic preparation plant BD ${prep.code} (${prep.id} / ${prep.scientificGenus}) must exist in the catalog.',
        );
        expect(
          byCode.isNotEmpty || byGenus.isNotEmpty,
          isTrue,
          reason:
              'Biodynamic preparation plant BD ${prep.code} must be searchable.',
        );
      }
    });
  });

  group('R4 Tier 2 — Data Quality, Taxonomy & Maria Thun Semantics', () {
    test('every entry has a unique snake_case id, non-empty Danish/English names, and binomial scientificName', () {
      final snakeCasePattern = RegExp(r'^[a-z0-9_]+$');
      final seenIds = <String>{};

      for (final crop in VegetableDatabase.allEntries) {
        expect(
          crop.id.trim(),
          isNotEmpty,
          reason: 'Crop id must not be empty.',
        );
        expect(
          snakeCasePattern.hasMatch(crop.id),
          isTrue,
          reason: 'Crop id "${crop.id}" must be valid snake_case.',
        );
        expect(
          seenIds.add(crop.id),
          isTrue,
          reason: 'Duplicate crop id "${crop.id}" found in allEntries.',
        );
        expect(
          crop.nameDa.trim(),
          isNotEmpty,
          reason: 'Crop "${crop.id}" must have a non-empty nameDa.',
        );
        expect(
          crop.nameEn.trim(),
          isNotEmpty,
          reason: 'Crop "${crop.id}" must have a non-empty nameEn.',
        );
        final tokens = crop.scientificName.trim().split(RegExp(r'\s+'));
        expect(
          tokens.length,
          greaterThanOrEqualTo(2),
          reason:
              'Crop "${crop.id}" scientificName "${crop.scientificName}" must be binomial (at least genus + species/cultivar).',
        );
      }
    });

    test('every entry has substantive, non-duplicate bilingual descriptions (>= 40 chars) without placeholders', () {
      final placeholderPattern = RegExp(
        r'\b(todo|tbd|lorem|ipsum|placeholder)\b',
        caseSensitive: false,
      );
      final seenDescriptionsDa = <String, String>{};
      final seenDescriptionsEn = <String, String>{};

      for (final crop in VegetableDatabase.allEntries) {
        final descDa = crop.descriptionDa.trim();
        final descEn = crop.descriptionEn.trim();

        expect(
          descDa.length,
          greaterThanOrEqualTo(40),
          reason:
              'Crop "${crop.id}" descriptionDa must be at least 40 characters (found ${descDa.length}).',
        );
        expect(
          descEn.length,
          greaterThanOrEqualTo(40),
          reason:
              'Crop "${crop.id}" descriptionEn must be at least 40 characters (found ${descEn.length}).',
        );

        expect(
          placeholderPattern.hasMatch(descDa),
          isFalse,
          reason: 'Crop "${crop.id}" descriptionDa contains placeholder text.',
        );
        expect(
          placeholderPattern.hasMatch(descEn),
          isFalse,
          reason: 'Crop "${crop.id}" descriptionEn contains placeholder text.',
        );
        expect(
          placeholderPattern.hasMatch(crop.thunNotesDa),
          isFalse,
          reason: 'Crop "${crop.id}" thunNotesDa contains placeholder text.',
        );
        expect(
          placeholderPattern.hasMatch(crop.thunNotesEn),
          isFalse,
          reason: 'Crop "${crop.id}" thunNotesEn contains placeholder text.',
        );

        final normalizedDa = descDa.toLowerCase();
        final normalizedEn = descEn.toLowerCase();

        expect(
          seenDescriptionsDa.containsKey(normalizedDa),
          isFalse,
          reason:
              'Duplicate descriptionDa between "${crop.id}" and "${seenDescriptionsDa[normalizedDa]}".',
        );
        seenDescriptionsDa[normalizedDa] = crop.id;

        expect(
          seenDescriptionsEn.containsKey(normalizedEn),
          isFalse,
          reason:
              'Duplicate descriptionEn between "${crop.id}" and "${seenDescriptionsEn[normalizedEn]}".',
        );
        seenDescriptionsEn[normalizedEn] = crop.id;
      }
    });

    test('no entry description or Maria Thun note conflates synodic (waxing/waning) and tropical (ascending/descending/Pflanzzeit) cycles', () {
      final conflationPatterns = <RegExp>[
        RegExp(
          r'\b(waxing|waning)\s*(\([a-z\s/]+\)|moon)?\s*\(?\s*(ascending|descending|pflanzzeit)\b',
          caseSensitive: false,
        ),
        RegExp(
          r'\b(ascending|descending|pflanzzeit)\s*(\([a-z\s/]+\)|moon)?\s*\(?\s*(waxing|waning)\b',
          caseSensitive: false,
        ),
        RegExp(
          r'\b(tiltagende|aftagende)\s*(\([a-zæøå\s/]+\)|måne)?\s*\(?\s*(opstigende|nedstigende|plantetid|pflanzzeit)\b',
          caseSensitive: false,
        ),
        RegExp(
          r'\b(opstigende|nedstigende|plantetid|pflanzzeit)\s*(\([a-zæøå\s/]+\)|måne)?\s*\(?\s*(tiltagende|aftagende)\b',
          caseSensitive: false,
        ),
      ];

      for (final crop in VegetableDatabase.allEntries) {
        final textsToInspect = <String>[
          crop.descriptionDa,
          crop.descriptionEn,
          crop.thunNotesDa,
          crop.thunNotesEn,
          for (final rule in crop.secondaryOrganRules) ...[
            rule.noteDa,
            rule.noteEn,
          ],
        ];

        for (final text in textsToInspect) {
          for (final pattern in conflationPatterns) {
            expect(
              pattern.hasMatch(text),
              isFalse,
              reason:
                  'Crop "${crop.id}" conflates synodic and tropical lunar terminology in: "$text"',
            );
          }
        }
      }
    });

    test('every month list contains valid integers in 1..12 with no duplicates and every entry has at least one actionable month list', () {
      void verifyMonthList(String cropId, String listName, List<int> months) {
        for (final m in months) {
          expect(
            m >= 1 && m <= 12,
            isTrue,
            reason: 'Crop "$cropId" $listName contains out-of-range month $m.',
          );
        }
        expect(
          months.toSet().length,
          equals(months.length),
          reason:
              'Crop "$cropId" $listName contains duplicate months: $months.',
        );
      }

      for (final crop in VegetableDatabase.allEntries) {
        verifyMonthList(crop.id, 'indoorSowingMonths', crop.indoorSowingMonths);
        verifyMonthList(crop.id, 'sowingMonths', crop.sowingMonths);
        verifyMonthList(crop.id, 'transplantMonths', crop.transplantMonths);
        verifyMonthList(crop.id, 'cuttingMonths', crop.cuttingMonths);
        verifyMonthList(crop.id, 'pruningMonths', crop.pruningMonths);
        verifyMonthList(crop.id, 'graftingMonths', crop.graftingMonths);
        verifyMonthList(crop.id, 'divisionMonths', crop.divisionMonths);
        verifyMonthList(crop.id, 'harvestMonths', crop.harvestMonths);

        for (final rule in crop.secondaryOrganRules) {
          expect(
            rule.months,
            isNotEmpty,
            reason:
                'Crop "${crop.id}" secondary organ rule "${rule.id}" must have non-empty months.',
          );
          verifyMonthList(
            crop.id,
            'secondaryOrganRules(${rule.id}).months',
            rule.months,
          );
        }

        final hasActionableMonths =
            crop.indoorSowingMonths.isNotEmpty ||
            crop.sowingMonths.isNotEmpty ||
            crop.transplantMonths.isNotEmpty ||
            crop.cuttingMonths.isNotEmpty ||
            crop.pruningMonths.isNotEmpty ||
            crop.graftingMonths.isNotEmpty ||
            crop.divisionMonths.isNotEmpty ||
            crop.harvestMonths.isNotEmpty;

        expect(
          hasActionableMonths,
          isTrue,
          reason:
              'Crop "${crop.id}" must have at least one non-empty actionable month list.',
        );
      }
    });

    test('at least 15 multi-purpose species define secondaryOrganRules and can be scheduled in TaskWindowPlanner', () {
      final multiOrganCrops = VegetableDatabase.allEntries
          .where((crop) => crop.secondaryOrganRules.isNotEmpty)
          .toList(growable: false);

      expect(
        multiOrganCrops.length,
        greaterThanOrEqualTo(15),
        reason:
            'At least 15 multi-purpose species must define secondaryOrganRules (found ${multiOrganCrops.length}).',
      );

      final start = DateTime.utc(2026, 7, 10, 8, 0);
      final ephemeris = _buildOrbitingFakeEphemeris(start);

      for (final crop in multiOrganCrops) {
        final secondaryRule = crop.secondaryOrganRules.first;
        final result = TaskWindowPlanner.findUpcomingWindows(
          action: TaskActionType.harvestStorage,
          targetQuality: secondaryRule.quality,
          crop: crop,
          organRule: secondaryRule,
          startTime: start,
          ephemeris: ephemeris,
          searchDays: 30,
        );

        expect(result.targetQuality, equals(secondaryRule.quality));
        expect(result.activeOrganRule?.id, equals(secondaryRule.id));
        expect(result.seasonalMonths, equals(secondaryRule.months));
        expect(
          result.windows,
          isNotEmpty,
          reason:
              'TaskWindowPlanner must find windows for multi-organ crop "${crop.id}" (${secondaryRule.id}).',
        );
        for (final w in result.windows) {
          expect(w.quality, equals(secondaryRule.quality));
        }
      }
    });
  });

  group('R4 Tier 3 — Bilingual Search, Alias & Category Filtering', () {
    test('VegetableDatabase.search resolves queries by Danish name, English name, scientific name, and aliases', () {
      // Danish name
      expect(
        VegetableDatabase.search('Gulerod').any((c) => c.id == 'carrot'),
        isTrue,
      );
      // English name
      expect(
        VegetableDatabase.search('Butterhead Lettuce')
            .any((c) => c.id == 'lettuce'),
        isTrue,
      );
      // Scientific name
      expect(
        VegetableDatabase.search('Althaea officinalis')
            .any((c) => c.id == 'marshmallow_root'),
        isTrue,
      );

      // Required bilingual aliases from R2:
      // "lægestokrose" / "althea", "jordskok" / "sunchoke", "ramsløg" / "wild garlic", "kvan" / "archangelica"
      const requiredAliases = <String>[
        'lægestokrose',
        'althea',
        'jordskok',
        'sunchoke',
        'ramsløg',
        'wild garlic',
        'kvan',
        'archangelica',
      ];

      for (final query in requiredAliases) {
        final results = VegetableDatabase.search(query);
        expect(
          results,
          isNotEmpty,
          reason:
              'VegetableDatabase.search("$query") must resolve at least one matching plant entry.',
        );
      }
    });

    test('VegetableDatabase.search filters accurately by PlantCategory and PlantQuality (including secondary organs)', () {
      for (final category in PlantCategory.values) {
        final byCat = VegetableDatabase.search('', category: category);
        expect(
          byCat,
          isNotEmpty,
          reason: 'Category ${category.name} must have searchable entries.',
        );
        expect(byCat.every((c) => c.category == category), isTrue);
      }

      // Marshmallow Root is primary PlantQuality.root with secondary leaf & flower rules
      final flowerWithSecondary = VegetableDatabase.search(
        'marshmallow',
        quality: PlantQuality.flower,
        includeSecondaryOrgans: true,
      );
      expect(
        flowerWithSecondary.any((c) => c.id == 'marshmallow_root'),
        isTrue,
      );

      final flowerPrimaryOnly = VegetableDatabase.search(
        'marshmallow',
        quality: PlantQuality.flower,
        includeSecondaryOrgans: false,
      );
      expect(flowerPrimaryOnly.any((c) => c.id == 'marshmallow_root'), isFalse);
    });
  });
}
