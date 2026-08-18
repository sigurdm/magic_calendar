import 'package:flutter_test/flutter_test.dart';
import 'package:sweph/sweph.dart';

void main() {
  test('Swiss Ephemeris Geocentric Moon Position Probe', () async {
    await Sweph.init();
    final pos = Sweph.swe_calc_ut(
      2451545.0,
      HeavenlyBody.SE_MOON,
      SwephFlag(2 | 256),
    );
    expect(pos.distance, greaterThan(0.0));
  });
}
