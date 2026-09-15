/// Marks a `sealed` Dart class as a WWDC26 App Intents union value (#53).
///
/// A union value lets a single intent parameter accept one of several entity
/// types. Declare a `sealed` base class with this annotation, then one
/// subclass per case annotated with [UnionCase]:
///
/// ```dart
/// @UnionValueSpec(identifier: 'com.example.GalleryContent')
/// sealed class GalleryContent {
///   const GalleryContent();
/// }
///
/// @UnionCase(entityType: 'PhotoEntity')
/// class PhotoContent extends GalleryContent {
///   final String id;
///   const PhotoContent(this.id);
/// }
///
/// @UnionCase(entityType: 'AlbumEntity')
/// class AlbumContent extends GalleryContent {
///   final String id;
///   const AlbumContent(this.id);
/// }
/// ```
///
/// The generated Swift uses the native iOS 27 `@UnionValue enum` (behind the
/// `rich-types` experimental feature); without it, a parameter of the union
/// type degrades to the first case's entity type.
class UnionValueSpec {
  /// A unique identifier for the union (reverse-DNS recommended).
  final String identifier;

  /// An optional human-readable title.
  final String? title;

  /// **Experimental (WWDC26, iOS 27+).** Whether to generate an
  /// `IntentValueQuery` returning this union (#133).
  ///
  /// One query that can answer with *several* entity types — the shape visual
  /// and free-text search need, since an app gets a single query per input
  /// type. The Dart handler is registered under [identifier] with
  /// `registerValueQueryHandler` and returns maps carrying a `_type` key naming
  /// the `@UnionCase` subclass, alongside that case entity's own fields.
  ///
  /// Rides the `rich-types` feature, like the union type itself.
  final bool valueQuery;

  const UnionValueSpec({
    required this.identifier,
    this.title,
    this.valueQuery = false,
  });
}

/// Marks a subclass of a [UnionValueSpec] `sealed` class as one union case.
///
/// Each case wraps a single App Entity. By convention the subclass has one
/// positional `String id` field holding the entity identifier.
class UnionCase {
  /// The Swift App Entity type for this case (e.g. 'PhotoEntity').
  final String entityType;

  const UnionCase({required this.entityType});
}
