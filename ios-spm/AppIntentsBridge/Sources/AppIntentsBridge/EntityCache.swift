import Foundation

/// One entity read out of the App Group entity cache.
///
/// This is a plain value type — it deliberately does not conform to `AppEntity`
/// so that it can be mapped onto whatever entity type the reading target
/// defines (a hand-written `AppEntity` in a Widget Extension, a SwiftUI view
/// model, …).
///
/// `id` and `title` are the two fields the cache contract guarantees; anything
/// else the Dart side wrote is available verbatim through ``values``.
public struct AppIntentsCachedEntity: Sendable, Equatable, Identifiable {
    /// The entity identifier (the value of the `@EntityId` field).
    public let id: String

    /// The display title (the value of the `@EntityTitle` field).
    public let title: String

    /// The display subtitle, when the entity declares an `@EntitySubtitle`
    /// field and the caller asked for it via `subtitleKey`.
    public let subtitle: String?

    /// The image name (SF Symbol or asset name), when the entity declares an
    /// `@EntityImage` field and the caller asked for it via `imageKey`.
    public let imageName: String?

    /// Every string-valued field of the cached payload, keyed by the entity's
    /// Dart field name. Use this to reach fields beyond id/title/subtitle/image.
    public let values: [String: String]

    public init(
        id: String,
        title: String,
        subtitle: String? = nil,
        imageName: String? = nil,
        values: [String: String] = [:]
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.imageName = imageName
        self.values = values
    }
}

/// Read-only access to the entity list `app_intents` persists into App Group
/// `UserDefaults`.
///
/// The package writes this cache so that a generated `EntityQuery` can answer
/// on a cold start without waiting for the Flutter engine. App Extensions —
/// Widget Extensions in particular — cannot start a Flutter engine at all, so
/// for them this cache is the *only* way to reach the entity list. This type
/// exists so that reading it does not require hardcoding the package's internal
/// key naming.
///
/// ## Choosing the storage identifier
/// The raw `UserDefaults` key is namespaced with a *storage identifier*, which
/// the main app resolves in this order (see `AppIntentsPlugin.cachePrefix`):
///
/// 1. the `storageIdentifier` passed to `AppIntentsPlugin.configure(...)`,
/// 2. otherwise `Bundle.main.bundleIdentifier` of the **main app**.
///
/// An extension's `Bundle.main.bundleIdentifier` is the *extension's* bundle id
/// (`com.example.app.MyWidget`), not the app's, so it cannot be inferred here.
/// That is why ``storageIdentifier`` is a required initializer argument: pass
/// the host app's bundle identifier, or the explicit `storageIdentifier` if the
/// app configured one.
///
/// ## Example (Widget Extension)
/// ```swift
/// import AppIntentsBridge
///
/// let cache = AppIntentsEntityCache(
///     appGroupIdentifier: "group.com.example.app",
///     storageIdentifier: "com.example.app"
/// )
/// let teams = cache.entities(forEntityIdentifier: "com.example.joinedTeam")
/// ```
public struct AppIntentsEntityCache: Sendable {
    /// The prefix `app_intents` puts in front of every cache key.
    ///
    /// - Important: This must stay in sync with `AppIntentsPlugin.cachePrefix`
    ///   in `packages/app_intents/ios/.../AppIntentsPlugin.swift`. The two live
    ///   in separate modules (the plugin deliberately has no dependency on this
    ///   package), so the format is asserted by `EntityCacheTests`.
    private static let keyPrefix = "app_intents."
    private static let keyInfix = ".cache."

    /// The prefix codegen uses for the default per-entity cache key.
    private static let entityKeyPrefix = "app_intents.entities."

    /// The `UserDefaults` suite the cache is read from.
    ///
    /// `UserDefaults` is documented as thread-safe but is not marked `Sendable`,
    /// so the reference is opted out explicitly. This type only ever reads.
    nonisolated(unsafe) private let defaults: UserDefaults?

    /// The storage identifier used to namespace cache keys.
    public let storageIdentifier: String

    /// The App Group identifier the cache is read from, when constructed with
    /// one.
    public let appGroupIdentifier: String?

    /// Creates a reader over an App Group's shared `UserDefaults`.
    ///
    /// - Parameters:
    ///   - appGroupIdentifier: The App Group the main app passed to
    ///     `AppIntentsPlugin.configure(appGroupIdentifier:)`. The reading target
    ///     must carry the same App Groups entitlement.
    ///   - storageIdentifier: The main app's bundle identifier, or the explicit
    ///     `storageIdentifier` if `configure(...)` was given one. See the type
    ///     documentation — this cannot be inferred from an extension.
    public init(appGroupIdentifier: String, storageIdentifier: String) {
        self.appGroupIdentifier = appGroupIdentifier
        self.storageIdentifier = storageIdentifier
        self.defaults = UserDefaults(suiteName: appGroupIdentifier)
    }

    /// Creates a reader over an explicit `UserDefaults` instance.
    ///
    /// Useful when the App Group suite is already resolved, and in tests.
    public init(userDefaults: UserDefaults, storageIdentifier: String) {
        self.appGroupIdentifier = nil
        self.storageIdentifier = storageIdentifier
        self.defaults = userDefaults
    }

    // MARK: - Key derivation

    /// The cache key codegen uses by default for an entity identifier.
    ///
    /// This is the key the Dart side passes to
    /// `AppIntents().setCachedValue(key, value)` — not the raw `UserDefaults`
    /// key. It matches the default that `@EntitySpec(enumerable: true)` /
    /// `@EntitySpec(indexed: true)` generate when `persistedCacheKey` is unset.
    public static func defaultCacheKey(forEntityIdentifier identifier: String) -> String {
        "\(entityKeyPrefix)\(identifier)"
    }

    /// The raw `UserDefaults` key for a cache key.
    ///
    /// Use this when you want to read the value yourself (or observe it)
    /// instead of going through ``entries(forCacheKey:)``.
    public static func storageKey(
        forCacheKey cacheKey: String,
        storageIdentifier: String
    ) -> String {
        "\(keyPrefix)\(storageIdentifier)\(keyInfix)\(cacheKey)"
    }

    /// The raw `UserDefaults` key for a cache key, using this reader's
    /// storage identifier.
    public func storageKey(forCacheKey cacheKey: String) -> String {
        Self.storageKey(forCacheKey: cacheKey, storageIdentifier: storageIdentifier)
    }

    /// The raw `UserDefaults` key for an entity identifier using the default
    /// cache key.
    public func storageKey(forEntityIdentifier identifier: String) -> String {
        storageKey(forCacheKey: Self.defaultCacheKey(forEntityIdentifier: identifier))
    }

    // MARK: - Reading

    /// The raw cached payload for a cache key.
    ///
    /// The Dart side may write either a JSON string or a pre-decoded array of
    /// maps; both are accepted here. Returns an empty array when the key is
    /// absent or the payload cannot be decoded.
    public func entries(forCacheKey cacheKey: String) -> [[String: Any]] {
        guard let defaults else { return [] }
        // Pick up writes made by the main app's process.
        defaults.synchronize()

        guard let raw = defaults.object(forKey: storageKey(forCacheKey: cacheKey)) else {
            return []
        }
        if let array = raw as? [[String: Any]] {
            return array
        }
        if let jsonString = raw as? String,
           let data = jsonString.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return parsed
        }
        return []
    }

    /// The cached entities for a cache key.
    ///
    /// Entries missing the id or title field are dropped, mirroring the
    /// generated `EntityQuery` fallback.
    ///
    /// - Parameters:
    ///   - cacheKey: The key passed to `setCachedValue` from Dart.
    ///   - idKey: The entity's `@EntityId` field name. Defaults to `"id"`.
    ///   - titleKey: The entity's `@EntityTitle` field name. Defaults to `"title"`.
    ///   - subtitleKey: The entity's `@EntitySubtitle` field name, if any.
    ///   - imageKey: The entity's `@EntityImage` field name, if any.
    public func entities(
        forCacheKey cacheKey: String,
        idKey: String = "id",
        titleKey: String = "title",
        subtitleKey: String? = nil,
        imageKey: String? = nil
    ) -> [AppIntentsCachedEntity] {
        entries(forCacheKey: cacheKey).compactMap { dict in
            guard let id = dict[idKey] as? String,
                  let title = dict[titleKey] as? String
            else { return nil }

            var values: [String: String] = [:]
            for (key, value) in dict {
                if let string = value as? String {
                    values[key] = string
                }
            }

            return AppIntentsCachedEntity(
                id: id,
                title: title,
                subtitle: subtitleKey.flatMap { dict[$0] as? String },
                imageName: imageKey.flatMap { dict[$0] as? String },
                values: values
            )
        }
    }

    /// The cached entities for an entity identifier, using the default cache
    /// key (`app_intents.entities.<identifier>`).
    ///
    /// Pass `cacheKey` explicitly when the entity declares a custom
    /// `@EntitySpec(persistedCacheKey:)`.
    public func entities(
        forEntityIdentifier identifier: String,
        cacheKey: String? = nil,
        idKey: String = "id",
        titleKey: String = "title",
        subtitleKey: String? = nil,
        imageKey: String? = nil
    ) -> [AppIntentsCachedEntity] {
        entities(
            forCacheKey: cacheKey ?? Self.defaultCacheKey(forEntityIdentifier: identifier),
            idKey: idKey,
            titleKey: titleKey,
            subtitleKey: subtitleKey,
            imageKey: imageKey
        )
    }
}
