/// Analyzed information about a WWDC26 union value (#53).
///
/// A union value maps to a native iOS 27 `@UnionValue enum` whose cases each
/// wrap an App Entity. Declared on the Dart side as a `sealed` class with one
/// `@UnionCase` subclass per case.
class UnionInfo {
  /// The Dart sealed class name (also the Swift enum name), e.g.
  /// `GalleryContent`.
  final String className;

  /// A unique identifier for the union.
  final String identifier;

  /// An optional human-readable title.
  final String? title;

  /// The union cases, in declaration order.
  final List<UnionCaseInfo> cases;

  const UnionInfo({
    required this.className,
    required this.identifier,
    this.title,
    required this.cases,
  });

  @override
  bool operator ==(Object other) =>
      other is UnionInfo &&
      other.className == className &&
      other.identifier == identifier &&
      other.title == title &&
      _listEquals(other.cases, cases);

  @override
  int get hashCode =>
      Object.hash(className, identifier, title, Object.hashAll(cases));

  @override
  String toString() =>
      'UnionInfo(className: $className, identifier: $identifier, '
      'title: $title, cases: $cases)';
}

/// One case of a [UnionInfo].
class UnionCaseInfo {
  /// The Dart subclass name (e.g. `PhotoContent`). Also the `_type` discriminant
  /// carried over the wire.
  final String dartClassName;

  /// The Swift App Entity type this case wraps (e.g. `PhotoEntity`).
  final String entityType;

  const UnionCaseInfo({required this.dartClassName, required this.entityType});

  /// The Swift enum case name: lower-camel-cased [dartClassName]
  /// (e.g. `PhotoContent` -> `photoContent`).
  String get swiftCaseName => dartClassName.isEmpty
      ? dartClassName
      : dartClassName[0].toLowerCase() + dartClassName.substring(1);

  @override
  bool operator ==(Object other) =>
      other is UnionCaseInfo &&
      other.dartClassName == dartClassName &&
      other.entityType == entityType;

  @override
  int get hashCode => Object.hash(dartClassName, entityType);

  @override
  String toString() =>
      'UnionCaseInfo(dartClassName: $dartClassName, entityType: $entityType)';
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
