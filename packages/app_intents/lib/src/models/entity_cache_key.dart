/// Cache keys for the persisted entity list used as the EntityQuery
/// cold-start fallback.
///
/// The Dart side writes the entity list with
/// `AppIntents().setCachedValue(key, value)`; the generated Swift `EntityQuery`
/// reads the same key before waiting on the Flutter executor. When
/// `@EntitySpec(persistedCacheKey:)` is not set but `enumerable` or `indexed`
/// is true, codegen falls back to [AppIntentsEntityCacheKey.forEntity] — so the
/// Dart side has to produce the exact same string.
///
/// Use this instead of writing `'app_intents.entities.<identifier>'` by hand.
///
/// ```dart
/// await AppIntents().setCachedValue(
///   AppIntentsEntityCacheKey.forEntity('com.example.taskapp.TaskEntity'),
///   jsonEncode(entityMaps),
/// );
/// ```
///
/// The Swift counterpart for App Extensions is
/// `AppIntentsEntityCache.defaultCacheKey(forEntityIdentifier:)` in the
/// `AppIntentsBridge` Swift package.
abstract final class AppIntentsEntityCacheKey {
  /// The prefix codegen uses for the default per-entity cache key.
  static const String prefix = 'app_intents.entities.';

  /// The default cache key for the entity with [identifier].
  ///
  /// [identifier] is the `@EntitySpec(identifier:)` value (e.g.
  /// `'com.example.taskapp.TaskEntity'`), **not** the Dart class name.
  static String forEntity(String identifier) => '$prefix$identifier';
}
