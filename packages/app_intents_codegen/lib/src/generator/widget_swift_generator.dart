import 'package:source_gen/source_gen.dart';

import '../models/entity_info.dart';
import '../models/widget_configuration_info.dart';

/// Generates Swift code for a **WidgetKit Widget Extension** target from
/// `@WidgetConfigurationSpec` declarations (#98).
///
/// ## Why this is a separate generator
/// A Widget Extension cannot start a Flutter engine, so none of the
/// `FlutterBridge` machinery the main [SwiftGenerator] emits can run there. The
/// output of this generator is therefore fully static: entity lists are read
/// synchronously from the App Group cache that `app_intents` already persists
/// for the cold-start fallback, through the public `AppIntentsEntityCache` API
/// in the `AppIntentsBridge` Swift package (#97).
///
/// ## Target separation is mandatory
/// The generated file must be added **only** to the Widget Extension target.
/// Compiling the same App Intent type into both the app and the extension
/// duplicates it in `Metadata.appIntents`, and iOS then fails to resolve the
/// intent at runtime. That is why the entity types generated here are named
/// `<Entity>WidgetEntity` rather than reusing the app target's names: even if
/// both files end up in one target by mistake, the failure is a compile error
/// rather than a silent runtime one.
class WidgetSwiftGenerator {
  /// Creates a widget Swift generator.
  ///
  /// [appGroupIdentifier] is the App Group the main app passed to
  /// `AppIntentsPlugin.configure(appGroupIdentifier:)`. [storageIdentifier] is
  /// the **main app's** bundle identifier (or the explicit `storageIdentifier`
  /// if `configure(...)` was given one) — an extension's own
  /// `Bundle.main.bundleIdentifier` is different, so it cannot be inferred at
  /// runtime.
  const WidgetSwiftGenerator({
    required this.appGroupIdentifier,
    required this.storageIdentifier,
  });

  /// The App Group identifier the generated queries read from.
  final String appGroupIdentifier;

  /// The storage identifier used to namespace cache keys.
  final String storageIdentifier;

  /// Indentation used for generated Swift code.
  static const _indent = '    ';

  /// Availability of everything generated here.
  ///
  /// `WidgetConfigurationIntent` and `EnumerableEntityQuery` are both iOS 17+,
  /// which is also the package minimum.
  static const _availability = '@available(iOS 17.0, *)';

  /// The name of the generated storage-configuration enum.
  static const cacheConfigName = 'GeneratedWidgetEntityCache';

  /// Mapping of Dart scalar types to Swift types for plain parameters.
  static const _typeMapping = <String, String>{
    'String': 'String',
    'int': 'Int',
    'double': 'Double',
    'bool': 'Bool',
    'DateTime': 'Date',
  };

  /// The generated Swift entity type name for an entity spec class.
  static String widgetEntityName(String entityClassName) =>
      '${entityClassName}WidgetEntity';

  /// The generated Swift query type name for an entity spec class.
  static String widgetQueryName(String entityClassName) =>
      '${entityClassName}WidgetQuery';

  /// Generates the complete Swift file for [configurations].
  ///
  /// [entities] must contain every `@EntitySpec` referenced by a
  /// `@WidgetParameter`; referenced entities that are missing, or that persist
  /// no cache, raise an [InvalidGenerationSourceError].
  String generateAll({
    required List<WidgetConfigurationInfo> configurations,
    required List<EntityInfo> entities,
  }) {
    final entitiesByName = {for (final e in entities) e.className: e};
    final referenced = _referencedEntities(configurations, entitiesByName);

    final buffer = StringBuffer();
    buffer.writeln('import AppIntents');
    buffer.writeln('import AppIntentsBridge');
    buffer.writeln();

    _writeCacheConfiguration(buffer);

    for (final entity in referenced) {
      buffer.writeln();
      _writeWidgetEntity(buffer, entity);
      buffer.writeln();
      _writeWidgetQuery(buffer, entity, configurations);
    }

    for (final config in configurations) {
      buffer.writeln();
      _writeConfigurationIntent(buffer, config);
    }

    return buffer.toString();
  }

  /// The entities referenced by [configurations], in a stable order, validated
  /// against [entitiesByName].
  List<EntityInfo> _referencedEntities(
    List<WidgetConfigurationInfo> configurations,
    Map<String, EntityInfo> entitiesByName,
  ) {
    final seen = <String>{};
    final result = <EntityInfo>[];

    for (final config in configurations) {
      for (final param in config.parameters) {
        final entityType = param.entityType;
        if (entityType == null || !seen.add(entityType)) continue;

        final entity = entitiesByName[entityType];
        if (entity == null) {
          throw InvalidGenerationSourceError(
            'Widget parameter `${config.className}.${param.name}` references '
            'entity type `$entityType`, but no @EntitySpec class with that '
            'name was found. Declare the entity with @EntitySpec, or drop the '
            'entityType so the parameter is generated as a plain value.',
          );
        }
        if (entity.effectiveCacheKey == null) {
          throw InvalidGenerationSourceError(
            'Widget parameter `${config.className}.${param.name}` references '
            'entity `$entityType`, which persists no entity cache. A Widget '
            'Extension cannot start a Flutter engine, so the generated query '
            'can only read the App Group cache. Add '
            '`enumerable: true` or an explicit `persistedCacheKey:` to '
            '@EntitySpec on `$entityType`, and write the entity list from Dart '
            'with AppIntents().setCachedValue.',
          );
        }
        result.add(entity);
      }
    }

    return result;
  }

  /// Writes the enum holding the App Group storage configuration.
  void _writeCacheConfiguration(StringBuffer buffer) {
    buffer.writeln('/// App Group storage the generated widget queries read.');
    buffer.writeln('///');
    buffer.writeln(
      '/// These values are baked in at generation time from the '
      '`--app-group` and',
    );
    buffer.writeln(
      '/// `--storage-identifier` options. The storage identifier is the '
      '**main app\'s**',
    );
    buffer.writeln(
      '/// bundle identifier (or the explicit `storageIdentifier` passed to',
    );
    buffer.writeln(
      '/// `AppIntentsPlugin.configure`) — this extension\'s own bundle '
      'identifier is',
    );
    buffer.writeln('/// different and would read the wrong key.');
    buffer.writeln('enum $cacheConfigName {');
    buffer.writeln(
      '${_indent}static let appGroupIdentifier = "${_swiftLiteral(appGroupIdentifier)}"',
    );
    buffer.writeln(
      '${_indent}static let storageIdentifier = "${_swiftLiteral(storageIdentifier)}"',
    );
    buffer.writeln();
    buffer.writeln('${_indent}static var cache: AppIntentsEntityCache {');
    buffer.writeln('$_indent${_indent}AppIntentsEntityCache(');
    buffer.writeln(
      '$_indent$_indent${_indent}appGroupIdentifier: appGroupIdentifier,',
    );
    buffer.writeln(
      '$_indent$_indent${_indent}storageIdentifier: storageIdentifier',
    );
    buffer.writeln('$_indent$_indent)');
    buffer.writeln('$_indent}');
    buffer.writeln('}');
  }

  /// Writes the cache-backed `AppEntity` struct for [info].
  void _writeWidgetEntity(StringBuffer buffer, EntityInfo info) {
    final entityName = widgetEntityName(info.className);
    final props = _cacheBackedProperties(info);

    buffer.writeln('/// Widget Extension entity for `${info.className}`.');
    buffer.writeln('///');
    buffer.writeln(
      '/// Backed by the App Group entity cache — see $cacheConfigName.',
    );
    buffer.writeln(_availability);
    buffer.writeln('struct $entityName: AppEntity {');
    buffer.writeln(
      '$_indent'
      'static var typeDisplayRepresentation: TypeDisplayRepresentation =',
    );
    buffer.writeln(
      '$_indent$_indent'
      'TypeDisplayRepresentation(name: "${_swiftLiteral(info.title)}")',
    );
    buffer.writeln();
    buffer.writeln(
      '${_indent}static var defaultQuery = '
      '${widgetQueryName(info.className)}()',
    );
    buffer.writeln();

    for (final entry in props.entries) {
      buffer.writeln(
        '${_indent}var ${_swiftPropertyName(entry.key, entry.value)}: '
        '${_swiftType(entry.value.dartType)}',
      );
    }

    buffer.writeln();
    _writeDisplayRepresentation(buffer, info, props);
    buffer.writeln('}');
  }

  /// Writes the `EnumerableEntityQuery` struct for [info].
  void _writeWidgetQuery(
    StringBuffer buffer,
    EntityInfo info,
    List<WidgetConfigurationInfo> configurations,
  ) {
    final entityName = widgetEntityName(info.className);
    final queryName = widgetQueryName(info.className);
    final props = _cacheBackedProperties(info);

    buffer.writeln('/// Reads `${info.className}` values from the App Group');
    buffer.writeln('/// cache the host app persists.');
    buffer.writeln(_availability);
    buffer.writeln('struct $queryName: EnumerableEntityQuery {');
    buffer.writeln(
      '$_indent/// App Group cache key written from Dart via setCachedValue.',
    );
    buffer.writeln(
      '${_indent}static let cacheKey = "${_swiftLiteral(info.effectiveCacheKey!)}"',
    );
    buffer.writeln();

    buffer.writeln(
      '${_indent}func allEntities() async throws -> [$entityName] {',
    );
    buffer.writeln('$_indent${_indent}Self.cachedEntities()');
    buffer.writeln('$_indent}');
    buffer.writeln();

    buffer.writeln(
      '${_indent}func entities(for identifiers: [String]) async throws '
      '-> [$entityName] {',
    );
    buffer.writeln('$_indent${_indent}let all = Self.cachedEntities()');
    buffer.writeln(
      '$_indent${_indent}return identifiers.compactMap { identifier in',
    );
    buffer.writeln(
      '$_indent$_indent${_indent}all.first { \$0.id == identifier }',
    );
    buffer.writeln('$_indent$_indent}');
    buffer.writeln('$_indent}');

    // `defaultResult()` bakes a value into an unedited widget instance at the
    // moment it is added, which breaks the "unconfigured widgets follow the
    // app's global setting" fallback — so it is opt-in per configuration.
    if (_wantsDefaultResult(info, configurations)) {
      buffer.writeln();
      buffer.writeln(
        '$_indent/// Pre-fills an unconfigured widget instance with the first',
      );
      buffer.writeln(
        '$_indent/// cached entity, captured when the widget is added.',
      );
      buffer.writeln('${_indent}func defaultResult() async -> $entityName? {');
      buffer.writeln('$_indent${_indent}Self.cachedEntities().first');
      buffer.writeln('$_indent}');
    }

    buffer.writeln();
    _writeCachedEntitiesReader(buffer, info, props);
    buffer.writeln('}');
  }

  /// Whether the query for [info] should implement `defaultResult()`.
  ///
  /// Only one query is generated per entity, so the per-configuration
  /// `generateDefaultResult` flag cannot differ between configurations that
  /// share an entity — one of them would silently get behavior it did not ask
  /// for. Disagreement is rejected here instead of resolved arbitrarily.
  bool _wantsDefaultResult(
    EntityInfo info,
    List<WidgetConfigurationInfo> configurations,
  ) {
    final sharing = configurations
        .where(
          (config) => config.referencedEntityTypes.contains(info.className),
        )
        .toList();
    if (sharing.isEmpty) return false;

    final wants = sharing.where((c) => c.generateDefaultResult).toList();
    if (wants.isEmpty) return false;
    if (wants.length == sharing.length) return true;

    final optedOut = sharing.where((c) => !c.generateDefaultResult);
    throw InvalidGenerationSourceError(
      'Entity `${info.className}` is referenced by widget configurations that '
      'disagree on `generateDefaultResult`: '
      '${wants.map((c) => c.className).join(', ')} opted in, while '
      '${optedOut.map((c) => c.className).join(', ')} did not. Only one '
      '`${widgetQueryName(info.className)}` is generated per entity, so the '
      'flag would apply to all of them. Set `generateDefaultResult` to the '
      'same value on every @WidgetConfigurationSpec that uses this entity.',
    );
  }

  /// Writes the private `cachedEntities()` helper that maps cached values onto
  /// the generated entity type.
  void _writeCachedEntitiesReader(
    StringBuffer buffer,
    EntityInfo info,
    Map<EntityPropertyRole, EntityPropertyInfo> props,
  ) {
    final entityName = widgetEntityName(info.className);
    final id = props[EntityPropertyRole.id]!;
    final title = props[EntityPropertyRole.title]!;
    final subtitle = props[EntityPropertyRole.subtitle];
    final image = props[EntityPropertyRole.image];

    buffer.writeln(
      '$_indent/// Reads the persisted entity list from App Group '
      'UserDefaults.',
    );
    buffer.writeln(
      '$_indent/// Returns an empty list when the host app has not written the',
    );
    buffer.writeln(
      '$_indent/// cache yet, or when the App Group is not reachable.',
    );
    buffer.writeln(
      '${_indent}private static func cachedEntities() -> [$entityName] {',
    );
    buffer.writeln('$_indent$_indent$cacheConfigName.cache');
    buffer.writeln('$_indent$_indent$_indent.entities(');
    buffer.writeln('$_indent$_indent$_indent${_indent}forCacheKey: cacheKey,');
    buffer.writeln(
      '$_indent$_indent$_indent${_indent}idKey: "${id.fieldName}",',
    );
    final lastArg = subtitle == null && image == null;
    buffer.writeln(
      '$_indent$_indent$_indent${_indent}titleKey: "${title.fieldName}"'
      '${lastArg ? '' : ','}',
    );
    if (subtitle != null) {
      buffer.writeln(
        '$_indent$_indent$_indent${_indent}subtitleKey: '
        '"${subtitle.fieldName}"${image == null ? '' : ','}',
      );
    }
    if (image != null) {
      buffer.writeln(
        '$_indent$_indent$_indent${_indent}imageKey: "${image.fieldName}"',
      );
    }
    buffer.writeln('$_indent$_indent$_indent)');
    buffer.writeln('$_indent$_indent$_indent.map { cached in');

    // The identifier property is always `id` on the generated Swift entity
    // (Identifiable), while `idKey` above carries the Dart field name.
    final args = <String>['id: cached.id'];
    args.add('${title.fieldName}: cached.title');
    if (subtitle != null) {
      args.add(
        '${subtitle.fieldName}: ${_coalesce('cached.subtitle', subtitle)}',
      );
    }
    if (image != null) {
      args.add('${image.fieldName}: ${_coalesce('cached.imageName', image)}');
    }

    buffer.writeln('$_indent$_indent$_indent$_indent$entityName(');
    for (var i = 0; i < args.length; i++) {
      final comma = i == args.length - 1 ? '' : ',';
      buffer.writeln(
        '$_indent$_indent$_indent$_indent$_indent${args[i]}$comma',
      );
    }
    buffer.writeln('$_indent$_indent$_indent$_indent)');
    buffer.writeln('$_indent$_indent$_indent}');
    buffer.writeln('$_indent}');
  }

  /// `cached.subtitle` / `cached.imageName` are always optional; coalesce when
  /// the entity declares the field non-optional.
  String _coalesce(String expression, EntityPropertyInfo prop) =>
      prop.dartType.endsWith('?') ? expression : '$expression ?? ""';

  /// Writes the `displayRepresentation` computed property.
  void _writeDisplayRepresentation(
    StringBuffer buffer,
    EntityInfo info,
    Map<EntityPropertyRole, EntityPropertyInfo> props,
  ) {
    final title = props[EntityPropertyRole.title]!;
    final subtitle = props[EntityPropertyRole.subtitle];
    final image = props[EntityPropertyRole.image];

    final args = <String>['title: "\\(${title.fieldName})"'];
    if (subtitle != null) {
      final expr = subtitle.dartType.endsWith('?')
          ? '${subtitle.fieldName} ?? ""'
          : subtitle.fieldName;
      args.add('subtitle: "\\($expr)"');
    }

    buffer.writeln(
      '${_indent}var displayRepresentation: DisplayRepresentation {',
    );

    if (image != null && image.dartType.endsWith('?')) {
      // A nil image must fall back to a representation without one, since
      // `.init(systemName:)` needs a non-optional name.
      buffer.writeln('$_indent${_indent}if let ${image.fieldName} {');
      final withImage = [
        ...args,
        'image: .init(systemName: ${image.fieldName})',
      ];
      buffer.writeln(
        '$_indent$_indent${_indent}return DisplayRepresentation('
        '${withImage.join(', ')})',
      );
      buffer.writeln('$_indent$_indent}');
      buffer.writeln(
        '$_indent${_indent}return DisplayRepresentation(${args.join(', ')})',
      );
    } else {
      if (image != null) {
        args.add('image: .init(systemName: ${image.fieldName})');
      } else if (info.displayImageName != null) {
        args.add(
          'image: .init(named: "${_swiftLiteral(info.displayImageName!)}", isTemplate: true)',
        );
      }
      buffer.writeln(
        '$_indent${_indent}DisplayRepresentation(${args.join(', ')})',
      );
    }

    buffer.writeln('$_indent}');
  }

  /// Writes the `WidgetConfigurationIntent` struct for [config].
  void _writeConfigurationIntent(
    StringBuffer buffer,
    WidgetConfigurationInfo config,
  ) {
    buffer.writeln('/// Widget configuration intent for the widget\'s');
    buffer.writeln('/// "long-press → Edit Widget" sheet.');
    buffer.writeln(_availability);
    buffer.writeln('struct ${config.swiftName}: WidgetConfigurationIntent {');
    buffer.writeln(
      '${_indent}static var title: LocalizedStringResource = '
      '"${_swiftLiteral(config.title)}"',
    );
    if (config.description != null) {
      buffer.writeln(
        '${_indent}static var description: IntentDescription = '
        'IntentDescription("${_swiftLiteral(config.description!)}")',
      );
    }
    buffer.writeln(
      '${_indent}static var isDiscoverable: Bool { ${config.isDiscoverable} }',
    );
    buffer.writeln();
    buffer.writeln(
      '$_indent/// Stable across builds: changing it invalidates existing',
    );
    buffer.writeln('$_indent/// widget configurations.');
    buffer.writeln(
      '${_indent}static var persistentIdentifier: String '
      '{ "${_swiftLiteral(config.identifier)}" }',
    );

    for (final param in config.parameters) {
      buffer.writeln();
      _writeParameter(buffer, config, param);
    }

    buffer.writeln('}');
  }

  /// Writes a single `@Parameter` declaration.
  void _writeParameter(
    StringBuffer buffer,
    WidgetConfigurationInfo config,
    WidgetParamInfo param,
  ) {
    final args = <String>['title: "${_swiftLiteral(param.title)}"'];
    if (param.description != null) {
      args.add('description: "${_swiftLiteral(param.description!)}"');
    }
    buffer.writeln('$_indent@Parameter(${args.join(', ')})');

    final entityType = param.entityType;
    // Entity parameters are always emitted optional, even when declared
    // non-optional: a required entity blocks the widget from rendering until
    // the user picks one, which is rarely what a configuration wants. Scalar
    // types already carry their nullability from `_swiftType`.
    final swiftType = entityType != null
        ? '${widgetEntityName(entityType)}?'
        : _swiftType(
            param.dartType,
            owner: '${config.className}.${param.name}',
          );
    buffer.writeln('${_indent}var ${param.name}: $swiftType');
  }

  /// The Swift property name for a cache-backed entity field.
  ///
  /// `AppEntity` refines `Identifiable`, so the identifier property **must** be
  /// named `id` — otherwise Swift infers `Identifiable.ID == ObjectIdentifier`
  /// and the conformance fails to compile. The Dart `@EntityId` field name may
  /// be anything (it names the key inside the cached payload, which is passed
  /// separately as `idKey:`), so it is normalized here. Other roles keep their
  /// Dart field names.
  String _swiftPropertyName(EntityPropertyRole role, EntityPropertyInfo prop) =>
      role == EntityPropertyRole.id ? 'id' : prop.fieldName;

  /// The entity's role-bearing properties, keyed by role.
  ///
  /// The App Group cache only carries id/title/subtitle/image, so those are the
  /// only fields the widget entity can be built from.
  Map<EntityPropertyRole, EntityPropertyInfo> _cacheBackedProperties(
    EntityInfo info,
  ) {
    final props = <EntityPropertyRole, EntityPropertyInfo>{};
    for (final role in const [
      EntityPropertyRole.id,
      EntityPropertyRole.title,
      EntityPropertyRole.subtitle,
      EntityPropertyRole.image,
    ]) {
      final prop = info.properties.where((p) => p.role == role).firstOrNull;
      if (prop != null) props[role] = prop;
    }

    final id = props[EntityPropertyRole.id];
    final title = props[EntityPropertyRole.title];
    if (id == null || title == null) {
      throw InvalidGenerationSourceError(
        'Entity `${info.className}` is used by a @WidgetConfigurationSpec but '
        'is missing an @EntityId or @EntityTitle field. Both are required to '
        'build an entity from the App Group cache.',
      );
    }

    // The App Group payload only ever carries strings (the Dart side writes
    // JSON / a map of string fields), and `AppIntentsCachedEntity` exposes them
    // as `String` / `String?`. A non-String role field would compile into an
    // assignment of `String` to e.g. `Int`, so reject it here rather than
    // letting Xcode report it against generated code.
    for (final entry in props.entries) {
      final prop = entry.value;
      final nullableAllowed =
          entry.key == EntityPropertyRole.subtitle ||
          entry.key == EntityPropertyRole.image;
      final allowed = nullableAllowed
          ? const ['String', 'String?']
          : const ['String'];
      if (!allowed.contains(prop.dartType)) {
        throw InvalidGenerationSourceError(
          'Entity `${info.className}` is used by a @WidgetConfigurationSpec, '
          'but its ${_roleName(entry.key)} field `${prop.fieldName}` is '
          '`${prop.dartType}`. A Widget Extension can only read the App Group '
          'cache, which carries strings, so this field must be '
          '${allowed.map((t) => '`$t`').join(' or ')}. '
          'Change the field type, or expose a string projection of it.',
        );
      }
    }

    // `_swiftPropertyName` renames the @EntityId field to `id` because
    // `AppEntity` refines `Identifiable`. If another role field is itself named
    // `id`, that rename collides and emits two `var id` declarations.
    for (final entry in props.entries) {
      if (entry.key == EntityPropertyRole.id) continue;
      if (entry.value.fieldName == 'id') {
        throw InvalidGenerationSourceError(
          'Entity `${info.className}` names its ${_roleName(entry.key)} field '
          '`id`, which collides with the generated identifier property. '
          '`AppEntity` refines `Identifiable`, so the @EntityId field '
          '(`${id.fieldName}`) is always emitted as `id` in Swift. Rename the '
          '${_roleName(entry.key)} field.',
        );
      }
    }

    return props;
  }

  /// The annotation name for a role, used in generation-time error messages.
  String _roleName(EntityPropertyRole role) => switch (role) {
    EntityPropertyRole.id => '@EntityId',
    EntityPropertyRole.title => '@EntityTitle',
    EntityPropertyRole.subtitle => '@EntitySubtitle',
    EntityPropertyRole.image => '@EntityImage',
    _ => role.name,
  };

  /// Escapes [value] for embedding inside a Swift `"..."` string literal.
  ///
  /// Author-supplied strings (titles, descriptions, image names) reach the
  /// generated Swift verbatim. Without escaping, a double quote produces Swift
  /// that does not compile, and a backslash-paren sequence would be silently
  /// reinterpreted as Swift string interpolation against a symbol that does not
  /// exist.
  String _swiftLiteral(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll('"', '\\"')
      .replaceAll('\n', '\\n')
      .replaceAll('\r', '\\r')
      .replaceAll('\t', '\\t');

  /// Converts a Dart scalar type to its Swift equivalent.
  String _swiftType(String dartType, {String? owner}) {
    final isNullable = dartType.endsWith('?');
    final base = isNullable
        ? dartType.substring(0, dartType.length - 1)
        : dartType;
    final swiftBase = _typeMapping[base];
    if (swiftBase == null) {
      if (owner == null) return isNullable ? '$base?' : base;
      throw InvalidGenerationSourceError(
        'Widget parameter `$owner` has unsupported type `$dartType`. Widget '
        'configuration parameters must be String/int/double/bool/DateTime, or '
        'a class annotated with @EntitySpec.',
      );
    }
    return isNullable ? '$swiftBase?' : swiftBase;
  }
}
