/// Represents analyzed information about an AppEnum specification.
class EnumInfo {
  /// The class name of the enum.
  final String className;

  /// The unique identifier for the enum.
  final String identifier;

  /// The human-readable title for the enum type.
  final String title;

  /// The enum cases with their display metadata.
  final List<EnumCaseInfo> cases;

  /// Experimental (WWDC26): the App Schema this enum conforms to, as a dotted
  /// `domain.schema` path (e.g. `messages.messageType`). When set and the
  /// `app-schema` feature is enabled, adds the `@AppEnum(schema:)` macro.
  final String? schema;

  const EnumInfo({
    required this.className,
    required this.identifier,
    required this.title,
    required this.cases,
    this.schema,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! EnumInfo) return false;
    return className == other.className &&
        identifier == other.identifier &&
        title == other.title &&
        schema == other.schema &&
        _listEquals(cases, other.cases);
  }

  @override
  int get hashCode =>
      Object.hash(className, identifier, title, schema, Object.hashAll(cases));

  @override
  String toString() =>
      'EnumInfo(className: $className, identifier: $identifier, '
      'title: $title, schema: $schema, cases: $cases)';
}

/// Represents a single case of an AppEnum.
class EnumCaseInfo {
  /// The case name (Swift enum case identifier).
  final String name;

  /// The display title for this case.
  final String displayTitle;

  /// Optional asset image name for this case.
  final String? imageName;

  const EnumCaseInfo({
    required this.name,
    required this.displayTitle,
    this.imageName,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! EnumCaseInfo) return false;
    return name == other.name &&
        displayTitle == other.displayTitle &&
        imageName == other.imageName;
  }

  @override
  int get hashCode => Object.hash(name, displayTitle, imageName);

  @override
  String toString() =>
      'EnumCaseInfo(name: $name, displayTitle: $displayTitle, imageName: $imageName)';
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
