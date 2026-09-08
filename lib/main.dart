import 'package:flutter/material.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sweph/sweph.dart';

import 'src/services/ephemeris_service.dart';
import 'src/services/weather_service.dart';
import 'src/ui/views/calendar_home_page.dart';
import 'src/ui/views/element_cards_gallery_page.dart';

export 'src/ui/components/moon_phase_widget.dart';
export 'src/ui/views/calendar_home_page.dart';
export 'src/ui/views/element_cards_gallery_page.dart';

void main() async {
  enableFlutterDriverExtension();
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

final class MyApp extends StatelessWidget {
  final EphemerisService ephemeris;
  final WeatherService weather;

  /// Rapid preview flag: when true, renders all 4 Goethean watercolor element
  /// cards simultaneously in a 2x2 grid.
  static const bool showGallery = false;

  /// Mobile preview flag: when true, renders the screen inside a 390x844 mobile viewport.
  static const bool previewMobile = false;

  const MyApp({super.key, required this.ephemeris, required this.weather});

  @override
  Widget build(BuildContext context) {
    final Widget page = showGallery
        ? const ElementCardsGalleryPage()
        : CalendarHomePage(ephemeris: ephemeris, weather: weather);

    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
      ),
      home: previewMobile
          ? Scaffold(
              backgroundColor: const Color(0xFF0A0A0E),
              body: Center(
                child: Container(
                  width: 390,
                  height: 844,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24, width: 1.5),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: page,
                ),
              ),
            )
          : page,
    );
  }
}
