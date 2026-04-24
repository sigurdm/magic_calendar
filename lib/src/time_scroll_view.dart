import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'ephemeris_service.dart';
import 'algorithm.dart';
import 'planting_icons.dart';

class TimeScrollController {
  _TimeScrollViewState? _state;
  void scrollToNow() => _state?._scrollToNow();
}

class TimeScrollView extends StatefulWidget {
  final EphemerisService ephemeris;
  final ValueChanged<DateTime> onTimeSelected;
  final TimeScrollController? controller;

  const TimeScrollView({
    super.key,
    required this.ephemeris,
    required this.onTimeSelected,
    this.controller,
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
  DateTime? _cachedStart;
  DateTime? _cachedEnd;

  bool _isLoading = false;
  Timer? _updateTimer;

  late AnimationController _momentumController;
  double _lastMomentumValue = 0.0;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    _centerTime = DateTime.now();

    _momentumController = AnimationController.unbounded(vsync: this);
    _momentumController.addListener(_handleMomentumTick);

    _scheduleUpdate(immediate: true);
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

      if (mounted) {
        setState(() {
          _visibleIntervals = intervals;
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
        behavior: HitTestBehavior.opaque,
        onScaleStart: (details) {
          _momentumController.stop();
          _baseScaleHourWidth = _hourWidth;
        },
        onScaleUpdate: (details) {
          if (details.scale != 1.0) {
            setState(() {
              _hourWidth = (_baseScaleHourWidth * details.scale)
                  .clamp(_minHourWidth, _maxHourWidth);
            });
            _scheduleUpdate();
          }
          _applyPanDelta(details.focalPointDelta.dx);
        },
        onScaleEnd: (details) {
          final velocity = details.velocity.pixelsPerSecond.dx;
          if (velocity.abs() > 100) {
            _lastMomentumValue = 0.0;
            _momentumController.value = 0.0;
            final simulation = FrictionSimulation(0.15, 0.0, velocity);
            _momentumController.animateWith(simulation);
          }
        },
        child: Listener(
          onPointerSignal: (pointerSignal) {
            if (pointerSignal is PointerScrollEvent) {
              if (pointerSignal.scrollDelta.dy != 0) {
                _momentumController.stop();
                setState(() {
                  _hourWidth = (_hourWidth -
                          pointerSignal.scrollDelta.dy * (_hourWidth / 100))
                      .clamp(_minHourWidth, _maxHourWidth);
                });
                _scheduleUpdate();
              }
            }
          },
          child: Stack(
            children: [
              CustomPaint(
                size: Size.infinite,
                painter: InfiniteTimelinePainter(
                  centerTime: _centerTime,
                  hourWidth: _hourWidth,
                  intervals: _visibleIntervals,
                ),
              ),
              if (_isLoading && _visibleIntervals.isEmpty)
                const Center(child: CircularProgressIndicator()),
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

  InfiniteTimelinePainter({
    required this.centerTime,
    required this.hourWidth,
    required this.intervals,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) return;
    final centerX = size.width / 2;
    final bgPaint = Paint()
      ..color = const Color(0xFFD0E1F9).withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 20, size.width, 80), bgPaint);

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
        _drawBlock(canvas, xStart, width, 'gray', Colors.grey[400]!,
            interval.quality, true);
      } else if (interval.quality != PlantQuality.none) {
        final color = _getColorForQuality(interval.quality);
        final label = _getLabelForQuality(interval.quality);
        _drawBlock(canvas, xStart, width, label, color, interval.quality, false);
      }
    }

    final tickPaint = Paint()..color = Colors.white24;
    final visibleHours = size.width / hourWidth;
    final startTime =
        centerTime.subtract(Duration(minutes: (visibleHours * 30).toInt()));
    final endTime =
        centerTime.add(Duration(minutes: (visibleHours * 30).toInt()));

    // Determine frequencies based on zoom level
    int hourLabelFrequency = 6;
    int tickFrequency = 1;
    int dateLabelFrequencyInDays = 1;
    bool showHourLabels = true;

    if (hourWidth < 5) {
      // Very zoomed out (2 weeks+)
      hourLabelFrequency = 24;
      tickFrequency = 24;
      dateLabelFrequencyInDays = 3;
      showHourLabels = false;
    } else if (hourWidth < 10) {
      // Zoomed out (1 week)
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

    // Use a fixed epoch to ensure consistent label selection across all scroll positions
    final epoch = DateTime(2000, 1, 1);

    for (var t = firstTickTime;
        t.isBefore(endTime);
        t = t.add(Duration(hours: tickFrequency))) {
      final offsetInHours = t.difference(centerTime).inSeconds / 3600.0;
      final x = centerX + (offsetInHours * hourWidth);

      final isHourLabelTime = t.hour % hourLabelFrequency == 0;
      final isMidnight = t.hour == 0;

      if (isHourLabelTime || isMidnight) {
        canvas.drawLine(
            Offset(x, 15), Offset(x, 25), tickPaint..color = Colors.white54);

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
          // Use absolute days from epoch to decide if we show this label
          final totalDaysFromEpoch = t.difference(epoch).inDays;
          if (totalDaysFromEpoch % dateLabelFrequencyInDays == 0) {
            final datePainter = TextPainter(
              text: TextSpan(
                text: DateFormat('EEE, MMM d').format(t),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
              textDirection: ui.TextDirection.ltr,
            );
            datePainter.layout();
            datePainter.paint(canvas, Offset(x + 5, size.height - 18));
          }
        }
      } else {
        canvas.drawLine(
            Offset(x, 18), Offset(x, 22), tickPaint..color = Colors.white24);
      }
    }
  }

  void _drawBlock(Canvas canvas, double startX, double width, String label,
      Color color, PlantQuality quality, bool isGrayDay) {
    final rect = Rect.fromLTWH(startX + 2, 30, width - 4, 60);
    final paint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = Colors.black45
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    canvas.drawRRect(rrect, paint);
    canvas.drawRRect(rrect, borderPaint);

    if (width > 20) {
      final iconSize = (width > 50) ? 20.0 : 16.0;
      final iconOffset = Offset(
        rect.left + (rect.width - iconSize) / 2,
        (width > 50) ? rect.top + 6 : rect.top + (rect.height - iconSize) / 2,
      );
      canvas.save();
      canvas.translate(iconOffset.dx, iconOffset.dy);
      PlantingPainter(
              quality: quality,
              isGrayDay: isGrayDay,
              color: Colors.black.withValues(alpha: 0.6))
          .paint(canvas, Size(iconSize, iconSize));
      canvas.restore();

      if (width > 40) {
        final textPainter = TextPainter(
          text: TextSpan(
              text: label,
              style: const TextStyle(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
          textDirection: ui.TextDirection.ltr,
        );
        textPainter.layout(maxWidth: rect.width);
        textPainter.paint(
            canvas,
            Offset(rect.left + (rect.width - textPainter.width) / 2,
                rect.top + 32));
      }
    }
  }

  Color _getColorForQuality(PlantQuality quality) {
    switch (quality) {
      case PlantQuality.root: return const Color(0xFF8D6E63);
      case PlantQuality.leaf: return const Color(0xFF66BB6A);
      case PlantQuality.flower: return const Color(0xFFAB47BC);
      case PlantQuality.fruit: return const Color(0xFFFFA726);
      case PlantQuality.none: return const Color(0xFF78909C);
    }
  }

  String _getLabelForQuality(PlantQuality quality) {
    switch (quality) {
      case PlantQuality.root: return 'Root';
      case PlantQuality.leaf: return 'Leaf';
      case PlantQuality.flower: return 'Flower';
      case PlantQuality.fruit: return 'Fruit';
      case PlantQuality.none: return '';
    }
  }

  @override
  bool shouldRepaint(covariant InfiniteTimelinePainter oldDelegate) =>
      oldDelegate.centerTime != centerTime ||
      oldDelegate.hourWidth != hourWidth ||
      oldDelegate.intervals != intervals;
}
