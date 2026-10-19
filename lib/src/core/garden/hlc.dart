/// Hybrid Logical Clock (HLC) implementation for deterministic, conflict-free
/// causal ordering across distributed devices sharing a garden diary.
///
/// An [Hlc] combines physical UTC wall-clock time ([wallTimeMs]) with a
/// monotonically increasing logical [counter] and a unique [actorId]. Its
/// canonical string representation ([toCanonicalString]) is lexicographically
/// sortable in ASCII (including directly inside SQLite `>` and `MAX()` queries).
final class Hlc implements Comparable<Hlc> {
  /// Maximum logical counter value (`65535`, 4 hex digits).
  static const int maxCounter = 0xFFFF;

  static final RegExp _actorIdPattern = RegExp(r'^[A-Za-z0-9_.\-:]+$');
  static final RegExp _canonicalPattern = RegExp(
    r'^(\d{15})-([0-9a-fA-F]{4})-([A-Za-z0-9_.\-:]+)$',
  );

  /// Physical UTC timestamp in milliseconds since Unix epoch.
  final int wallTimeMs;

  /// Logical tie-breaker counter within the same millisecond (`0..65535`).
  final int counter;

  /// Unique identifier of the device or gardener actor that produced the event.
  final String actorId;

  /// Creates an [Hlc].
  ///
  /// The [wallTimeMs] must be non-negative, [counter] must be in `0..65535`,
  /// and [actorId] must be non-empty ASCII (`[A-Za-z0-9_.\-:]`).
  Hlc({required this.wallTimeMs, this.counter = 0, required this.actorId}) {
    RangeError.checkNotNegative(wallTimeMs, 'wallTimeMs');
    RangeError.checkValueInInterval(counter, 0, maxCounter, 'counter');
    if (actorId.isEmpty || !_actorIdPattern.hasMatch(actorId)) {
      throw ArgumentError.value(
        actorId,
        'actorId',
        'Must be non-empty alphanumeric/identifier characters',
      );
    }
  }

  /// Creates an initial [Hlc] from a [DateTime] and [actorId].
  factory Hlc.fromDateTime(
    DateTime timestamp, {
    String actorId = 'local',
    int counter = 0,
  }) {
    final ms = timestamp.toUtc().millisecondsSinceEpoch;
    return Hlc(wallTimeMs: ms < 0 ? 0 : ms, counter: counter, actorId: actorId);
  }

  /// Parses a canonical HLC string (`<15-digit-ms>-<4-hex-counter>-<actorId>`).
  ///
  /// Throws a [FormatException] if [formatted] is not a valid canonical HLC.
  factory Hlc.parse(String formatted) {
    final parsed = tryParse(formatted);
    if (parsed == null) {
      throw FormatException('Invalid HLC string', formatted);
    }
    return parsed;
  }

  /// Attempts to parse [formatted] as a canonical [Hlc], returning `null` if invalid.
  static Hlc? tryParse(String? formatted) {
    if (formatted == null || formatted.isEmpty) return null;
    final match = _canonicalPattern.firstMatch(formatted);
    if (match == null) return null;
    final wallMs = int.tryParse(match.group(1)!, radix: 10);
    final cnt = int.tryParse(match.group(2)!, radix: 16);
    final actor = match.group(3)!;
    if (wallMs == null || cnt == null) return null;
    return Hlc(wallTimeMs: wallMs, counter: cnt, actorId: actor);
  }

  /// UTC [DateTime] corresponding to [wallTimeMs].
  DateTime get dateTimeUtc =>
      DateTime.fromMillisecondsSinceEpoch(wallTimeMs, isUtc: true);

  /// Fixed-width canonical string (`<15-digit-ms>-<4-hex-counter>-<actorId>`)
  /// whose ASCII sort order matches [compareTo].
  String toCanonicalString() {
    final msPart = wallTimeMs.toRadixString(10).padLeft(15, '0');
    final counterPart = counter.toRadixString(16).toLowerCase().padLeft(4, '0');
    return '$msPart-$counterPart-$actorId';
  }

  @override
  int compareTo(Hlc other) {
    final wallCmp = wallTimeMs.compareTo(other.wallTimeMs);
    if (wallCmp != 0) return wallCmp;
    final cntCmp = counter.compareTo(other.counter);
    if (cntCmp != 0) return cntCmp;
    return actorId.compareTo(other.actorId);
  }

  /// Whether this HLC is strictly newer than [other].
  bool operator >(Hlc other) => compareTo(other) > 0;

  /// Whether this HLC is newer than or equal to [other].
  bool operator >=(Hlc other) => compareTo(other) >= 0;

  /// Whether this HLC is strictly older than [other].
  bool operator <(Hlc other) => compareTo(other) < 0;

  /// Whether this HLC is older than or equal to [other].
  bool operator <=(Hlc other) => compareTo(other) <= 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Hlc &&
          wallTimeMs == other.wallTimeMs &&
          counter == other.counter &&
          actorId == other.actorId;

  @override
  int get hashCode => Object.hash(wallTimeMs, counter, actorId);

  @override
  String toString() => toCanonicalString();
}

/// Stateful Hybrid Logical Clock generator for a local garden actor.
final class HlcClock {
  /// Local actor identifier stamped onto emitted [Hlc] timestamps.
  final String actorId;

  Hlc _last;

  /// Creates an [HlcClock] for [actorId], optionally seeded with [initial].
  HlcClock({required this.actorId, Hlc? initial})
    : _last = initial ?? Hlc(wallTimeMs: 0, counter: 0, actorId: actorId) {
    if (actorId.isEmpty) {
      throw ArgumentError.value(actorId, 'actorId', 'Must not be empty');
    }
  }

  /// Most recently emitted or observed [Hlc].
  Hlc get last => _last;

  /// Emits a new [Hlc] strictly greater than [last] for a local mutation.
  Hlc now([DateTime? physicalNow]) {
    final wallMs = (physicalNow ?? DateTime.now())
        .toUtc()
        .millisecondsSinceEpoch;
    final clampedWallMs = wallMs < 0 ? 0 : wallMs;
    if (clampedWallMs > _last.wallTimeMs) {
      _last = Hlc(wallTimeMs: clampedWallMs, counter: 0, actorId: actorId);
    } else {
      final nextCounter = (_last.counter + 1).clamp(0, Hlc.maxCounter);
      final nextWall = _last.counter >= Hlc.maxCounter
          ? _last.wallTimeMs + 1
          : _last.wallTimeMs;
      _last = Hlc(
        wallTimeMs: nextWall,
        counter: _last.counter >= Hlc.maxCounter ? 0 : nextCounter,
        actorId: actorId,
      );
    }
    return _last;
  }

  /// Advances this clock upon observing a [remote] HLC during sync or merge.
  Hlc receive(Hlc remote, [DateTime? physicalNow]) {
    final wallMs = (physicalNow ?? DateTime.now())
        .toUtc()
        .millisecondsSinceEpoch;
    final clampedWallMs = wallMs < 0 ? 0 : wallMs;

    int maxWall = clampedWallMs;
    if (_last.wallTimeMs > maxWall) maxWall = _last.wallTimeMs;
    if (remote.wallTimeMs > maxWall) maxWall = remote.wallTimeMs;

    int nextCounter;
    if (maxWall == _last.wallTimeMs && maxWall == remote.wallTimeMs) {
      final hi = _last.counter > remote.counter
          ? _last.counter
          : remote.counter;
      nextCounter = hi + 1;
    } else if (maxWall == _last.wallTimeMs) {
      nextCounter = _last.counter + 1;
    } else if (maxWall == remote.wallTimeMs) {
      nextCounter = remote.counter + 1;
    } else {
      nextCounter = 0;
    }

    if (nextCounter > Hlc.maxCounter) {
      maxWall += 1;
      nextCounter = 0;
    }

    _last = Hlc(wallTimeMs: maxWall, counter: nextCounter, actorId: actorId);
    return _last;
  }
}
