import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_calendar/src/core/models/models.dart';
import 'package:magic_calendar/src/core/task_window_planner.dart';
import 'package:magic_calendar/src/core/vegetable_database.dart';
import 'package:magic_calendar/src/ui/components/task_planner_card.dart';

import 'support/fakes.dart';

/// Builds a [FakeEphemerisService] whose Moon advances ~13.2 degrees/day along the
/// ecliptic and oscillates in declination over a 27.2-day tropical cycle.
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
  group('TaskWindowPlanner - Maria Thun Task Window Search', () {
    test('Take Grape Cuttings finds Fruit Day windows and ranks Descending Moon (Pflanzzeit) as optimal', () {
      final start = DateTime.utc(2026, 9, 28, 8, 0);
      final ephemeris = _buildOrbitingFakeEphemeris(start);
      final grapevine = VegetableDatabase.findById('grapevine');
      expect(grapevine, isNotNull);
      expect(grapevine!.quality, PlantQuality.fruit);

      final result = TaskWindowPlanner.findUpcomingWindows(
        action: TaskActionType.takeCuttings,
        targetQuality: grapevine.quality,
        crop: grapevine,
        startTime: start,
        ephemeris: ephemeris,
        searchDays: 30,
      );

      expect(result.windows, isNotEmpty);
      expect(
        result.windows.any((w) => w.suitability == TaskSuitability.optimal),
        isTrue,
      );
      for (final window in result.windows) {
        expect(window.quality, PlantQuality.fruit);
        if (window.isDescending) {
          expect(window.suitability, TaskSuitability.optimal);
        } else {
          expect(window.suitability, TaskSuitability.favorable);
        }
      }

      // September is outside Grapevine cuttingMonths ([1, 2, 3, 11, 12]),
      // so isCurrentlyInSeason is false and nextSeasonalStartDate is November 1, 2026.
      expect(result.isCurrentlyInSeason, isFalse);
      expect(result.nextSeasonalStartDate, DateTime(2026, 11, 1, 9, 0));
    });

    test('Sow Lettuce finds Leaf Day windows as optimal regardless of Ascending/Descending Moon', () {
      final aprilStart = DateTime.utc(2026, 4, 10, 8, 0);
      final ephemeris = _buildOrbitingFakeEphemeris(aprilStart);
      final lettuce = VegetableDatabase.findById('lettuce');
      expect(lettuce, isNotNull);

      final result = TaskWindowPlanner.findUpcomingWindows(
        action: TaskActionType.sowOutdoor,
        targetQuality: lettuce!.quality,
        crop: lettuce,
        startTime: aprilStart,
        ephemeris: ephemeris,
        searchDays: 14,
      );

      expect(result.isCurrentlyInSeason, isTrue);
      expect(result.nextSeasonalStartDate, isNull);
      expect(result.windows, isNotEmpty);
      for (final window in result.windows) {
        expect(window.quality, PlantQuality.leaf);
        expect(window.suitability, TaskSuitability.optimal);
      }
    });

    test('Harvest Marshmallow Root requires Root Day + Descending Moon for optimal storage/medicinal root harvest', () {
      final octoberStart = DateTime.utc(2026, 10, 5, 8, 0);
      final ephemeris = _buildOrbitingFakeEphemeris(octoberStart);
      final marshmallow = VegetableDatabase.findById('marshmallow_root');
      expect(marshmallow, isNotNull);
      expect(marshmallow!.quality, PlantQuality.root);

      final result = TaskWindowPlanner.findUpcomingWindows(
        action: TaskActionType.harvestStorage,
        targetQuality: marshmallow.quality,
        crop: marshmallow,
        startTime: octoberStart,
        ephemeris: ephemeris,
        searchDays: 30,
      );

      expect(result.isCurrentlyInSeason, isTrue);
      expect(result.windows, isNotEmpty);
      expect(
        result.windows.any(
          (w) =>
              w.quality == PlantQuality.root &&
              w.isDescending &&
              w.suitability == TaskSuitability.optimal,
        ),
        isTrue,
      );
    });

    test('Graft Scions (TaskActionType.graft) uses graftingMonths and ranks Ascending Moon + matching Plant-Part Day as optimal', () {
      final marchStart = DateTime.utc(2026, 3, 10, 8, 0);
      final ephemeris = _buildOrbitingFakeEphemeris(marchStart);
      final appleTree = VegetableDatabase.findById('apple_tree');
      expect(appleTree, isNotNull);
      expect(appleTree!.graftingMonths, isNotEmpty);
      expect(appleTree.graftingMonths, contains(3));

      final result = TaskWindowPlanner.findUpcomingWindows(
        action: TaskActionType.graft,
        targetQuality: appleTree.quality,
        crop: appleTree,
        startTime: marchStart,
        ephemeris: ephemeris,
        searchDays: 30,
      );

      expect(result.isCurrentlyInSeason, isTrue);
      expect(result.seasonalMonths, equals(appleTree.graftingMonths));
      expect(result.windows, isNotEmpty);
      expect(
        result.windows.any((w) => w.suitability == TaskSuitability.optimal),
        isTrue,
      );

      for (final window in result.windows) {
        expect(window.quality, PlantQuality.fruit);
        // Grafting requires Ascending Moon (!isDescending) for rising sap union
        if (!window.isDescending) {
          expect(window.suitability, TaskSuitability.optimal);
        } else {
          expect(window.suitability, TaskSuitability.favorable);
        }
      }
    });

    test('Divide Perennials (TaskActionType.divide) uses divisionMonths and ranks Descending Moon (Pflanzzeit) + matching Plant-Part Day as optimal', () {
      final octoberStart = DateTime.utc(2026, 10, 5, 8, 0);
      final ephemeris = _buildOrbitingFakeEphemeris(octoberStart);
      final marshmallow = VegetableDatabase.findById('marshmallow_root');
      expect(marshmallow, isNotNull);
      expect(marshmallow!.divisionMonths, isNotEmpty);
      expect(marshmallow.divisionMonths, contains(10));

      final result = TaskWindowPlanner.findUpcomingWindows(
        action: TaskActionType.divide,
        targetQuality: marshmallow.quality,
        crop: marshmallow,
        startTime: octoberStart,
        ephemeris: ephemeris,
        searchDays: 30,
      );

      expect(result.isCurrentlyInSeason, isTrue);
      expect(result.seasonalMonths, equals(marshmallow.divisionMonths));
      expect(result.windows, isNotEmpty);
      expect(
        result.windows.any((w) => w.suitability == TaskSuitability.optimal),
        isTrue,
      );

      for (final window in result.windows) {
        expect(window.quality, PlantQuality.root);
        // Perennial division requires Descending Moon (Pflanzzeit)
        if (window.isDescending) {
          expect(window.suitability, TaskSuitability.optimal);
        } else {
          expect(window.suitability, TaskSuitability.favorable);
        }
      }
    });

    test('Multi-organ scheduling overrides primary quality and flips storage harvest between Descending Moon (Root) and Ascending Moon (Flower/Leaf/Fruit)', () {
      final julyStart = DateTime.utc(2026, 7, 15, 8, 0);
      final ephemeris = _buildOrbitingFakeEphemeris(julyStart);
      final marshmallow = VegetableDatabase.findById('marshmallow_root');
      expect(marshmallow, isNotNull);
      expect(marshmallow!.hasMultipleOrgans, isTrue);
      expect(marshmallow.supportsQuality(PlantQuality.root), isTrue);
      expect(marshmallow.supportsQuality(PlantQuality.flower), isTrue);
      expect(marshmallow.supportsQuality(PlantQuality.leaf), isTrue);

      // 1. Primary organ: Root harvest -> Root Day + Descending Moon is optimal
      final rootResult = TaskWindowPlanner.findUpcomingWindows(
        action: TaskActionType.harvestStorage,
        targetQuality: PlantQuality.root,
        crop: marshmallow,
        startTime: julyStart,
        ephemeris: ephemeris,
        searchDays: 30,
      );
      expect(rootResult.targetQuality, PlantQuality.root);
      expect(rootResult.activeOrganRule, isNull);
      for (final w in rootResult.windows) {
        expect(w.quality, PlantQuality.root);
        if (w.isDescending) {
          expect(w.suitability, TaskSuitability.optimal);
        } else {
          expect(w.suitability, TaskSuitability.favorable);
        }
      }

      // 2. Secondary organ: Flower harvest -> Flower Day + Ascending Moon (!isDescending) is optimal
      final flowerResult = TaskWindowPlanner.findUpcomingWindows(
        action: TaskActionType.harvestStorage,
        targetQuality: PlantQuality.flower,
        crop: marshmallow,
        startTime: julyStart,
        ephemeris: ephemeris,
        searchDays: 30,
      );
      expect(flowerResult.targetQuality, PlantQuality.flower);
      expect(flowerResult.activeOrganRule, isNotNull);
      expect(flowerResult.activeOrganRule!.quality, PlantQuality.flower);
      expect(flowerResult.isCurrentlyInSeason, isTrue);
      expect(flowerResult.windows, isNotEmpty);
      for (final w in flowerResult.windows) {
        expect(w.quality, PlantQuality.flower);
        if (!w.isDescending) {
          expect(w.suitability, TaskSuitability.optimal);
        } else {
          expect(w.suitability, TaskSuitability.favorable);
        }
      }
    });
  });

  group('TaskPlannerCard Widget', () {
    testWidgets(
      'renders quick presets, switches between presets, and invokes onTimeJump when a window is tapped',
      (tester) async {
        final start = DateTime(2026, 9, 28, 10, 0);
        final ephemeris = _buildOrbitingFakeEphemeris(start);
        DateTime? jumpedTo;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: TaskPlannerCard(
                  selectedDate: start,
                  ephemeris: ephemeris,
                  onTimeJump: (dt) {
                    jumpedTo = dt;
                  },
                ),
              ),
            ),
          ),
        );

        expect(find.text('When Is a Good Time To...?'), findsOneWidget);
        expect(find.text('Take Grape Cuttings'), findsOneWidget);
        expect(find.text('Sow Lettuce'), findsOneWidget);
        expect(find.text('Harvest Marshmallow Root'), findsOneWidget);

        // Tap "Jump to Nov 2026" prime season button for Grapevine cuttings in September
        final jumpSeasonBtn = find.byKey(
          const ValueKey('jump_to_prime_season_button'),
        );
        expect(jumpSeasonBtn, findsOneWidget);
        await tester.ensureVisible(jumpSeasonBtn);
        await tester.tap(jumpSeasonBtn);
        await tester.pump();
        expect(jumpedTo, DateTime(2026, 11, 1, 9, 0));

        // Switch preset to "Sow Lettuce"
        final sowLettucePreset = find.byKey(
          const ValueKey('preset_sowOutdoor_lettuce'),
        );
        await tester.ensureVisible(sowLettucePreset);
        await tester.tap(sowLettucePreset);
        await tester.pump();
        expect(
          find.textContaining('Hovedsalat (Butterhead Lettuce)'),
          findsWidgets,
        );
      },
    );

    testWidgets(
      'supports selecting Graft and Divide actions, category filtering, multi-organ overrides, and searching plants by alias',
      (tester) async {
        tester.view.physicalSize = const Size(800, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final start = DateTime(2026, 4, 15, 10, 0);
        final ephemeris = _buildOrbitingFakeEphemeris(start);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: TaskPlannerCard(
                  selectedDate: start,
                  ephemeris: ephemeris,
                  onTimeJump: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);

        // Select Graft action chip
        final graftChip = find.byKey(const ValueKey('task_action_graft'));
        expect(graftChip, findsOneWidget);
        await tester.ensureVisible(graftChip);
        await tester.tap(graftChip);
        await tester.pump();
        expect(tester.takeException(), isNull);

        // Select Divide action chip
        final divideChip = find.byKey(const ValueKey('task_action_divide'));
        expect(divideChip, findsOneWidget);
        await tester.ensureVisible(divideChip);
        await tester.tap(divideChip);
        await tester.pump();
        expect(tester.takeException(), isNull);

        // Filter by PlantCategory
        final medicinalCatChip = find.byKey(
          const ValueKey('planner_category_medicinalHerb'),
        );
        expect(medicinalCatChip, findsOneWidget);
        await tester.ensureVisible(medicinalCatChip);
        await tester.tap(medicinalCatChip);
        await tester.pump();
        expect(tester.takeException(), isNull);

        final allCatChip = find.byKey(const ValueKey('planner_category_all'));
        expect(allCatChip, findsOneWidget);
        await tester.ensureVisible(allCatChip);
        await tester.tap(allCatChip);
        await tester.pump();
        expect(tester.takeException(), isNull);

        // Enter alias query in search field to find Marshmallow Root ('Althea')
        final searchField = find.byKey(
          const ValueKey('task_planner_plant_search'),
        );
        expect(searchField, findsOneWidget);
        await tester.enterText(searchField, 'Althea');
        await tester.pump();
        expect(tester.takeException(), isNull);

        final marshmallowChip = find.byKey(
          const ValueKey('planner_crop_marshmallow_root'),
        );
        expect(marshmallowChip, findsOneWidget);
        await tester.ensureVisible(marshmallowChip);
        await tester.tap(marshmallowChip);
        await tester.pump();
        expect(tester.takeException(), isNull);

        // Switch Marshmallow Root to its secondary Flower organ override
        final flowerOrganOverride = find.byKey(
          const ValueKey('crop_organ_override_flower'),
        );
        if (flowerOrganOverride.evaluate().isNotEmpty) {
          await tester.ensureVisible(flowerOrganOverride);
          await tester.tap(flowerOrganOverride);
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
      },
    );
  });
}
