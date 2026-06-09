/// A structured personal name received from (or passed to) an App Intent
/// parameter.
///
/// Maps to iOS `PersonNameComponents`. With the `rich-types` experimental
/// feature the generated Swift uses the native (iOS 27) `PersonNameComponents`
/// parameter, carrying every component. Without it — the default and the
/// `#else` fallback — the stable SDK has no `PersonNameComponents` parameter
/// conformance, so the parameter falls back to a plain formatted `String` and
/// only [givenName] is populated.
///
/// The wire format between Swift and Dart is always a `Map<String, String>` of
/// the non-null components, so the Dart handler is branch-agnostic.
class PersonName {
  /// The given (first) name.
  final String? givenName;

  /// The family (last) name.
  final String? familyName;

  /// The middle name.
  final String? middleName;

  /// A name prefix (e.g. "Dr.").
  final String? namePrefix;

  /// A name suffix (e.g. "Jr.").
  final String? nameSuffix;

  /// A nickname.
  final String? nickname;

  const PersonName({
    this.givenName,
    this.familyName,
    this.middleName,
    this.namePrefix,
    this.nameSuffix,
    this.nickname,
  });

  factory PersonName.fromMap(Map<String, dynamic> map) => PersonName(
    givenName: map['givenName'] as String?,
    familyName: map['familyName'] as String?,
    middleName: map['middleName'] as String?,
    namePrefix: map['namePrefix'] as String?,
    nameSuffix: map['nameSuffix'] as String?,
    nickname: map['nickname'] as String?,
  );

  Map<String, dynamic> toMap() => {
    if (givenName != null) 'givenName': givenName,
    if (familyName != null) 'familyName': familyName,
    if (middleName != null) 'middleName': middleName,
    if (namePrefix != null) 'namePrefix': namePrefix,
    if (nameSuffix != null) 'nameSuffix': nameSuffix,
    if (nickname != null) 'nickname': nickname,
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PersonName) return false;
    return givenName == other.givenName &&
        familyName == other.familyName &&
        middleName == other.middleName &&
        namePrefix == other.namePrefix &&
        nameSuffix == other.nameSuffix &&
        nickname == other.nickname;
  }

  @override
  int get hashCode => Object.hash(
    givenName,
    familyName,
    middleName,
    namePrefix,
    nameSuffix,
    nickname,
  );

  @override
  String toString() =>
      'PersonName(givenName: $givenName, familyName: $familyName, '
      'middleName: $middleName, namePrefix: $namePrefix, '
      'nameSuffix: $nameSuffix, nickname: $nickname)';
}
