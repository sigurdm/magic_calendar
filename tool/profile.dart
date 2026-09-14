// ignore_for_file: avoid_print
import 'package:magic_calendar/src/services/ephemeris_service.dart';
import 'package:sweph/sweph.dart';

void main() async {
  print('Initializing Swiss Ephemeris...');
  final initStopwatch = Stopwatch()..start();
  await Sweph.init();
  print('Init took ${initStopwatch.elapsedMilliseconds}ms');

  final service = AstronomiaEphemerisService();
  final start = DateTime.now();
  final end = start.add(const Duration(days: 14));

  print('\nRunning getIntervals for 14 days...');
  final calcStopwatch = Stopwatch()..start();
  final intervals = service.getIntervals(start, end);
  calcStopwatch.stop();

  print('getIntervals took ${calcStopwatch.elapsedMilliseconds}ms');
  print('Found ${intervals.length} intervals:');
  for (final interval in intervals) {
    print(
      ' - ${interval.start} to ${interval.end}: ${interval.quality.name} (Gray: ${interval.isGrayDay})',
    );
  }
}
