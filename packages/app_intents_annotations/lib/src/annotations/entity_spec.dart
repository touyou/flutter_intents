import 'entity_export.dart';
import 'entity_ownership.dart';

/// Annotation to specify an entity with its metadata.
class EntitySpec {
  /// A unique identifier for the entity.
  final String identifier;

  /// A human-readable title for the entity.
  final String title;

  /// A human-readable plural title for the entity.
  final String pluralTitle;

  /// An optional description of the entity.
  final String? description;

  /// Optional asset image name for entity display representation.
  ///
  /// Generates `DisplayRepresentation` with
  /// `.init(named: displayImageName, isTemplate: true)` image.
  final String? displayImageName;

  /// Whether to generate `IndexedEntity` conformance for Spotlight search.
  ///
  /// Generates `@available(iOS 26.0, *)` extension with `CSSearchableItemAttributeSet`.
  final bool indexed;

  /// Whether to generate `EnumerableEntityQuery` conformance.
  ///
  /// Generates an extension with `allEntities()` that delegates to `suggestedEntities()`.
  final bool enumerable;

  /// Cache key used by the generated Swift `EntityQuery` to look up the entity
  /// list before waiting on the Flutter executor.
  ///
  /// This is the key passed to `AppIntents().setCachedValue(key, value)` from
  /// Dart — not the raw `UserDefaults` key (the plugin internally namespaces
  /// it under `app_intents.<bundleId>.cache.`).
  ///
  /// ## Payload shape
  /// The value written from Dart must be either:
  /// - A `String` containing JSON of `List<Map<String, dynamic>>`, or
  /// - A pre-decoded `List<Map<String, dynamic>>` (passes through the
  ///   MethodChannel as `[[String: Any]]` on the Swift side).
  ///
  /// Each map must contain string-typed keys matching the entity's annotated
  /// field names (`@EntityId`, `@EntityTitle`, `@EntitySubtitle`,
  /// `@EntityImage`). Maps missing the id or title fields are silently
  /// dropped. Use entity field names, **not** the underlying model's field
  /// names — they often differ.
  ///
  /// ## Cold-start motivation
  /// When iOS kills the host app and Siri/Shortcuts fires an EntityQuery,
  /// `FlutterBridge` waits up to 5 seconds for the Flutter executor to be
  /// registered. On a real cold start, that timeout can be exhausted before
  /// the engine is ready, surfacing as a generic "internal error". The cache
  /// lookup runs synchronously and short-circuits this path when the data is
  /// already in App Group UserDefaults.
  ///
  /// ## Default key
  /// When unset but [enumerable] or [indexed] is `true`, codegen uses
  /// `app_intents.entities.<identifier>` as the default cache key. The Dart
  /// side must call `setCachedValue` with that exact string. When unset and
  /// neither flag is true, no fallback is generated and the Flutter executor
  /// must be available.
  final String? persistedCacheKey;

  /// **Experimental (WWDC26, iOS 27+).** The App Schema this entity conforms to,
  /// as a dotted `domain.schema` path (e.g. `'messages.message'`).
  ///
  /// When experimental code generation is enabled, the generated Swift adds the
  /// `@AppEntity(schema: .messages.message)` macro so the entity is described in
  /// a vocabulary Siri/Apple Intelligence already understands. Emitted in a
  /// `#if APP_INTENTS_WWDC26` block with a stable `@AppEntity`-only fallback.
  /// Has no effect unless experimental generation is enabled.
  final String? schema;

  /// **Experimental (WWDC26, iOS 27+).** The ownership state of this entity.
  ///
  /// When experimental code generation is enabled (the `ownership` feature),
  /// the generated Swift adds an `OwnershipProvidingEntity` conformance
  /// declaring `var ownership: EntityOwnership`. Emitted in a
  /// `#if APP_INTENTS_WWDC26` block. Has no effect unless experimental
  /// generation is enabled.
  final EntityOwnershipState? ownership;

  /// **Experimental (WWDC26, iOS 27+).** Whether to generate an
  /// `IntentValueQuery`-conforming type for this entity (#51).
  ///
  /// An `IntentValueQuery` receives a serializable search input (e.g. a text
  /// query) from the system — for content that is hard to index ahead of time
  /// (large, server-side, or fast-changing) — and returns matching entities.
  /// Unlike [enumerable]/the default `EntityQuery`, it can take an arbitrary
  /// search input.
  ///
  /// When the `value-query` experimental feature is enabled, the generated
  /// Swift adds a `<Entity>ValueQuery: IntentValueQuery` struct (in a
  /// `#if APP_INTENTS_WWDC26` block) whose `values(for:)` delegates to a Dart
  /// handler via `FlutterBridge.shared.queryValues`. The Dart side registers
  /// the handler with `AppIntents().registerValueQueryHandler` — emitted
  /// whenever this flag is set (it references no iOS-version-specific symbol,
  /// so it is safe to ship unconditionally; an unused registration is
  /// harmless until the Swift side is enabled).
  ///
  /// The visual (`SemanticContentDescriptor`/pixel-buffer) variant is out of
  /// scope (#58, native-only). See `docs/adr/0001-intent-value-query-bridge.md`.
  final bool valueQuery;

  /// **Experimental (WWDC26, iOS 27+).** The system structured type this entity
  /// is exported as for cross-app sharing (#54).
  ///
  /// When the `value-representation` experimental feature is enabled, the
  /// generated Swift adds a `Transferable` conformance with
  /// `ValueRepresentation(exporting:)` (in a `#if APP_INTENTS_WWDC26` block) so
  /// the entity can be handed to other apps in a system-understood form.
  ///
  /// [EntityExportType.person] builds an `IntentPerson` from the entity's
  /// `@EntityId`/`@EntityTitle` fields — no extra Dart-side data needed. Other
  /// catalog entries (e.g. `PlaceDescriptor`) are added as they gain a Dart
  /// representation. See `docs/adr/0002-cross-app-entity-sharing.md`.
  final EntityExportType? exportAs;

  const EntitySpec({
    required this.identifier,
    required this.title,
    required this.pluralTitle,
    this.description,
    this.displayImageName,
    this.indexed = false,
    this.enumerable = false,
    this.persistedCacheKey,
    this.schema,
    this.ownership,
    this.valueQuery = false,
    this.exportAs,
  });
}
