import 'package:flutter_test/flutter_test.dart';
import 'package:magic_calendar/src/core/algorithm.dart';
import 'package:magic_calendar/src/core/dornach_boundaries.dart';
import 'package:magic_calendar/src/services/ephemeris_service.dart';
import 'package:sweph/sweph.dart';

import 'support/sweph_test_loader.dart';

/// One sampled instant and the calendar state expected at it.
typedef _Case = ({DateTime time, PlantQuality quality, bool isGrayDay});

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Instants sampled from the published 2026 Maria Thun calendar.
///
/// Sampled at constellation boundaries and at midday either side of them, so a
/// boundary that moves by more than a couple of hours shows up here.
final _expectations = <_Case>[
  (
    time: DateTime.utc(2026, 1, 1, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 1, 10, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 1, 1, 12, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 1, 2, 0, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 1, 2, 10, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 2, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 2, 14, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 3, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 3, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 4, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 4, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 5, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 5, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 6, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 6, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 7, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 7, 6, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 1, 7, 12, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 1, 7, 18, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 8, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 8, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 8, 14, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 9, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 9, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 10, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 10, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 11, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 11, 8, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 11, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 12, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 12, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 13, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 13, 2, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 13, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 14, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 14, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 15, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 15, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 16, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 16, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 17, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 17, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 18, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 18, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 18, 22, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 19, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 19, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 20, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 20, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 21, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 21, 2, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 21, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 21, 20, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 1, 22, 0, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 1, 22, 8, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 22, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 23, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 23, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 23, 14, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 24, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 24, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 25, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 25, 10, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 25, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 26, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 26, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 27, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 27, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 27, 14, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 28, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 28, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 29, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 29, 10, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 1, 29, 12, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 1, 30, 0, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 1, 30, 10, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 30, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 31, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 31, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 1, 31, 22, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 1, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 1, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 2, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 2, 10, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 2, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 3, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 3, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 3, 14, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 2, 4, 0, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 2, 4, 2, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 4, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 5, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 5, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 6, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 6, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 7, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 7, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 7, 16, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 8, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 8, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 9, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 9, 10, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 9, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 10, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 10, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 11, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 11, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 11, 18, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 12, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 12, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 13, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 13, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 14, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 14, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 15, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 15, 6, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 15, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 16, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 16, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 17, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 17, 10, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 17, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 18, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 18, 2, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 2, 18, 12, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 2, 18, 14, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 19, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 19, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 19, 20, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 20, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 20, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 21, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 21, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 21, 16, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 22, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 22, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 23, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 23, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 23, 20, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 24, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 24, 12, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 2, 25, 0, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 2, 25, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 26, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 26, 6, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 26, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 27, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 27, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 28, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 28, 6, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 2, 28, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 1, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 1, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 1, 18, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 2, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 2, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 3, 0, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 3, 3, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 4, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 4, 10, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 4, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 5, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 5, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 6, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 6, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 7, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 7, 2, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 7, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 8, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 8, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 8, 18, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 9, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 9, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 10, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 10, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 11, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 11, 4, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 11, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 12, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 12, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 13, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 13, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 14, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 14, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 14, 14, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 15, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 15, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 16, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 16, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 16, 18, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 17, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 17, 10, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 3, 17, 12, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 3, 17, 22, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 18, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 18, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 19, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 19, 6, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 19, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 20, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 20, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 21, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 21, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 22, 0, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 3, 22, 12, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 3, 23, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 23, 2, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 23, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 24, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 24, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 25, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 25, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 26, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 26, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 27, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 27, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 28, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 28, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 29, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 29, 2, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 29, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 30, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 30, 6, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 3, 30, 12, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 3, 30, 18, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 31, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 31, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 3, 31, 18, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 1, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 1, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 2, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 2, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 3, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 3, 10, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 3, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 4, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 4, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 5, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 5, 2, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 5, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 6, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 6, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 7, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 7, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 8, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 8, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 9, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 9, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 10, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 10, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 10, 22, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 11, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 11, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 12, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 12, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 13, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 13, 4, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 13, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 13, 18, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 4, 14, 0, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 4, 14, 6, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 14, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 15, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 15, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 15, 16, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 16, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 16, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 17, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 17, 8, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 17, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 18, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 18, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 18, 20, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 4, 19, 0, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 4, 19, 12, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 4, 19, 20, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 20, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 20, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 21, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 21, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 21, 18, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 22, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 22, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 23, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 23, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 23, 18, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 24, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 24, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 25, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 25, 6, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 25, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 26, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 26, 10, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 4, 26, 12, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 4, 26, 22, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 27, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 27, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 28, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 28, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 29, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 29, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 30, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 30, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 4, 30, 16, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 1, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 1, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 2, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 2, 10, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 2, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 3, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 3, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 4, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 4, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 4, 18, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 5, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 5, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 6, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 6, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 7, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 7, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 8, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 8, 6, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 8, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 9, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 9, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 10, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 10, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 11, 0, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 5, 11, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 12, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 12, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 13, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 13, 2, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 13, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 14, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 14, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 14, 20, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 15, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 15, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 16, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 16, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 16, 20, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 17, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 17, 2, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 5, 17, 12, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 5, 18, 0, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 5, 18, 2, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 18, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 19, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 19, 2, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 19, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 20, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 20, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 21, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 21, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 22, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 22, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 22, 14, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 23, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 23, 10, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 5, 23, 12, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 5, 23, 22, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 24, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 24, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 25, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 25, 4, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 25, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 26, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 26, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 27, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 27, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 27, 22, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 28, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 28, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 29, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 29, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 29, 16, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 30, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 30, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 31, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 5, 31, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 1, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 1, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 2, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 2, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 3, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 3, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 4, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 4, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 5, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 5, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 6, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 6, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 6, 20, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 7, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 7, 2, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 6, 7, 12, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 6, 7, 14, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 8, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 8, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 9, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 9, 10, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 9, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 10, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 10, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 11, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 11, 6, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 11, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 12, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 12, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 13, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 13, 6, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 13, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 14, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 14, 12, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 6, 15, 0, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 6, 15, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 15, 14, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 16, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 16, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 17, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 17, 10, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 17, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 18, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 18, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 18, 22, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 19, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 19, 12, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 6, 20, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 20, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 21, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 21, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 22, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 22, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 23, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 23, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 24, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 24, 4, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 24, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 25, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 25, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 25, 22, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 26, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 26, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 27, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 27, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 28, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 28, 8, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 28, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 29, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 29, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 30, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 6, 30, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 1, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 1, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 1, 18, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 2, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 2, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 3, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 3, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 4, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 4, 2, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 7, 4, 12, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 7, 4, 14, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 5, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 5, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 6, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 6, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 6, 16, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 7, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 7, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 8, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 8, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 9, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 9, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 10, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 10, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 10, 16, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 11, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 11, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 12, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 12, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 12, 20, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 7, 13, 0, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 7, 13, 12, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 7, 13, 20, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 14, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 14, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 14, 20, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 15, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 15, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 16, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 16, 8, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 16, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 16, 20, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 7, 17, 0, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 7, 17, 8, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 17, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 18, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 18, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 18, 20, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 19, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 19, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 20, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 20, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 21, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 21, 10, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 21, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 22, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 22, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 23, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 23, 4, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 23, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 24, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 24, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 25, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 25, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 26, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 26, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 27, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 27, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 28, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 28, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 29, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 29, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 30, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 30, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 31, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 7, 31, 6, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 7, 31, 12, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 7, 31, 18, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 1, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 1, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 2, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 2, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 2, 22, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 3, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 3, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 4, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 4, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 4, 18, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 5, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 5, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 6, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 6, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 6, 22, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 7, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 7, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 8, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 8, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 9, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 9, 8, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 9, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 10, 0, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 8, 10, 12, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 8, 11, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 11, 6, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 11, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 12, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 12, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 12, 18, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 13, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 13, 4, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 8, 13, 12, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 8, 13, 16, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 14, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 14, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 15, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 15, 6, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 15, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 16, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 16, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 17, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 17, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 17, 18, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 18, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 18, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 19, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 19, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 20, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 20, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 21, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 21, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 21, 20, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 22, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 22, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 23, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 23, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 24, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 24, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 25, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 25, 8, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 25, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 26, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 26, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 27, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 27, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 27, 14, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 8, 28, 0, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 8, 28, 2, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 28, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 29, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 29, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 30, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 30, 4, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 30, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 31, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 8, 31, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 1, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 1, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 2, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 2, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 3, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 3, 4, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 3, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 4, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 4, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 5, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 5, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 5, 16, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 6, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 6, 10, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 9, 6, 12, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 9, 7, 0, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 9, 7, 10, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 7, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 7, 14, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 8, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 8, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 9, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 9, 2, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 9, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 9, 14, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 9, 10, 0, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 9, 10, 2, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 10, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 11, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 11, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 11, 14, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 12, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 12, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 13, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 13, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 14, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 14, 4, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 14, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 15, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 15, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 15, 20, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 16, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 16, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 17, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 17, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 18, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 18, 4, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 18, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 19, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 19, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 20, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 20, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 21, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 21, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 21, 16, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 22, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 22, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 23, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 23, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 23, 22, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 9, 24, 0, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 9, 24, 10, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 24, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 25, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 25, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 26, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 26, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 27, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 27, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 28, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 28, 8, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 28, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 29, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 29, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 30, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 30, 10, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 9, 30, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 1, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 1, 10, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 10, 1, 12, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 10, 2, 0, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 10, 2, 10, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 2, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 2, 20, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 3, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 3, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 4, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 4, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 4, 20, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 5, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 5, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 6, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 6, 10, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 6, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 6, 20, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 10, 7, 0, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 10, 7, 8, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 7, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 8, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 8, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 9, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 9, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 10, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 10, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 11, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 11, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 12, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 12, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 13, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 13, 4, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 13, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 14, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 14, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 15, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 15, 10, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 15, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 16, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 16, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 17, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 17, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 18, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 18, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 19, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 19, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 20, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 20, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 21, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 21, 4, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 10, 21, 12, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 10, 21, 16, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 22, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 22, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 23, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 23, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 23, 20, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 24, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 24, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 25, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 25, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 25, 16, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 26, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 26, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 27, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 27, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 27, 18, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 28, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 28, 8, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 10, 28, 12, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 10, 29, 0, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 10, 29, 8, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 29, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 30, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 30, 4, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 30, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 31, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 10, 31, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 1, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 1, 2, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 1, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 2, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 2, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 2, 14, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 2, 22, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 11, 3, 0, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 11, 3, 10, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 3, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 4, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 4, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 5, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 5, 6, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 5, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 6, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 6, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 7, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 7, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 7, 20, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 8, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 8, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 9, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 9, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 10, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 10, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 11, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 11, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 11, 20, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 12, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 12, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 13, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 13, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 14, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 14, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 15, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 15, 8, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 15, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 16, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 16, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 17, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 17, 6, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 11, 17, 12, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 11, 17, 18, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 18, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 18, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 19, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 19, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 20, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 20, 6, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 20, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 21, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 21, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 22, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 22, 2, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 22, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 23, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 23, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 24, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 24, 4, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 24, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 25, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 25, 10, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 11, 25, 12, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 11, 26, 0, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 11, 26, 10, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 26, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 27, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 27, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 28, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 28, 10, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 28, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 29, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 29, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 29, 20, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 29, 22, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 11, 30, 0, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 11, 30, 10, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 11, 30, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 1, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 1, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 2, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 2, 10, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 2, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 3, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 3, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 4, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 4, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 5, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 5, 2, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 5, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 6, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 6, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 6, 18, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 7, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 7, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 8, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 8, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 9, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 9, 2, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 9, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 10, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 10, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 11, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 11, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 12, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 12, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 12, 16, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 13, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 13, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 14, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 14, 8, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 12, 14, 12, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 12, 14, 20, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 15, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 15, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 16, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 16, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 17, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 17, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 17, 16, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 18, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 18, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 19, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 19, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 20, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 20, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 21, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 21, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 21, 16, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 22, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 22, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 23, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 23, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 23, 22, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 12, 24, 0, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 12, 24, 12, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 12, 24, 22, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 25, 0, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 25, 12, 0),
    quality: PlantQuality.flower,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 25, 20, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 26, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 26, 12, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 27, 0, 0),
    quality: PlantQuality.leaf,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 27, 2, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 12, 27, 12, 0),
    quality: PlantQuality.none,
    isGrayDay: true,
  ),
  (
    time: DateTime.utc(2026, 12, 27, 14, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 28, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 28, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 29, 0, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 29, 12, 0),
    quality: PlantQuality.fruit,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 29, 18, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 30, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 30, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 31, 0, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
  (
    time: DateTime.utc(2026, 12, 31, 12, 0),
    quality: PlantQuality.root,
    isGrayDay: false,
  ),
];

void main() async {
  await ensureSwephLoaded();
  await Sweph.init();
  final service = AstronomiaEphemerisService();

  group('2026 calendar matches the published Maria Thun tables', () {
    for (var month = 1; month <= 12; month++) {
      final cases = _expectations.where((c) => c.time.month == month).toList();

      test('${_monthNames[month - 1]} (${cases.length} sampled instants)', () {
        // Collected rather than asserted one by one: a single `expect` per
        // instant would abort the month at the first mismatch, and when a
        // boundary calculation shifts it is the *shape* of the failures
        // across the month that says what went wrong.
        final mismatches = <String>[];

        for (final expectation in cases) {
          final info = getCalendarInfo(
            expectation.time,
            service,
            boundaries: customCalendarBoundaries,
          );
          if (info.quality != expectation.quality) {
            mismatches.add(
              '${expectation.time}: quality was ${info.quality.name}, '
              'expected ${expectation.quality.name}',
            );
          }
          if (info.isGrayDay != expectation.isGrayDay) {
            mismatches.add(
              '${expectation.time}: isGrayDay was ${info.isGrayDay}, '
              'expected ${expectation.isGrayDay}',
            );
          }
        }

        expect(mismatches, isEmpty, reason: mismatches.join('\n'));
      });
    }
  });
}
