// Fetches the 1991–2020 daily climate series for central Funen, Denmark
// (Årslev, the Danish horticultural research station, 55.31° N, 10.45° E)
// from Open-Meteo and writes `lib/src/core/climate/danish_reference_climate.dart`.
//
// Usage: dart run tool/generate_reference_climate.dart
import 'dart:convert';
import 'dart:io';

import 'package:magic_calendar/src/core/climate/climate_profile.dart';
import 'package:magic_calendar/src/repository/open_meteo_client.dart';

const double _latitude = 55.31;
const double _longitude = 10.45;

Future<void> main(List<String> args) async {
  final client = OpenMeteoClient();
  try {
    final series = await client.getDailyClimateSeries(_latitude, _longitude);
    final profile = ClimateProfile.fromDailySeries(
      series,
      latitude: _latitude,
      longitude: _longitude,
    );
    final json = profile.toJson();
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(json));
  } finally {
    client.close();
  }
}
