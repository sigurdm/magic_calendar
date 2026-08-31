import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'dart:ui' as ui;
import 'dart:math' as math;

import '../../services/ephemeris_service.dart';

/// CustomPainter for rendering an interactive infinite timeline of celestial and weather events.
final class InfiniteTimelinePainter extends CustomPainter {
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

  final bool showBiodynamicOverlay;

  InfiniteTimelinePainter({
    required this.centerTime,
    required this.hourWidth,
    required this.intervals,
    required this.weatherData,
    required this.ephemeris,
    required this.latitude,
    required this.longitude,
    this.showBiodynamicOverlay = false,
    this.rootImage,
    this.leafImage,
    this.flowerImage,
    this.fruitImage,
    this.noneImage,
    this.grayDayImage,
  });

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

    final int sampleCount = math.max(100, (totalDuration / 1800).clamp(100, 360).toInt());
    final List<Color> finalColors = [];
    final List<double> finalStops = [];

    final latRad = latitude * math.pi / 180.0;
    final sinLat = math.sin(latRad);
    final cosLat = math.cos(latRad);

    for (int i = 0; i <= sampleCount; i++) {
      final t = i / sampleCount;
      final time = canvasStartTime.add(
        Duration(seconds: (totalDuration * t).toInt()),
      );

      final utc = time.toUtc();
      final dayOfYear = utc.difference(DateTime.utc(utc.year, 1, 1)).inDays + 1;
      final decRad =
          -23.44 *
          math.cos((360.0 / 365.0) * (dayOfYear + 10) * math.pi / 180.0) *
          math.pi /
          180.0;
      final sinDec = math.sin(decRad);
      final cosDec = math.cos(decRad);

      final h =
          (utc.hour +
              utc.minute / 60.0 +
              utc.second / 3600.0 -
              12.0 +
              longitude / 15.0) *
          15.0;
      final hRad = h * math.pi / 180.0;

      final sinAlt = (sinLat * sinDec + cosLat * cosDec * math.cos(hRad)).clamp(-1.0, 1.0);
      final altRad = math.asin(sinAlt);
      final alt = altRad * 180.0 / math.pi;

      Color c;
      if (alt > 0) {
        final factor = (alt / 40.0).clamp(0.0, 1.0);
        c = Color.lerp(
          const Color(0xFFFFB74D),
          const Color(0xFFFFFDE7),
          factor,
        )!;
      } else if (alt > -6) {
        final factor = ((alt + 6) / 6.0).clamp(0.0, 1.0);
        c = Color.lerp(
          const Color(0xFF121212),
          const Color(0xFFFFB74D),
          factor,
        )!;
      } else {
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
    canvas.drawRect(Rect.fromLTWH(0, 27, size.width, 20), paint);

    for (
      var d = DateTime(
        canvasStartTime.year,
        canvasStartTime.month,
        canvasStartTime.day,
      );
      d.isBefore(canvasEndTime.add(const Duration(days: 1)));
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      final ss = ephemeris.getSunriseSunset(d, latitude, longitude);

      if (ss.sunrise != null) {
        final x =
            centerX +
            (ss.sunrise!.difference(centerTime).inSeconds / 3600.0 * hourWidth);
        if (x >= 0 && x <= size.width) {
          _drawIcon(canvas, x, '☀️', 10, 37);
        }
      }
      if (ss.sunset != null) {
        final x =
            centerX +
            (ss.sunset!.difference(centerTime).inSeconds / 3600.0 * hourWidth);
        if (x >= 0 && x <= size.width) {
          _drawIcon(canvas, x, '🌙', 10, 37);
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
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
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

    _paintIntervalsWithTransitions(
      canvas,
      size,
      startTime,
      endTime,
      centerX,
    );

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
    bool first = true;

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
        final yTemp = mapTempToY(wd.temperature);
        _drawText(canvas, x, '${wd.temperature.round()}°', 10, yTemp - 12);

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

    final maxHalfBlendPx = (1.5 / 2.0) * hourWidth; // ~0.75 hours in pixels
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
        colors[i] = _getColorForQuality(interval.quality).withValues(alpha: 0.8);
      } else {
        colors[i] = Colors.transparent;
      }
    }

    final leftOffsets = List<double>.filled(count, 0.0);
    final rightOffsets = List<double>.filled(count, 0.0);

    for (int i = 0; i < count - 1; i++) {
      final curr = visibleIntervals[i];
      final next = visibleIntervals[i + 1];
      final touches = (next.start.difference(curr.end).inSeconds).abs() <= 120;
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

        final hasLeftNeighbor = i > 0 &&
            (visibleIntervals[i].start.difference(visibleIntervals[i - 1].end).inSeconds).abs() <= 120;
        final hasRightNeighbor = i < count - 1 &&
            (visibleIntervals[i + 1].start.difference(visibleIntervals[i].end).inSeconds).abs() <= 120;

        final isLeftIsolated = !hasLeftNeighbor && leftOffsets[i] == 0.0;
        final isRightIsolated = !hasRightNeighbor && rightOffsets[i] == 0.0;

        if (isLeftIsolated || isRightIsolated) {
          canvas.drawRRect(
            RRect.fromRectAndCorners(
              rect,
              topLeft: isLeftIsolated ? const Radius.circular(3) : Radius.zero,
              bottomLeft: isLeftIsolated ? const Radius.circular(3) : Radius.zero,
              topRight: isRightIsolated ? const Radius.circular(3) : Radius.zero,
              bottomRight: isRightIsolated ? const Radius.circular(3) : Radius.zero,
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
        final hasLeftTransitionNeighbor = i > 0 &&
            (visibleIntervals[i].start.difference(visibleIntervals[i - 1].end).inSeconds).abs() <= 120 &&
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

        final hasRightTransitionNeighbor = i < count - 1 &&
            (visibleIntervals[i + 1].start.difference(visibleIntervals[i].end).inSeconds).abs() <= 120 &&
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
      final label = interval.isGrayDay ? "gray" : _getLabelForQuality(interval.quality);

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
          label != "gray" && (quality == PlantQuality.root || label == "root");
      final isMorning =
          label != "gray" &&
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
        canvas.drawImageRect(image, src, dst, Paint());

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
        oldDelegate.weatherData != weatherData ||
        oldDelegate.latitude != latitude ||
        oldDelegate.longitude != longitude ||
        oldDelegate.showBiodynamicOverlay != showBiodynamicOverlay ||
        oldDelegate.rootImage != rootImage ||
        oldDelegate.leafImage != leafImage ||
        oldDelegate.flowerImage != flowerImage ||
        oldDelegate.fruitImage != fruitImage ||
        oldDelegate.noneImage != noneImage ||
        oldDelegate.grayDayImage != grayDayImage;
  }
}
