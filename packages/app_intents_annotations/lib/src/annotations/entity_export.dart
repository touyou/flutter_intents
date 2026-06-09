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
/// See `docs/adr/0002-cross-app-entity-sharing.md`.
enum EntityExportType {
  /// Export the entity as an `IntentPerson`, built from the entity's
  /// `@EntityId` (→ `.applicationDefined`) and `@EntityTitle`
  /// (→ `.displayName`) fields. Suitable for entities that represent people
  /// — contacts, recipients, participants.
  ///
  /// This is the catalog's starting point because it can be constructed from an
  /// entity's existing id/title fields with no extra Dart-side data. Other
  /// system types (e.g. `PlaceDescriptor`) need structured fields the entity
  /// does not carry today, so they are added as the catalog grows.
  person,
}
