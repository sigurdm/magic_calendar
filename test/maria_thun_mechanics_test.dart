import 'package:flutter_test/flutter_test.dart';
import 'package:magic_calendar/src/core/algorithm.dart';
import 'package:magic_calendar/src/services/ephemeris_service.dart';
import 'package:sweph/sweph.dart';

import 'support/sweph_test_loader.dart';

void main() {
  setUpAll(() async {
    await ensureSwephLoaded();
    await Sweph.init();
  });

  group('Maria Thun Mechanics - Ephemeris & Astronomical Aspects', () {
    final service = AstronomiaEphemerisService();

    test('Observer location can be updated dynamically (topocentric fix)', () {
      // Set to Copenhagen, Denmark
      service.setObserverLocation(55.6761, 12.5683, 10.0);
      final dec1 = service.getMoonDeclination(DateTime.utc(2026, 6, 21, 12, 0));

      // Set to Melbourne, Australia
      service.setObserverLocation(-37.8136, 144.9631, 30.0);
      final dec2 = service.getMoonDeclination(DateTime.utc(2026, 6, 21, 12, 0));

      // Reset to Dornach
      service.setObserverLocation(47.4814, 7.6178, 350.0);

      // Topocentric declination should reflect the observer's geographic position
      expect(dec1, isNotNull);
      expect(dec2, isNotNull);
      expect(
        (dec1 - dec2).abs(),
        greaterThan(0.01),
        reason: 'Topocentric declination must vary with geographic latitude',
      );
    });

    test('getAspects identifies planetary aspects including squares, trines, and oppositions', () {
      // Sample test date in 2026
      final aspects = service.getAspects(DateTime.utc(2026, 1, 1, 12, 0));
      expect(aspects, isA<List<PlanetaryAspect>>());

      for (final aspect in aspects) {
        expect(aspect.body1, isNotEmpty);
        expect(aspect.body2, isNotEmpty);
        expect(aspect.agriculturalEffect, isNotEmpty);
        expect(aspect.separationDegrees, inInclusiveRange(0.0, 180.0));
      }
    });

    test('getCalendarInfo populates activeAspects and isEclipse fields', () {
      final info = getCalendarInfo(
        DateTime.utc(2026, 1, 1, 12, 0),
        service,
        includePlanets: true,
      );

      expect(info.activeAspects, isNotNull);
      expect(info.isEclipse, isFalse);
    });

    test('isNearEclipse identifies eclipses across 2026', () {
      // Solar eclipse on 2026-02-17 (Annular solar eclipse)
      final nearEclipse = service.isNearEclipse(
        DateTime.utc(2026, 2, 17, 12, 0),
      );
      expect(nearEclipse, isTrue);

      // Normal date far from eclipse
      final normalDate = service.isNearEclipse(
        DateTime.utc(2026, 6, 15, 12, 0),
      );
      expect(normalDate, isFalse);
    });
  });
}
