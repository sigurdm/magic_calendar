import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart'; // Added for rootBundle
import 'ephemeris_service.dart';
import 'weather_service.dart';

class TimeScrollController {
  _TimeScrollViewState? _state;
  void scrollToNow() => _state?._scrollToNow();
}

class TimeScrollView extends StatefulWidget {
  final EphemerisService ephemeris;
  final WeatherService weatherService;
  final ValueChanged<DateTime> onTimeSelected;
  final TimeScrollController? controller;
  final double latitude;
  final double longitude;

  const TimeScrollView({
    super.key,
    required this.ephemeris,
    required this.weatherService,
    required this.onTimeSelected,
    this.controller,
    this.latitude = 56.0,
    this.longitude = 10.0,
  });

  @override
  State<TimeScrollView> createState() => _TimeScrollViewState();
}

class _TimeScrollViewState extends State<TimeScrollView>
    with SingleTickerProviderStateMixin {
  late DateTime _centerTime;
  double _hourWidth = 40.0;
  final double _minHourWidth = 2.5;
  final double _maxHourWidth = 500.0;

  double _baseScaleHourWidth = 40.0;

  List<CalendarInterval> _visibleIntervals = [];
  List<WeatherDataPoint> _weatherData = [];
  DateTime? _cachedStart;
  DateTime? _cachedEnd;

  bool _isLoading = false;
  Timer? _updateTimer;

  late AnimationController _momentumController;
  double _lastMomentumValue = 0.0;

  ui.Image? _rootImage;
  ui.Image? _leafImage;
  ui.Image? _flowerImage;
  ui.Image? _fruitImage;
  ui.Image? _noneImage;
  ui.Image? _grayDayImage;

  Future<void> _loadIcons() async {
    _rootImage = await _loadAssetImage('assets/icons/root.png');
    _leafImage = await _loadAssetImage('assets/icons/leaf.png');
    _flowerImage = await _loadAssetImage('assets/icons/flower.png');
    _fruitImage = await _loadAssetImage('assets/icons/fruit.png');
    _noneImage = await _loadAssetImage('assets/icons/none.png');
    _grayDayImage = await _loadAssetImage('assets/icons/gray_day.png');
    if (mounted) {
      setState(() {});
    }
  }

  Future<ui.Image> _loadAssetImage(String path) async {
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frameInfo = await codec.getNextFrame();
    return frameInfo.image;
  }

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    _centerTime = DateTime.now();

    _momentumController = AnimationController.unbounded(vsync: this);
    _momentumController.addListener(_handleMomentumTick);

    _scheduleUpdate(immediate: true);
    _loadIcons(); // Load icons on init
  }

  void _handleMomentumTick() {
    if (!_momentumController.isAnimating) return;
    final delta = _momentumController.value - _lastMomentumValue;
    _lastMomentumValue = _momentumController.value;
    _applyPanDelta(delta);
  }

  void _applyPanDelta(double dx) {
    if (dx == 0) return;
    setState(() {
      final hoursDelta = dx / _hourWidth;
      _centerTime = _centerTime.subtract(
        Duration(seconds: (hoursDelta * 3600).toInt()),
      );
    });
    widget.onTimeSelected(_centerTime);
    _scheduleUpdate();
  }

  void _scheduleUpdate({bool immediate = false}) {
    _updateTimer?.cancel();
    if (immediate) {
      _performUpdate();
    } else {
      _updateTimer = Timer(const Duration(milliseconds: 100), _performUpdate);
    }
  }

  Future<void> _performUpdate() async {
    if (!mounted) return;

    final range = const Duration(days: 30);
    final start = _centerTime.subtract(range);
    final end = _centerTime.add(range);

    if (_cachedStart == null ||
        _centerTime.difference(_cachedStart!).inDays.abs() < 5 ||
        _cachedEnd!.difference(_centerTime).inDays.abs() < 5) {
      setState(() => _isLoading = true);

      final intervals = await compute(
        computeIntervalsInIsolate,
        IntervalRequest(start, end),
      );

      List<WeatherDataPoint> weather = [];
      try {
        weather = await widget.weatherService.getForecast(
          widget.latitude,
          widget.longitude,
        );
      } catch (e) {
        debugPrint('Error fetching weather: $e');
      }

      if (mounted) {
        setState(() {
          _visibleIntervals = intervals;
          _weatherData = weather;
          _cachedStart = start;
          _cachedEnd = end;
          _isLoading = false;
        });
      }
    }
  }

  @override
  void didUpdateWidget(TimeScrollView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?._state = null;
      widget.controller?._state = this;
    }
  }

  void _scrollToNow() {
    _momentumController.stop();
    setState(() {
      _centerTime = DateTime.now();
    });
    widget.onTimeSelected(_centerTime);
    _scheduleUpdate(immediate: true);
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _momentumController.dispose();
    widget.controller?._state = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: GestureDetector(
        onHorizontalDragUpdate: (details) {
          _momentumController.stop();
          _applyPanDelta(details.delta.dx);
        },
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity.abs() > 100) {
            final simulation = FrictionSimulation(0.1, 0.0, -velocity);
            _lastMomentumValue = 0.0;
            _momentumController.animateWith(simulation);
          }
        },
        onScaleStart: (details) {
          _baseScaleHourWidth = _hourWidth;
        },
        onScaleUpdate: (details) {
          if (details.scale != 1.0) {
            setState(() {
              _hourWidth = (_baseScaleHourWidth * details.scale).clamp(
                _minHourWidth,
                _maxHourWidth,
              );
            });
          } else {
            _applyPanDelta(details.focalPointDelta.dx);
          }
        },
        child: Container(
          color: Colors.transparent,
          child: Stack(
            children: [
              if (_isLoading) const Center(child: CircularProgressIndicator()),
              IgnorePointer(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: InfiniteTimelinePainter(
                    centerTime: _centerTime,
                    hourWidth: _hourWidth,
                    intervals: _visibleIntervals,
                    weatherData: _weatherData,
                    ephemeris: widget.ephemeris,
                    latitude: widget.latitude,
                    longitude: widget.longitude,
                    rootImage: _rootImage,
                    leafImage: _leafImage,
                    flowerImage: _flowerImage,
                    fruitImage: _fruitImage,
                    noneImage: _noneImage,
                    grayDayImage: _grayDayImage,
                  ),
                ),
              ),
              IgnorePointer(
                child: Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 2,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 4),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InfiniteTimelinePainter extends CustomPainter {
  final DateTime centerTime;
  final double hourWidth;
  final List<CalendarInterval> intervals;
  final List<WeatherDataPoint> weatherData;
  final EphemerisService ephemeris;
  final double latitude;
  final double longitude;
  final ui.Image? rootImage;
  final ui.Image? leafImage;
  final ui.Image? flowerImage;
  final ui.Image? fruitImage;
  final ui.Image? noneImage;
  final ui.Image? grayDayImage;

  InfiniteTimelinePainter({
    required this.centerTime,
    required this.hourWidth,
    required this.intervals,
    required this.weatherData,
    required this.ephemeris,
    required this.latitude,
    required this.longitude,
    this.rootImage,
    this.leafImage,
    this.flowerImage,
    this.fruitImage,
    this.noneImage,
    this.grayDayImage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) return;
    final centerX = size.width / 2;

    final visibleHours = size.width / hourWidth;
    final startTime = centerTime.subtract(
      Duration(hours: (visibleHours / 2).ceil() + 24),
    );
    final endTime = centerTime.add(
      Duration(hours: (visibleHours / 2).ceil() + 24),
    );

    // Calculate Gradient Background with robust interpolation
    final canvasStartTime = centerTime.subtract(
      Duration(hours: (visibleHours / 2).ceil()),
    );
    final canvasEndTime = centerTime.add(
      Duration(hours: (visibleHours / 2).ceil()),
    );
    final totalDuration = canvasEndTime
        .difference(canvasStartTime)
        .inSeconds
        .toDouble();

    final List<({DateTime time, Color color})> markers = [];

    // Collect markers for a 3-day window to ensure we always have points before/after the canvas
    for (int dayOffset = -2; dayOffset <= 2; dayOffset++) {
      final d = DateTime(
        centerTime.year,
        centerTime.month,
        centerTime.day + dayOffset,
      );
      final ss = ephemeris.getSunriseSunset(d, latitude, longitude);

      if (ss.sunrise != null && ss.sunset != null) {
        final midday = ss.sunrise!.add(ss.sunset!.difference(ss.sunrise!) ~/ 2);
        final morningStart = ss.sunrise!.subtract(const Duration(minutes: 90));
        final eveningEnd = ss.sunset!.add(const Duration(minutes: 90));

        markers.add((time: morningStart, color: Colors.black));
        markers.add((time: ss.sunrise!, color: const Color(0xFFD32F2F)));
        markers.add((
          time: ss.sunrise!.add(const Duration(minutes: 60)),
          color: const Color(0xFFFFF9C4),
        ));
        markers.add((
          time: midday,
          color: const Color(0xFFFFFDE7),
        )); // Brightest noon
        markers.add((
          time: ss.sunset!.subtract(const Duration(minutes: 60)),
          color: const Color(0xFFFFF9C4),
        ));
        markers.add((time: ss.sunset!, color: const Color(0xFFD32F2F)));
        markers.add((time: eveningEnd, color: Colors.black));
      } else {
        // Simple fallback
        markers.add((time: d, color: const Color(0xFFFFF9C4)));
      }
    }
    markers.sort((a, b) => a.time.compareTo(b.time));

    Color interpolate(DateTime target) {
      if (markers.isEmpty) return Colors.black;
      if (target.isBefore(markers.first.time)) return markers.first.color;
      if (target.isAfter(markers.last.time)) return markers.last.color;

      for (int i = 0; i < markers.length - 1; i++) {
        final m1 = markers[i];
        final m2 = markers[i + 1];
        if (target.isAtSameMomentAs(m1.time)) return m1.color;
        if (target.isAfter(m1.time) && target.isBefore(m2.time)) {
          final t =
              target.difference(m1.time).inSeconds /
              m2.time.difference(m1.time).inSeconds;
          return Color.lerp(m1.color, m2.color, t)!;
        }
      }
      return markers.last.color;
    }

    final List<Color> finalColors = [];
    final List<double> finalStops = [];

    // Add exact start color at stop 0.0
    finalColors.add(interpolate(canvasStartTime));
    finalStops.add(0.0);

    // Add all markers that fall within the canvas
    for (var m in markers) {
      if (m.time.isAfter(canvasStartTime) && m.time.isBefore(canvasEndTime)) {
        finalColors.add(m.color);
        finalStops.add(
          m.time.difference(canvasStartTime).inSeconds / totalDuration,
        );
      }
    }

    // Add exact end color at stop 1.0
    finalColors.add(interpolate(canvasEndTime));
    finalStops.add(1.0);

    if (finalColors.length >= 2) {
      final paint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, 0),
          Offset(size.width, 0),
          finalColors,
          finalStops,
        );
      canvas.drawRect(Rect.fromLTWH(0, 20, size.width, 80), paint);
    }

    // Draw Solar Icons
    for (
      var d = DateTime(
        canvasStartTime.year,
        canvasStartTime.month,
        canvasStartTime.day,
      );
      d.isBefore(canvasEndTime.add(const Duration(days: 1)));
      d = d.add(const Duration(days: 1))
    ) {
      final ss = ephemeris.getSunriseSunset(d, latitude, longitude);

      if (ss.sunrise != null) {
        final x =
            centerX +
            (ss.sunrise!.difference(centerTime).inSeconds / 3600.0 * hourWidth);
        if (x >= 0 && x <= size.width) _drawIcon(canvas, x, '☀️', 12);
      }
      if (ss.sunset != null) {
        final x =
            centerX +
            (ss.sunset!.difference(centerTime).inSeconds / 3600.0 * hourWidth);
        if (x >= 0 && x <= size.width) _drawIcon(canvas, x, '🌙', 12);
      }
    }

    final tickPaint = Paint()
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Determine frequencies based on zoom level
    int hourLabelFrequency = 6;
    int tickFrequency = 1;
    int dateLabelFrequencyInDays = 1;
    bool showHourLabels = true;

    if (hourWidth < 5) {
      hourLabelFrequency = 24;
      tickFrequency = 24;
      dateLabelFrequencyInDays = 3;
      showHourLabels = false;
    } else if (hourWidth < 10) {
      hourLabelFrequency = 24;
      tickFrequency = 12;
      dateLabelFrequencyInDays = 2;
      showHourLabels = false;
    } else if (hourWidth < 20) {
      hourLabelFrequency = 12;
      tickFrequency = 3;
      dateLabelFrequencyInDays = 1;
    } else if (hourWidth < 40) {
      hourLabelFrequency = 6;
      tickFrequency = 1;
      dateLabelFrequencyInDays = 1;
    }

    final firstTickTime = DateTime(
      startTime.year,
      startTime.month,
      startTime.day,
      (startTime.hour ~/ tickFrequency) * tickFrequency,
    );

    final epoch = DateTime(2000, 1, 1);

    for (
      var t = firstTickTime;
      t.isBefore(endTime);
      t = t.add(Duration(hours: tickFrequency))
    ) {
      final offsetInHours = t.difference(centerTime).inSeconds / 3600.0;
      final x = centerX + (offsetInHours * hourWidth);

      final isHourLabelTime = t.hour % hourLabelFrequency == 0;
      final isMidnight = t.hour == 0;

      if (isHourLabelTime || isMidnight) {
        canvas.drawLine(
          Offset(x, 15),
          Offset(x, 25),
          tickPaint..color = Colors.white54,
        );

        if (showHourLabels && !isMidnight) {
          final hourPainter = TextPainter(
            text: TextSpan(
              text: '${t.hour.toString().padLeft(2, '0')}:00',
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
            textDirection: ui.TextDirection.ltr,
          );
          hourPainter.layout();
          hourPainter.paint(canvas, Offset(x - hourPainter.width / 2, 2));
        }

        if (isMidnight) {
          final totalDaysFromEpoch = t.difference(epoch).inDays;
          if (totalDaysFromEpoch % dateLabelFrequencyInDays == 0) {
            final datePainter = TextPainter(
              text: TextSpan(
                text: DateFormat('EEE, MMM d').format(t),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              textDirection: ui.TextDirection.ltr,
            );
            datePainter.layout();
            datePainter.paint(canvas, Offset(x + 5, size.height - 18));
          }
        }
      } else {
        canvas.drawLine(
          Offset(x, 18),
          Offset(x, 22),
          tickPaint..color = Colors.white24,
        );
      }
    }

    for (final interval in intervals) {
      final startOffsetInHours =
          interval.start.difference(centerTime).inSeconds / 3600.0;
      final endOffsetInHours =
          interval.end.difference(centerTime).inSeconds / 3600.0;
      final xStart = centerX + (startOffsetInHours * hourWidth);
      final xEnd = centerX + (endOffsetInHours * hourWidth);
      final width = xEnd - xStart;
      if (xEnd < 0 || xStart > size.width) continue;
      if (interval.isGrayDay) {
        _drawBlock(
          canvas,
          xStart,
          width,
          'gray',
          Colors.grey[400]!,
          interval.quality,
          true,
        );
      } else if (interval.quality != PlantQuality.none) {
        final color = _getColorForQuality(interval.quality);
        final label = _getLabelForQuality(interval.quality);
        _drawBlock(
          canvas,
          xStart,
          width,
          label,
          color,
          interval.quality,
          false,
        );
      }
    }
    // Draw Weather Row
    final weatherRowY = 85.0;

    for (final wd in weatherData) {
      final offsetInHours = wd.time.difference(centerTime).inSeconds / 3600.0;
      final x = centerX + (offsetInHours * hourWidth);

      if (x >= 0 && x <= size.width) {
        // Draw temperature
        final tp = TextPainter(
          text: TextSpan(
            text: '${wd.temperature.round()}°',
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
          textDirection: ui.TextDirection.ltr,
        );
        tp.layout();
        tp.paint(canvas, Offset(x - tp.width / 2, weatherRowY));
      }
    }
  }

  void _drawIcon(Canvas canvas, double x, String icon, double fontSize) {
    final tp = TextPainter(
      text: TextSpan(
        text: icon,
        style: TextStyle(fontSize: fontSize),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(x - tp.width / 2, 85));
  }

  void _drawBlock(
    Canvas canvas,
    double x,
    double width,
    String label,
    Color color,
    PlantQuality quality,
    bool isGrayDay,
  ) {
    final rect = Rect.fromLTWH(x, 30, width, 50);
    final paint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      paint,
    );

    if (width > 30) {
      final iconSize = math.min(width * 0.6, 30.0);
      ui.Image? image;
      if (isGrayDay) {
        image = grayDayImage;
      } else {
        switch (quality) {
          case PlantQuality.root:
            image = rootImage;
            break;
          case PlantQuality.leaf:
            image = leafImage;
            break;
          case PlantQuality.flower:
            image = flowerImage;
            break;
          case PlantQuality.fruit:
            image = fruitImage;
            break;
          case PlantQuality.none:
            image = noneImage;
            break;
        }
      }

      if (image != null) {
        canvas.save();
        canvas.translate(x + (width - iconSize) / 2, 30 + (50 - iconSize) / 2);
        final src = Rect.fromLTWH(
          0,
          0,
          image.width.toDouble(),
          image.height.toDouble(),
        );
        final dst = Rect.fromLTWH(0, 0, iconSize, iconSize);
        canvas.drawImageRect(image, src, dst, Paint());

        // Draw a nice frame around the image
        final framePaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawRRect(
          RRect.fromRectAndRadius(dst, const Radius.circular(2)),
          framePaint,
        );

        canvas.restore();
      }
    }
  }

  Color _getColorForQuality(PlantQuality quality) {
    switch (quality) {
      case PlantQuality.root:
        return const Color(0xFF8D6E63);
      case PlantQuality.leaf:
        return const Color(0xFF66BB6A);
      case PlantQuality.flower:
        return const Color(0xFFAB47BC);
      case PlantQuality.fruit:
        return const Color(0xFFFFA726);
      case PlantQuality.none:
        return Colors.transparent;
    }
  }

  String _getLabelForQuality(PlantQuality quality) {
    switch (quality) {
      case PlantQuality.root:
        return 'root';
      case PlantQuality.leaf:
        return 'leaf';
      case PlantQuality.flower:
        return 'flower';
      case PlantQuality.fruit:
        return 'fruit';
      case PlantQuality.none:
        return '';
    }
  }

  @override
  bool shouldRepaint(covariant InfiniteTimelinePainter oldDelegate) {
    return oldDelegate.centerTime != centerTime ||
        oldDelegate.hourWidth != hourWidth ||
        oldDelegate.intervals != intervals ||
        oldDelegate.latitude != latitude ||
        oldDelegate.longitude != longitude;
  }
}
