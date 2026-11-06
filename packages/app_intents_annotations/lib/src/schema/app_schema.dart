/// App Schema catalog (WWDC26, iOS 27+).
///
/// App Schemas describe an entity/intent/enum in a vocabulary Siri and Apple
/// Intelligence already understand. You pass a schema as a dotted
/// `'<domain>.<schema>'` string to `@EntitySpec(schema:)`,
/// `@IntentSpec(schema:)`, or `@EnumSpec(schema:)`; the generated Swift emits
/// the matching `@AppEntity(schema: .<domain>.<schema>)` macro.
///
/// The system matches schemas by their **raw identifier string**, so any
/// `'<domain>.<schema>'` value is accepted. This catalog exists so you don't
/// have to hand-write magic strings: it exposes the known domains as
/// [AppSchemaDomain] and a curated set of verified schema identifiers as
/// [AppSchemas]. The catalog is intentionally **not exhaustive** — Apple adds
/// schemas across OS versions — so a string that isn't listed here is still
/// valid. Use [AppSchemas.of] to build one for a schema this catalog doesn't
/// name yet.
///
/// Apple replaced the older `AssistantSchema` with `AppSchema`; the macro call
/// sites and identifier strings are identical, so this catalog applies to both.
library;

/// The known App Schema domains (the namespace before the dot, e.g. `messages`
/// in `messages.message`).
///
/// This list reflects the domains documented for the iOS 27 SDK. It may not be
/// exhaustive across future OS versions — an unknown domain string is still
/// accepted by the system.
enum AppSchemaDomain {
  /// `audio` — music and audio playback.
  audio('audio'),

  /// `books` — reading and book content.
  books('books'),

  /// `browser` — web browsing.
  browser('browser'),

  /// `calendar` — events and calendars.
  calendar('calendar'),

  /// `camera` — capture and camera control.
  camera('camera'),

  /// `clock` — alarms, timers, world clocks.
  clock('clock'),

  /// `imageGeneration` — image generation (e.g. Image Playground).
  imageGeneration('imageGeneration'),

  /// `journal` — journaling.
  journal('journal'),

  /// `mail` — email.
  mail('mail'),

  /// `maps` — places and navigation.
  maps('maps'),

  /// `messages` — messaging.
  messages('messages'),

  /// `notes` — note taking.
  notes('notes'),

  /// `phone` — calls and contacts.
  phone('phone'),

  /// `photos` — photo and video libraries.
  photos('photos'),

  /// `reader` — long-form reading.
  reader('reader'),

  /// `reminders` — tasks and reminders.
  reminders('reminders'),

  /// `spreadsheet` — spreadsheets.
  spreadsheet('spreadsheet'),

  /// `system` — system-level actions.
  system('system'),

  /// `video` — movies, TV shows and other video content.
  ///
  /// iOS / tvOS / visionOS **27.3** (unavailable on macOS and watchOS). The
  /// generated schema form is compiled only against a 27.3 SDK or newer (on
  /// top of `APP_INTENTS_WWDC26`); an older SDK gets the stable form, so a
  /// project that has not moved to 27.3 keeps compiling.
  video('video'),

  /// `visualIntelligence` — visual search integration.
  visualIntelligence('visualIntelligence'),

  /// `whiteboard` — freeform/whiteboard canvases.
  whiteboard('whiteboard'),

  /// `wordProcessor` — documents and word processing.
  wordProcessor('wordProcessor');

  const AppSchemaDomain(this.keyword);

  /// The dotted-path keyword (and Swift accessor) for this domain.
  final String keyword;

  /// Resolves a domain keyword (e.g. `'messages'`) to its [AppSchemaDomain],
  /// or `null` when the keyword is not a known domain.
  static AppSchemaDomain? fromKeyword(String keyword) {
    for (final domain in AppSchemaDomain.values) {
      if (domain.keyword == keyword) return domain;
    }
    return null;
  }
}

/// A curated, verified catalog of App Schema identifiers, grouped by domain.
///
/// Each value is the dotted `'<domain>.<schema>'` string you pass to
/// `@EntitySpec(schema:)` / `@IntentSpec(schema:)` / `@EnumSpec(schema:)`.
/// Example:
///
/// ```dart
/// @EntitySpec(identifier: '…', title: '…', pluralTitle: '…',
///     schema: AppSchemas.messages.message)
/// ```
///
/// Not every schema is listed (the set grows with each OS). For one this
/// catalog doesn't name, pass the raw string or use [AppSchemas.of]:
///
/// ```dart
/// schema: AppSchemas.of(AppSchemaDomain.calendar, 'event')
/// ```
abstract final class AppSchemas {
  /// Builds a `'<domain>.<schema>'` identifier for a schema not named in this
  /// catalog. The [schema] name must match Apple's documented schema for the
  /// domain (the system matches by string).
  static String of(AppSchemaDomain domain, String schema) =>
      '${domain.keyword}.$schema';

  /// Schemas in the `messages` domain.
  static const MessagesSchemas messages = MessagesSchemas._();

  /// Schemas in the `mail` domain.
  static const MailSchemas mail = MailSchemas._();

  /// Schemas in the `photos` domain.
  static const PhotosSchemas photos = PhotosSchemas._();

  /// Schemas in the `system` domain.
  static const SystemSchemas system = SystemSchemas._();

  /// Schemas in the `video` domain (iOS / tvOS / visionOS 27.3+).
  static const VideoSchemas video = VideoSchemas._();
}

/// Verified schemas in the `messages` domain.
final class MessagesSchemas {
  const MessagesSchemas._();

  /// `messages.message` — a message entity (`@AppEntity`).
  String get message => 'messages.message';

  /// `messages.messagePerson` — a message participant entity (`@AppEntity`).
  String get messagePerson => 'messages.messagePerson';

  /// `messages.sendMessage` — send a message (`@AppIntent`).
  String get sendMessage => 'messages.sendMessage';

  /// `messages.unsendMessage` — unsend a sent message (`@AppIntent`).
  String get unsendMessage => 'messages.unsendMessage';

  /// `messages.editSentMessage` — edit a sent message (`@AppIntent`).
  String get editSentMessage => 'messages.editSentMessage';

  /// `messages.setMessageReadStatus` — set read status (`@AppIntent`).
  String get setMessageReadStatus => 'messages.setMessageReadStatus';

  /// `messages.messageType` — message type (`@AppEnum`).
  String get messageType => 'messages.messageType';

  /// `messages.messageEffect` — message effect (`@AppEnum`).
  String get messageEffect => 'messages.messageEffect';

  /// `messages.messageAttribute` — message attribute (`@AppEnum`).
  String get messageAttribute => 'messages.messageAttribute';
}

/// Verified schemas in the `mail` domain.
final class MailSchemas {
  const MailSchemas._();

  /// `mail.message` — an email message entity (`@AppEntity`).
  String get message => 'mail.message';

  /// `mail.openMessage` — open an email message (`@AppIntent`).
  String get openMessage => 'mail.openMessage';
}

/// Verified schemas in the `photos` domain.
final class PhotosSchemas {
  const PhotosSchemas._();

  /// `photos.asset` — a photo/video asset entity (`@AppEntity`).
  String get asset => 'photos.asset';

  /// `photos.recognizedPerson` — a person recognized in an asset (`@AppEntity`).
  String get recognizedPerson => 'photos.recognizedPerson';

  /// `photos.search` — search the media library (`@AppIntent`).
  String get search => 'photos.search';

  /// `photos.openAsset` — open an asset (`@AppIntent`).
  String get openAsset => 'photos.openAsset';

  /// `photos.crop` — crop an asset (`@AppIntent`).
  String get crop => 'photos.crop';

  /// `photos.postToSharedAlbum` — post an asset to a shared album (`@AppIntent`).
  String get postToSharedAlbum => 'photos.postToSharedAlbum';

  /// `photos.createAssets` — create assets from files (`@AppIntent`).
  String get createAssets => 'photos.createAssets';

  /// `photos.assetType` — asset type (`@AppEnum`).
  String get assetType => 'photos.assetType';
}

/// Verified schemas in the `system` domain.
final class SystemSchemas {
  const SystemSchemas._();

  /// `system.searchInApp` — re-run the user's search inside your app's own
  /// search UI (`@AppIntent`, iOS 27+).
  ///
  /// iOS 17 exposed this as `system.search`; iOS 27 renamed it to
  /// `system.searchInApp`. Use the OS-appropriate identifier for the iOS
  /// version you target; this catalog exposes the iOS 27 name. For the iOS 17
  /// fallback identifier, use `AppSchemas.of(AppSchemaDomain.system, 'search')`.
  String get searchInApp => 'system.searchInApp';

  /// `system.open` — open a target entity in your app (`@AppIntent`, iOS 17+).
  String get open => 'system.open';
}

/// Verified schemas in the `video` domain (iOS / tvOS / visionOS 27.3+, not
/// macOS or watchOS).
///
/// The schema form is compiled only with `APP_INTENTS_WWDC26` set and a 27.3
/// SDK or newer; otherwise the stable form is. See [AppSchemaDomain.video].
final class VideoSchemas {
  const VideoSchemas._();

  /// `video.addToWatchList` — add content to the watch list (`@AppIntent`).
  String get addToWatchList => 'video.addToWatchList';

  /// `video.removeFromWatchList` — remove content from the watch list
  /// (`@AppIntent`).
  String get removeFromWatchList => 'video.removeFromWatchList';

  /// `video.playContent` — play a movie, show or video (`@AppIntent`).
  String get playContent => 'video.playContent';

  /// `video.playTrailer` — play a trailer (`@AppIntent`).
  String get playTrailer => 'video.playTrailer';

  /// `video.movie` — a movie (`@AppEntity`).
  String get movie => 'video.movie';

  /// `video.tvShow` — a TV show (`@AppEntity`).
  String get tvShow => 'video.tvShow';

  /// `video.tvSeason` — a season of a TV show (`@AppEntity`).
  String get tvSeason => 'video.tvSeason';

  /// `video.tvEpisode` — an episode of a TV show (`@AppEntity`).
  String get tvEpisode => 'video.tvEpisode';

  /// `video.freeformVideo` — a video that is not a movie or episode
  /// (`@AppEntity`).
  String get freeformVideo => 'video.freeformVideo';

  /// `video.image` — artwork for video content (`@AppEntity`).
  String get image => 'video.image';

  /// `video.contentCreator` — a creator or channel (`@AppEntity`).
  String get contentCreator => 'video.contentCreator';

  /// `video.person` — a cast or crew member (`@AppEntity`).
  String get person => 'video.person';

  /// `video.videoContentType` — kind of video content (`@AppEnum`).
  String get videoContentType => 'video.videoContentType';

  /// `video.imageType` — kind of artwork (`@AppEnum`).
  String get imageType => 'video.imageType';

  /// `video.personRole` — a person's role (`@AppEnum`).
  String get personRole => 'video.personRole';
}
