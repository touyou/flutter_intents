/// Normalizes an intent handler's return value into the map a generated
/// snippet view reads through `{result.key}` placeholders.
///
/// Handlers in this library return whatever suits the app — a domain model, a
/// map, or nothing — so the generated registration funnels the value through
/// here instead of demanding one shape. Accepted:
///
/// - `null` → an empty map (the snippet renders its `{result.…}` slots empty)
/// - a `Map` → used directly, with keys coerced to `String`
/// - anything with a `toJson()` returning a `Map` → that map. This is the same
///   convention the generated entity handlers already rely on.
///
/// Anything else throws [ArgumentError] rather than silently producing an
/// empty card: a snippet that quietly renders blank is close to impossible to
/// diagnose from the Siri surface where it appears.
Map<String, dynamic> intentResultPayload(Object? result) {
  if (result == null) return const <String, dynamic>{};
  if (result is Map) return _coerce(result);

  final dynamic dynamicResult = result;
  final Object? json;
  try {
    json = dynamicResult.toJson();
  } on NoSuchMethodError {
    throw ArgumentError.value(
      result,
      'result',
      'Intent handler returned a ${result.runtimeType}, which a snippet '
          'template cannot read. Return a Map<String, dynamic>, or give the '
          'type a toJson() method.',
    );
  }

  if (json is Map) return _coerce(json);
  throw ArgumentError.value(
    result,
    'result',
    'Intent handler returned a ${result.runtimeType} whose toJson() produced '
        '${json.runtimeType} instead of a Map.',
  );
}

Map<String, dynamic> _coerce(Map<dynamic, dynamic> map) =>
    map.map((key, value) => MapEntry('$key', value));
