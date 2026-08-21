import Testing
import Foundation
@testable import AppIntentsBridge

@Suite("AppIntentsEntityCache Tests")
struct EntityCacheTests {

    /// Builds an isolated UserDefaults suite so tests never touch the real
    /// standard defaults.
    private func makeDefaults(_ name: String) -> UserDefaults {
        let defaults = UserDefaults(suiteName: "AppIntentsEntityCacheTests.\(name)")!
        defaults.removePersistentDomain(forName: "AppIntentsEntityCacheTests.\(name)")
        return defaults
    }

    // MARK: - Key derivation

    /// This is the contract with `AppIntentsPlugin.cachePrefix`. If the plugin's
    /// prefix format ever changes, this expectation must change with it —
    /// otherwise extensions silently read the wrong key.
    @Test("Storage key matches the plugin's app_intents.<storage>.cache.<key> format")
    func storageKeyFormat() {
        let key = AppIntentsEntityCache.storageKey(
            forCacheKey: "app_intents.entities.com.example.joinedTeam",
            storageIdentifier: "com.example.app"
        )

        #expect(key == "app_intents.com.example.app.cache.app_intents.entities.com.example.joinedTeam")
    }

    @Test("Default cache key matches the codegen default")
    func defaultCacheKey() {
        let key = AppIntentsEntityCache.defaultCacheKey(
            forEntityIdentifier: "com.example.joinedTeam"
        )

        #expect(key == "app_intents.entities.com.example.joinedTeam")
    }

    @Test("Instance storage key helpers use the configured storage identifier")
    func instanceStorageKeys() {
        let cache = AppIntentsEntityCache(
            userDefaults: makeDefaults("instanceKeys"),
            storageIdentifier: "com.example.app"
        )

        #expect(
            cache.storageKey(forCacheKey: "custom.key")
                == "app_intents.com.example.app.cache.custom.key"
        )
        #expect(
            cache.storageKey(forEntityIdentifier: "com.example.joinedTeam")
                == "app_intents.com.example.app.cache.app_intents.entities.com.example.joinedTeam"
        )
    }

    // MARK: - Reading

    @Test("Reads a JSON string payload")
    func readsJSONStringPayload() {
        let defaults = makeDefaults("jsonString")
        let cache = AppIntentsEntityCache(
            userDefaults: defaults,
            storageIdentifier: "com.example.app"
        )
        let json = """
        [{"id":"t1","title":"Team One"},{"id":"t2","title":"Team Two"}]
        """
        defaults.set(json, forKey: cache.storageKey(forEntityIdentifier: "com.example.joinedTeam"))

        let entities = cache.entities(forEntityIdentifier: "com.example.joinedTeam")

        #expect(entities.map(\.id) == ["t1", "t2"])
        #expect(entities.map(\.title) == ["Team One", "Team Two"])
    }

    @Test("Reads a pre-decoded array payload")
    func readsArrayPayload() {
        let defaults = makeDefaults("array")
        let cache = AppIntentsEntityCache(
            userDefaults: defaults,
            storageIdentifier: "com.example.app"
        )
        defaults.set(
            [["id": "t1", "title": "Team One"]],
            forKey: cache.storageKey(forEntityIdentifier: "com.example.joinedTeam")
        )

        let entities = cache.entities(forEntityIdentifier: "com.example.joinedTeam")

        #expect(entities.count == 1)
        #expect(entities.first?.id == "t1")
    }

    @Test("Honors custom field names and exposes every string field")
    func customFieldNames() {
        let defaults = makeDefaults("customFields")
        let cache = AppIntentsEntityCache(
            userDefaults: defaults,
            storageIdentifier: "com.example.app"
        )
        defaults.set(
            [[
                "teamId": "t1",
                "name": "Team One",
                "note": "subtitle text",
                "symbol": "person.3",
                "extra": "kept",
            ]],
            forKey: cache.storageKey(forCacheKey: "custom.key")
        )

        let entities = cache.entities(
            forCacheKey: "custom.key",
            idKey: "teamId",
            titleKey: "name",
            subtitleKey: "note",
            imageKey: "symbol"
        )

        #expect(entities.count == 1)
        let entity = entities[0]
        #expect(entity.id == "t1")
        #expect(entity.title == "Team One")
        #expect(entity.subtitle == "subtitle text")
        #expect(entity.imageName == "person.3")
        #expect(entity.values["extra"] == "kept")
    }

    @Test("Drops entries missing id or title")
    func dropsIncompleteEntries() {
        let defaults = makeDefaults("incomplete")
        let cache = AppIntentsEntityCache(
            userDefaults: defaults,
            storageIdentifier: "com.example.app"
        )
        defaults.set(
            #"[{"id":"t1"},{"title":"No id"},{"id":"t2","title":"Team Two"}]"#,
            forKey: cache.storageKey(forEntityIdentifier: "com.example.joinedTeam")
        )

        let entities = cache.entities(forEntityIdentifier: "com.example.joinedTeam")

        #expect(entities.map(\.id) == ["t2"])
    }

    @Test("Missing key and undecodable payloads return an empty list")
    func missingAndInvalidPayloads() {
        let defaults = makeDefaults("invalid")
        let cache = AppIntentsEntityCache(
            userDefaults: defaults,
            storageIdentifier: "com.example.app"
        )

        #expect(cache.entities(forEntityIdentifier: "com.example.missing").isEmpty)

        defaults.set("not json", forKey: cache.storageKey(forCacheKey: "broken"))
        #expect(cache.entities(forCacheKey: "broken").isEmpty)
        #expect(cache.entries(forCacheKey: "broken").isEmpty)
    }

    @Test("An unreachable App Group reports isAccessible == false")
    func unreachableAppGroup() {
        // On a device, a missing App Groups entitlement makes
        // UserDefaults(suiteName:) return nil. A test process is not sandboxed,
        // so an arbitrary suite name would succeed here; `NSGlobalDomain` is a
        // reserved name that is documented to return nil, which exercises the
        // same branch. Reads must stay safe, but the caller has to be able to
        // tell this apart from "the cache is empty".
        let cache = AppIntentsEntityCache(
            appGroupIdentifier: "NSGlobalDomain",
            storageIdentifier: "com.example.app"
        )

        #expect(cache.isAccessible == false)
        #expect(cache.entries(forCacheKey: "any").isEmpty)
        #expect(cache.entities(forEntityIdentifier: "com.example.missing").isEmpty)
        // Key derivation still works without storage.
        #expect(cache.storageKey(forCacheKey: "any") == "app_intents.com.example.app.cache.any")
    }

    @Test("A reachable suite reports isAccessible == true")
    func reachableSuite() {
        let cache = AppIntentsEntityCache(
            userDefaults: makeDefaults("reachable"),
            storageIdentifier: "com.example.app"
        )

        #expect(cache.isAccessible == true)
        // An empty result here genuinely means "nothing written yet".
        #expect(cache.entities(forEntityIdentifier: "com.example.missing").isEmpty)
    }

    @Test("A custom persistedCacheKey overrides the default key")
    func customPersistedCacheKey() {
        let defaults = makeDefaults("customKey")
        let cache = AppIntentsEntityCache(
            userDefaults: defaults,
            storageIdentifier: "com.example.app"
        )
        defaults.set(
            #"[{"id":"t1","title":"Team One"}]"#,
            forKey: cache.storageKey(forCacheKey: "com.example.taskapp.cache.teams")
        )

        let entities = cache.entities(
            forEntityIdentifier: "com.example.joinedTeam",
            cacheKey: "com.example.taskapp.cache.teams"
        )

        #expect(entities.map(\.title) == ["Team One"])
    }
}
