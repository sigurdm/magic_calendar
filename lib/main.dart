import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'src/algorithm.dart';
import 'src/ephemeris_service.dart';
import 'src/time_scroll_view.dart';
import 'src/planetary_ribbon.dart';
import 'src/planting_icons.dart';

void main() {
  runApp(MyApp(ephemeris: AstronomiaEphemerisService()));
}

class MyApp extends StatelessWidget {
  final EphemerisService ephemeris;
  const MyApp({super.key, required this.ephemeris});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Magic Calendar',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
      ),
      home: CalendarHomePage(ephemeris: ephemeris),
    );
  }
}

class CalendarHomePage extends StatefulWidget {
  final EphemerisService ephemeris;
  const CalendarHomePage({super.key, required this.ephemeris});

  @override
  State<CalendarHomePage> createState() => _CalendarHomePageState();
}

class _CalendarHomePageState extends State<CalendarHomePage> {
  final ValueNotifier<DateTime> _selectedDateNotifier =
      ValueNotifier(DateTime.now());
  final ValueNotifier<CalendarInfo?> _infoNotifier = ValueNotifier(null);
  final _timeScrollController = TimeScrollController();

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    // Initial fetch
    _updateInfo(_selectedDateNotifier.value, immediate: true);
  }

  void _updateInfo(DateTime time, {bool immediate = false}) {
    if (immediate) {
      _infoNotifier.value =
          getCalendarInfo(time, widget.ephemeris, includePlanets: true);
      return;
    }

    // Debounced heavy update
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () async {
      final updatedInfo = await compute(
        computeCalendarInfoInIsolate,
        InfoRequest(time, true),
      );
      if (mounted) {
        _infoNotifier.value = updatedInfo;
      }
    });
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
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 40),
                  ValueListenableBuilder<DateTime>(
                    valueListenable: _selectedDateNotifier,
                    builder: (context, date, _) {
                      return Text(
                        DateFormat('EEEE, MMM d, y - HH:00').format(date),
                        style: GoogleFonts.outfit(
                          fontSize: 20,
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
                      if (info == null) return const SizedBox(height: 140);
                      return _buildQualityCard(info);
                    },
                  ),
                  const SizedBox(height: 20),
                  TimeScrollView(
                    ephemeris: widget.ephemeris,
                    controller: _timeScrollController,
                    onTimeSelected: _onTimeSelected,
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
                      if (info == null) return const SizedBox();
                      return _buildDetailsCard(info);
                    },
                  ),
                ],
              ),
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Magic Calendar',
              style: GoogleFonts.outfit(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'Biodynamic Planting Guide',
              style: GoogleFonts.outfit(
                fontSize: 16,
                color: Colors.white70,
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
              icon: const Icon(
                Icons.history,
                color: Colors.white,
              ),
              label: const Text(
                'NOW',
                style: TextStyle(color: Colors.white),
              ),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withValues(
                  alpha: 0.1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(
                Icons.calendar_month,
                color: Colors.white,
              ),
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

  Widget _buildQualityCard(CalendarInfo info) {
    Color cardColor = Colors.grey[800]!;
    String title = 'Unknown';
    String desc = 'Select a date to see quality.';

    if (info.isGrayDay) {
      cardColor = const Color(0xFFD32F2F);
      title = 'Gray Day';
      desc = info.message;
    } else {
      switch (info.quality) {
        case PlantQuality.root:
          cardColor = const Color(0xFF8D6E63);
          title = 'Root Day';
          desc = 'Good for planting carrots, beets, potatoes, onions.';
          break;
        case PlantQuality.leaf:
          cardColor = const Color(0xFF66BB6A);
          title = 'Leaf Day';
          desc = 'Good for planting lettuce, spinach, herbs, cabbage.';
          break;
        case PlantQuality.flower:
          cardColor = const Color(0xFFAB47BC);
          title = 'Flower Day';
          desc = 'Good for planting broccoli, cauliflower, cut flowers.';
          break;
        case PlantQuality.fruit:
          cardColor = const Color(0xFFFFA726);
          title = 'Fruit Day';
          desc = 'Good for planting tomatoes, beans, grains, fruit trees.';
          break;
        case PlantQuality.none:
          cardColor = const Color(0xFF78909C);
          title = 'No Specific Quality';
          desc = 'Neutral day for planting.';
          break;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: cardColor.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PlantingQualityIcon(
                quality: info.quality,
                isGrayDay: info.isGrayDay,
                size: 40,
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
      child: Row(
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
                _buildDetailRow('Sap Flow', info.sapFlow),
                const SizedBox(height: 12),
                _buildDetailRow('Vitality', info.vitality),
                const SizedBox(height: 12),
                _buildDetailRow(
                  'Illumination',
                  '${(info.moonPhase.illuminatedFraction * 100).toStringAsFixed(1)}%',
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Column(
            children: [
              MoonPhaseWidget(info: info.moonPhase),
              const SizedBox(height: 8),
              Text(
                info.moonPhase.isWaxing ? 'Waxing' : 'Waning',
                style: GoogleFonts.outfit(fontSize: 12, color: Colors.white54),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
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
    );
  }
}

class MoonPhaseWidget extends StatelessWidget {
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

class MoonPainter extends CustomPainter {
  final MoonPhaseInfo info;

  MoonPainter({required this.info});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final bgPaint = Paint()..color = const Color(0xFF1E1E2E); // Match background
    final lightPaint = Paint()..color = const Color(0xFFFFF9C4); // Pale yellow

    // Draw background circle
    canvas.drawCircle(center, radius, bgPaint);

    double k = info.illuminatedFraction;

    if (info.isWaxing) {
      // Right side is light
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
          -math.pi / 2, math.pi, true, lightPaint);
      if (k < 0.5) {
        // Dark ellipse on the right side to create crescent
        double ellipseWidth = (1 - 2 * k) * radius;
        canvas.drawOval(
            Rect.fromLTRB(center.dx - ellipseWidth, center.dy - radius,
                center.dx + ellipseWidth, center.dy + radius),
            bgPaint);
      } else {
        // Light ellipse on the left side to create gibbous
        double ellipseWidth = (2 * k - 1) * radius;
        canvas.drawOval(
            Rect.fromLTRB(center.dx - ellipseWidth, center.dy - radius,
                center.dx + ellipseWidth, center.dy + radius),
            lightPaint);
      }
    } else {
      // Left side is light
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
          math.pi / 2, math.pi, true, lightPaint);
      if (k < 0.5) {
        // Dark ellipse on the left side to create crescent
        double ellipseWidth = (1 - 2 * k) * radius;
        canvas.drawOval(
            Rect.fromLTRB(center.dx - ellipseWidth, center.dy - radius,
                center.dx + ellipseWidth, center.dy + radius),
            bgPaint);
      } else {
        // Light ellipse on the right side to create gibbous
        double ellipseWidth = (2 * k - 1) * radius;
        canvas.drawOval(
            Rect.fromLTRB(center.dx - ellipseWidth, center.dy - radius,
                center.dx + ellipseWidth, center.dy + radius),
            lightPaint);
      }
    }

    // Optional: add a subtle glow or border
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius, borderPaint);
  }

  @override
  bool shouldRepaint(covariant MoonPainter oldDelegate) =>
      oldDelegate.info.phaseAngle != info.phaseAngle;
}
