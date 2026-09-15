import 'entity_export.dart';

/// Annotations for marking entity parameters in intent specifications.
class EntityId {
  const EntityId();
}

/// Annotations for marking entity parameters in intent specifications.
class EntityTitle {
  const EntityTitle();
}

/// Annotations for marking entity parameters in intent specifications.
class EntitySubtitle {
  const EntitySubtitle();
}

/// Annotations for marking entity parameters in intent specifications.
class EntityImage {
  const EntityImage();
}

/// Marks the entity field holding the **stable**, cross-device identifier of a
/// `@EntitySpec(syncable: true)` entity (#132).
///
/// Use this only when the entity's `@EntityId` is *local* — assigned by this
/// device or this install — and a second, server-assigned identifier is what
/// stays the same everywhere. Declaring it turns the generated entity's Swift
/// `id` into `SyncableEntityIdentifier<String, String>`, so Siri can carry a
/// reference to the entity from one device to another.
///
/// When the `@EntityId` is *already* stable (a server UUID), do **not** declare
/// this: `@EntitySpec(syncable: true)` alone is enough and costs nothing.
///
/// Requires `syncable: true` and the `donation` experimental feature; the
/// generated entity dual-branches, because `SyncableEntityIdentifier` is iOS
/// 27 only. A dual-id entity cannot currently be used as an
/// `@IntentParam(entityType:)` value — codegen rejects that combination rather
/// than putting a non-serializable identifier on the wire.
class EntityStableId {
  const EntityStableId();
}

/// Annotations for marking entity parameters in intent specifications.
class EntityDefaultQuery {
  const EntityDefaultQuery();
}

/// Marks an entity field to be exposed to the system as a Swift `@Property`.
///
/// Use this for semantic properties beyond the id/title/subtitle/image roles —
/// for example a message body or note that Spotlight and Apple Intelligence
/// should be able to search.
///
/// - [title]: optional human-readable title (`@Property(title: "Body")`).
/// - [indexingKey]: a `CSSearchableItemAttributeSet` key path name (without the
///   leading `\.`), e.g. `'contentDescription'`. When set, generates
///   `@Property(indexingKey: \.contentDescription)` for semantic indexing
///   (iOS 18.4+). The generated entity gets an explicit initializer because the
///   `@Property` wrapper has no `init(wrappedValue:)`.
class EntityProperty {
  /// An optional human-readable title for the property.
  final String? title;

  /// A `CSSearchableItemAttributeSet` key path name for semantic indexing.
  final String? indexingKey;

  const EntityProperty({this.title, this.indexingKey});
}

/// Marks an entity field as supplying part of a structured **export** value
/// (#54, #128).
///
/// Unlike [EntityProperty] — which exposes a field to Spotlight / Apple
/// Intelligence as a Swift `@Property` — this only tells the code generator
/// which field to read when building the system type named by
/// `@EntitySpec(exportAs:)`. The field becomes a plain stored property on the
/// generated Swift entity and is populated from the same entity dictionary the
/// queries already return, so the Dart cache projection must include it.
///
/// ```dart
/// @EntitySpec(identifier: '…', title: 'Store', pluralTitle: 'Stores',
///             exportAs: EntityExportType.place)
/// class StoreEntitySpec extends EntitySpecBase<Store> {
///   @EntityId final String id;
///   @EntityTitle final String name;
///   @EntityExportField(EntityExportRole.latitude) final double? lat;
///   @EntityExportField(EntityExportRole.longitude) final double? lng;
/// }
/// ```
class EntityExportField {
  /// The part this field plays in the structured export.
  final EntityExportRole role;

  const EntityExportField(this.role);
}
