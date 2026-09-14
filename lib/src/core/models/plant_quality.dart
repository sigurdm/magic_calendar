/// Plant qualities for agricultural biodynamic calendar.
enum PlantQuality {
  root,
  leaf,
  flower,
  fruit,
  none;

  /// Capitalized human-readable label (e.g. 'Root', 'Leaf', 'None').
  String get displayName {
    if (this == none) return 'None';
    return name[0].toUpperCase() + name.substring(1);
  }
}
