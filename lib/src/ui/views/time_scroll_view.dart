import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/services.dart';
import '../../services/ephemeris_service.dart';
import '../../services/weather_service.dart';
import '../painters/infinite_timeline_painter.dart';

/// Controller for programmatic interaction with [TimeScrollView].
final class TimeScrollController {
  _TimeScrollViewState? _state;

  /// Scrolls the timeline to the current date and time.
  void scrollToNow() => _state?._scrollToNow();
}

/// Interactive timeline scroll view showing celestial events, biodynamic qualities, and weather.
final class TimeScrollView extends StatefulWidget {
  /// Ephemeris service dependency.
  final EphemerisService ephemeris;

  /// Weather service dependency.
  final WeatherService weatherService;

  /// Callback fired when user selects a time on the timeline.
  final ValueChanged<DateTime> onTimeSelected;

  /// Optional controller.
  final TimeScrollController? controller;

  /// Latitude coordinate.
  final double latitude;

  /// Longitude coordinate.
  final double longitude;

  /// Creates a [TimeScrollView].
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
    _loadIcons();
  }

  void _handleMomentumTick() {
    if (!_momentumController.isAnimating) {
      return;
    }
    final delta = _momentumController.value - _lastMomentumValue;
    _lastMomentumValue = _momentumController.value;
    _applyPanDelta(delta);
  }

  void _applyPanDelta(double dx) {
    if (dx == 0) {
      return;
    }
    setState(() {
      _panOffset += dx;
      final secondsOffset = -_panOffset / _hourWidth * 3600.0;
      _centerTime = _baseTime.add(Duration(seconds: secondsOffset.toInt()));

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

  List<CalendarInterval> _mergeIntervals(
    List<CalendarInterval> list1,
    List<CalendarInterval> list2,
  ) {
    final combined = [...list1, ...list2];
    if (combined.isEmpty) {
      return [];
    }
    combined.sort((a, b) => a.start.compareTo(b.start));

    final List<CalendarInterval> merged = [];
    for (final interval in combined) {
      if (merged.isEmpty) {
        merged.add(interval);
      } else {
        final last = merged.last;
        if (interval.start.isBefore(last.end) ||
            interval.start.isAtSameMomentAs(last.end)) {
          if (last.quality == interval.quality &&
              last.isGrayDay == interval.isGrayDay &&
              last.isSpecial == interval.isSpecial &&
              last.message == interval.message) {
            final maxEnd =
                interval.end.isAfter(last.end) ? interval.end : last.end;
            merged[merged.length - 1] = CalendarInterval(
              start: last.start,
              end: maxEnd,
              quality: last.quality,
              isGrayDay: last.isGrayDay,
              isSpecial: last.isSpecial,
              message: last.message,
            );
          } else if (interval.end.isAfter(last.end)) {
            if (interval.start.isAfter(last.start)) {
              merged.add(interval);
            }
          }
        } else {
          merged.add(interval);
        }
      }
    }
    return merged;
  }

  Future<void> _performUpdate() async {
    if (!mounted) {
      return;
    }

    final range = const Duration(days: 60);
    final start = _centerTime.subtract(range);
    final end = _centerTime.add(range);

    if (_cachedStart == null ||
        _centerTime.difference(_cachedStart!).inDays.abs() < 30 ||
        _cachedEnd!.difference(_centerTime).inDays.abs() < 30) {
      setState(() => _isLoading = true);

      final intervals = await widget.ephemeris.getIntervals(start, end);
      if (!mounted) {
        return;
      }

      final merged = _mergeIntervals(_visibleIntervals, intervals);

      setState(() {
        _visibleIntervals = merged;
        _cachedStart = merged.isNotEmpty ? merged.first.start : start;
        _cachedEnd = merged.isNotEmpty ? merged.last.end : end;
        _isLoading = false;
      });

      final now = DateTime.now();
      List<WeatherDataPoint> combinedWeather = [];

      if (start.isBefore(now)) {
        final histEnd = end.isBefore(now) ? end : now;
        try {
          final histWeather = await widget.weatherService.getHistoricalData(
            widget.latitude,
            widget.longitude,
            start,
            histEnd,
          );
          combinedWeather.addAll(
            histWeather.where((p) => !p.time.isAfter(now)),
          );
        } catch (e) {
          debugPrint('Error fetching historical weather: $e');
        }
      }

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
