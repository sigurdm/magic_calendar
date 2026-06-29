import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'package:sweph/sweph.dart';

import 'src/services/ephemeris_service.dart';
import 'src/ui/views/time_scroll_view.dart';
import 'src/ui/components/planetary_ribbon.dart';
import 'src/ui/components/planting_icons.dart';
import 'src/services/weather_service.dart';
import 'src/ui/painters/moon_painter.dart';

void main() async {
  enableFlutterDriverExtension();
  final weatherService = CombinedWeatherService(
    yrNoService: YrNoWeatherService(
      userAgent: 'MagicCalendar/1.0 (sigurd.meldgaard@example.com)',
    ),
    dmiService: DmiWeatherService(),
  );

  await Sweph.init();
  await EphemerisWorker.init();

  runApp(
    MyApp(ephemeris: IsolateEphemerisService(), weather: weatherService),
  );
}

final class MyApp extends StatelessWidget {
  final EphemerisService ephemeris;
  final WeatherService weather;

  const MyApp({super.key, required this.ephemeris, required this.weather});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
      ),
      home: CalendarHomePage(ephemeris: ephemeris, weather: weather),
    );
  }
}

final class CalendarHomePage extends StatefulWidget {
  final EphemerisService ephemeris;
  final WeatherService weather;

  const CalendarHomePage({
    super.key,
    required this.ephemeris,
    required this.weather,
  });

  @override
  State<CalendarHomePage> createState() => _CalendarHomePageState();
}

final class _CalendarHomePageState extends State<CalendarHomePage> {
  final ValueNotifier<DateTime> _selectedDateNotifier = ValueNotifier(
    DateTime.now(),
  );
  final ValueNotifier<CalendarInfo?> _infoNotifier = ValueNotifier(null);
  final ValueNotifier<List<WeatherDataPoint>?> _weatherNotifier = ValueNotifier(
    null,
  );
  final ValueNotifier<double> _latNotifier = ValueNotifier(54.9037);
  final ValueNotifier<double> _lonNotifier = ValueNotifier(10.6074);
  final _timeScrollController = TimeScrollController();
  late final WeatherService _weatherService;

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _weatherService = widget.weather;
    _fetchWeather();
    _updateInfo(_selectedDateNotifier.value, immediate: true);
  }

  void _fetchWeather() async {
    try {
      final forecast = await _weatherService.getForecast(
        _latNotifier.value,
        _lonNotifier.value,
      );
      _weatherNotifier.value = forecast;
    } catch (e) {
      debugPrint('Failed to fetch weather: $e');
    }
  }

  void _updateInfo(DateTime time, {bool immediate = false}) async {
    final info = await EphemerisWorker.getCalendarInfo(time, true);
    if (mounted) {
      _infoNotifier.value = info;
    }
  }

  void _onTimeSelected(DateTime time) {
    _selectedDateNotifier.value = time;
    _updateInfo(time);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _selectedDateNotifier.dispose();
    _infoNotifier.dispose();
    _latNotifier.dispose();
    _lonNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E1E2E), Color(0xFF11111B)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                ValueListenableBuilder<DateTime>(
                  valueListenable: _selectedDateNotifier,
                  builder: (context, date, _) {
                    return Text(
                      DateFormat('EEEE, MMM d, y - HH:00').format(date),
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                ValueListenableBuilder<CalendarInfo?>(
                  valueListenable: _infoNotifier,
                  builder: (context, info, _) {
                    if (info == null) {
                      return const SizedBox(height: 140);
                    }
                    return _buildQualityCard(info);
                  },
                ),
                const SizedBox(height: 20),
                ListenableBuilder(
                  listenable: Listenable.merge([_latNotifier, _lonNotifier]),
                  builder: (context, _) {
                    return TimeScrollView(
                      ephemeris: widget.ephemeris,
                      weatherService: _weatherService,
                      controller: _timeScrollController,
                      onTimeSelected: _onTimeSelected,
                      latitude: _latNotifier.value,
                      longitude: _lonNotifier.value,
                    );
                  },
                ),
                const SizedBox(height: 20),
                PlanetaryRibbon(
                  timeNotifier: _selectedDateNotifier,
                  ephemeris: widget.ephemeris,
                ),
                const SizedBox(height: 20),
                ValueListenableBuilder<CalendarInfo?>(
                  valueListenable: _infoNotifier,
                  builder: (context, info, _) {
                    if (info == null) {
                      return const SizedBox();
                    }
                    return _buildDetailsCard(info);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: _showLocationPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 18,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    ValueListenableBuilder<double>(
                      valueListenable: _latNotifier,
                      builder: (context, lat, _) {
                        return ValueListenableBuilder<double>(
                          valueListenable: _lonNotifier,
                          builder: (context, lon, _) {
                            return Text(
                              '${lat.toStringAsFixed(1)}°, ${lon.toStringAsFixed(1)}°',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white70,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Magic Calendar',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        Row(
          children: [
            TextButton.icon(
              onPressed: () {
                _timeScrollController.scrollToNow();
              },
              icon: const Icon(Icons.history, color: Colors.white),
              label: const Text('NOW', style: TextStyle(color: Colors.white)),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.calendar_month, color: Colors.white),
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDateNotifier.value,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (date != null) {
                  _onTimeSelected(date);
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  void _showLocationPicker() {
    final latController = TextEditingController(
      text: _latNotifier.value.toString(),
    );
    final lonController = TextEditingController(
      text: _lonNotifier.value.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: latController,
              decoration: const InputDecoration(
                labelText: 'Latitude (-90 to 90)',
              ),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: lonController,
              decoration: const InputDecoration(
                labelText: 'Longitude (-180 to 180)',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final lat = double.tryParse(latController.text);
              final lon = double.tryParse(lonController.text);
              if (lat != null && lon != null) {
                _latNotifier.value = lat.clamp(-90, 90);
                _lonNotifier.value = lon.clamp(-180, 180);
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityCard(CalendarInfo info) {
    String title = 'Unknown';
    String desc = 'Select a date to see quality.';

    if (info.isGrayDay) {
      title = 'Gray Day';
      desc = info.message;
    } else if (info.message.startsWith('Special')) {
      title = info.message.split(':').first;
      String explanation = '';
      switch (info.quality) {
        case PlantQuality.flower:
          explanation =
              'In biodynamic gardening, planetary trines in Air/Light constellations create exceptional cosmic energy for flowering plants. Ideal for sowing, cultivating, and picking cut flowers, medicinal herbs, and broccoli/cauliflower to maximize aroma, fragrance, and essential oils.';
          break;
        case PlantQuality.fruit:
          explanation =
              'In biodynamic gardening, planetary trines in Fire constellations concentrate warmth and energy into seed formation and fruit ripening. Excellent for harvesting tomatoes, apples, squash, and grains for long-term storage and superior flavor.';
          break;
        case PlantQuality.leaf:
          explanation =
              'In biodynamic gardening, planetary trines in Water constellations channel intense moisture impulses. Peak time for sowing leafy greens, lettuce, spinach, and herbs, promoting lush foliage and preventing early bolting.';
          break;
        case PlantQuality.root:
          explanation =
              'In biodynamic gardening, planetary trines in Earth constellations focus gravitational earth forces deep into root systems. Optimal for planting and harvesting long-storing root vegetables like carrots, potatoes, parsnips, and beets.';
          break;
        default:
          explanation =
              'Special planetary alignment boosting elemental plant development.';
          break;
      }
      desc = '${info.message}\n\n$explanation';
    } else {
      switch (info.quality) {
        case PlantQuality.root:
          title = 'Root Day';
          desc = 'Good for planting carrots, beets, potatoes, onions.';
          break;
        case PlantQuality.leaf:
          title = 'Leaf Day';
          desc = 'Good for planting lettuce, spinach, herbs, cabbage.';
          break;
        case PlantQuality.flower:
          title = 'Flower Day';
          desc = 'Good for planting broccoli, cauliflower, cut flowers.';
          break;
        case PlantQuality.fruit:
          title = 'Fruit Day';
          desc = 'Good for planting tomatoes, beans, grains, fruit trees.';
          break;
        case PlantQuality.none:
          title = 'No Specific Quality';
          desc = 'Neutral day for planting.';
          break;
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                children: [
                  PlantingQualityIcon(
                    quality: info.quality,
                    isGrayDay: info.isGrayDay,
                    size: 200,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                desc,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsCard(CalendarInfo info) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: ValueListenableBuilder<DateTime>(
        valueListenable: _selectedDateNotifier,
        builder: (context, date, _) {
          final moonPhase = widget.ephemeris.getMoonPhase(date);

          final dec1 = widget.ephemeris.getMoonDeclination(date);
          final dec2 = widget.ephemeris.getMoonDeclination(
            date.add(const Duration(hours: 1)),
          );
          final realTimeSapFlow = dec2 > dec1 ? 'Ascending' : 'Descending';

          final isAscending = dec2 > dec1;
          final sapExplanation = isAscending
              ? "Sap rises, bringing energy to leaves, flowers and fruits. Ideal for harvesting above-ground crops."
              : "Sap recedes to the soil. Ideal for planting, pruning, and harvesting root crops.";

          final vitalityExplanation = moonPhase.isWaxing
              ? "Increasing lunar vitality stimulates above-ground growth and germination."
              : "Decreasing lunar vitality supports root development and soil consolidation.";

          String illumExplanation;
          if (moonPhase.illuminatedFraction > 0.8) {
            illumExplanation =
                "High nocturnal light stimulates foliage growth.";
          } else if (moonPhase.illuminatedFraction < 0.2) {
            illumExplanation =
                "Dark nights encourage root formation and plant rest.";
          } else {
            illumExplanation = "Balanced lunar light influence.";
          }

          return ValueListenableBuilder<List<WeatherDataPoint>?>(
            valueListenable: _weatherNotifier,
            builder: (context, weatherList, _) {
              WeatherDataPoint? selectedWeather;
              if (weatherList != null && weatherList.isNotEmpty) {
                selectedWeather = weatherList.reduce(
                  (a, b) =>
                      a.time.difference(date).inSeconds.abs() <
                          b.time.difference(date).inSeconds.abs()
                      ? a
                      : b,
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Celestial Rhythms',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildDetailRow(
                          'Sap Flow',
                          realTimeSapFlow,
                          explanation: sapExplanation,
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          'Vitality',
                          moonPhase.name,
                          explanation: vitalityExplanation,
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          'Illumination',
                          '${(moonPhase.illuminatedFraction * 100).toStringAsFixed(1)}%',
                          explanation: illumExplanation,
                        ),
                        if (selectedWeather != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Weather Predicted',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildDetailRow(
                            'Temperature',
                            '${selectedWeather.temperature.round()}°C',
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            'Wind',
                            '${selectedWeather.windSpeed.round()} m/s',
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            'Clouds',
                            '${selectedWeather.cloudCover.round()}%',
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            'Precipitation',
                            '${selectedWeather.precipitation.toStringAsFixed(1)} mm',
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Column(
                    children: [
                      MoonPhaseWidget(info: moonPhase),
                      const SizedBox(height: 8),
                      Text(
                        moonPhase.isWaxing ? 'Waxing' : 'Waning',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {String? explanation}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(fontSize: 16, color: Colors.white70),
            ),
            Expanded(
              child: Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (explanation != null)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              explanation,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: Colors.white54,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }
}

final class MoonPhaseWidget extends StatelessWidget {
  final MoonPhaseInfo info;
  final double size;

  const MoonPhaseWidget({super.key, required this.info, this.size = 60});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: MoonPainter(info: info),
    );
  }
}
