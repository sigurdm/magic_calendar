import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sweph/sweph.dart';

import 'src/services/ephemeris_service.dart';
import 'src/services/weather_service.dart';
import 'src/ui/theme/app_theme.dart';
import 'src/ui/views/calendar_home_page.dart';

/// Entry point for the Magic Calendar application.
Future<void> main() async {
  // Must run before any platform channel use (`getApplicationSupportDirectory`
  // below) and before `runApp`. This was previously satisfied only as a side
  // effect of `enableFlutterDriverExtension()` constructing the binding.
  WidgetsFlutterBinding.ensureInitialized();

  final weatherService = CombinedWeatherService(
    yrNoService: YrNoWeatherService(
      userAgent: 'MagicCalendar/1.0 post@sigurdmeldgaard.dk',
    ),
    dmiService: DmiWeatherService(),
  );

  String? epheFilesPath;
  try {
    final appSupportDir = await getApplicationSupportDirectory();
    epheFilesPath = '${appSupportDir.path}/ephe_files';
  } catch (_) {
    // Fallback if path_provider fails in non-app environments
  }

  await Sweph.init(epheFilesPath: epheFilesPath);
  await EphemerisWorker.init(epheFilesPath: epheFilesPath);

  runApp(MyApp(ephemeris: IsolateEphemerisService(), weather: weatherService));
}

/// Root widget of the Magic Calendar application.
final class MyApp extends StatelessWidget {
  /// Source of astronomical data.
  final EphemerisService ephemeris;

  /// Source of weather forecasts and history.
  final WeatherService weather;

  /// Creates the application root.
  const MyApp({super.key, required this.ephemeris, required this.weather});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: buildAppTheme(),
      home: CalendarHomePage(ephemeris: ephemeris, weather: weather),
    );
  }
}
