import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/garden/field_journal_entry.dart';
import '../../core/garden/garden_profile.dart';
import '../../services/ephemeris_service.dart';
import '../theme/goethean_palette.dart';

/// CustomPainter for rendering an interactive infinite timeline of celestial and weather events.
final class InfiniteTimelinePainter extends CustomPainter {
  static final DateFormat _dayLabelFormat = DateFormat('EEE, MMM d');
  static final DateTime _epoch2000Utc = DateTime.utc(2000, 1, 1);

  static const int _maxDayFormatCacheEntries = 128;
  static final LinkedHashMap<int, String> _dayLabelCache = LinkedHashMap();

  static const int _maxTextPainterCacheEntries = 384;
  static final LinkedHashMap<(String, TextStyle, int?), TextPainter>
  _textPainterCache = LinkedHashMap();

  static const List<String> _hourLabelStrings = <String>[
    '00:00',
    '01:00',
    '02:00',
    '03:00',
    '04:00',
    '05:00',
    '06:00',
    '07:00',
    '08:00',
    '09:00',
    '10:00',
    '11:00',
    '12:00',
    '13:00',
    '14:00',
    '15:00',
    '16:00',
    '17:00',
    '18:00',
    '19:00',
    '20:00',
    '21:00',
    '22:00',
    '23:00',
  ];

  static const TextStyle _dateHeaderStyle = TextStyle(
    fontFamily: 'Outfit',
    color: Colors.white,
    fontSize: 12,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle _hourLabelStyle = TextStyle(
    fontFamily: 'Outfit',
    color: Colors.white38,
    fontSize: 10,
  );

  static const TextStyle _plannedBadgeTextStyle = TextStyle(
    fontFamily: 'Outfit',
    fontSize: 9.5,
    fontWeight: FontWeight.w700,
    color: Color(0xFFF6ECD8),
    fontFamilyFallback: ['Symbola', 'DejaVu Sans', 'Noto Color Emoji'],
  );

  static const TextStyle _journalBadgeTextStyle = TextStyle(
    fontFamily: 'Outfit',
    fontSize: 10.0,
    fontWeight: FontWeight.w700,
    color: Color(0xFFF6ECD8),
    fontFamilyFallback: ['Symbola', 'DejaVu Sans', 'Noto Color Emoji'],
  );

  static const TextStyle _weatherTextStyle10 = TextStyle(
    fontFamily: 'Outfit',
    color: Colors.white70,
    fontSize: 10,
  );

  static const TextStyle _weatherTextStyle8 = TextStyle(
    fontFamily: 'Outfit',
    color: Colors.white70,
    fontSize: 8,
  );

  static const List<String> _emojiFallback = <String>[
    'Symbola',
    'DejaVu Sans',
    'Noto Color Emoji',
  ];

  static final Float64List _solarSinTable = _buildSolarSinTable();
  static Float64List _buildSolarSinTable() {
    const steps = 20;
    final table = Float64List(steps + 1);
    for (int s = 0; s <= steps; s++) {
      table[s] = math.sin((s / steps) * math.pi);
    }
    return table;
  }

  static final Paint _nightWarmPaint = Paint()
    ..color = const Color(0xFF17141D)
    ..style = PaintingStyle.fill;

  static final Paint _nightCoolPaint = Paint()
    ..color = const Color(0xFF13131D)
    ..style = PaintingStyle.fill;

  static final Paint _tickPaint = Paint()
    ..strokeWidth = 1.0
    ..style = PaintingStyle.stroke;

  static final Paint _tempBgPaint = Paint()
    ..color = const Color(0x1AD0E2FF)
    ..style = PaintingStyle.fill;

  static final Paint _windBgPaint = Paint()
    ..color = const Color(0x0DE0E0E0)
    ..style = PaintingStyle.fill;

  static final Paint _tempLinePaint = Paint()
    ..color = Colors.orangeAccent.withValues(alpha: 0.3)
    ..strokeWidth = 1.0
    ..style = PaintingStyle.stroke;

  static final Paint _windLinePaint = Paint()
    ..color = Colors.lightBlueAccent.withValues(alpha: 0.3)
    ..strokeWidth = 1.0
    ..style = PaintingStyle.stroke;

  static final Paint _precipBarPaint = Paint()
    ..color = const Color(0xFF42A5F5)
    ..style = PaintingStyle.fill;

  static final Paint _nowLinePaint = Paint()
    ..color = Colors.blueAccent
    ..strokeWidth = 2.0
    ..style = PaintingStyle.stroke;

  static final Paint _nowGlowPaint = Paint()
    ..color = Colors.blueAccent.withValues(alpha: 0.3)
    ..strokeWidth = 6.0
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0)
    ..style = PaintingStyle.stroke;

  static final Paint _windArrowPaint = Paint()
    ..color = Colors.lightBlueAccent
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..strokeCap = StrokeCap.round;

  static final Path _windArrowPath = Path()
    ..moveTo(0, 6)
    ..lineTo(0, -6)
    ..moveTo(-3, -3)
    ..lineTo(0, -6)
    ..lineTo(3, -3);

  static final Paint _pinDarkFillPaint = Paint()
    ..color = const Color(0xFF1A1612)
    ..style = PaintingStyle.fill;

  static final Paint _plannedBadgeBgPaint = Paint()
    ..color = const Color(0xEB181C22)
    ..style = PaintingStyle.fill;

  static final Paint _journalBadgeBgPaint = Paint()
    ..color = const Color(0xF01E1A16)
    ..style = PaintingStyle.fill;

  static final Paint _journalStemPaint = Paint()
    ..color = GoetheanPalette.aspectGold.withValues(alpha: 0.85)
    ..strokeWidth = 1.4
    ..style = PaintingStyle.stroke;

  static final Paint _journalPinStrokePaint = Paint()
    ..color = GoetheanPalette.aspectGold
    ..strokeWidth = 1.2
    ..style = PaintingStyle.stroke;

  static final Paint _journalBadgeStrokePaint = Paint()
    ..color = GoetheanPalette.aspectGold.withValues(alpha: 0.9)
    ..strokeWidth = 1.2
    ..style = PaintingStyle.stroke;

  static final Paint _journalOutcomePaint = Paint()
    ..color = GoetheanPalette.aspectGold;

  static final Paint _specialBorderPaint = Paint()
    ..color = const Color(0xFFFFD700)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;

  static final Paint _prepEveningPaint = Paint()
    ..color = const Color(0xFFD7CCC8);

  static final Paint _prepMorningPaint = Paint()
    ..color = const Color(0xFF80DEEA);

  static final Paint _imageFilterPaint = Paint()
    ..filterQuality = FilterQuality.medium;

  static final Paint _imageFramePaint = Paint()
    ..color = const Color(0x59FFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.75;

  static final Paint _reusableFillPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _reusableStrokePaint = Paint()
    ..style = PaintingStyle.stroke;
  static final Paint _reusableShaderPaint = Paint();
  static final Paint _reusableArcShaderPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4;
  static final Paint _reusableStemGlowPaint = Paint()
    ..strokeWidth = 4.0
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

  static final Path _sharedHillPath = Path();
  static final Path _sharedArcPath = Path();
  static final Path _sharedTempPath = Path();
  static final Path _sharedWindPath = Path();
  static final Path _sharedDiamondPath = Path();

  static String _formatDayLabel(DateTime midnight) {
    final key = midnight.year * 10000 + midnight.month * 100 + midnight.day;
    final existing = _dayLabelCache.remove(key);
    if (existing != null) {
      _dayLabelCache[key] = existing;
      return existing;
    }
    final formatted = _dayLabelFormat.format(midnight);
    if (_dayLabelCache.length >= _maxDayFormatCacheEntries) {
      _dayLabelCache.remove(_dayLabelCache.keys.first);
    }
    _dayLabelCache[key] = formatted;
    return formatted;
  }

  static TextPainter _resolveTextPainter(
    String text,
    TextStyle style, {
    int? maxLines,
  }) {
    final key = (text, style, maxLines);
    final existing = _textPainterCache.remove(key);
    if (existing != null) {
      _textPainterCache[key] = existing;
      return existing;
    }
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: maxLines,
      textDirection: ui.TextDirection.ltr,
    )..layout();
    if (_textPainterCache.length >= _maxTextPainterCacheEntries) {
      _textPainterCache.remove(_textPainterCache.keys.first);
    }
    _textPainterCache[key] = tp;
    return tp;
  }

  static bool _isWeatherSortedAscending(List<WeatherDataPoint> data) {
    for (int i = 1; i < data.length; i++) {
      if (data[i].time.isBefore(data[i - 1].time)) {
        return false;
      }
    }
    return true;
  }

  static (int, int) _visibleWeatherRange(
    List<WeatherDataPoint> data,
    DateTime startTime,
    DateTime endTime,
  ) {
    final len = data.length;
    if (len == 0 || startTime.isAfter(endTime)) return (0, 0);
    if (len <= 8 || !_isWeatherSortedAscending(data)) {
      return (0, len);
    }
    int lo = 0;
    int hi = len;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (data[mid].time.isBefore(startTime)) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    final startIdx = lo;
    hi = len;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (!data[mid].time.isAfter(endTime)) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return (startIdx, lo);
  }

  static (bool, bool) _journalSortOrder(List<FieldJournalEntry> entries) {
    bool asc = true;
    bool desc = true;
    for (int i = 1; i < entries.length; i++) {
      final prev = entries[i - 1].timestamp;
      final curr = entries[i].timestamp;
      if (curr.isBefore(prev)) asc = false;
      if (curr.isAfter(prev)) desc = false;
      if (!asc && !desc) break;
    }
    return (asc, desc);
  }

  static (int, int, bool) _visibleJournalRange(
    List<FieldJournalEntry> entries,
    DateTime minTime,
    DateTime maxTime,
  ) {
    final len = entries.length;
    if (len == 0 || minTime.isAfter(maxTime)) return (0, 0, false);
    if (len <= 8) return (0, len, false);

    final (isAsc, isDesc) = _journalSortOrder(entries);
    if (isAsc) {
      // Ascending order by timestamp
      int lo = 0;
      int hi = len;
      while (lo < hi) {
        final mid = (lo + hi) >> 1;
        if (entries[mid].timestamp.isBefore(minTime)) {
          lo = mid + 1;
        } else {
          hi = mid;
        }
      }
      final startIdx = lo;
      hi = len;
      while (lo < hi) {
        final mid = (lo + hi) >> 1;
        if (!entries[mid].timestamp.isAfter(maxTime)) {
          lo = mid + 1;
        } else {
          hi = mid;
        }
      }
      return (startIdx, lo, true);
    } else if (isDesc) {
      // Descending order by timestamp (newest first, as returned by SQLite store)
      int lo = 0;
      int hi = len;
      while (lo < hi) {
        final mid = (lo + hi) >> 1;
        if (entries[mid].timestamp.isAfter(maxTime)) {
          lo = mid + 1;
        } else {
          hi = mid;
        }
      }
      final startIdx = lo;
      hi = len;
      while (lo < hi) {
        final mid = (lo + hi) >> 1;
        if (!entries[mid].timestamp.isBefore(minTime)) {
          lo = mid + 1;
        } else {
          hi = mid;
        }
      }
      return (startIdx, lo, true);
    }
    return (0, len, false);
  }

  static int _computeIntervalsFingerprint(List<CalendarInterval> list) {
    int hash = list.length;
    for (int i = 0; i < list.length; i++) {
      final item = list[i];
      hash = Object.hash(
        hash,
        item.start.microsecondsSinceEpoch,
        item.end.microsecondsSinceEpoch,
        item.quality.index,
        item.isGrayDay,
        item.isSpecial,
        item.message,
      );
    }
    return hash;
  }

  static int _computeListFingerprint<T>(List<T> list) =>
      Object.hash(list.length, Object.hashAll(list));

  final DateTime centerTime;
  final double hourWidth;
  final List<CalendarInterval> intervals;
  final List<WeatherDataPoint> weatherData;
  final List<FieldJournalEntry> journalEntries;
  final List<QueuedGardenTask> queuedTasks;
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

  final int _intervalsFingerprint;
  final int _weatherFingerprint;
  final int _journalFingerprint;
  final int _queuedTasksFingerprint;

  InfiniteTimelinePainter({
    required this.centerTime,
    required this.hourWidth,
    required this.intervals,
    required this.weatherData,
    required this.ephemeris,
    required this.latitude,
    required this.longitude,
    this.journalEntries = const [],
    this.queuedTasks = const [],
    this.showBiodynamicOverlay = false,
    this.organicFlow = true,
    this.warmPalette = true,
    this.rootImage,
    this.leafImage,
    this.flowerImage,
    this.fruitImage,
    this.noneImage,
    this.grayDayImage,
  }) : _intervalsFingerprint = _computeIntervalsFingerprint(intervals),
       _weatherFingerprint = _computeListFingerprint(weatherData),
       _journalFingerprint = _computeListFingerprint(journalEntries),
       _queuedTasksFingerprint = _computeListFingerprint(queuedTasks);

  /// Returns the horizontal canvas coordinate (`x`) for [timestamp] given [canvasWidth].
  double xForTime(DateTime timestamp, double canvasWidth) {
    if (!canvasWidth.isFinite || !hourWidth.isFinite) return 0.0;
    final centerX = canvasWidth / 2.0;
    final offsetInHours =
        timestamp.difference(centerTime).inMicroseconds / 3600000000.0;
    return centerX + (offsetInHours * hourWidth);
  }

  /// Returns the subset of [journalEntries] whose markers fall within the visible [canvasWidth].
  List<FieldJournalEntry> visibleJournalEntries(double canvasWidth) {
    if (canvasWidth <= 0 ||
        !canvasWidth.isFinite ||
        hourWidth <= 0 ||
        !hourWidth.isFinite ||
        journalEntries.isEmpty) {
      return const [];
    }
    final halfSpanMicros =
        (((canvasWidth / 2.0 + 24.0) / hourWidth) * 3600000000.0).ceil();
    final minTime = centerTime.subtract(
      Duration(microseconds: halfSpanMicros + 1000),
    );
    final maxTime = centerTime.add(
      Duration(microseconds: halfSpanMicros + 1000),
    );
    final (lo, hi, _) = _visibleJournalRange(journalEntries, minTime, maxTime);

    final result = <FieldJournalEntry>[];
    for (int i = lo; i < hi; i++) {
      final entry = journalEntries[i];
      final x = xForTime(entry.timestamp, canvasWidth);
      if (x >= -24.0 && x <= canvasWidth + 24.0) {
        result.add(entry);
      }
    }
    return result;
  }

  /// Returns the subset of time-placed [queuedTasks] (`plannedStartDate != null`)
  /// whose markers fall within the visible [canvasWidth].
  List<QueuedGardenTask> visiblePlannedTasks(double canvasWidth) {
    if (canvasWidth <= 0 ||
        !canvasWidth.isFinite ||
        hourWidth <= 0 ||
        !hourWidth.isFinite ||
        queuedTasks.isEmpty) {
      return const [];
    }
    final result = <QueuedGardenTask>[];
    for (final task in queuedTasks) {
      final start = task.plannedStartDate;
      if (start == null) continue;
      final x = xForTime(start, canvasWidth);
      if (x >= -24.0 && x <= canvasWidth + 24.0) {
        result.add(task);
      }
    }
    return result;
  }

  /// Hit-tests whether [canvasLocalPosition] lands on a visible planned bed task
  /// marker's crown pin (`y ≈ 15`) or planned badge capsule (`y ≈ 132..152`),
  /// returning the matching [QueuedGardenTask] or `null`.
  QueuedGardenTask? hitTestPlannedTask(
    Offset canvasLocalPosition,
    Size canvasSize,
  ) {
    if (queuedTasks.isEmpty ||
        canvasSize.width <= 0 ||
        canvasSize.height <= 0 ||
        !canvasSize.width.isFinite) {
      return null;
    }
    final visible = visiblePlannedTasks(canvasSize.width);
    if (visible.isEmpty) return null;

    final inPinBand =
        canvasLocalPosition.dy >= 4.0 && canvasLocalPosition.dy <= 26.0;
    final inBadgeBand =
        canvasLocalPosition.dy >= 128.0 && canvasLocalPosition.dy <= 156.0;
    if (!inPinBand && !inBadgeBand) return null;

    QueuedGardenTask? best;
    double bestDx = double.infinity;
    final maxHitHalfWidth = hourWidth >= 6.0 ? 38.0 : 18.0;

    for (final task in visible) {
      final x = xForTime(task.plannedStartDate!, canvasSize.width);
      final dx = (canvasLocalPosition.dx - x).abs();
      if (dx <= maxHitHalfWidth && dx < bestDx) {
        bestDx = dx;
        best = task;
      }
    }
    return best;
  }

  /// Hit-tests whether [canvasLocalPosition] lands on a visible journal marker's
  /// crown pin (`y ≈ 15`) or badge capsule (`y ≈ 154..172`), returning the
  /// matching [FieldJournalEntry] or `null`.
  FieldJournalEntry? hitTestJournalEntry(
    Offset canvasLocalPosition,
    Size canvasSize,
  ) {
    if (journalEntries.isEmpty ||
        canvasSize.width <= 0 ||
        canvasSize.height <= 0 ||
        !canvasSize.width.isFinite) {
      return null;
    }
    final visible = visibleJournalEntries(canvasSize.width);
    if (visible.isEmpty) return null;

    final inPinBand =
        canvasLocalPosition.dy >= 4.0 && canvasLocalPosition.dy <= 26.0;
    final inBadgeBand =
        canvasLocalPosition.dy >= 146.0 && canvasLocalPosition.dy <= 178.0;
    if (!inPinBand && !inBadgeBand) return null;

    FieldJournalEntry? best;
    double bestDx = double.infinity;
    final maxHitHalfWidth = hourWidth >= 6.0 ? 38.0 : 18.0;

    for (final entry in visible) {
      final x = xForTime(entry.timestamp, canvasSize.width);
      final dx = (canvasLocalPosition.dx - x).abs();
      if (dx <= maxHitHalfWidth && dx < bestDx) {
        bestDx = dx;
        best = entry;
      }
    }
    return best;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 ||
        size.height <= 0 ||
        !size.width.isFinite ||
        !size.height.isFinite ||
        hourWidth <= 0 ||
        !hourWidth.isFinite) {
      return;
    }
    final centerX = size.width / 2;

    final visibleHours = size.width / hourWidth;
    final halfWindowHours = (visibleHours / 2).ceil() + 24;
    final startTime = centerTime.subtract(Duration(hours: halfWindowHours));
    final endTime = centerTime.add(Duration(hours: halfWindowHours));

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
    canvas.drawRRect(
      stripRRect,
      warmPalette || organicFlow ? _nightWarmPaint : _nightCoolPaint,
    );

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
    final dailySunTimes = <SunriseSunsetInfo>[];

    final organicHillColors = <Color>[
      const Color(0xF2FFF176),
      const Color(0xC7E5A93C),
      GoetheanPalette.rootEarth.withValues(alpha: 0.35),
    ];
    const organicArcColors = <Color>[
      Color(0x33E5A93C),
      Color(0xFFFFF9C4),
      Color(0x33E5A93C),
    ];

    for (
      var d = rangeStartDate;
      d.isBefore(rangeEndDate);
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      final ss = ephemeris.getSunriseSunset(d, latitude, longitude);
      dailySunTimes.add(ss);

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
              final hillPath = _sharedHillPath..reset();
              final arcPath = _sharedArcPath..reset();
              final stripBottom = stripY + stripHeight;
              final hillAmp = stripHeight - 1.5;
              final arcBase = stripBottom - 0.5;
              final arcAmp = stripHeight - 2.2;

              hillPath.moveTo(startX, stripBottom);
              const steps = 20;
              for (int s = 0; s <= steps; s++) {
                final u = s / steps;
                final px = startX + u * dayWidth;
                final sinElev = _solarSinTable[s];
                hillPath.lineTo(px, stripBottom - (sinElev * hillAmp));
                final arcPy = arcBase - (sinElev * arcAmp);
                if (s == 0) {
                  arcPath.moveTo(px, arcPy);
                } else {
                  arcPath.lineTo(px, arcPy);
                }
              }
              hillPath.lineTo(endX, stripBottom);
              hillPath.close();

              canvas.drawPath(
                hillPath,
                _reusableShaderPaint
                  ..shader = ui.Gradient.linear(
                    Offset(xNoon, stripY),
                    Offset(xNoon, stripBottom),
                    organicHillColors,
                    const [0.0, 0.65, 1.0],
                  ),
              );
              // Golden solar trajectory crest line
              canvas.drawPath(
                arcPath,
                _reusableArcShaderPaint
                  ..shader = ui.Gradient.linear(
                    Offset(startX, stripY),
                    Offset(endX, stripY),
                    organicArcColors,
                    const [0.0, 0.5, 1.0],
                  ),
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
                _reusableShaderPaint..shader = dayShader,
              );
            }
          }
        }
      }
    }
    canvas.restore();

    // 3. Draw sun/moon icons smoothly fading in from hourWidth >= 3.5
    if (iconAlpha > 0) {
      for (final ss in dailySunTimes) {
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

    final dayLoopEnd = endTime.add(const Duration(days: 1));

    // Draw daily midnight lines and date headers immune to DST drift
    for (
      var d = DateTime(startTime.year, startTime.month, startTime.day);
      d.isBefore(dayLoopEnd);
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      final midnight = DateTime(d.year, d.month, d.day);
      final offsetInHours = midnight.difference(centerTime).inSeconds / 3600.0;
      final x = centerX + (offsetInHours * hourWidth);

      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        _tickPaint..color = Colors.white24,
      );

      final totalDaysFromEpoch = DateTime.utc(
        d.year,
        d.month,
        d.day,
      ).difference(_epoch2000Utc).inDays;
      final mod =
          (totalDaysFromEpoch % dateLabelFrequencyInDays +
              dateLabelFrequencyInDays) %
          dateLabelFrequencyInDays;
      if (mod == 0) {
        final datePainter = _resolveTextPainter(
          _formatDayLabel(midnight),
          _dateHeaderStyle,
        );
        datePainter.paint(canvas, Offset(x + 5, size.height - 18));
      }
    }

    // Draw sub-daily tick marks and hour labels
    if (showHourLabels || tickFrequency < 24) {
      for (
        var d = DateTime(startTime.year, startTime.month, startTime.day);
        d.isBefore(dayLoopEnd);
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
              _tickPaint..color = Colors.white54,
            );
            if (showHourLabels) {
              final hourPainter = _resolveTextPainter(
                _hourLabelStrings[h],
                _hourLabelStyle,
              );
              hourPainter.paint(canvas, Offset(x - hourPainter.width / 2, 50));
            }
          } else {
            canvas.drawLine(
              Offset(x, 32),
              Offset(x, 42),
              _tickPaint..color = Colors.white24,
            );
          }
        }
      }
    }

    _paintIntervalsWithTransitions(canvas, size, startTime, endTime, centerX);

    const tempRowY = 65.0;
    const tempRowHeight = 50.0;
    const windRowY = 115.0;
    const windRowHeight = 50.0;

    canvas.drawRect(
      Rect.fromLTWH(0, tempRowY, size.width, tempRowHeight),
      _tempBgPaint,
    );

    canvas.drawRect(
      Rect.fromLTWH(0, windRowY, size.width, windRowHeight),
      _windBgPaint,
    );

    if (weatherData.isNotEmpty) {
      final (weatherStartIdx, weatherEndIdx) = _visibleWeatherRange(
        weatherData,
        startTime,
        endTime,
      );

      final tempPath = _sharedTempPath..reset();
      final windPath = _sharedWindPath..reset();
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

      for (int i = weatherStartIdx; i < weatherEndIdx; i++) {
        final wd = weatherData[i];
        if (wd.time.isBefore(startTime) || wd.time.isAfter(endTime)) {
          continue;
        }
        final offsetInHours = wd.time.difference(centerTime).inSeconds / 3600.0;
        final x = centerX + (offsetInHours * hourWidth);
        final temp = wd.temperature;
        if (temp != null && temp.isFinite) {
          final yTemp = mapTempToY(temp);
          if (firstTemp) {
            tempPath.moveTo(x, yTemp);
            firstTemp = false;
          } else {
            tempPath.lineTo(x, yTemp);
          }
        }

        if (wd.precipitation.isFinite && wd.precipitation > 0) {
          final barHeight = (wd.precipitation * 8.0).clamp(3.0, 40.0);
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
            _precipBarPaint,
          );
        }

        if (wd.windSpeed.isFinite) {
          final yWind = mapWindToY(wd.windSpeed);
          if (firstWind) {
            windPath.moveTo(x, yWind);
            firstWind = false;
          } else {
            windPath.lineTo(x, yWind);
          }
        }
      }

      canvas.drawPath(tempPath, _tempLinePaint);
      canvas.drawPath(windPath, _windLinePaint);

      for (int i = weatherStartIdx; i < weatherEndIdx; i++) {
        final wd = weatherData[i];
        if (wd.time.isBefore(startTime) || wd.time.isAfter(endTime)) {
          continue;
        }
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
          final hasValidTemp = temp != null && temp.isFinite;
          final yTemp = hasValidTemp
              ? mapTempToY(temp)
              : tempRowY + tempRowHeight / 2;
          if (hasValidTemp) {
            _drawText(canvas, x, '${temp.round()}°', 10, yTemp - 12);
          }

          if (wd.cloudCover.isFinite && wd.cloudCover > 30) {
            _drawIcon(canvas, x, '☁️', 12, yTemp + 5);
          }

          if (wd.precipitation.isFinite && wd.precipitation > 0) {
            _drawText(
              canvas,
              x,
              '${wd.precipitation.toStringAsFixed(1)}mm',
              8,
              yTemp + 15,
            );
          }

          if (wd.windSpeed.isFinite) {
            final yWind = mapWindToY(wd.windSpeed);
            _drawText(canvas, x, '${wd.windSpeed.round()}m/s', 10, yWind - 12);
            if (wd.windDirection.isFinite) {
              _drawWindArrow(canvas, x, yWind + 10, wd.windDirection);
            }
          }
        }
      }
    }

    final now = DateTime.now();
    final nowOffsetInHours = now.difference(centerTime).inSeconds / 3600.0;
    final nowX = centerX + (nowOffsetInHours * hourWidth);

    if (nowX >= 0 && nowX <= size.width) {
      canvas.drawLine(
        Offset(nowX, 0),
        Offset(nowX, size.height),
        _nowLinePaint,
      );
      canvas.drawLine(
        Offset(nowX, 0),
        Offset(nowX, size.height),
        _nowGlowPaint,
      );
    }

    _paintPlannedTaskMarkers(canvas, size, startTime, endTime, centerX);
    _paintJournalMarkers(canvas, size, startTime, endTime, centerX);
  }

  void _paintPlannedTaskMarkers(
    Canvas canvas,
    Size size,
    DateTime startTime,
    DateTime endTime,
    double centerX,
  ) {
    if (queuedTasks.isEmpty) return;

    final showCompactLabel = hourWidth >= 5.0;

    for (final task in queuedTasks) {
      final start = task.plannedStartDate;
      if (start == null) continue;
      if (start.isBefore(startTime) || start.isAfter(endTime)) continue;

      final offsetInHours =
          start.difference(centerTime).inMicroseconds / 3600000000.0;
      final x = centerX + (offsetInHours * hourWidth);
      if (x < -28.0 || x > size.width + 28.0) continue;

      final markerColor = _getColorForQuality(task.targetQuality);

      // 1. Dashed vertical stem from cosmic quality bar (y = 22) to planned row (y = 140)
      final dashPaint = _reusableStrokePaint
        ..color = markerColor.withValues(alpha: 0.78)
        ..strokeWidth = 1.3;
      for (double y = 22.0; y < 138.0; y += 6.0) {
        canvas.drawLine(
          Offset(x, y),
          Offset(x, math.min(y + 3.5, 138.0)),
          dashPaint,
        );
      }

      // 2. Diamond crown pin on the cosmic quality bar (y = 15)
      final diamond = _sharedDiamondPath
        ..reset()
        ..moveTo(x, 10.5)
        ..lineTo(x + 4.5, 15.0)
        ..lineTo(x, 19.5)
        ..lineTo(x - 4.5, 15.0)
        ..close();
      canvas.drawPath(diamond, _pinDarkFillPaint);
      canvas.drawPath(
        diamond,
        _reusableStrokePaint
          ..color = markerColor
          ..strokeWidth = 1.5,
      );

      // 3. Planned task badge capsule at y = 133..151
      final bedSuffix = task.bedName != null ? ' · ${task.bedName}' : '';
      final badgeText = showCompactLabel
          ? '📅 ${task.targetLabel}$bedSuffix'
          : '📅';
      final tp = _resolveTextPainter(
        badgeText,
        _plannedBadgeTextStyle,
        maxLines: 1,
      );

      final padH = showCompactLabel ? 6.0 : 4.0;
      final badgeWidth = math.max(18.0, tp.width + padH * 2);
      const badgeHeight = 18.0;
      const badgeY = 133.0;
      final badgeRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x - badgeWidth / 2, badgeY, badgeWidth, badgeHeight),
        const Radius.circular(6.0),
      );

      canvas.drawRRect(badgeRect, _plannedBadgeBgPaint);
      canvas.drawRRect(
        badgeRect,
        _reusableFillPaint..color = markerColor.withValues(alpha: 0.24),
      );
      canvas.drawRRect(
        badgeRect,
        _reusableStrokePaint
          ..color = markerColor.withValues(alpha: 0.85)
          ..strokeWidth = 1.2,
      );

      tp.paint(
        canvas,
        Offset(x - tp.width / 2, badgeY + (badgeHeight - tp.height) / 2),
      );
    }
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
    final (lo, hi, _) = _visibleJournalRange(
      journalEntries,
      startTime,
      endTime,
    );

    for (int i = lo; i < hi; i++) {
      final entry = journalEntries[i];
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
      canvas.drawLine(
        Offset(x, 22.0),
        Offset(x, 162.0),
        _reusableStemGlowPaint..color = markerColor.withValues(alpha: 0.28),
      );
      canvas.drawLine(Offset(x, 22.0), Offset(x, 162.0), _journalStemPaint);

      // 2. Crown node pin on the cosmic quality bar (y = 15)
      final pinCenter = Offset(x, 15.0);
      canvas.drawCircle(pinCenter, 4.2, _pinDarkFillPaint);
      canvas.drawCircle(
        pinCenter,
        3.2,
        _reusableFillPaint..color = markerColor,
      );
      canvas.drawCircle(pinCenter, 4.2, _journalPinStrokePaint);

      // 3. Journal badge capsule at y = 154..172
      final badgeText = showCompactLabel
          ? '${entry.timelineMarkerGlyph} ${entry.timelineMarkerLabel}'
          : entry.timelineMarkerGlyph;
      final tp = _resolveTextPainter(
        badgeText,
        _journalBadgeTextStyle,
        maxLines: 1,
      );

      final padH = showCompactLabel ? 6.0 : 4.0;
      final badgeWidth = math.max(18.0, tp.width + padH * 2);
      const badgeHeight = 18.0;
      const badgeY = 154.0;
      final badgeRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x - badgeWidth / 2, badgeY, badgeWidth, badgeHeight),
        const Radius.circular(9.0),
      );

      canvas.drawRRect(badgeRect, _journalBadgeBgPaint);
      canvas.drawRRect(
        badgeRect,
        _reusableFillPaint..color = markerColor.withValues(alpha: 0.28),
      );
      canvas.drawRRect(badgeRect, _journalBadgeStrokePaint);

      tp.paint(
        canvas,
        Offset(x - tp.width / 2, badgeY + (badgeHeight - tp.height) / 2),
      );

      if (entry.hasOutcome) {
        canvas.drawCircle(
          Offset(x + badgeWidth / 2 - 2.0, badgeY + 2.0),
          3.0,
          _journalOutcomePaint,
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
    final style = fontSize == 10
        ? _weatherTextStyle10
        : (fontSize == 8
              ? _weatherTextStyle8
              : TextStyle(
                  fontFamily: 'Outfit',
                  color: Colors.white70,
                  fontSize: fontSize,
                ));
    final tp = _resolveTextPainter(text, style);
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
    final quantizedAlpha = (opacity.clamp(0.0, 1.0) * 20.0).round() / 20.0;
    final style = TextStyle(
      fontSize: fontSize,
      color: Colors.white.withValues(alpha: quantizedAlpha),
      fontFamilyFallback: _emojiFallback,
    );
    final tp = _resolveTextPainter(icon, style);
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
    canvas.drawPath(_windArrowPath, _windArrowPaint);
    canvas.restore();
  }

  void _paintIntervalsWithTransitions(
    Canvas canvas,
    Size size,
    DateTime startTime,
    DateTime endTime,
    double centerX,
  ) {
    final totalLen = intervals.length;
    if (totalLen == 0) return;

    int startIdx = 0;
    int endIdx = totalLen;
    var isSorted =
        totalLen < 2 || !intervals.first.start.isAfter(intervals.last.start);
    if (isSorted && totalLen > 8) {
      for (int i = 1; i < totalLen; i++) {
        if (intervals[i].start.isBefore(intervals[i - 1].start)) {
          isSorted = false;
          break;
        }
      }
    }
    if (isSorted && totalLen > 8) {
      int lo = 0;
      int hi = totalLen;
      while (lo < hi) {
        final mid = (lo + hi) >> 1;
        if (intervals[mid].end.isBefore(startTime)) {
          lo = mid + 1;
        } else {
          hi = mid;
        }
      }
      // Include one neighboring interval before startTime so boundary transition
      // blends across startTime are not clipped.
      startIdx = lo > 0 ? lo - 1 : 0;
      hi = totalLen;
      while (lo < hi) {
        final mid = (lo + hi) >> 1;
        if (!intervals[mid].start.isAfter(endTime)) {
          lo = mid + 1;
        } else {
          hi = mid;
        }
      }
      // Include one neighboring interval after endTime so boundary transition
      // blends across endTime are not clipped.
      endIdx = lo < totalLen ? lo + 1 : totalLen;
    }

    final maxBlendHours = organicFlow ? math.max(5.0, 18.0 / hourWidth) : 1.5;
    final blendMargin = Duration(seconds: (maxBlendHours * 3600).ceil() + 120);
    final paddedStart = startTime.subtract(blendMargin);
    final paddedEnd = endTime.add(blendMargin);

    final visibleIntervals = <CalendarInterval>[];
    for (int i = startIdx; i < endIdx; i++) {
      final interval = intervals[i];
      if (interval.end.isBefore(paddedStart) ||
          interval.start.isAfter(paddedEnd)) {
        continue;
      }
      visibleIntervals.add(interval);
    }

    final count = visibleIntervals.length;
    if (count == 0) return;

    final maxHalfBlendPx = organicFlow
        ? math.max(18.0, 5.0 * hourWidth)
        : (1.5 / 2.0) * hourWidth; // ~0.75 hours in pixels
    final xStarts = Float64List(count);
    final xEnds = Float64List(count);
    final colors = List<Color>.filled(count, Colors.transparent);

    final grayColor = Colors.grey[400]!.withValues(alpha: 0.8);

    for (int i = 0; i < count; i++) {
      final interval = visibleIntervals[i];
      final startOffsetInHours =
          interval.start.difference(centerTime).inSeconds / 3600.0;
      final endOffsetInHours =
          interval.end.difference(centerTime).inSeconds / 3600.0;
      xStarts[i] = centerX + (startOffsetInHours * hourWidth);
      xEnds[i] = centerX + (endOffsetInHours * hourWidth);

      if (interval.isGrayDay) {
        colors[i] = grayColor;
      } else if (interval.quality != PlantQuality.none) {
        colors[i] = _getColorForQuality(interval.quality)
            .withValues(alpha: 0.8);
      } else {
        colors[i] = Colors.transparent;
      }
    }

    final leftOffsets = Float64List(count);
    final rightOffsets = Float64List(count);

    for (int i = 0; i < count - 1; i++) {
      final curr = visibleIntervals[i];
      final next = visibleIntervals[i + 1];
      final touches = next.start.difference(curr.end).inSeconds.abs() <= 120;
      if (touches) {
        final hasTransition = colors[i] != colors[i + 1];
        if (hasTransition) {
          final currWidth = math.max(0.0, xEnds[i] - xStarts[i]);
          final nextWidth = math.max(0.0, xEnds[i + 1] - xStarts[i + 1]);
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
        final currWidth = math.max(0.0, xEnds[i] - xStarts[i]);
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
        final paint = _reusableFillPaint..color = color;

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
          canvas.drawRect(
            rect,
            _reusableShaderPaint
              ..shader = ui.Gradient.linear(
                Offset(blendStart, 0),
                Offset(blendEnd, 0),
                [colors[i], colors[i + 1]],
                const [0.0, 1.0],
              ),
          );
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
          canvas.drawRect(
            rect,
            _reusableShaderPaint
              ..shader = ui.Gradient.linear(
                Offset(xStarts[i], 0),
                Offset(xStarts[i] + leftOffsets[i], 0),
                [colors[i].withValues(alpha: 0.0), colors[i]],
                const [0.0, 1.0],
              ),
          );
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
          canvas.drawRect(
            rect,
            _reusableShaderPaint
              ..shader = ui.Gradient.linear(
                Offset(exitStart, 0),
                Offset(xEnds[i], 0),
                [colors[i], colors[i].withValues(alpha: 0.0)],
                const [0.0, 1.0],
              ),
          );
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
    if (width <= 0 || !width.isFinite) return;
    final rect = Rect.fromLTWH(x, 5, width, 20);

    if (isSpecial) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        _specialBorderPaint,
      );
    }

    if (showBiodynamicOverlay) {
      final prepStripRect = Rect.fromLTWH(x, 2, width, 3);
      final isEvening =
          label != 'gray' && (quality == PlantQuality.root || label == 'root');
      final isMorning =
          label != 'gray' &&
          (quality == PlantQuality.flower || quality == PlantQuality.fruit);

      if (isEvening) {
        canvas.drawRect(prepStripRect, _prepEveningPaint);
      } else if (isMorning) {
        canvas.drawRect(prepStripRect, _prepMorningPaint);
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
          case PlantQuality.leaf:
            image = leafImage;
          case PlantQuality.flower:
            image = flowerImage;
          case PlantQuality.fruit:
            image = fruitImage;
          case PlantQuality.none:
            image = noneImage;
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
        canvas.drawImageRect(image, src, dst, _imageFilterPaint);
        canvas.drawRRect(
          RRect.fromRectAndRadius(dst, const Radius.circular(2)),
          _imageFramePaint,
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
  bool shouldRepaint(covariant InfiniteTimelinePainter oldDelegate) {
    return oldDelegate.centerTime != centerTime ||
        oldDelegate.hourWidth != hourWidth ||
        oldDelegate.latitude != latitude ||
        oldDelegate.longitude != longitude ||
        oldDelegate.ephemeris != ephemeris ||
        oldDelegate.showBiodynamicOverlay != showBiodynamicOverlay ||
        oldDelegate.organicFlow != organicFlow ||
        oldDelegate.warmPalette != warmPalette ||
        oldDelegate.rootImage != rootImage ||
        oldDelegate.leafImage != leafImage ||
        oldDelegate.flowerImage != flowerImage ||
        oldDelegate.fruitImage != fruitImage ||
        oldDelegate.noneImage != noneImage ||
        oldDelegate.grayDayImage != grayDayImage ||
        !identical(oldDelegate.intervals, intervals) ||
        oldDelegate._intervalsFingerprint != _intervalsFingerprint ||
        !identical(oldDelegate.weatherData, weatherData) ||
        oldDelegate._weatherFingerprint != _weatherFingerprint ||
        !identical(oldDelegate.journalEntries, journalEntries) ||
        oldDelegate._journalFingerprint != _journalFingerprint ||
        !identical(oldDelegate.queuedTasks, queuedTasks) ||
        oldDelegate._queuedTasksFingerprint != _queuedTasksFingerprint;
  }
}
