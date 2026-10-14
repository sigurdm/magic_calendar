import '../seasonal_calendar.dart';
import 'climate_profile.dart';
import 'danish_reference_climate.dart';
import 'koppen_class.dart';

/// Which feature of the annual cycle a seasonal task is timed by.
///
/// The Danish calendar's months encode different things for different
/// tasks. Hardy crops follow soil and air warmth; frost-tender crops wait
/// for the last frost; pruning and hardwood cuttings follow dormancy. When
/// the calendar is moved to another climate these can shift by different
/// amounts, so each task says which one it depends on.
enum SeasonalAnchor {
  /// The smoothed daily mean temperature: when it crosses 5, 10 and 15 °C.
  thermal,

  /// The later (in spring) or earlier (in autumn) of [thermal] and the air
  /// frost dates, so frost-tender crops are never moved into frost risk.
  frostTender,

  /// Only the coldest and warmest days of the year: the orientation of the
  /// seasons, for dormancy work.
  dormancy,
}

/// How far the Danish sowing calendar carries over to a climate.
enum CalendarTransferability {
  /// Seasons are shaped like Denmark's; shifting the dates is enough.
  transfers,

  /// Shifted dates are a usable start, but something (heat, summer drought,
  /// aridity, a very short season) needs local judgement.
  transfersWithCaveats,

  /// The seasons are not driven by temperature in a way the Danish months
  /// can describe. Seasonal windows should not be shown.
  doesNotTransfer,
}

/// Maps local dates onto the dates of the Danish calendar the app's crop
/// data is written for.
///
/// Month lists in the vegetable database are Danish. Ask
/// [referenceMonth] which Danish month a local date corresponds to, and
/// look that up.
sealed class SeasonAlignment {
  const SeasonAlignment();

  /// The date in the Danish reference calendar whose season matches
  /// [localDate], according to [anchor].
  ///
  /// The time of day is kept. The result is at most about half a year away
  /// from [localDate].
  DateTime referenceDate(
    DateTime localDate, {
    SeasonalAnchor anchor = SeasonalAnchor.thermal,
  });

  /// The month (1–12) of [referenceDate].
  int referenceMonth(
    DateTime localDate, {
    SeasonalAnchor anchor = SeasonalAnchor.thermal,
  });

  /// The local months (1–12) that correspond to the Danish
  /// [referenceMonths] according to [anchor].
  List<int> localMonthsFor(
    Iterable<int> referenceMonths, {
    SeasonalAnchor anchor = SeasonalAnchor.thermal,
  });

  /// Whether local summer falls in April–September.
  bool get hasNorthernSeasons;

  /// How far the Danish calendar carries over to the local climate.
  CalendarTransferability get transferability;

  /// Human-readable warnings about applying the Danish calendar here.
  ///
  /// Empty when [transferability] is [CalendarTransferability.transfers].
  List<String> get caveats;

  /// A label naming the basis of the alignment, such as
  /// `Northern Hemisphere` or `Cfb climate`.
  String get label;

  /// A compact form of [label], such as `Northern` or `Cfb`.
  String get shortLabel;

  /// The local [ClimateProfile] backing this alignment, or `null` when only
  /// latitude-based hemisphere alignment is available.
  ClimateProfile? get localProfile;
}

/// The fallback alignment used before a climate profile is known: north of
/// the equator dates are unchanged, south of it they move by six months.
final class HemisphereSeasonAlignment extends SeasonAlignment {
  /// Latitude of the location in degrees.
  final double latitude;

  /// Creates an alignment for a location at [latitude].
  const HemisphereSeasonAlignment({required this.latitude});

  @override
  bool get hasNorthernSeasons => latitude >= 0;

  @override
  DateTime referenceDate(
    DateTime localDate, {
    SeasonalAnchor anchor = SeasonalAnchor.thermal,
  }) => toNorthernSeasonEquivalent(localDate, isNorthern: hasNorthernSeasons);

  @override
  int referenceMonth(
    DateTime localDate, {
    SeasonalAnchor anchor = SeasonalAnchor.thermal,
  }) => hasNorthernSeasons
      ? localDate.month
      : southernHemisphereMonth(localDate.month);

  @override
  List<int> localMonthsFor(
    Iterable<int> referenceMonths, {
    SeasonalAnchor anchor = SeasonalAnchor.thermal,
  }) => [
    for (final month in referenceMonths)
      hasNorthernSeasons ? month : southernHemisphereMonth(month),
  ];

  @override
  CalendarTransferability get transferability =>
      CalendarTransferability.transfers;

  @override
  List<String> get caveats => const [];

  @override
  String get label =>
      hasNorthernSeasons ? 'Northern Hemisphere' : 'Southern Hemisphere';

  @override
  String get shortLabel => hasNorthernSeasons ? 'Northern' : 'Southern';

  @override
  ClimateProfile? get localProfile => null;

  @override
  bool operator ==(Object other) =>
      other is HemisphereSeasonAlignment &&
      hasNorthernSeasons == other.hasNorthernSeasons;

  @override
  int get hashCode => hasNorthernSeasons.hashCode;
}

/// Aligns a location's seasons with the Danish reference climate.
///
/// Season offsets (days after the climatological coldest day) are mapped
/// through a monotone piecewise-linear warp whose knots pair up matching
/// events in both climates:
///
///  * [SeasonalAnchor.thermal]: the coldest day, the days the smoothed mean
///    rises through and falls back through 5, 10 and 15 °C (where both
///    climates have that crossing), and the warmest day.
///  * [SeasonalAnchor.dormancy]: the coldest and warmest days only.
///  * [SeasonalAnchor.frostTender]: [SeasonalAnchor.thermal], held back in
///    spring to no later a Danish date than the one with the same 1-in-10
///    last-frost risk, and brought forward in autumn to no earlier than the
///    one with the same 1-in-10 first-frost risk.
///
/// Both profiles are derived the same way from the same reanalysis, so
/// most of its bias cancels out of the comparison.
final class ClimateSeasonAlignment extends SeasonAlignment {
  /// The climate of the location being planned for.
  final ClimateProfile local;

  /// The climate the Danish calendar was written for.
  final ClimateProfile reference;

  final int _baseShift;
  final _PiecewiseLinear _thermal;
  final _PiecewiseLinear _dormancy;
  final _PiecewiseLinear? _springFrost;
  final _PiecewiseLinear? _autumnFrost;

  /// Creates an alignment of [local] with [reference], which defaults to
  /// [DanishReferenceClimate.profile].
  factory ClimateSeasonAlignment({
    required ClimateProfile local,
    ClimateProfile? reference,
  }) {
    final target = reference ?? DanishReferenceClimate.profile;
    final localWarmest = local.warmestSeasonOffset;
    final referenceWarmest = target.warmestSeasonOffset;
    final warmest = (localWarmest, referenceWarmest);

    final springKnots = <(int, int)>[];
    final autumnKnots = <(int, int)>[];
    for (final threshold in ClimateProfile.thermalThresholds) {
      final localSeason = local.thermalSeason(threshold);
      final referenceSeason = target.thermalSeason(threshold);
      if (localSeason.isBounded && referenceSeason.isBounded) {
        springKnots.add((localSeason.start!, referenceSeason.start!));
        autumnKnots.add((localSeason.end!, referenceSeason.end!));
      }
    }

    final localFrost = local.frost;
    final referenceFrost = target.frost;
    final springFrostKnot = switch ((
      localFrost.lastSpringFrost90,
      referenceFrost.lastSpringFrost90,
    )) {
      (final localDay?, final referenceDay?) => (localDay, referenceDay),
      _ => null,
    };
    final autumnFrostKnot = switch ((
      localFrost.firstAutumnFrost10,
      referenceFrost.firstAutumnFrost10,
    )) {
      (final localDay?, final referenceDay?) => (localDay, referenceDay),
      _ => null,
    };

    return ClimateSeasonAlignment._(
      local,
      target,
      (target.coldestDay - local.coldestDay + climateYearLength ~/ 2) %
              climateYearLength -
          climateYearLength ~/ 2,
      _PiecewiseLinear.monotone(
        spring: springKnots,
        warmest: warmest,
        autumn: autumnKnots.reversed,
      ),
      _PiecewiseLinear.monotone(warmest: warmest),
      springFrostKnot == null
          ? null
          : _PiecewiseLinear.monotone(
              spring: [springFrostKnot],
              warmest: warmest,
            ),
      autumnFrostKnot == null
          ? null
          : _PiecewiseLinear.monotone(
              warmest: warmest,
              autumn: [autumnFrostKnot],
            ),
    );
  }

  ClimateSeasonAlignment._(
    this.local,
    this.reference,
    this._baseShift,
    this._thermal,
    this._dormancy,
    this._springFrost,
    this._autumnFrost,
  );

  /// The reference season offset matching the local season [offset].
  double _warp(double offset, SeasonalAnchor anchor) {
    switch (anchor) {
      case SeasonalAnchor.thermal:
        return _thermal(offset);
      case SeasonalAnchor.dormancy:
        return _dormancy(offset);
      case SeasonalAnchor.frostTender:
        final thermal = _thermal(offset);
        if (offset < local.warmestSeasonOffset) {
          final frost = _springFrost;
          return frost == null
              ? thermal
              : (frost(offset) < thermal ? frost(offset) : thermal);
        }
        final frost = _autumnFrost;
        return frost == null
            ? thermal
            : (frost(offset) > thermal ? frost(offset) : thermal);
    }
  }

  @override
  DateTime referenceDate(
    DateTime localDate, {
    SeasonalAnchor anchor = SeasonalAnchor.thermal,
  }) {
    final offset = local.seasonOffsetOf(climateDayOfYear(localDate));
    final referenceOffset = _warp(offset.toDouble(), anchor);
    final shift = _baseShift + (referenceOffset - offset).round();
    return localDate.isUtc
        ? DateTime.utc(
            localDate.year,
            localDate.month,
            localDate.day + shift,
            localDate.hour,
            localDate.minute,
            localDate.second,
            localDate.millisecond,
            localDate.microsecond,
          )
        : DateTime(
            localDate.year,
            localDate.month,
            localDate.day + shift,
            localDate.hour,
            localDate.minute,
            localDate.second,
            localDate.millisecond,
            localDate.microsecond,
          );
  }

  @override
  int referenceMonth(
    DateTime localDate, {
    SeasonalAnchor anchor = SeasonalAnchor.thermal,
  }) => referenceDate(localDate, anchor: anchor).month;

  /// Months in which at least half the days map into [referenceMonths]; if
  /// there are none, months in which any day does.
  @override
  List<int> localMonthsFor(
    Iterable<int> referenceMonths, {
    SeasonalAnchor anchor = SeasonalAnchor.thermal,
  }) {
    final wanted = referenceMonths.toSet();
    if (wanted.isEmpty) return const [];
    final matchingDays = List.filled(12, 0);
    final daysInMonth = List.filled(12, 0);
    for (var day = 0; day < climateYearLength; day++) {
      final date = climateDateOfDay(day);
      daysInMonth[date.month - 1]++;
      if (wanted.contains(referenceMonth(date, anchor: anchor))) {
        matchingDays[date.month - 1]++;
      }
    }
    final mostly = [
      for (var month = 1; month <= 12; month++)
        if (matchingDays[month - 1] * 2 >= daysInMonth[month - 1]) month,
    ];
    if (mostly.isNotEmpty) return mostly;
    return [
      for (var month = 1; month <= 12; month++)
        if (matchingDays[month - 1] > 0) month,
    ];
  }

  @override
  bool get hasNorthernSeasons => local.hasNorthernSeasons;

  @override
  CalendarTransferability get transferability =>
      transferabilityOf(local.koppen);

  @override
  List<String> get caveats {
    final koppen = local.koppen;
    final warmest = local.normals.warmestMonthTemperature.round();
    return [
      if (koppen.group == KoppenGroup.tropical)
        'Tropical climate: temperatures hardly change through the year, and '
            'planting follows the rains. The Danish seasonal windows do not '
            'apply here, so only the cosmic rhythms are shown.',
      if (koppen == KoppenClass.bwh || koppen == KoppenClass.bwk)
        'Desert climate: growing depends on irrigation, and the hottest '
            'months are the resting season. The Danish seasonal windows do '
            'not apply here, so only the cosmic rhythms are shown.',
      if (koppen == KoppenClass.bsh || koppen == KoppenClass.bsk)
        'Semi-arid climate: rainfall, not temperature, limits the season. '
            'Expect to irrigate, and sow cool-season crops in the wetter '
            'months.',
      if (koppen == KoppenClass.ef)
        'Ice-cap climate: no month averages above freezing, so nothing '
            'grows outdoors. The Danish seasonal windows do not apply here.',
      if (koppen == KoppenClass.et)
        'Tundra climate: the warm season is very short. Most crops need a '
            'greenhouse or cold frame.',
      if (koppen.hasHotSummer)
        'Hot summers (warmest month about $warmest °C): cool-season crops '
            'such as lettuce, spinach and peas bolt in midsummer. Sow them '
            'in spring and autumn instead.',
      if (koppen.hasDrySummer)
        'Dry summers: the Danish calendar assumes summer rain. Plan on '
            'irrigation, or move sowing towards the wet season.',
      if (koppen.hasVeryColdWinter)
        'Very cold winters (coldest month below −38 °C): the perennials in '
            'the database are unlikely to survive.',
    ];
  }

  /// How far the Danish calendar carries over to a [koppen] climate.
  static CalendarTransferability transferabilityOf(KoppenClass koppen) =>
      switch (koppen.group) {
        KoppenGroup.tropical => CalendarTransferability.doesNotTransfer,
        KoppenGroup.arid =>
          koppen == KoppenClass.bwh || koppen == KoppenClass.bwk
              ? CalendarTransferability.doesNotTransfer
              : CalendarTransferability.transfersWithCaveats,
        KoppenGroup.polar =>
          koppen == KoppenClass.ef
              ? CalendarTransferability.doesNotTransfer
              : CalendarTransferability.transfersWithCaveats,
        KoppenGroup.temperate || KoppenGroup.cold =>
          koppen.hasHotSummer || koppen.hasDrySummer || koppen.hasVeryColdWinter
              ? CalendarTransferability.transfersWithCaveats
              : CalendarTransferability.transfers,
      };

  @override
  ClimateProfile? get localProfile => local;

  @override
  String get label => '${local.koppen.code} climate';

  @override
  String get shortLabel => local.koppen.code;
}

/// A monotone piecewise-linear map from [0, 365] onto [0, 365].
final class _PiecewiseLinear {
  final List<double> _xs;
  final List<double> _ys;

  _PiecewiseLinear._(this._xs, this._ys);

  /// Interpolates through (0, 0), the [spring] knots, [warmest], the
  /// [autumn] knots, and (365, 365), in that order.
  ///
  /// Knots that would break strict monotonicity in either coordinate are
  /// dropped, as are spring knots at or after [warmest] and autumn knots at
  /// or before it.
  factory _PiecewiseLinear.monotone({
    Iterable<(int, int)> spring = const [],
    required (int, int) warmest,
    Iterable<(int, int)> autumn = const [],
  }) {
    final (warmestX, warmestY) = warmest;
    final candidates = [
      for (final (x, y) in spring)
        if (x < warmestX && y < warmestY) (x, y),
      warmest,
      for (final (x, y) in autumn)
        if (x > warmestX && y > warmestY) (x, y),
      (climateYearLength, climateYearLength),
    ];
    final xs = <double>[0];
    final ys = <double>[0];
    for (final (x, y) in candidates) {
      if (x > xs.last && y > ys.last) {
        xs.add(x.toDouble());
        ys.add(y.toDouble());
      }
    }
    return _PiecewiseLinear._(xs, ys);
  }

  double call(double x) {
    for (var i = 1; i < _xs.length; i++) {
      if (x <= _xs[i]) {
        final fraction = (x - _xs[i - 1]) / (_xs[i] - _xs[i - 1]);
        return _ys[i - 1] + fraction * (_ys[i] - _ys[i - 1]);
      }
    }
    return _ys.last;
  }
}
