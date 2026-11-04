import 'dart:convert';

import 'biodynamic_prep.dart';
import 'models/models.dart';
import 'task_window_planner.dart';
import 'vegetable_database.dart';

/// Display alarm (`VALARM`) attached to a [CalendarExportEvent] in an RFC 5545
/// `.ics` calendar stream.
final class CalendarExportAlarm {
  /// Lead duration before the event's start time when the alarm triggers.
  final Duration triggerBefore;

  /// Human-readable reminder text shown by the calendar client.
  final String description;

  /// Creates an immutable [CalendarExportAlarm].
  ///
  /// The [triggerBefore] duration must be non-negative, and [description] must
  /// not be empty.
  CalendarExportAlarm({
    required this.triggerBefore,
    required this.description,
  }) {
    if (triggerBefore.isNegative) {
      throw ArgumentError.value(
        triggerBefore,
        'triggerBefore',
        'Must be non-negative',
      );
    }
    if (description.trim().isEmpty) {
      throw ArgumentError.value(
        description,
        'description',
        'Must not be empty',
      );
    }
  }
}

/// A biodynamic gardening, orchard, or preparation event ready for RFC 5545
/// `.ics` calendar export.
final class CalendarExportEvent {
  /// Globally unique event identifier (`UID`).
  final String uid;

  /// Short calendar event title (`SUMMARY`).
  final String summary;

  /// Detailed multi-line event notes (`DESCRIPTION`).
  final String description;

  /// Event start timestamp (`DTSTART`).
  final DateTime start;

  /// Event end timestamp (`DTEND`).
  final DateTime end;

  /// Optional geographic coordinates or location label (`LOCATION`).
  final String? location;

  /// Category tags attached to the event (`CATEGORIES`).
  final List<String> categories;

  /// Alarms attached to the main event (`VALARM`).
  final List<CalendarExportAlarm> alarms;

  /// Optional stirring start timestamp preceding a preparation spray window.
  ///
  /// For BD 500 Horn Manure and BD 501 Horn Silica, this begins 1 hour before
  /// [start]; for CPP and BD 508, 20 minutes before [start].
  final DateTime? stirringStart;

  /// Optional stirring duration preceding [start].
  final Duration? stirringDuration;

  /// Optional title for the companion stirring `VEVENT`.
  final String? stirringSummary;

  /// Optional detailed instructions for the companion stirring `VEVENT`.
  final String? stirringDescription;

  /// Creates an immutable [CalendarExportEvent].
  ///
  /// The [uid] and [summary] must not be empty, and [end] must be after
  /// [start]. When [stirringStart] or [stirringDuration] is provided,
  /// [stirringDuration] must be positive.
  CalendarExportEvent({
    required this.uid,
    required this.summary,
    required this.description,
    required this.start,
    required this.end,
    this.location,
    List<String> categories = const <String>[],
    List<CalendarExportAlarm> alarms = const <CalendarExportAlarm>[],
    this.stirringStart,
    this.stirringDuration,
    this.stirringSummary,
    this.stirringDescription,
  }) : categories = List.unmodifiable(categories),
       alarms = List.unmodifiable(alarms) {
    if (uid.trim().isEmpty) {
      throw ArgumentError.value(uid, 'uid', 'Must not be empty');
    }
    if (summary.trim().isEmpty) {
      throw ArgumentError.value(summary, 'summary', 'Must not be empty');
    }
    if (!end.isAfter(start)) {
      throw ArgumentError.value(end, 'end', 'Must be after start');
    }
    if ((stirringStart != null) != (stirringDuration != null)) {
      throw ArgumentError.value(
        stirringDuration,
        'stirringDuration',
        'Must be provided together with stirringStart',
      );
    }
    if (stirringDuration != null && stirringDuration! <= Duration.zero) {
      throw ArgumentError.value(
        stirringDuration,
        'stirringDuration',
        'Must be positive when provided',
      );
    }
  }

  /// Total duration of the main event from [start] to [end].
  Duration get duration => end.difference(start);

  /// Whether this event includes a pre-spray dynamization stirring window.
  bool get hasStirringWindow =>
      stirringStart != null &&
      stirringDuration != null &&
      stirringDuration! > Duration.zero;

  /// End timestamp of the pre-spray stirring window, if present.
  DateTime? get stirringEnd =>
      hasStirringWindow ? stirringStart!.add(stirringDuration!) : null;

  /// Suggested `.ics` filename derived from [summary] and [start].
  String get suggestedFileName {
    final normalized = summary
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final slug = normalized.isEmpty ? 'biodynamic-window' : normalized;
    final truncatedSlug = slug.length > 42 ? slug.substring(0, 42) : slug;
    final year = start.year.toString().padLeft(4, '0');
    final month = start.month.toString().padLeft(2, '0');
    final day = start.day.toString().padLeft(2, '0');
    return '$truncatedSlug-$year-$month-$day.ics';
  }
}

/// Pure-Dart RFC 5545 iCalendar (`.ics`) builder for Maria Thun task windows,
/// biodynamic preparation sprays (with 1-hour stirring lead windows), and
/// 7-day synthesis digests.
abstract final class IcsCalendarExporter {
  /// Product identifier written to the `VCALENDAR` header.
  static const String prodId =
      '-//Magic Calendar//Maria Thun Biodynamic Calendar//EN';

  /// Formats a single [event] as an RFC 5545 `.ics` string.
  static String formatEvent(
    CalendarExportEvent event, {
    DateTime? timestamp,
    bool includeStirringEvent = true,
  }) {
    return formatCalendar(
      <CalendarExportEvent>[event],
      timestamp: timestamp,
      includeStirringEvents: includeStirringEvent,
    );
  }

  /// Formats [events] into a complete RFC 5545 `VCALENDAR` payload with CRLF
  /// line endings and 75-octet line folding.
  ///
  /// The [events] list must not be empty.
  static String formatCalendar(
    List<CalendarExportEvent> events, {
    DateTime? timestamp,
    String calendarName = 'Magic Calendar — Biodynamic Windows',
    bool includeStirringEvents = true,
  }) {
    if (events.isEmpty) {
      throw ArgumentError.value(events, 'events', 'Must not be empty');
    }

    final dtStamp = (timestamp ?? DateTime.now()).toUtc();
    final lines = <String>[
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:$prodId',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
      'X-WR-CALNAME:${_escapeText(calendarName)}',
    ];

    for (final event in events) {
      if (includeStirringEvents && event.hasStirringWindow) {
        _appendStirringVEvent(lines, event, dtStamp: dtStamp);
      }
      _appendMainVEvent(lines, event, dtStamp: dtStamp);
    }

    lines.add('END:VCALENDAR');
    return '${lines.map(_foldContentLine).join('\r\n')}\r\n';
  }

  /// Creates a [CalendarExportEvent] for a [TaskWindow] found by
  /// [TaskWindowPlanner].
  ///
  /// Schedules a focused 2-hour working block at [TaskWindow.peakTime]
  /// (clamped within `[window.start, window.end]`) while recording the full
  /// sidereal constellation span and weather/climate notes in the description.
  static CalendarExportEvent fromTaskWindow({
    required TaskWindow window,
    required TaskActionType action,
    VegetableEntry? crop,
    CropTaskSchedule? organRule,
    double? latitude,
    double? longitude,
  }) {
    if (!window.end.isAfter(window.start)) {
      throw ArgumentError.value(
        window.end,
        'window.end',
        'Must be after window.start',
      );
    }

    final targetLabel = crop != null
        ? (organRule != null
              ? '${crop.localizedDisplayName} (${organRule.localizedLabel})'
              : crop.localizedDisplayName)
        : '${window.quality.displayName} Plants';
    final summary =
        '${action.displayName}: $targetLabel (${window.quality.displayName} Day)';

    DateTime blockStart = window.peakTime;
    if (blockStart.isBefore(window.start)) {
      blockStart = window.start;
    } else if (!blockStart.isBefore(window.end)) {
      final latestStart = window.end.subtract(const Duration(hours: 2));
      blockStart = latestStart.isAfter(window.start)
          ? latestStart
          : window.start;
    }
    DateTime blockEnd = blockStart.add(const Duration(hours: 2));
    if (blockEnd.isAfter(window.end)) {
      blockEnd = window.end;
    }
    if (!blockEnd.isAfter(blockStart)) {
      blockStart = window.start;
      blockEnd = window.end;
    }

    final descriptionLines = <String>[
      'Maria Thun Biodynamic Task Window — ${window.suitability == TaskSuitability.optimal ? "OPTIMAL" : "FAVORABLE"}',
      'Action: ${action.displayName} (${action.danishName})',
      'Target: $targetLabel',
      'Cosmic Window: ${_formatReadableRange(window.start, window.end)}',
      'Recommended Peak Time: ${_formatReadableDateTime(window.peakTime)}',
      'Factors: ${window.headline}',
      '',
      window.cosmicExplanation,
      if (window.weatherNote != null) ...<String>[
        '',
        'Weather Synthesis: ${window.weatherNote}',
      ],
      if (window.climateNote != null) ...<String>[
        '',
        'Climatology Note: ${window.climateNote}',
      ],
    ];

    final uid =
        'task-${action.name}-${crop?.id ?? window.quality.name}-'
        '${blockStart.toUtc().millisecondsSinceEpoch}@magic-calendar';

    return CalendarExportEvent(
      uid: uid,
      summary: summary,
      description: descriptionLines.join('\n'),
      start: blockStart,
      end: blockEnd,
      location: _formatCoordinates(latitude, longitude),
      categories: <String>[
        'Biodynamic',
        action.displayName,
        '${window.quality.displayName} Day',
        if (window.isDescending) 'Pflanzzeit',
      ],
      alarms: <CalendarExportAlarm>[
        CalendarExportAlarm(
          triggerBefore: const Duration(minutes: 30),
          description: 'Upcoming biodynamic window: $summary',
        ),
      ],
    );
  }

  /// Creates a [CalendarExportEvent] for a biodynamic field preparation spray
  /// window (`BD 500`, `BD 501`, `CPP`, or `BD 508`), automatically attaching
  /// the pre-spray dynamization stirring start time (`1 hour` before spray for
  /// BD 500/501, `20 minutes` before spray for CPP/BD 508).
  ///
  /// The [sprayEnd] must be after [sprayStart].
  static CalendarExportEvent fromBiodynamicSpray({
    required BiodynamicPrepType preparation,
    required DateTime sprayStart,
    required DateTime sprayEnd,
    required CalendarInfo calendarInfo,
    String? weatherSummary,
    double? latitude,
    double? longitude,
  }) {
    if (!sprayEnd.isAfter(sprayStart)) {
      throw ArgumentError.value(
        sprayEnd,
        'sprayEnd',
        'Must be after sprayStart',
      );
    }

    final stirringMinutes = preparation.stirringMinutes > 0
        ? preparation.stirringMinutes
        : 60;
    final stirringDuration = Duration(minutes: stirringMinutes);
    final stirringStart = sprayStart.subtract(stirringDuration);

    final breathLabel =
        preparation == BiodynamicPrepType.bd501 ||
            preparation == BiodynamicPrepType.bd508
        ? 'Morning Exhalation'
        : 'Earth Inhalation';
    final moonArcLabel = calendarInfo.isMoonDescending
        ? 'Descending Moon (Pflanzzeit)'
        : 'Ascending Moon';

    final stirringTimeRange =
        '${_formatHourMinute(stirringStart)}–${_formatHourMinute(sprayStart)}';
    final sprayTimeRange =
        '${_formatHourMinute(sprayStart)}–${_formatHourMinute(sprayEnd)}';

    final summary =
        'Spray ${preparation.code} ${preparation.commonName} ($breathLabel)';
    final stirringSummary =
        'Stir ${preparation.code} ${preparation.commonName} (${stirringMinutes}m Dynamization)';

    final stirringDescription = <String>[
      'Begin dynamizing ${preparation.code} (${preparation.commonName}) in warmed rainwater ($stirringTimeRange) immediately before the $sprayTimeRange spray window.',
      if (preparation == BiodynamicPrepType.bd500 ||
          preparation == BiodynamicPrepType.bd501)
        'Stir rhythmically for 1 full hour: form a deep vortex in one direction, then reverse abruptly into creative chaos before building a vortex in the opposite direction.'
      else
        'Stir rhythmically for $stirringMinutes minutes with alternating vortices and chaos reversals.',
      'Cosmic Context: ${calendarInfo.quality.displayName} Day • $moonArcLabel',
      if (weatherSummary != null) 'Forecast Weather: $weatherSummary',
    ].join('\n');

    final description = <String>[
      'Biodynamic Field Spray Window — ${preparation.code} (${preparation.commonName})',
      '1. Stirring Start ($stirringMinutes min): ${_formatReadableDateTime(stirringStart)} → ${_formatHourMinute(sprayStart)}',
      '2. Spray Application: ${_formatReadableDateTime(sprayStart)} → ${_formatHourMinute(sprayEnd)}',
      'Cosmic Rhythm: ${calendarInfo.quality.displayName} Day • $moonArcLabel • $breathLabel',
      '',
      preparation.description,
      if (weatherSummary != null) ...<String>[
        '',
        'Weather Synthesis: $weatherSummary',
      ],
    ].join('\n');

    final uid =
        'prep-${preparation.name}-${sprayStart.toUtc().millisecondsSinceEpoch}@magic-calendar';

    return CalendarExportEvent(
      uid: uid,
      summary: summary,
      description: description,
      start: sprayStart,
      end: sprayEnd,
      location: _formatCoordinates(latitude, longitude),
      categories: <String>[
        'Biodynamic',
        preparation.code,
        '${calendarInfo.quality.displayName} Day',
        breathLabel,
      ],
      alarms: <CalendarExportAlarm>[
        CalendarExportAlarm(
          triggerBefore: stirringDuration,
          description:
              'Begin $stirringMinutes-minute stirring for ${preparation.code} ${preparation.commonName} now (spray starts at ${_formatHourMinute(sprayStart)})',
        ),
        CalendarExportAlarm(
          triggerBefore: const Duration(minutes: 10),
          description:
              'Finish stirring and prepare sprayer for ${preparation.code} ${preparation.commonName}',
        ),
      ],
      stirringStart: stirringStart,
      stirringDuration: stirringDuration,
      stirringSummary: stirringSummary,
      stirringDescription: stirringDescription,
    );
  }

  static void _appendStirringVEvent(
    List<String> lines,
    CalendarExportEvent event, {
    required DateTime dtStamp,
  }) {
    final stirStart = event.stirringStart!;
    final stirEnd = event.stirringEnd!;
    final stirMinutes = event.stirringDuration!.inMinutes;
    final stirTitle =
        event.stirringSummary ??
        'Stir Preparation ($stirMinutes min Dynamization) before ${event.summary}';
    final stirBody =
        event.stirringDescription ??
        'Dynamize preparation for $stirMinutes minutes prior to ${event.summary}.';

    lines.addAll(<String>[
      'BEGIN:VEVENT',
      'UID:stir-${event.uid}',
      'DTSTAMP:${_formatIcsUtcDateTime(dtStamp)}',
      'DTSTART:${_formatIcsDateTime(stirStart)}',
      'DTEND:${_formatIcsDateTime(stirEnd)}',
      'SUMMARY:${_escapeText(stirTitle)}',
      'DESCRIPTION:${_escapeText(stirBody)}',
      if (event.location != null && event.location!.trim().isNotEmpty)
        'LOCATION:${_escapeText(event.location!)}',
      'CATEGORIES:Biodynamic,Stirring,Dynamization',
      'BEGIN:VALARM',
      'ACTION:DISPLAY',
      'TRIGGER:-PT10M',
      'DESCRIPTION:${_escapeText('Prepare rainwater and vessel for $stirTitle')}',
      'END:VALARM',
      'END:VEVENT',
    ]);
  }

  static void _appendMainVEvent(
    List<String> lines,
    CalendarExportEvent event, {
    required DateTime dtStamp,
  }) {
    lines.addAll(<String>[
      'BEGIN:VEVENT',
      'UID:${event.uid}',
      'DTSTAMP:${_formatIcsUtcDateTime(dtStamp)}',
      'DTSTART:${_formatIcsDateTime(event.start)}',
      'DTEND:${_formatIcsDateTime(event.end)}',
      'SUMMARY:${_escapeText(event.summary)}',
      'DESCRIPTION:${_escapeText(event.description)}',
      if (event.location != null && event.location!.trim().isNotEmpty)
        'LOCATION:${_escapeText(event.location!)}',
      if (event.categories.isNotEmpty)
        'CATEGORIES:${event.categories.map(_escapeText).join(',')}',
    ]);

    for (final alarm in event.alarms) {
      final totalMinutes = alarm.triggerBefore.inMinutes;
      lines.addAll(<String>[
        'BEGIN:VALARM',
        'ACTION:DISPLAY',
        'TRIGGER:-PT${totalMinutes}M',
        'DESCRIPTION:${_escapeText(alarm.description)}',
        'END:VALARM',
      ]);
    }

    lines.add('END:VEVENT');
  }

  static String _formatIcsUtcDateTime(DateTime dt) {
    final utc = dt.toUtc();
    return '${_pad4(utc.year)}${_pad2(utc.month)}${_pad2(utc.day)}'
        'T${_pad2(utc.hour)}${_pad2(utc.minute)}${_pad2(utc.second)}Z';
  }

  static String _formatIcsDateTime(DateTime dt) {
    if (dt.isUtc) {
      return _formatIcsUtcDateTime(dt);
    }
    return '${_pad4(dt.year)}${_pad2(dt.month)}${_pad2(dt.day)}'
        'T${_pad2(dt.hour)}${_pad2(dt.minute)}${_pad2(dt.second)}';
  }

  static String _escapeText(String input) {
    return input
        .replaceAll(r'\', r'\\')
        .replaceAll(';', r'\;')
        .replaceAll(',', r'\,')
        .replaceAll('\r\n', r'\n')
        .replaceAll('\r', r'\n')
        .replaceAll('\n', r'\n');
  }

  /// Folds a single RFC 5545 content line so no line exceeds 75 UTF-8 octets.
  static String _foldContentLine(String line) {
    if (utf8.encode(line).length <= 75) return line;

    final buffer = StringBuffer();
    int currentLineBytes = 0;
    for (final rune in line.runes) {
      final charByteLength = rune <= 0x7F
          ? 1
          : (rune <= 0x7FF ? 2 : (rune <= 0xFFFF ? 3 : 4));
      if (currentLineBytes + charByteLength > 75) {
        buffer.write('\r\n ');
        currentLineBytes = 1;
      }
      buffer.writeCharCode(rune);
      currentLineBytes += charByteLength;
    }
    return buffer.toString();
  }

  static String? _formatCoordinates(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) return null;
    final latHemisphere = latitude >= 0 ? 'N' : 'S';
    final lonHemisphere = longitude >= 0 ? 'E' : 'W';
    return '${latitude.abs().toStringAsFixed(2)}°$latHemisphere, '
        '${longitude.abs().toStringAsFixed(2)}°$lonHemisphere';
  }

  static String _formatReadableRange(DateTime start, DateTime end) =>
      '${_formatReadableDateTime(start)} → ${_formatReadableDateTime(end)}';

  static String _formatReadableDateTime(DateTime dt) {
    const weekdays = <String>[
      '',
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];
    const months = <String>[
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${weekdays[dt.weekday]}, ${months[dt.month]} ${dt.day} at ${_formatHourMinute(dt)}';
  }

  static String _formatHourMinute(DateTime dt) =>
      '${_pad2(dt.hour)}:${_pad2(dt.minute)}';

  static String _pad2(int value) => value.toString().padLeft(2, '0');

  static String _pad4(int value) => value.toString().padLeft(4, '0');
}
