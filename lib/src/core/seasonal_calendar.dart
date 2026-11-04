/// Seasonal date helpers shared by the biodynamic preparation and plant
/// recommendation logic.
///
/// Two concerns live here because both were previously duplicated across
/// several call sites with subtly different (and in one case incorrect)
/// implementations:
///
///  * mapping a southern-hemisphere date onto its northern-hemisphere seasonal
///    equivalent, and
///  * determining the date of Easter, which anchors the biodynamic burial
///    cycle.
library;

/// Shifts [month] by six months to map a southern-hemisphere month onto the
/// northern-hemisphere month with the equivalent season.
///
/// January (deep southern summer) maps to July, December maps to June, and so
/// on. [month] must be between 1 and 12 (inclusive) and the result is 1-based.
///
/// Use this when only the season matters. When you need a full date, use
/// [toNorthernSeasonEquivalent], which also carries the year correctly.
int southernHemisphereMonth(int month) {
  RangeError.checkValueInInterval(month, 1, 12, 'month');
  return ((month + 5) % 12) + 1;
}

/// Maps [date] onto the northern-hemisphere date with the equivalent season.
///
/// Returns [date] unchanged when [isNorthern] is true. Otherwise it advances
/// the date by six months so that, for example, southern midsummer lines up
/// with northern midsummer.
///
/// Unlike a bare month-index shift, this rolls the year over: 31 December 2026
/// maps to 30 June **2027**, not 2026. Getting that wrong previously moved a
/// southern-hemisphere date backwards by six months instead of forwards,
/// placing it in the wrong burial cycle.
///
/// Day-of-month overflow is normalised by [DateTime] itself (31 August maps
/// into early March, since February has no 31st).
DateTime toNorthernSeasonEquivalent(DateTime date, {required bool isNorthern}) {
  if (isNorthern) {
    return date;
  }
  // `DateTime` normalises a month index greater than 12 into the next year,
  // which is exactly the roll-over we want.
  if (date.isUtc) {
    return DateTime.utc(
      date.year,
      date.month + 6,
      date.day,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );
  }
  return DateTime(
    date.year,
    date.month + 6,
    date.day,
    date.hour,
    date.minute,
    date.second,
    date.millisecond,
    date.microsecond,
  );
}

final Map<int, DateTime> _easterCache = <int, DateTime>{};

/// Returns the date of Easter Sunday in [year] in the Gregorian calendar.
///
/// Easter is a moveable feast falling between 22 March and 25 April, so it
/// cannot be approximated by a fixed date without drifting by up to three
/// weeks. This uses the anonymous Gregorian algorithm (Meeus/Butcher), which is
/// exact for all years in the Gregorian calendar.
///
/// The returned value is a local [DateTime] at midnight.
DateTime gregorianEaster(int year) {
  if (_easterCache[year] case final cached?) {
    return cached;
  }
  if (_easterCache.length >= 256) {
    _easterCache.clear();
  }
  final a = year % 19;
  final b = year ~/ 100;
  final c = year % 100;
  final d = b ~/ 4;
  final e = b % 4;
  final f = (b + 8) ~/ 25;
  final g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4;
  final k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final month = (h + l - 7 * m + 114) ~/ 31;
  final day = ((h + l - 7 * m + 114) % 31) + 1;
  return _easterCache[year] = DateTime(year, month, day);
}
