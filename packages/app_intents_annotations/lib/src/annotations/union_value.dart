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

  const UnionValueSpec({required this.identifier, this.title});
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
