/// The ownership state of an entity.
///
/// Maps to the WWDC26 `EntityOwnership` option set (iOS 27+). Declaring an
/// entity's ownership lets Siri/Apple Intelligence decide whether an intent
/// with side effects needs explicit confirmation.
///
/// This is an **experimental WWDC26 feature**: the generated
/// `OwnershipProvidingEntity` conformance is only emitted when experimental
/// code generation is enabled, wrapped in `#if APP_INTENTS_WWDC26`.
enum EntityOwnershipState {
  /// Ownership is unknown. Generates `.unknown`.
  unknown,

  /// The entity is shared with others. Generates `.shared`.
  shared,

  /// The entity is public. Generates `.public`.
  public,
}
