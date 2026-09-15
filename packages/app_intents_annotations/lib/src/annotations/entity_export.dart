/// The system structured type an entity can be exported as for cross-app
/// sharing (#54).
///
/// Maps to the WWDC26 `ValueRepresentation`/`Transferable` export of an entity
/// as a system-understood intent value, so other apps and system features
/// (Maps, Contacts, etc.) can receive it. Declaring an export lets the system
/// transfer your entity across app boundaries in a structured form.
///
/// This is an **experimental WWDC26 feature**: the generated `Transferable`
/// conformance with `ValueRepresentation(exporting:)` is only emitted when the
/// `value-representation` experimental feature is enabled, wrapped in
/// `#if APP_INTENTS_WWDC26`.
///
/// ## The catalog is closed by the SDK, not by this package
/// `ValueRepresentation(exporting:)` exists only for `IntentPerson` (a
/// special-cased overload) and for types conforming to the underscored
/// `_SystemIntentValue` protocol. Measured against the iOS 27.0 SDK, that is
/// `GeoToolbox.PlaceDescriptor`, `LinkPresentation.LinkMetadata`,
/// `MediaIntents.AudioSearch`, `Photos.PHAsset`,
/// `VisualIntelligence.SemanticContentDescriptor`, `IntentPrompt` and
/// `SystemShortcut` — **not** `IntentCurrencyAmount`, `IntentFile` or
/// `EntityCollection`, which are only `_IntentValue`. A type existing in the
/// SDK is not enough to make it exportable.
///
/// See `docs/adr/0002-cross-app-entity-sharing.md`.
enum EntityExportType {
  /// Export the entity as an `IntentPerson`, built from the entity's
  /// `@EntityId` (→ `.applicationDefined`) and `@EntityTitle`
  /// (→ `.displayName`) fields. Suitable for entities that represent people
  /// — contacts, recipients, participants.
  ///
  /// This is the catalog's starting point because it can be constructed from an
  /// entity's existing id/title fields with no extra Dart-side data. The other
  /// entries need structured fields the entity does not carry by default, which
  /// is what [EntityExportRole] supplies.
  person,

  /// Export the entity as a `GeoToolbox.PlaceDescriptor` — the type Maps and
  /// the location-aware App Schemas accept.
  ///
  /// Requires the entity to designate its location fields with
  /// [EntityExportRole.latitude] + [EntityExportRole.longitude], and/or
  /// [EntityExportRole.address]. Either representation is enough on its own;
  /// when both are declared both are exported. The entity's `@EntityTitle`
  /// becomes the descriptor's `commonName`.
  ///
  /// `PlaceDescriptor` lives in **GeoToolbox** — the `AppIntents` type of the
  /// same name was deprecated in iOS 16 — and is iOS 26.0+.
  place,
}

/// The part an entity field plays when the entity is exported as a system
/// structured type (#54, #128).
///
/// The id/title/subtitle/image roles describe how an entity *displays*; these
/// describe the data a structured export needs and the display roles cannot
/// supply. Attach one with [EntityExportField].
enum EntityExportRole {
  /// Decimal degrees latitude (`double`/`double?`), paired with [longitude] to
  /// build `PlaceDescriptor.PlaceRepresentation.coordinate`.
  latitude,

  /// Decimal degrees longitude (`double`/`double?`), paired with [latitude].
  longitude,

  /// A postal or free-form address (`String`/`String?`), exported as
  /// `PlaceDescriptor.PlaceRepresentation.address`.
  address,
}
