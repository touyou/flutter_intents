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
///
/// ## This is not a `UserDefaults` key
/// The value returned here is the *cache key*. The plugin namespaces it with
/// the storage identifier before writing, so the raw key in the App Group
/// `UserDefaults` is:
///
/// ```text
/// app_intents.<storageIdentifier>.cache.app_intents.entities.<identifier>
/// ```
///
/// where `<storageIdentifier>` is what was passed to
/// `AppIntentsPlugin.configure(storageIdentifier:)`, falling back to the **main
/// app's** bundle identifier (then the App Group identifier, then
/// `'app_intents'`). Note that an App Extension's own
/// `Bundle.main.bundleIdentifier` is *not* the main app's, so it cannot be used
/// to rebuild this key. Passing the cache key straight to
/// `UserDefaults.string(forKey:)` does not raise — it silently returns `null`,
/// which only shows up as an empty widget configuration picker.
///
/// From Swift, derive the raw key with
/// `AppIntentsEntityCache.storageKey(forCacheKey:storageIdentifier:)` (or just
/// read through `AppIntentsEntityCache.entities(forCacheKey:)`) rather than
/// assembling it by hand. See `docs/usage.md` → "Consuming AppIntentsBridge"
/// for how to add that package to an App Extension target.
abstract final class AppIntentsEntityCacheKey {
  /// The prefix codegen uses for the default per-entity cache key.
  static const String prefix = 'app_intents.entities.';

  /// The default cache key for the entity with [identifier].
  ///
  /// [identifier] is the `@EntitySpec(identifier:)` value (e.g.
  /// `'com.example.taskapp.TaskEntity'`), **not** the Dart class name.
  static String forEntity(String identifier) => '$prefix$identifier';
}
