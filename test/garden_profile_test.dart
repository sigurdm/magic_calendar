import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_calendar/main.dart';
import 'package:magic_calendar/src/core/models/models.dart';
import 'package:magic_calendar/src/core/task_window_planner.dart';
import 'package:magic_calendar/src/services/garden_service.dart';
import 'package:magic_calendar/src/ui/components/plant_recommendations_card.dart';
import 'package:magic_calendar/src/ui/components/task_planner_card.dart';

import 'support/fakes.dart';

void main() {
  group('GardenProfile & SavedLocation domain models', () {
    test('SavedLocation validates coordinates and resolves preset names', () {
      final presetMatch = SavedLocation.validated(
        latitude: 54.9037,
        longitude: 10.6074,
      );
      expect(presetMatch.name, 'Svendborg, Denmark');
      expect(presetMatch.displayLabel, 'Svendborg, Denmark');
      expect(presetMatch.headerBadgeLabel, 'Svendborg, Denmark (54.9°, 10.6°)');

      final unnamed = SavedLocation.validated(
        latitude: 56.16,
        longitude: 10.21,
      );
      expect(unnamed.name, isEmpty);
      expect(unnamed.displayLabel, '56.2°, 10.2°');
      expect(unnamed.headerBadgeLabel, '56.2°, 10.2°');

      expect(
        () => SavedLocation.validated(latitude: 95.0, longitude: 10.0),
        throwsArgumentError,
      );
      expect(
        () => SavedLocation.validated(latitude: 55.0, longitude: -190.0),
        throwsArgumentError,
      );
    });

    test(
      'QueuedGardenTask validates invariants and resolves crop metadata',
      () {
        final task = QueuedGardenTask(
          id: QueuedGardenTask.canonicalIdFor(
            action: TaskActionType.sowOutdoor,
            cropId: 'carrot',
            targetQuality: PlantQuality.root,
          ),
          action: TaskActionType.sowOutdoor,
          cropId: 'carrot',
          targetQuality: PlantQuality.root,
          note: 'Bed 3',
        );
        expect(task.crop, isNotNull);
        expect(task.crop!.nameEn, 'Carrot');
        expect(task.summaryLabel, contains('Sow Outdoors'));
        expect(task.summaryLabel, contains('Carrot'));

        expect(
          () => QueuedGardenTask(
            id: '',
            action: TaskActionType.sowOutdoor,
            targetQuality: PlantQuality.root,
          ),
          throwsArgumentError,
        );
        expect(
          () => QueuedGardenTask(
            id: 'bad_quality',
            action: TaskActionType.sowOutdoor,
            targetQuality: PlantQuality.none,
          ),
          throwsArgumentError,
        );
      },
    );

    test('GardenProfile defensive copies, immutable transitions, and JSON round-trip', () {
      final mutableSaved = <SavedLocation>[
        const SavedLocation(
          name: 'Allotment',
          latitude: 55.67,
          longitude: 12.56,
        ),
      ];
      final mutableCrops = <String>['carrot', 'kale'];
      final mutableTasks = <QueuedGardenTask>[
        QueuedGardenTask(
          id: 'prune:apple_tree:fruit',
          action: TaskActionType.prune,
          cropId: 'apple_tree',
          targetQuality: PlantQuality.fruit,
        ),
      ];

      final profile = GardenProfile(
        savedLocations: mutableSaved,
        starredCropIds: mutableCrops,
        taskQueue: mutableTasks,
      );

      // Mutating caller lists must not affect GardenProfile
      mutableSaved.clear();
      mutableCrops.clear();
      mutableTasks.clear();
      expect(profile.savedLocations, hasLength(1));
      expect(profile.starredCropIds, hasLength(2));
      expect(profile.taskQueue, hasLength(1));
      expect(profile.starredCrops.map((c) => c.id), ['carrot', 'kale']);

      // Toggle crop
      final withTomato = profile.withToggledCrop('tomato');
      expect(withTomato.isCropStarred('tomato'), isTrue);
      final withoutCarrot = withTomato.withToggledCrop('carrot');
      expect(withoutCarrot.isCropStarred('carrot'), isFalse);

      // Active location & saved locations
      const customLoc = SavedLocation(
        name: 'Summerhouse Garden',
        latitude: 56.0,
        longitude: 11.3,
      );
      final updatedLoc = withoutCarrot.withActiveLocation(customLoc);
      expect(updatedLoc.activeLocation, customLoc);
      expect(updatedLoc.savedLocations, contains(customLoc));

      // JSON round-trip
      final json = updatedLoc.toJson();
      final restored = GardenProfile.fromJson(json);
      expect(restored, equals(updatedLoc));

      // Version mismatch throws FormatException
      expect(
        () => GardenProfile.fromJson({...json, 'version': 999}),
        throwsFormatException,
      );
    });
  });

  group('FileGardenProfileStore & GardenProfileController persistence', () {
    test(
      'persists changes to disk and reloads across controller instances',
      () async {
        final tempDir = await Directory.systemTemp.createTemp('garden_store_');
        addTearDown(() => tempDir.delete(recursive: true));

        final filePath = '${tempDir.path}/garden_profile.json';
        final store = createFileGardenProfileStore(filePath)!;

        final controller1 = await GardenProfileController.load(store: store);
        expect(controller1.value.activeLocation, SavedLocation.defaultLocation);

        await controller1.setActiveLocation(
          const SavedLocation(
            name: 'Aarhus Kitchen Garden',
            latitude: 56.1629,
            longitude: 10.2039,
          ),
        );
        await controller1.toggleStarredCrop('carrot');
        await controller1.toggleStarredCrop('butterhead_lettuce');
        await controller1.toggleQueuedTask(
          action: TaskActionType.sowOutdoor,
          cropId: 'carrot',
          targetQuality: PlantQuality.root,
        );
        controller1.upsertPlot(
          GardenPlot(
            name: 'South Greenhouse',
            areaName: 'Orchard',
            plotType: GardenPlotType.greenhouse,
          ),
        );

        // Load a second controller from the same file on disk
        final controller2 = await GardenProfileController.load(store: store);
        expect(controller2.value.activeLocation.name, 'Aarhus Kitchen Garden');
        expect(
          controller2.value.starredCropIds,
          containsAll(['carrot', 'butterhead_lettuce']),
        );
        expect(controller2.value.taskQueue, hasLength(1));
        expect(controller2.value.taskQueue.first.cropId, 'carrot');
        expect(controller2.findPlot('South Greenhouse'), isNotNull);
        expect(
          controller2.findPlot('South Greenhouse')!.plotType,
          GardenPlotType.greenhouse,
        );

        controller1.dispose();
        controller2.dispose();
      },
    );
  });

  group('My Garden UI Integration Tests', () {
    testWidgets(
      'HomeHeader & LocationPickerDialog save custom named location and update coordinates',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final store = MemoryGardenProfileStore();
        final gardenController = GardenProfileController(store: store);
        addTearDown(gardenController.dispose);

        await tester.pumpWidget(
          MyApp(
            ephemeris: FakeEphemerisService(),
            weather: FakeWeatherService(),
            gardenController: gardenController,
          ),
        );
        await tester.pumpAndSettle();

        // Default named location is shown in header
        expect(find.text('Svendborg, Denmark'), findsOneWidget);

        // Open LocationPickerDialog
        await tester.tap(find.byKey(const ValueKey('location_picker_button')));
        await tester.pumpAndSettle();

        expect(find.text('Set Location'), findsOneWidget);

        await tester.enterText(
          find.byKey(const ValueKey('location_name_field')),
          'Bornholm Orchard',
        );
        await tester.enterText(
          find.byKey(const ValueKey('location_latitude_field')),
          '55.12',
        );
        await tester.enterText(
          find.byKey(const ValueKey('location_longitude_field')),
          '14.92',
        );
        await tester.tap(find.byKey(const ValueKey('save_location_button')));
        await tester.pumpAndSettle();

        expect(find.text('Bornholm Orchard'), findsOneWidget);
        expect(store.current?.activeLocation.name, 'Bornholm Orchard');
        expect(store.current?.savedLocations, isNotEmpty);

        // Re-open dialog and verify saved location chip & deletion
        await tester.tap(find.byKey(const ValueKey('location_picker_button')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('saved_location_Bornholm Orchard')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const ValueKey('delete_saved_location_Bornholm Orchard')),
        );
        await tester.pumpAndSettle();
        expect(store.current?.savedLocations, isEmpty);
      },
    );

    testWidgets(
      'PlantRecommendationsCard stars crops, shows My Garden Today banner, and filters by My Garden',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final gardenController = GardenProfileController(
          store: MemoryGardenProfileStore(),
        );
        addTearDown(gardenController.dispose);

        final rootInfo = CalendarInfo(
          quality: PlantQuality.root,
          isGrayDay: false,
          message: 'Root Day',
          sapFlow: 'Descending',
          isMoonAscending: false,
          vitality: 'Waxing',
          moonPhase: const MoonPhaseInfo(
            illuminatedFraction: 0.5,
            isWaxing: true,
            phaseAngle: 90,
          ),
          planets: const [],
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: PlantRecommendationsCard(
                  info: rootInfo,
                  selectedDate: DateTime(2026, 4, 15, 12, 0),
                  gardenController: gardenController,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initially no starred crops -> banner absent
        expect(
          find.byKey(const ValueKey('my_garden_today_banner')),
          findsNothing,
        );

        // Star Carrot via its chip star button
        final starCarrot = find.byKey(const ValueKey('star_crop_carrot'));
        expect(starCarrot, findsOneWidget);
        await tester.tap(starCarrot);
        await tester.pumpAndSettle();

        expect(gardenController.value.isCropStarred('carrot'), isTrue);
        expect(
          find.byKey(const ValueKey('my_garden_today_banner')),
          findsOneWidget,
        );
        expect(
          find.textContaining('1 of your 1 starred crops align'),
          findsOneWidget,
        );

        // Toggle My Garden filter chip
        final myGardenChip = find.byKey(const ValueKey('rec_filter_my_garden'));
        expect(myGardenChip, findsOneWidget);
        await tester.tap(myGardenChip);
        await tester.pumpAndSettle();

        expect(find.text('Gulerod (Carrot)'), findsOneWidget);
        expect(find.text('Pastinak (Parsnip)'), findsNothing);
      },
    );

    testWidgets(
      'TaskPlannerCard queues tasks, displays Active Task Queue with next window, and jumps timeline',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1100);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final gardenController = GardenProfileController(
          initialProfile: GardenProfile(starredCropIds: const ['carrot']),
          store: MemoryGardenProfileStore(),
        );
        addTearDown(gardenController.dispose);

        final epoch = DateTime.utc(2026, 4, 15, 10, 0);
        final orbitingEphemeris = FakeEphemerisService(
          longitudeAt: (time) {
            final hours = time.difference(epoch).inMinutes / 60.0;
            return (hours * (360.0 / (27.32 * 24.0))) % 360.0;
          },
          declinationAt: (time) {
            final hours = time.difference(epoch).inMinutes / 60.0;
            return 20.0 - (hours % 48.0);
          },
        );

        DateTime? jumpedTo;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: TaskPlannerCard(
                  selectedDate: DateTime(2026, 4, 15, 10, 0),
                  ephemeris: orbitingEphemeris,
                  gardenController: gardenController,
                  onTimeJump: (t) => jumpedTo = t,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initially no queued tasks
        expect(
          find.byKey(const ValueKey('active_task_queue_section')),
          findsNothing,
        );

        // Queue the active task (Take Cuttings · Grapevine)
        final queueBtn = find.byKey(const ValueKey('toggle_queue_task_button'));
        expect(queueBtn, findsOneWidget);
        await tester.ensureVisible(queueBtn);
        await tester.tap(queueBtn);
        await tester.pumpAndSettle();

        expect(gardenController.value.hasQueuedTasks, isTrue);
        expect(
          find.byKey(const ValueKey('active_task_queue_section')),
          findsOneWidget,
        );

        final taskId = gardenController.value.taskQueue.first.id;
        final jumpBtn = find.byKey(ValueKey('jump_queued_task_$taskId'));
        expect(jumpBtn, findsOneWidget);
        await tester.ensureVisible(jumpBtn);
        await tester.tap(jumpBtn);
        await tester.pumpAndSettle();
        expect(jumpedTo, isNotNull);

        // Mark queued task done
        final removeBtn = find.byKey(ValueKey('remove_queued_task_$taskId'));
        await tester.ensureVisible(removeBtn);
        await tester.tap(removeBtn);
        await tester.pumpAndSettle();
        expect(gardenController.value.hasQueuedTasks, isFalse);
      },
    );
  });
}
