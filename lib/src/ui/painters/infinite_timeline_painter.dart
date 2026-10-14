import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/garden/field_journal_entry.dart';
import '../../services/ephemeris_service.dart';
import '../theme/goethean_palette.dart';

/// CustomPainter for rendering an interactive infinite timeline of celestial and weather events.
final class InfiniteTimelinePainter extends CustomPainter {
  final DateTime centerTime;
  final double hourWidth;
  final List<CalendarInterval> intervals;
  final List<WeatherDataPoint> weatherData;
  final List<FieldJournalEntry> journalEntries;
  final EphemerisService ephemeris;
  final double latitude;
  final double longitude;
  final ui.Image? rootImage;
  final ui.Image? leafImage;
  final ui.Image? flowerImage;
  final ui.Image? fruitImage;
  final ui.Image? noneImage;
  final ui.Image? grayDayImage;

  final bool showBiodynamicOverlay;
  final bool organicFlow;
  final bool warmPalette;

  InfiniteTimelinePainter({
    required this.centerTime,
    required this.hourWidth,
    required this.intervals,
    required this.weatherData,
    required this.ephemeris,
    required this.latitude,
    required this.longitude,
    this.journalEntries = const [],
    this.showBiodynamicOverlay = false,
    this.organicFlow = true,
    this.warmPalette = true,
    this.rootImage,
    this.leafImage,
    this.flowerImage,
    this.fruitImage,
    this.noneImage,
    this.grayDayImage,
  });

  /// Returns the horizontal canvas coordinate (`x`) for [timestamp] given [canvasWidth].
  double xForTime(DateTime timestamp, double canvasWidth) {
    final centerX = canvasWidth / 2.0;
    final offsetInHours =
        timestamp.difference(centerTime).inMicroseconds / 3600000000.0;
    return centerX + (offsetInHours * hourWidth);
  }

  /// Returns the subset of [journalEntries] whose markers fall within the visible [canvasWidth].
  List<FieldJournalEntry> visibleJournalEntries(double canvasWidth) {
    if (canvasWidth <= 0 || hourWidth <= 0 || journalEntries.isEmpty) {
      return const [];
    }
    final result = <FieldJournalEntry>[];
    for (final entry in journalEntries) {
      final x = xForTime(entry.timestamp, canvasWidth);
      if (x >= -24.0 && x <= canvasWidth + 24.0) {
        result.add(entry);
      }
    }
    return result;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || hourWidth <= 0) {
      return;
    }
    final centerX = size.width / 2;

    final visibleHours = size.width / hourWidth;
    final startTime = centerTime.subtract(
      Duration(hours: (visibleHours / 2).ceil() + 24),
    );
    final endTime = centerTime.add(
      Duration(hours: (visibleHours / 2).ceil() + 24),
    );

    // Exact pixel-to-time mapping for canvas edges:
    // x = 0 corresponds to centerTime - (centerX / hourWidth) hours.
    // x = size.width corresponds to centerTime + ((size.width - centerX) / hourWidth) hours.
    final startSeconds = (centerX / hourWidth) * 3600.0;
    final endSeconds = ((size.width - centerX) / hourWidth) * 3600.0;
    final canvasStartTime = centerTime.subtract(
      Duration(microseconds: (startSeconds * 1000000).round()),
    );
    final canvasEndTime = centerTime.add(
      Duration(microseconds: (endSeconds * 1000000).round()),
    );

    // Zoom-adaptive Level of Detail (LOD) factor [0.0 = extreme zoom out, 1.0 = zoomed in]
    final lodFactor = ((hourWidth - 1.5) / 6.5).clamp(0.0, 1.0);

    // Strip layout: 12px-18px height, positioned between quality ribbon (y=5..25) and ticks (y=49+)
    final stripHeight = ui.lerpDouble(12.0, 18.0, lodFactor)!;
    final stripY = 37.0 - (stripHeight / 2.0);
    final stripRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, stripY, size.width, stripHeight),
      Radius.circular(organicFlow ? 6 : 3),
    );

    // 1. Base nocturnal track
    final nightPaint = Paint()
      ..color = warmPalette || organicFlow
          ? const Color(0xFF17141D)
          : const Color(0xFF13131D)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(stripRRect, nightPaint);

    // 2. Daytime solar capsules or Sinusoidal Solar Horizon Wave
    final iconAlpha = hourWidth >= 3.5
        ? ((hourWidth - 3.5) / 4.0).clamp(0.0, 1.0)
        : 0.0;
    final iconY = stripY + (stripHeight - 11.0) / 2.0;

    final rangeStartDate = DateTime(
      canvasStartTime.year,
      canvasStartTime.month,
      canvasStartTime.day,
    ).subtract(const Duration(days: 1));
    final rangeEndDate = DateTime(
      canvasEndTime.year,
      canvasEndTime.month,
      canvasEndTime.day,
    ).add(const Duration(days: 1));

    // Clip solar capsules cleanly to the ribbon rounded bounds
    canvas.save();
    canvas.clipRRect(stripRRect);

    final dayAlpha = ui.lerpDouble(0.75, 0.95, lodFactor)!;
    const dawnGold = Color(0xFFE5A93C); // Warm amber dawn/dusk
    const peakSun = Color(0xFFFFF176); // Radiant sunlight gold

    for (
      var d = rangeStartDate;
      d.isBefore(rangeEndDate);
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      final ss = ephemeris.getSunriseSunset(d, latitude, longitude);

      if (ss.sunrise != null && ss.sunset != null) {
        final xRise =
            centerX +
            (ss.sunrise!.difference(centerTime).inSeconds / 3600.0 * hourWidth);
        final xSet =
            centerX +
            (ss.sunset!.difference(centerTime).inSeconds / 3600.0 * hourWidth);
        final xNoon =
            centerX +
            (ss.noon.difference(centerTime).inSeconds / 3600.0 * hourWidth);

        // 30-minute twilight transition envelope before sunrise and after sunset
        final twilightPx = (organicFlow ? 1.2 : 0.5) * hourWidth;
        final startX = xRise - twilightPx;
        final endX = xSet + twilightPx;

        // Skip if outside canvas
        if (endX >= 0 && startX <= size.width) {
          final dayWidth = endX - startX;
          if (dayWidth > 0) {
            if (organicFlow) {
              // Sinusoidal solar-altitude hill rising from horizon at sunrise to zenith at solar noon
              final hillPath = Path()..moveTo(startX, stripY + stripHeight);
              const steps = 20;
              for (int s = 0; s <= steps; s++) {
                final u = s / steps;
                final px = startX + u * dayWidth;
                final sinElev = math.sin(u * math.pi);
                final py =
                    (stripY + stripHeight) - (sinElev * (stripHeight - 1.5));
                hillPath.lineTo(px, py);
              }
              hillPath.lineTo(endX, stripY + stripHeight);
              hillPath.close();

              final hillRect = Rect.fromLTRB(
                startX,
                stripY,
                endX,
                stripY + stripHeight,
              );
              canvas.drawPath(
                hillPath,
                Paint()
                  ..shader = ui.Gradient.linear(
                    Offset(xNoon, stripY),
                    Offset(xNoon, stripY + stripHeight),
                    [
                      peakSun.withValues(alpha: 0.95),
                      dawnGold.withValues(alpha: 0.78),
                      GoetheanPalette.rootEarth.withValues(alpha: 0.35),
                    ],
                    const [0.0, 0.65, 1.0],
                  ),
              );
              // Golden solar trajectory crest line
              final arcPath = Path();
              for (int s = 0; s <= steps; s++) {
                final u = s / steps;
                final px = startX + u * dayWidth;
                final sinElev = math.sin(u * math.pi);
                final py =
                    (stripY + stripHeight - 0.5) -
                    (sinElev * (stripHeight - 2.2));
                if (s == 0) {
                  arcPath.moveTo(px, py);
                } else {
                  arcPath.lineTo(px, py);
                }
              }
              canvas.drawPath(
                arcPath,
                Paint()
                  ..shader = LinearGradient(
                    colors: [
                      dawnGold.withValues(alpha: 0.2),
                      const Color(0xFFFFF9C4),
                      dawnGold.withValues(alpha: 0.2),
                    ],
                  ).createShader(hillRect)
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1.4,
              );
            } else {
              final tRise = ((xRise - startX) / dayWidth).clamp(0.0, 1.0);
              final tNoon = ((xNoon - startX) / dayWidth).clamp(0.0, 1.0);
              final tSet = ((xSet - startX) / dayWidth).clamp(0.0, 1.0);

              final dayShader = ui.Gradient.linear(
                Offset(startX, 0),
                Offset(endX, 0),
                [
                  const Color(0xFF13131D),
                  dawnGold.withValues(alpha: dayAlpha),
                  peakSun.withValues(alpha: dayAlpha),
                  dawnGold.withValues(alpha: dayAlpha),
                  const Color(0xFF13131D),
                ],
                [0.0, tRise, tNoon, tSet, 1.0],
              );

              canvas.drawRect(
                Rect.fromLTRB(startX, stripY, endX, stripY + stripHeight),
                Paint()..shader = dayShader,
              );
            }
          }
        }
      }
    }
    canvas.restore();

    // 3. Draw sun/moon icons smoothly fading in from hourWidth >= 3.5
    if (iconAlpha > 0) {
      for (
        var d = rangeStartDate;
        d.isBefore(rangeEndDate);
        d = DateTime(d.year, d.month, d.day + 1)
      ) {
        final ss = ephemeris.getSunriseSunset(d, latitude, longitude);
        if (ss.sunrise != null) {
          final x =
              centerX +
              (ss.sunrise!.difference(centerTime).inSeconds /
                  3600.0 *
                  hourWidth);
          if (x >= 0 && x <= size.width) {
            _drawIcon(canvas, x, '☀️', 10, iconY, iconAlpha);
          }
        }
        if (ss.sunset != null) {
          final x =
              centerX +
              (ss.sunset!.difference(centerTime).inSeconds /
                  3600.0 *
                  hourWidth);
          if (x >= 0 && x <= size.width) {
            _drawIcon(canvas, x, '🌙', 10, iconY, iconAlpha);
          }
        }
      }
    }

    final tickPaint = Paint()
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

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

    // Draw daily midnight lines and date headers immune to DST drift
    for (
      var d = DateTime(startTime.year, startTime.month, startTime.day);
      d.isBefore(endTime.add(const Duration(days: 1)));
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      final midnight = DateTime(d.year, d.month, d.day);
      final offsetInHours = midnight.difference(centerTime).inSeconds / 3600.0;
      final x = centerX + (offsetInHours * hourWidth);

      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        tickPaint..color = Colors.white24,
      );

      final totalDaysFromEpoch = DateTime.utc(
        d.year,
        d.month,
        d.day,
      ).difference(DateTime.utc(2000, 1, 1)).inDays;
      final mod =
          (totalDaysFromEpoch % dateLabelFrequencyInDays +
              dateLabelFrequencyInDays) %
          dateLabelFrequencyInDays;
      if (mod == 0) {
        final datePainter = TextPainter(
          text: TextSpan(
            text: DateFormat('EEE, MMM d').format(midnight),
            style: const TextStyle(
              fontFamily: 'Outfit',
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

    // Draw sub-daily tick marks and hour labels
    if (showHourLabels || tickFrequency < 24) {
      for (
        var d = DateTime(startTime.year, startTime.month, startTime.day);
        d.isBefore(endTime.add(const Duration(days: 1)));
        d = DateTime(d.year, d.month, d.day + 1)
      ) {
        for (int h = tickFrequency; h < 24; h += tickFrequency) {
          final t = DateTime(d.year, d.month, d.day, h);
          if (t.isBefore(startTime) || t.isAfter(endTime)) continue;
          final offsetInHours = t.difference(centerTime).inSeconds / 3600.0;
          final x = centerX + (offsetInHours * hourWidth);

          final isHourLabelTime = h % hourLabelFrequency == 0;
          if (isHourLabelTime) {
            canvas.drawLine(
              Offset(x, 25),
              Offset(x, 49),
              tickPaint..color = Colors.white54,
            );
            if (showHourLabels) {
              final hourPainter = TextPainter(
                text: TextSpan(
                  text: '${h.toString().padLeft(2, '0')}:00',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    color: Colors.white38,
                    fontSize: 10,
                  ),
                ),
                textDirection: ui.TextDirection.ltr,
              );
              hourPainter.layout();
              hourPainter.paint(canvas, Offset(x - hourPainter.width / 2, 50));
            }
          } else {
            canvas.drawLine(
              Offset(x, 32),
              Offset(x, 42),
              tickPaint..color = Colors.white24,
            );
          }
        }
      }
    }

    _paintIntervalsWithTransitions(canvas, size, startTime, endTime, centerX);

    final tempRowY = 65.0;
    final tempRowHeight = 50.0;
    final windRowY = 115.0;
    final windRowHeight = 50.0;

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
    bool firstTemp = true;
    bool firstWind = true;

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
      final temp = wd.temperature;
      if (temp != null) {
        final yTemp = mapTempToY(temp);
        if (firstTemp) {
          tempPath.moveTo(x, yTemp);
          firstTemp = false;
        } else {
          tempPath.lineTo(x, yTemp);
        }
      }
      final yWind = mapWindToY(wd.windSpeed);

      if (wd.precipitation > 0) {
        final barHeight = (wd.precipitation * 8.0).clamp(3.0, 40.0);
        final barPaint = Paint()
          ..color = const Color(0xFF42A5F5)
          ..style = PaintingStyle.fill;

        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              x - 3,
              tempRowY + tempRowHeight - barHeight,
              6,
              barHeight,
            ),
            const Radius.circular(2),
          ),
          barPaint,
        );
      }

      if (firstWind) {
        windPath.moveTo(x, yWind);
        firstWind = false;
      } else {
        windPath.lineTo(x, yWind);
      }
    }

    canvas.drawPath(tempPath, tempLinePaint);
    canvas.drawPath(windPath, windLinePaint);

    for (final wd in weatherData) {
      final hour = wd.time.toLocal().hour;
      bool showLabel = false;

      if (hourWidth < 10) {
        showLabel = hour == 12;
      } else if (hourWidth < 20) {
        showLabel = hour == 0 || hour == 12;
      } else if (hourWidth < 40) {
        showLabel = hour % 6 == 0;
      } else {
        showLabel = hour % 3 == 0;
      }

      if (!showLabel) continue;

      final offsetInHours = wd.time.difference(centerTime).inSeconds / 3600.0;
      final x = centerX + (offsetInHours * hourWidth);

      if (x >= 0 && x <= size.width) {
        final temp = wd.temperature;
        final yTemp = temp != null
            ? mapTempToY(temp)
            : tempRowY + tempRowHeight / 2;
        if (temp != null) {
          _drawText(canvas, x, '${temp.round()}°', 10, yTemp - 12);
        }

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

        final yWind = mapWindToY(wd.windSpeed);
        _drawText(canvas, x, '${wd.windSpeed.round()}m/s', 10, yWind - 12);
        _drawWindArrow(canvas, x, yWind + 10, wd.windDirection);
      }
    }

    final now = DateTime.now();
    final nowOffsetInHours = now.difference(centerTime).inSeconds / 3600.0;
    final nowX = centerX + (nowOffsetInHours * hourWidth);

    if (nowX >= 0 && nowX <= size.width) {
      final nowPaint = Paint()
        ..color = Colors.blueAccent
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      canvas.drawLine(Offset(nowX, 0), Offset(nowX, size.height), nowPaint);

      final glowPaint = Paint()
        ..color = Colors.blueAccent.withValues(alpha: 0.3)
        ..strokeWidth = 6.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0)
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(nowX, 0), Offset(nowX, size.height), glowPaint);
    }

    _paintJournalMarkers(canvas, size, startTime, endTime, centerX);
  }

  void _paintJournalMarkers(
    Canvas canvas,
    Size size,
    DateTime startTime,
    DateTime endTime,
    double centerX,
  ) {
    if (journalEntries.isEmpty) return;

    final showCompactLabel = hourWidth >= 5.0;

    for (final entry in journalEntries) {
      if (entry.timestamp.isBefore(startTime) ||
          entry.timestamp.isAfter(endTime)) {
        continue;
      }
      final offsetInHours =
          entry.timestamp.difference(centerTime).inMicroseconds / 3600000000.0;
      final x = centerX + (offsetInHours * hourWidth);
      if (x < -28.0 || x > size.width + 28.0) continue;

      final markerColor = entry.quality == PlantQuality.none
          ? GoetheanPalette.aspectGold
          : _getColorForQuality(entry.quality);

      // 1. Soft vertical botanical stem connecting quality ribbon to journal marker row
      final stemGlowPaint = Paint()
        ..color = markerColor.withValues(alpha: 0.28)
        ..strokeWidth = 4.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
      canvas.drawLine(Offset(x, 22.0), Offset(x, 162.0), stemGlowPaint);

      final stemPaint = Paint()
        ..color = GoetheanPalette.aspectGold.withValues(alpha: 0.85)
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(x, 22.0), Offset(x, 162.0), stemPaint);

      // 2. Crown node pin on the cosmic quality bar (y = 15)
      canvas.drawCircle(
        Offset(x, 15.0),
        4.2,
        Paint()
          ..color = const Color(0xFF1A1612)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        Offset(x, 15.0),
        3.2,
        Paint()
          ..color = markerColor
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        Offset(x, 15.0),
        4.2,
        Paint()
          ..color = GoetheanPalette.aspectGold
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke,
      );

      // 3. Journal badge capsule at y = 154..172
      final badgeText = showCompactLabel
          ? '${entry.timelineMarkerGlyph} ${entry.timelineMarkerLabel}'
          : entry.timelineMarkerGlyph;
      final tp = TextPainter(
        text: TextSpan(
          text: badgeText,
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 10.0,
            fontWeight: FontWeight.w700,
            color: Color(0xFFF6ECD8),
            fontFamilyFallback: ['Symbola', 'DejaVu Sans', 'Noto Color Emoji'],
          ),
        ),
        maxLines: 1,
        textDirection: ui.TextDirection.ltr,
      )..layout();

      final padH = showCompactLabel ? 6.0 : 4.0;
      final badgeWidth = math.max(18.0, tp.width + padH * 2);
      const badgeHeight = 18.0;
      const badgeY = 154.0;
      final badgeRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x - badgeWidth / 2, badgeY, badgeWidth, badgeHeight),
        const Radius.circular(9.0),
      );

      canvas.drawRRect(
        badgeRect,
        Paint()
          ..color = const Color(0xFF1E1A16).withValues(alpha: 0.94)
          ..style = PaintingStyle.fill,
      );
      canvas.drawRRect(
        badgeRect,
        Paint()
          ..color = markerColor.withValues(alpha: 0.28)
          ..style = PaintingStyle.fill,
      );
      canvas.drawRRect(
        badgeRect,
        Paint()
          ..color = GoetheanPalette.aspectGold.withValues(alpha: 0.9)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke,
      );

      tp.paint(
        canvas,
        Offset(x - tp.width / 2, badgeY + (badgeHeight - tp.height) / 2),
      );

      if (entry.hasOutcome) {
        canvas.drawCircle(
          Offset(x + badgeWidth / 2 - 2.0, badgeY + 2.0),
          3.0,
          Paint()..color = GoetheanPalette.aspectGold,
        );
      }
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
        style: TextStyle(
          fontFamily: 'Outfit',
          color: Colors.white70,
          fontSize: fontSize,
        ),
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
    double opacity = 1.0,
  ]) {
    final tp = TextPainter(
      text: TextSpan(
        text: icon,
        style: TextStyle(
          fontSize: fontSize,
          color: Colors.white.withValues(alpha: opacity),
          fontFamilyFallback: const [
            'Symbola',
            'DejaVu Sans',
            'Noto Color Emoji',
          ],
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(x - tp.width / 2, y ?? 85));
  }

  void _drawWindArrow(
    Canvas canvas,
    double x,
    double y,
    double windDirDegrees,
  ) {
    canvas.save();
    canvas.translate(x, y);
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

  void _paintIntervalsWithTransitions(
    Canvas canvas,
    Size size,
    DateTime startTime,
    DateTime endTime,
    double centerX,
  ) {
    if (intervals.isEmpty) return;

    final visibleIntervals = <CalendarInterval>[];
    for (final interval in intervals) {
      if (interval.end.isBefore(startTime) || interval.start.isAfter(endTime)) {
        continue;
      }
      visibleIntervals.add(interval);
    }

    if (visibleIntervals.isEmpty) return;

    final maxHalfBlendPx = organicFlow
        ? math.max(18.0, 5.0 * hourWidth)
        : (1.5 / 2.0) * hourWidth; // ~0.75 hours in pixels
    final count = visibleIntervals.length;
    final xStarts = List<double>.filled(count, 0.0);
    final xEnds = List<double>.filled(count, 0.0);
    final colors = List<Color>.filled(count, Colors.transparent);

    for (int i = 0; i < count; i++) {
      final interval = visibleIntervals[i];
      final startOffsetInHours =
          interval.start.difference(centerTime).inSeconds / 3600.0;
      final endOffsetInHours =
          interval.end.difference(centerTime).inSeconds / 3600.0;
      xStarts[i] = centerX + (startOffsetInHours * hourWidth);
      xEnds[i] = centerX + (endOffsetInHours * hourWidth);

      if (interval.isGrayDay) {
        colors[i] = Colors.grey[400]!.withValues(alpha: 0.8);
      } else if (interval.quality != PlantQuality.none) {
        colors[i] = _getColorForQuality(interval.quality)
            .withValues(alpha: 0.8);
      } else {
        colors[i] = Colors.transparent;
      }
    }

    final leftOffsets = List<double>.filled(count, 0.0);
    final rightOffsets = List<double>.filled(count, 0.0);

    for (int i = 0; i < count - 1; i++) {
      final curr = visibleIntervals[i];
      final next = visibleIntervals[i + 1];
      final touches = next.start.difference(curr.end).inSeconds.abs() <= 120;
      if (touches) {
        final hasTransition = colors[i] != colors[i + 1];
        if (hasTransition) {
          final currWidth = xEnds[i] - xStarts[i];
          final nextWidth = xEnds[i + 1] - xStarts[i + 1];
          final leftHalf = math.min(maxHalfBlendPx, currWidth / 2.0);
          final rightHalf = math.min(maxHalfBlendPx, nextWidth / 2.0);

          rightOffsets[i] = leftHalf;
          leftOffsets[i + 1] = rightHalf;
        }
      }
    }

    for (int i = 0; i < count; i++) {
      final interval = visibleIntervals[i];
      if (interval.isGrayDay) {
        final currWidth = xEnds[i] - xStarts[i];
        if (leftOffsets[i] == 0.0) {
          leftOffsets[i] = math.min(maxHalfBlendPx * 2.0, currWidth / 3.0);
        }
        if (rightOffsets[i] == 0.0) {
          rightOffsets[i] = math.min(maxHalfBlendPx * 2.0, currWidth / 3.0);
        }
      }
    }

    // 1. Draw solid fills
    for (int i = 0; i < count; i++) {
      final color = colors[i];
      if (color.a == 0.0) continue;

      final solidStart = xStarts[i] + leftOffsets[i];
      final solidEnd = xEnds[i] - rightOffsets[i];

      if (solidEnd > solidStart) {
        final rect = Rect.fromLTWH(solidStart, 5, solidEnd - solidStart, 20);
        final paint = Paint()
          ..color = color
          ..style = PaintingStyle.fill;

        final hasLeftNeighbor =
            i > 0 &&
            visibleIntervals[i].start
                    .difference(visibleIntervals[i - 1].end)
                    .inSeconds
                    .abs() <=
                120;
        final hasRightNeighbor =
            i < count - 1 &&
            visibleIntervals[i + 1].start
                    .difference(visibleIntervals[i].end)
                    .inSeconds
                    .abs() <=
                120;

        final isLeftIsolated = !hasLeftNeighbor && leftOffsets[i] == 0.0;
        final isRightIsolated = !hasRightNeighbor && rightOffsets[i] == 0.0;

        if (isLeftIsolated || isRightIsolated) {
          canvas.drawRRect(
            RRect.fromRectAndCorners(
              rect,
              topLeft: isLeftIsolated ? const Radius.circular(3) : Radius.zero,
              bottomLeft: isLeftIsolated
                  ? const Radius.circular(3)
                  : Radius.zero,
              topRight: isRightIsolated
                  ? const Radius.circular(3)
                  : Radius.zero,
              bottomRight: isRightIsolated
                  ? const Radius.circular(3)
                  : Radius.zero,
            ),
            paint,
          );
        } else {
          canvas.drawRect(rect, paint);
        }
      }
    }

    // 2. Draw soft linear gradient transitions across boundaries
    for (int i = 0; i < count - 1; i++) {
      if (rightOffsets[i] > 0.0 && leftOffsets[i + 1] > 0.0) {
        final xBoundary = xEnds[i];
        final leftHalf = rightOffsets[i];
        final rightHalf = leftOffsets[i + 1];
        final blendStart = xBoundary - leftHalf;
        final blendEnd = xBoundary + rightHalf;
        final blendWidth = blendEnd - blendStart;

        if (blendWidth > 0) {
          final rect = Rect.fromLTWH(blendStart, 5, blendWidth, 20);
          final gradientPaint = Paint()
            ..shader = ui.Gradient.linear(
              Offset(blendStart, 0),
              Offset(blendEnd, 0),
              [colors[i], colors[i + 1]],
              const [0.0, 1.0],
            );
          canvas.drawRect(rect, gradientPaint);
        }
      }
    }

    // 3. Feather Gray Day entry / exit
    for (int i = 0; i < count; i++) {
      final interval = visibleIntervals[i];
      if (interval.isGrayDay) {
        final hasLeftTransitionNeighbor =
            i > 0 &&
            visibleIntervals[i].start
                    .difference(visibleIntervals[i - 1].end)
                    .inSeconds
                    .abs() <=
                120 &&
            rightOffsets[i - 1] > 0.0;
        if (!hasLeftTransitionNeighbor && leftOffsets[i] > 0.0) {
          final rect = Rect.fromLTWH(xStarts[i], 5, leftOffsets[i], 20);
          final paint = Paint()
            ..shader = ui.Gradient.linear(
              Offset(xStarts[i], 0),
              Offset(xStarts[i] + leftOffsets[i], 0),
              [colors[i].withValues(alpha: 0.0), colors[i]],
              const [0.0, 1.0],
            );
          canvas.drawRect(rect, paint);
        }

        final hasRightTransitionNeighbor =
            i < count - 1 &&
            visibleIntervals[i + 1].start
                    .difference(visibleIntervals[i].end)
                    .inSeconds
                    .abs() <=
                120 &&
            leftOffsets[i + 1] > 0.0;
        if (!hasRightTransitionNeighbor && rightOffsets[i] > 0.0) {
          final exitStart = xEnds[i] - rightOffsets[i];
          final rect = Rect.fromLTWH(exitStart, 5, rightOffsets[i], 20);
          final paint = Paint()
            ..shader = ui.Gradient.linear(
              Offset(exitStart, 0),
              Offset(xEnds[i], 0),
              [colors[i], colors[i].withValues(alpha: 0.0)],
              const [0.0, 1.0],
            );
          canvas.drawRect(rect, paint);
        }
      }
    }

    // 4. Draw decorations (borders, biodynamic strip, and icons)
    for (int i = 0; i < count; i++) {
      final interval = visibleIntervals[i];
      final xStart = xStarts[i];
      final width = xEnds[i] - xStart;
      final label = interval.isGrayDay
          ? 'gray'
          : _getLabelForQuality(interval.quality);

      _drawBlockDecorations(
        canvas,
        xStart,
        width,
        label,
        interval.quality,
        interval.isGrayDay,
        interval.isSpecial,
      );
    }
  }

  void _drawBlockDecorations(
    Canvas canvas,
    double x,
    double width,
    String label,
    PlantQuality quality,
    bool isGrayDay,
    bool isSpecial,
  ) {
    final rect = Rect.fromLTWH(x, 5, width, 20);

    if (isSpecial) {
      final borderPaint = Paint()
        ..color = const Color(0xFFFFD700)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        borderPaint,
      );
    }

    if (showBiodynamicOverlay) {
      final prepStripRect = Rect.fromLTWH(x, 2, width, 3);
      final prepPaint = Paint();
      final isEvening =
          label != 'gray' && (quality == PlantQuality.root || label == 'root');
      final isMorning =
          label != 'gray' &&
          (quality == PlantQuality.flower || quality == PlantQuality.fruit);

      if (isEvening) {
        prepPaint.color = const Color(
          0xFFD7CCC8,
        ); // BD 500 Horn Manure Earth strip
        canvas.drawRect(prepStripRect, prepPaint);
      } else if (isMorning) {
        prepPaint.color = const Color(
          0xFF80DEEA,
        ); // BD 501 Horn Silica Air/Light strip
        canvas.drawRect(prepStripRect, prepPaint);
      }
    }

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
        canvas.translate(x + (width - iconSize) / 2, 5 + (20 - iconSize) / 2);
        final src = Rect.fromLTWH(
          0,
          0,
          image.width.toDouble(),
          image.height.toDouble(),
        );
        final dst = Rect.fromLTWH(0, 0, iconSize, iconSize);
        canvas.drawImageRect(
          image,
          src,
          dst,
          Paint()..filterQuality = FilterQuality.medium,
        );

        final framePaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.75;
        canvas.drawRRect(
          RRect.fromRectAndRadius(dst, const Radius.circular(2)),
          framePaint,
        );

        canvas.restore();
      }
    }
  }

  Color _getColorForQuality(PlantQuality quality) {
    if (warmPalette || organicFlow) {
      switch (quality) {
        case PlantQuality.root:
          return GoetheanPalette.rootEarth;
        case PlantQuality.leaf:
          return GoetheanPalette.leafWater;
        case PlantQuality.flower:
          return GoetheanPalette.flowerAir;
        case PlantQuality.fruit:
          return GoetheanPalette.fruitWarmth;
        case PlantQuality.none:
          return Colors.transparent;
      }
    }
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
  bool shouldRepaint(covariant InfiniteTimelinePainter oldDelegate) => true;
}
