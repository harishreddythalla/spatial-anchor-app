class LocationContext {
  final String? regionName; // e.g. State
  final String? villageName;
  final String? mandalName;
  final String? districtName;

  const LocationContext({
    this.regionName,
    this.villageName,
    this.mandalName,
    this.districtName,
  });

  static const LocationContext unknown = LocationContext();

  bool get isKnown =>
      regionName != null ||
      villageName != null ||
      mandalName != null ||
      districtName != null;

  // Most specific name available
  String? get mostSpecificName =>
      villageName ?? mandalName ?? districtName ?? regionName;

  List<(String, String)> get labeledParts {
    if (!isKnown) return const [];
    final parts = <(String, String)>[];
    if (regionName != null) parts.add(('Region', regionName!));
    if (districtName != null) parts.add(('District', districtName!));
    if (mandalName != null) parts.add(('Mandal', mandalName!));
    if (villageName != null) parts.add(('Village', villageName!));
    return parts;
  }

  String get displayString {
    if (!isKnown) return 'Outside mapped area';
    final parts = labeledParts.map((p) => '${p.$1}: ${p.$2}').toList();
    return '📍 ${parts.join('  •  ')}';
  }

  @override
  String toString() => displayString;

  @override
  bool operator ==(Object other) =>
      other is LocationContext &&
      other.regionName == regionName &&
      other.villageName == villageName &&
      other.mandalName == mandalName &&
      other.districtName == districtName;

  @override
  int get hashCode =>
      Object.hash(regionName, villageName, mandalName, districtName);
}
