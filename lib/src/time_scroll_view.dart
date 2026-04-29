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
    this.latitude = 54.9037,
    this.longitude = 10.6074,
  });

  @override
  State<TimeScrollView> createState() => _TimeScrollViewState();
}

class _TimeScrollViewState extends State<TimeScrollView>
    with SingleTickerProviderStateMixin {
  late DateTime _centerTime;
  late DateTime _baseTime;
  double _panOffset = 0.0;
  double _viewportWidth = 400.0;
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
    _baseTime = _centerTime;

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
      _panOffset += dx;
      final secondsOffset = -_panOffset / _hourWidth * 3600.0;
      _centerTime = _baseTime.add(Duration(seconds: secondsOffset.toInt()));

      // Re-center the buffer if we scroll beyond half the screen width
      if (_panOffset.abs() > _viewportWidth / 2) {
        _baseTime = _centerTime;
        _panOffset = 0.0;
      }
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

    final range = const Duration(days: 60);
    final start = _centerTime.subtract(range);
    final end = _centerTime.add(range);

    if (_cachedStart == null ||
        _centerTime.difference(_cachedStart!).inDays.abs() < 15 ||
        _cachedEnd!.difference(_centerTime).inDays.abs() < 15) {
      setState(() => _isLoading = true);

      // 1. Fetch astronomical intervals (Instant from FFI worker)
      final intervals = await EphemerisWorker.getIntervals(start, end);
      if (!mounted) return;
      
      // Update UI immediately with celestial data
      setState(() {
        _visibleIntervals = intervals;
        _cachedStart = start;
        _cachedEnd = end;
        _isLoading = false; // Stop loading spinner since main data is here
      });

      // 2. Fetch weather data (Slow network calls) in the background
      final now = DateTime.now();
      List<WeatherDataPoint> combinedWeather = [];

      // Fetch historical data if range starts before now
      if (start.isBefore(now)) {
        final histEnd = end.isBefore(now) ? end : now;
        try {
          final histWeather = await widget.weatherService.getHistoricalData(
            widget.latitude,
            widget.longitude,
            start,
            histEnd,
          );
          combinedWeather.addAll(histWeather);
        } catch (e) {
          debugPrint('Error fetching historical weather: $e');
        }
      }

      // Fetch forecast if range ends after now
      if (end.isAfter(now)) {
        try {
          final forecast = await widget.weatherService.getForecast(
            widget.latitude,
            widget.longitude,
          );
          combinedWeather.addAll(
            forecast.where((p) => p.time.isAfter(now) && p.time.isBefore(end)),
          );
        } catch (e) {
          debugPrint('Error fetching forecast: $e');
        }
      }

      combinedWeather.sort((a, b) => a.time.compareTo(b.time));

      // Update UI with weather data once it arrives
      if (mounted) {
        setState(() {
          _weatherData = combinedWeather;
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
      _baseTime = _centerTime;
      _panOffset = 0.0;
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
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportWidth = constraints.maxWidth;
        final canvasWidth = _viewportWidth * 3;

        return SizedBox(
          height: 200,
          child: Listener(
            onPointerSignal: (pointerSignal) {
              if (pointerSignal is PointerScrollEvent) {
                GestureBinding.instance.pointerSignalResolver.register(
                  pointerSignal,
                  (PointerSignalEvent event) {
                    if (event is PointerScrollEvent) {
                      setState(() {
                        final zoomFactor = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
                        _hourWidth = (_hourWidth * zoomFactor).clamp(
                          _minHourWidth,
                          _maxHourWidth,
                        );
                        // Reset buffer on zoom
                        _baseTime = _centerTime;
                        _panOffset = 0.0;
                      });
                    }
                  },
                );
              }
            },
            child: GestureDetector(
              onScaleStart: (details) {
                _baseScaleHourWidth = _hourWidth;
                _momentumController.stop();
              },
              onScaleUpdate: (details) {
                if (details.scale != 1.0) {
                  setState(() {
                    _hourWidth = (_baseScaleHourWidth * details.scale).clamp(
                      _minHourWidth,
                      _maxHourWidth,
                    );
                    _baseTime = _centerTime;
                    _panOffset = 0.0;
                  });
                } else {
                  _applyPanDelta(details.focalPointDelta.dx);
                }
              },
              onScaleEnd: (details) {
                final velocity = details.velocity.pixelsPerSecond.dx;
                if (velocity.abs() > 100) {
                  final simulation = FrictionSimulation(0.1, 0.0, -velocity);
                  _lastMomentumValue = 0.0;
                  _momentumController.animateWith(simulation);
                }
              },
              child: Container(
                color: Colors.transparent,
                child: Stack(
                  children: [
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator()),
                    IgnorePointer(
                      child: ClipRect(
                        child: Transform.translate(
                          offset: Offset(_panOffset, 0),
                          child: OverflowBox(
                            maxWidth: canvasWidth,
                            minWidth: canvasWidth,
                            child: RepaintBoundary(
                              child: CustomPaint(
                                size: Size(canvasWidth, 200),
                                painter: InfiniteTimelinePainter(
                                  centerTime: _baseTime,
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
                          ),
                        ),
                      ),
                    ),
                    IgnorePointer(
                      child: Align(
                        alignment: Alignment.center,
                        child: Container(
                          width: 2,
                          height: double.infinity,
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
          ),
        );
      },
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

    // Sample every 30 minutes to prevent aliasing when zoomed out (min 100 samples)
    final int sampleCount = math.max(100, (totalDuration / 1800).toInt());
    final List<Color> finalColors = [];
    final List<double> finalStops = [];

    for (int i = 0; i <= sampleCount; i++) {
      final t = i / sampleCount;
      final time = canvasStartTime.add(
        Duration(seconds: (totalDuration * t).toInt()),
      );

      final utc = time.toUtc();
      final dayOfYear = utc.difference(DateTime.utc(utc.year, 1, 1)).inDays + 1;
      // Solar declination
      final decRad = -23.44 * math.cos((360.0 / 365.0) * (dayOfYear + 10) * math.pi / 180.0) * math.pi / 180.0;
      final latRad = latitude * math.pi / 180.0;

      // Solar hour angle
      final h = (utc.hour + utc.minute / 60.0 + utc.second / 3600.0 - 12.0 + longitude / 15.0) * 15.0;
      final hRad = h * math.pi / 180.0;

      // Solar altitude
      final altRad = math.asin(
        math.sin(latRad) * math.sin(decRad) +
        math.cos(latRad) * math.cos(decRad) * math.cos(hRad)
      );
      final alt = altRad * 180.0 / math.pi;

      Color c;
      if (alt > 0) {
        // Daylight: Orange -> White/Yellow
        final factor = (alt / 40.0).clamp(0.0, 1.0);
        c = Color.lerp(const Color(0xFFFFB74D), const Color(0xFFFFFDE7), factor)!;
      } else if (alt > -6) {
        // Civil twilight: Night -> Dawn/Dusk
        final factor = ((alt + 6) / 6.0).clamp(0.0, 1.0);
        c = Color.lerp(const Color(0xFF121212), const Color(0xFFFFB74D), factor)!;
      } else {
        // Nautical/Astronomical twilight and Night are visually pitch black
        c = const Color(0xFF121212);
      }

      finalColors.add(c);
      finalStops.add(t);
    }

    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(size.width, 0),
        finalColors,
        finalStops,
      );
    // Sunlight gradient: narrower ribbon (27 to 47)
    canvas.drawRect(Rect.fromLTWH(0, 27, size.width, 20), paint);

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
        if (x >= 0 && x <= size.width) _drawIcon(canvas, x, '☀️', 10, 37);
      }
      if (ss.sunset != null) {
        final x =
            centerX +
            (ss.sunset!.difference(centerTime).inSeconds / 3600.0 * hourWidth);
        if (x >= 0 && x <= size.width) _drawIcon(canvas, x, '🌙', 10, 37);
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
        if (isMidnight) {
          // Midnight lines span the entire height as a faint day grid
          canvas.drawLine(
            Offset(x, 0),
            Offset(x, size.height),
            tickPaint..color = Colors.white24,
          );
        } else {
          // Standard hour ticks
          canvas.drawLine(
            Offset(x, 25),
            Offset(x, 49),
            tickPaint..color = Colors.white54,
          );
        }

        if (showHourLabels && !isMidnight) {
          final hourPainter = TextPainter(
            text: TextSpan(
              text: '${t.hour.toString().padLeft(2, '0')}:00',
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
            textDirection: ui.TextDirection.ltr,
          );
          hourPainter.layout();
          hourPainter.paint(canvas, Offset(x - hourPainter.width / 2, 50));
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
          Offset(x, 32),
          Offset(x, 42),
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
    final tempRowY = 65.0;
    final tempRowHeight = 50.0;
    final windRowY = 115.0;
    final windRowHeight = 50.0;

    // Draw backgrounds
    final tempBgPaint = Paint()
      ..color = const Color(0xFFD0E2FF).withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(0, tempRowY, size.width, tempRowHeight),
      tempBgPaint,
    );

    final windBgPaint = Paint()
      ..color = const Color(0xFFE0E0E0).withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(0, windRowY, size.width, windRowHeight),
      windBgPaint,
    );

    final tempLinePaint = Paint()
      ..color = Colors.orangeAccent.withValues(alpha: 0.3)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final windLinePaint = Paint()
      ..color = Colors.lightBlueAccent.withValues(alpha: 0.3)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final tempPath = Path();
    final windPath = Path();
    bool first = true;

    // Mapping functions
    double mapTempToY(double temp) {
      final clamped = temp.clamp(0.0, 30.0);
      return tempRowY + tempRowHeight - (clamped / 30.0 * tempRowHeight);
    }

    double mapWindToY(double speed) {
      final clamped = speed.clamp(0.0, 15.0);
      return windRowY + windRowHeight - (clamped / 15.0 * windRowHeight);
    }

    for (final wd in weatherData) {
      final offsetInHours = wd.time.difference(centerTime).inSeconds / 3600.0;
      final x = centerX + (offsetInHours * hourWidth);
      final yTemp = mapTempToY(wd.temperature);
      final yWind = mapWindToY(wd.windSpeed);

      if (wd.precipitation > 0) {
        // 1mm of rain = 8px height, min 3px, max 40px
        final barHeight = (wd.precipitation * 8.0).clamp(3.0, 40.0);
        final barPaint = Paint()
          ..color = const Color(0xFF42A5F5) // Opaque, vibrant blue
          ..style = PaintingStyle.fill;
          
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              x - 3, // Slightly wider (6px total)
              tempRowY + tempRowHeight - barHeight,
              6,
              barHeight,
            ),
            const Radius.circular(2), // Rounded corners
          ),
          barPaint,
        );
      }

      if (first) {
        tempPath.moveTo(x, yTemp);
        windPath.moveTo(x, yWind);
        first = false;
      } else {
        tempPath.lineTo(x, yTemp);
        windPath.lineTo(x, yWind);
      }
    }

    canvas.drawPath(tempPath, tempLinePaint);
    canvas.drawPath(windPath, windLinePaint);

    // Draw labels and arrows
    for (int i = 0; i < weatherData.length; i += 12) {
      final wd = weatherData[i];
      final offsetInHours = wd.time.difference(centerTime).inSeconds / 3600.0;
      final x = centerX + (offsetInHours * hourWidth);

      if (x >= 0 && x <= size.width) {
        // Temp label
        final yTemp = mapTempToY(wd.temperature);
        _drawText(canvas, x, '${wd.temperature.round()}°', 10, yTemp - 12);

        // Cloud cover on temp chart
        if (wd.cloudCover > 30) {
          _drawIcon(canvas, x, '☁️', 12, yTemp + 5);
        }

        if (wd.precipitation > 0) {
          _drawText(
            canvas,
            x,
            '${wd.precipitation.toStringAsFixed(1)}mm',
            8,
            yTemp + 15,
          );
        }

        // Wind speed label and arrow on wind chart
        final yWind = mapWindToY(wd.windSpeed);
        _drawText(canvas, x, '${wd.windSpeed.round()}m/s', 10, yWind - 12);

        // Draw the precise wind arrow
        _drawWindArrow(canvas, x, yWind + 10, wd.windDirection);
      }
    }

    // Draw Current Wall Time Indicator (Blue Line)
    final now = DateTime.now();
    final nowOffsetInHours = now.difference(centerTime).inSeconds / 3600.0;
    final nowX = centerX + (nowOffsetInHours * hourWidth);

    if (nowX >= 0 && nowX <= size.width) {
      final nowPaint = Paint()
        ..color = Colors.blueAccent
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
        
      // Draw the line spanning the full height
      canvas.drawLine(Offset(nowX, 0), Offset(nowX, size.height), nowPaint);
      
      // Add a subtle glow effect
      final glowPaint = Paint()
        ..color = Colors.blueAccent.withValues(alpha: 0.3)
        ..strokeWidth = 6.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0)
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(nowX, 0), Offset(nowX, size.height), glowPaint);
    }
  }

  void _drawText(
    Canvas canvas,
    double x,
    String text,
    double fontSize,
    double y,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: Colors.white70, fontSize: fontSize),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(x - tp.width / 2, y));
  }

  void _drawIcon(
    Canvas canvas,
    double x,
    String icon,
    double fontSize, [
    double? y,
  ]) {
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

  void _drawWindArrow(Canvas canvas, double x, double y, double windDirDegrees) {
    canvas.save();
    canvas.translate(x, y);
    // Meteorological wind direction is where the wind comes FROM.
    // 0° = North (blowing South).
    // We rotate the canvas so the arrow points to where the wind is GOING.
    // Default arrow points UP (0°), so we add 180°.
    canvas.rotate((windDirDegrees + 180) * math.pi / 180.0);

    final paint = Paint()
      ..color = Colors.lightBlueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, 6)
      ..lineTo(0, -6)
      ..moveTo(-3, -3)
      ..lineTo(0, -6)
      ..lineTo(3, -3);

    canvas.drawPath(path, paint);
    canvas.restore();
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
    // Ribbon at the very top (5 to 25)
    final rect = Rect.fromLTWH(x, 5, width, 20);
    final paint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      paint,
    );

    if (width > 15) {
      final iconSize = math.min(width * 0.6, 14.0);
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
        // Center icon inside the 20px tall ribbon
        canvas.translate(x + (width - iconSize) / 2, 5 + (20 - iconSize) / 2);
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
