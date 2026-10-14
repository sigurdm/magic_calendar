/// Whether a USDA plant hardiness half-zone is the cooler `a` or warmer `b`
/// half of its whole zone.
enum HardinessSubzone {
  /// The cooler `a` half of a whole zone.
  a,

  /// The warmer `b` half of a whole zone.
  b,
}

/// A USDA plant hardiness half-zone, such as `8b`.
///
/// Zones are defined by the mean annual extreme minimum temperature: zone 1a
/// starts at −60 °F (−51.1 °C) and each half-zone spans 5 °F (2.8 °C), up to
/// 13b, which ends at 70 °F (21.1 °C).
///
/// See: <https://planthardiness.ars.usda.gov/pages/about-the-map>.
final class HardinessZone implements Comparable<HardinessZone> {
  /// The whole zone number, from 1 to 13.
  final int zone;

  /// The `a` or `b` half-zone of [zone].
  final HardinessSubzone subzone;

  /// Whether this is the warmer `b` half of [zone] rather than the `a` half.
  bool get isWarmerHalf => subzone == HardinessSubzone.b;

  /// The coldest zone, 1a.
  static const HardinessZone coldest = HardinessZone(1, HardinessSubzone.a);

  /// The warmest zone, 13b.
  static const HardinessZone warmest = HardinessZone(13, HardinessSubzone.b);

  /// Creates the half-zone [zone] with [subzone] (`a` or `b`).
  ///
  /// The [zone] must be between 1 and 13.
  const HardinessZone(this.zone, [this.subzone = HardinessSubzone.a])
    : assert(zone >= 1 && zone <= 13, 'Must be between 1 and 13');

  /// The half-zone containing a mean annual extreme minimum temperature of
  /// [celsius] °C.
  ///
  /// Temperatures below zone 1a map to 1a and temperatures above 13b map to
  /// 13b. The [celsius] must be finite.
  factory HardinessZone.fromMeanAnnualExtremeMinimum(double celsius) {
    if (!celsius.isFinite) {
      throw ArgumentError.value(celsius, 'celsius', 'Must be finite');
    }
    final fahrenheit = celsius * 9 / 5 + 32;
    final halfZone = ((fahrenheit + 60) / 5).floor().clamp(0, 25);
    return HardinessZone(
      halfZone ~/ 2 + 1,
      halfZone.isOdd ? HardinessSubzone.b : HardinessSubzone.a,
    );
  }

  /// Parses a label such as `8b`, or returns null if [label] is not a zone
  /// from `1a` to `13b`.
  static HardinessZone? tryParse(String label) {
    final match = RegExp(r'^(\d{1,2})([ab])$').firstMatch(label);
    if (match == null) return null;
    final zone = int.parse(match[1]!);
    if (zone < 1 || zone > 13) return null;
    return HardinessZone(
      zone,
      match[2] == 'b' ? HardinessSubzone.b : HardinessSubzone.a,
    );
  }

  /// The conventional label, such as `8b`.
  String get label => '$zone${isWarmerHalf ? 'b' : 'a'}';

  int get _halfZoneIndex => (zone - 1) * 2 + (isWarmerHalf ? 1 : 0);

  /// The coldest mean annual extreme minimum in this half-zone, in °C.
  double get lowerBoundCelsius =>
      _fahrenheitToCelsius(-60.0 + 5 * _halfZoneIndex);

  /// The mean annual extreme minimum at which the next half-zone starts, in
  /// °C.
  double get upperBoundCelsius =>
      _fahrenheitToCelsius(-55.0 + 5 * _halfZoneIndex);

  /// The number of half-zones between this zone and [other].
  ///
  /// Positive when this zone is warmer than [other].
  int halfZonesWarmerThan(HardinessZone other) =>
      _halfZoneIndex - other._halfZoneIndex;

  static double _fahrenheitToCelsius(double fahrenheit) =>
      (fahrenheit - 32) * 5 / 9;

  @override
  int compareTo(HardinessZone other) =>
      _halfZoneIndex.compareTo(other._halfZoneIndex);

  @override
  bool operator ==(Object other) =>
      other is HardinessZone &&
      zone == other.zone &&
      isWarmerHalf == other.isWarmerHalf;

  @override
  int get hashCode => _halfZoneIndex.hashCode;

  @override
  String toString() => 'HardinessZone($label)';
}
