import 'package:flutter_test/flutter_test.dart';
import 'package:magic_calendar/src/core/algorithm.dart';
import 'package:magic_calendar/src/core/dornach_boundaries.dart';
import 'package:magic_calendar/src/services/ephemeris_service.dart';

import 'support/fakes.dart';

void main() {
  group('TransitionEnvelope & Cusp Blending', () {
    test('Identifies stable quality far from boundary', () {
      // 70.0 is deep inside Taurus (Earth / Root: 55.0 to 90.0)
      final envelope = TransitionEnvelope.fromLongitude(70.0);

      expect(envelope.isTransition, isFalse);
      expect(envelope.fromQuality, PlantQuality.root);
      expect(envelope.toQuality, PlantQuality.root);
      expect(envelope.description, contains('Stable Root impulse'));
    });

    test('Detects cusp entry ~0.75° before boundary (Aries Fruit -> Taurus Root at 55°)', () {
      // Boundary is at 55.0. 55.0 - 0.75 = 54.25
      final envelope = TransitionEnvelope.fromLongitude(54.25);

      expect(envelope.isTransition, isTrue);
      expect(envelope.fromQuality, PlantQuality.fruit);
      expect(envelope.toQuality, PlantQuality.root);
      expect(envelope.progress, closeTo(0.0, 0.01));
      expect(envelope.description, contains('Fruit to Root'));
    });

    test('Detects exact cusp boundary crossing (50% progress)', () {
      // Exactly at 55.0
      final envelope = TransitionEnvelope.fromLongitude(55.0);

      expect(envelope.isTransition, isTrue);
      expect(envelope.fromQuality, PlantQuality.fruit);
      expect(envelope.toQuality, PlantQuality.root);
      expect(envelope.progress, closeTo(0.5, 0.01));
      expect(envelope.description, contains('50%'));
    });

    test('Detects cusp exit ~0.75° after boundary', () {
      // 55.0 + 0.75 = 55.75
      final envelope = TransitionEnvelope.fromLongitude(55.75);

      expect(envelope.isTransition, isTrue);
      expect(envelope.fromQuality, PlantQuality.fruit);
      expect(envelope.toQuality, PlantQuality.root);
      expect(envelope.progress, closeTo(1.0, 0.01));
      expect(envelope.description, contains('100%'));
    });

    test('Just beyond threshold is not in transition', () {
      // 55.0 + 0.76 is outside the 0.75° threshold
      final envelope = TransitionEnvelope.fromLongitude(55.76);

      expect(envelope.isTransition, isFalse);
      expect(envelope.fromQuality, PlantQuality.root);
      expect(envelope.toQuality, PlantQuality.root);
    });

    test(
      'Handles 360° / 0° wrap-around boundary (Aquarius Air -> Pisces Water)',
      () {
        // Aquarius ends at 360/0, Pisces starts at 0
        // 359.5° is 0.5° before 360°
        final beforeWrap = TransitionEnvelope.fromLongitude(359.5);

        expect(beforeWrap.isTransition, isTrue);
        expect(beforeWrap.fromQuality, PlantQuality.flower); // Aquarius
        expect(beforeWrap.toQuality, PlantQuality.leaf); // Pisces
        expect(beforeWrap.progress, closeTo(0.167, 0.02));

        // 0.3° is 0.3° after 0°
        final afterWrap = TransitionEnvelope.fromLongitude(0.3);

        expect(afterWrap.isTransition, isTrue);
        expect(afterWrap.fromQuality, PlantQuality.flower);
        expect(afterWrap.toQuality, PlantQuality.leaf);
        expect(afterWrap.progress, closeTo(0.7, 0.02));
      },
    );

    test('Custom threshold parameter works', () {
      // With threshold of 1.0 degree: 53.8 is outside, 54.1 is inside
      final outEnv = TransitionEnvelope.fromLongitude(
        53.8,
        dornachBoundaries,
        1.0,
      );
      expect(outEnv.isTransition, isFalse);

      final inEnv = TransitionEnvelope.fromLongitude(
        54.1,
        dornachBoundaries,
        1.0,
      );
      expect(inEnv.isTransition, isTrue);
      expect(inEnv.fromQuality, PlantQuality.fruit);
      expect(inEnv.toQuality, PlantQuality.root);
    });

    test('getCalendarInfo populates transitionEnvelope correctly', () {
      final boundaryTime = DateTime.utc(2026, 6, 21, 12, 0);
      // Moon at 54.8° (in cusp transition to Taurus Root)
      final service = FakeEphemerisService(
        moonLongitude: 54.8,
        moonPhase: const MoonPhaseInfo(
          illuminatedFraction: 0.5,
          isWaxing: false,
          phaseAngle: 90.0,
        ),
      );

      final info = getCalendarInfo(boundaryTime, service);

      expect(info.transitionEnvelope, isNotNull);
      expect(info.transitionEnvelope!.isTransition, isTrue);
      expect(info.transitionEnvelope!.fromQuality, PlantQuality.fruit);
      expect(info.transitionEnvelope!.toQuality, PlantQuality.root);
      expect(info.transitionEnvelope!.progress, greaterThan(0.0));
      expect(info.transitionEnvelope!.progress, lessThan(0.5));
    });
  });
}
