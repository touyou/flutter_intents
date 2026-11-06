import 'dart:async';

import 'package:flutter/services.dart';

import '../../app_intents_method_channel.dart';
import '../../app_intents_platform_interface.dart';
import '../models/models.dart';
import 'manifest.dart';
import 'schema_validator.dart';

/// Lists and runs the registered Dart handlers the way a native caller does,
/// under plain `flutter test`.
///
/// Every call is encoded with the plugin's codec and delivered on the
/// `app_intents` channel, the same entry iOS App Intents and Android
/// AppFunctions use. So a handler that returns a value the codec cannot carry
/// fails here as it would on a device, and an [AppIntentError] comes back with
/// its code unchanged. The harness never reaches a handler any other way.
///
/// ```dart
/// late AppIntentsHarness harness;
///
/// setUp(() {
///   TestWidgetsFlutterBinding.ensureInitialized();
///   harness = AppIntentsHarness(
///     manifest: AppIntentsManifest.parse(
///       File('test/app_intents.json').readAsStringSync()),
///   );
///   initializeAppIntents(); // your generated registrations
/// });
/// tearDown(() => harness.dispose());
///
/// test('every declared intent has a handler', () {
///   expect(harness.list().unhandledIntents, isEmpty);
/// });
///
/// test('createTask', () async {
///   final result = await harness.run(
///     'com.example.taskapp.createTask', {'title': 'Milk'});
///   expect(result, isEmpty);
/// });
/// ```
///
/// What the operating system decides (Siri routing, the Shortcuts UI,
/// AppFunctions discovery) is out of reach here by design.
class AppIntentsHarness {
  /// Installs a fresh plugin instance as [AppIntentsPlatform.instance].
  ///
  /// Register handlers **after** constructing the harness: registrations made
  /// on the previous instance do not carry over. Call [dispose] in
  /// `tearDown` to put the previous instance back.
  ///
  /// [manifest] is optional. With it, [list] reports declared intents that have
  /// no handler and [run] validates params against the declared schema before
  /// the call; set [validateParams] to false to send malformed params on
  /// purpose.
  ///
  /// [handlerRegistrationTimeout] is how long [run] waits for a handler that is
  /// not registered yet. A device waits 5 seconds for a cold start; the
  /// harness defaults to zero, so a missing handler fails at once with
  /// `handlerNotFound`.
  AppIntentsHarness({
    this.manifest,
    this.validateParams = true,
    Duration handlerRegistrationTimeout = Duration.zero,
    this.onRequestValue,
  }) : _previous = AppIntentsPlatform.instance {
    _platform = _HarnessPlatform(this)
      ..handlerRegistrationTimeout = handlerRegistrationTimeout;
    AppIntentsPlatform.instance = _platform;
  }

  /// The declarations from `app_intents_codegen:describe`, if given.
  final AppIntentsManifest? manifest;

  /// Whether [run] checks params against [manifest] before the call.
  final bool validateParams;

  /// Answers `AppIntentExecution.requestValue` (#131), standing in for the
  /// system prompt. Without it a request resolves to null, which is what
  /// Android does.
  final FutureOr<Object?> Function(String executionId, String parameter)?
  onRequestValue;

  final AppIntentsPlatform _previous;
  late final _HarnessPlatform _platform;
  var _nextExecution = 0;

  static const _codec = StandardMethodCodec();
  static const _channel = 'app_intents';

  /// Progress the handlers reported, in order.
  final List<HarnessProgress> progressReports = [];

  /// Calls the handlers made toward the native side that the harness
  /// answered itself: donations, onscreen entity changes, App Shortcut
  /// parameter updates. Each is the method name and its arguments.
  final List<MethodCall> nativeCalls = [];

  /// The in-memory stand-in for the App Group cache that
  /// `getCachedValue` / `setCachedValue` read and write.
  final Map<String, Object?> cache = {};

  /// What a native caller could reach right now.
  ///
  /// With a [manifest], also what it declared but nothing handles — which on a
  /// device only shows up as a `handlerNotFound` at run time.
  AppIntentsInventory list() => AppIntentsInventory._(
    intents: _platform.registeredIntentIdentifiers,
    entityQueries: _platform.registeredEntityQueryIdentifiers,
    suggestedEntities: _platform.registeredSuggestedEntitiesIdentifiers,
    valueQueries: _platform.registeredValueQueryIdentifiers,
    manifest: manifest,
  );

  /// Runs the intent [identifier] with [params] and returns the handler's
  /// result map.
  ///
  /// Opens an execution scope the way the generated Android bridge does for
  /// every call: the params carry an `_executionId`, so
  /// `AppIntentExecution.current` is non-null inside the handler.
  ///
  /// Throws [AppIntentError] with the code the native side would see, and
  /// [AppIntentsSchemaViolation] when [params] do not match the declared
  /// schema.
  Future<Map<String, dynamic>> run(
    String identifier, [
    Map<String, Object?> params = const {},
  ]) => start(identifier, params).result;

  /// Starts the intent [identifier] and returns before it finishes, so a test
  /// can [HarnessRun.cancel] it or watch [progressReports] meanwhile.
  HarnessRun start(
    String identifier, [
    Map<String, Object?> params = const {},
  ]) {
    _checkParams(identifier, params);
    final executionId = 'harness-${++_nextExecution}';
    final result = _invoke('executeIntent', {
      'identifier': identifier,
      'params': {...params, intentExecutionIdKey: executionId},
    }).then((value) => _stringMap(value));
    return HarnessRun._(this, executionId, result);
  }

  /// Runs the entity query handler for [entityIdentifier] with [identifiers].
  ///
  /// With a [manifest], each returned map is checked against the entity's
  /// schema: a map missing its id or title is dropped by the generated Swift
  /// query, so it is reported here instead of disappearing on a device.
  Future<List<Map<String, dynamic>>> queryEntities(
    String entityIdentifier,
    List<String> identifiers,
  ) async => _checkEntities(
    entityIdentifier,
    await _invoke('queryEntities', {
      'entityIdentifier': entityIdentifier,
      'identifiers': identifiers,
    }),
  );

  /// Runs the suggested entities handler for [entityIdentifier].
  Future<List<Map<String, dynamic>>> suggestedEntities(
    String entityIdentifier,
  ) async => _checkEntities(
    entityIdentifier,
    await _invoke('getSuggestedEntities', {
      'entityIdentifier': entityIdentifier,
    }),
  );

  /// Runs the value query handler for [entityIdentifier] with [input] (#51).
  Future<List<Map<String, dynamic>>> queryValues(
    String entityIdentifier,
    Map<String, Object?> input,
  ) async => _checkEntities(
    entityIdentifier,
    await _invoke('queryValues', {
      'entityIdentifier': entityIdentifier,
      'input': input,
    }),
  );

  /// Delivers a cancellation for [executionId], as the system does (#130).
  Future<void> cancel(String executionId, {String reason = 'userCancelled'}) =>
      _invoke('intentCancelled', {
        'executionId': executionId,
        'reason': reason,
      });

  /// Restores the plugin instance that was active before this harness.
  void dispose() {
    _platform.dispose();
    if (identical(AppIntentsPlatform.instance, _platform)) {
      AppIntentsPlatform.instance = _previous;
    }
    final previous = _previous;
    if (previous is MethodChannelAppIntents) previous.attachMethodCallHandler();
  }

  void _checkParams(String identifier, Map<String, Object?> params) {
    if (!validateParams) return;
    final declared = manifest?.intent(identifier);
    if (declared == null) return;
    final errors = validateJsonSchema(params, declared.parameters);
    if (errors.isNotEmpty) {
      throw AppIntentsSchemaViolation._(identifier, errors);
    }
  }

  List<Map<String, dynamic>> _checkEntities(
    String entityIdentifier,
    Object? value,
  ) {
    final entities = [
      for (final item in (value as List?) ?? const []) _stringMap(item),
    ];
    final declared = manifest?.entity(entityIdentifier);
    if (declared != null) {
      final errors = [
        for (var i = 0; i < entities.length; i++)
          ...validateJsonSchema(entities[i], declared.schema, path: '\$[$i]'),
      ];
      if (errors.isNotEmpty) {
        throw AppIntentsSchemaViolation._(entityIdentifier, errors);
      }
    }
    return entities;
  }

  /// Sends [method] on the plugin channel as the native side would and
  /// decodes the reply envelope.
  Future<Object?> _invoke(String method, Map<String, Object?> arguments) {
    final completer = Completer<Object?>();
    ServicesBinding.instance.channelBuffers.push(
      _channel,
      _codec.encodeMethodCall(MethodCall(method, arguments)),
      (reply) {
        if (reply == null) {
          completer.completeError(
            StateError('No handler on the "$_channel" channel answered.'),
          );
          return;
        }
        try {
          completer.complete(_codec.decodeEnvelope(reply));
        } on PlatformException catch (e) {
          final details = e.details;
          completer.completeError(
            AppIntentError(
              code: e.code,
              message: e.message ?? '',
              details: details is Map ? _stringMap(details) : null,
            ),
          );
        } catch (e, stack) {
          completer.completeError(e, stack);
        }
      },
    );
    return completer.future;
  }

  static Map<String, dynamic> _stringMap(Object? value) => value is Map
      ? value.map((key, value) => MapEntry(key.toString(), value))
      : <String, dynamic>{};
}

/// An intent started with [AppIntentsHarness.start].
class HarnessRun {
  HarnessRun._(this._harness, this.executionId, this.result);

  final AppIntentsHarness _harness;

  /// The `_executionId` the handler sees.
  final String executionId;

  /// Completes with the handler's result, or with the error a native caller
  /// would get.
  final Future<Map<String, dynamic>> result;

  /// Progress reported by this run so far.
  List<HarnessProgress> get progress => [
    for (final p in _harness.progressReports)
      if (p.executionId == executionId) p,
  ];

  /// Cancels this run (#130).
  Future<void> cancel({String reason = 'userCancelled'}) =>
      _harness.cancel(executionId, reason: reason);
}

/// One progress report from a handler.
class HarnessProgress {
  const HarnessProgress._(this.executionId, this.completed, this.total);

  /// The run that reported it.
  final String executionId;

  /// Units done.
  final int completed;

  /// Units in total.
  final int total;

  /// [completed] / [total].
  double get fraction => total == 0 ? 0 : completed / total;

  @override
  String toString() => 'HarnessProgress($executionId, $completed/$total)';
}

/// What [AppIntentsHarness.list] found.
class AppIntentsInventory {
  AppIntentsInventory._({
    required this.intents,
    required this.entityQueries,
    required this.suggestedEntities,
    required this.valueQueries,
    this.manifest,
  });

  /// Intent identifiers with a handler.
  final Set<String> intents;

  /// Entity identifiers with an entity query handler.
  final Set<String> entityQueries;

  /// Entity identifiers with a suggested entities handler.
  final Set<String> suggestedEntities;

  /// Entity identifiers with a value query handler.
  final Set<String> valueQueries;

  /// The manifest this was compared with, if any.
  final AppIntentsManifest? manifest;

  /// Declared intents that no handler answers. Empty without a manifest.
  Set<String> get unhandledIntents => {
    for (final i in manifest?.intents ?? const <DeclaredIntent>[])
      if (!intents.contains(i.identifier)) i.identifier,
  };

  /// Declared entities without an entity query handler. Empty without a
  /// manifest.
  Set<String> get unhandledEntities => {
    for (final e in manifest?.entities ?? const <DeclaredEntity>[])
      if (!entityQueries.contains(e.identifier)) e.identifier,
  };

  /// Handlers registered under an identifier the manifest does not declare,
  /// usually a typo or a stale manifest. Empty without a manifest.
  Set<String> get undeclaredIntents {
    final m = manifest;
    if (m == null) return const {};
    return {
      for (final id in intents)
        if (m.intent(id) == null) id,
    };
  }

  @override
  String toString() =>
      'AppIntentsInventory(intents: $intents, entityQueries: $entityQueries, '
      'suggestedEntities: $suggestedEntities, valueQueries: $valueQueries'
      '${manifest == null ? '' : ', unhandledIntents: $unhandledIntents'})';
}

/// Params or entities that do not match the manifest's schema.
class AppIntentsSchemaViolation implements Exception {
  AppIntentsSchemaViolation._(this.identifier, this.errors);

  /// The intent or entity identifier.
  final String identifier;

  /// One line per mismatch, each starting with a `$`-rooted path.
  final List<String> errors;

  @override
  String toString() =>
      'AppIntentsSchemaViolation($identifier):\n  ${errors.join('\n  ')}';
}

/// The plugin with its outgoing calls answered in memory, since no native
/// side is attached under `flutter test`.
class _HarnessPlatform extends MethodChannelAppIntents {
  _HarnessPlatform(this._harness);

  final AppIntentsHarness _harness;

  @override
  Future<String?> getPlatformVersion() async => 'harness';

  @override
  Future<void> reportIntentProgress(
    String executionId,
    int completed,
    int total,
  ) async {
    _harness.progressReports.add(
      HarnessProgress._(executionId, completed, total),
    );
  }

  @override
  Future<Object?> requestIntentValue(
    String executionId,
    String parameter,
  ) async => _harness.onRequestValue?.call(executionId, parameter);

  void _record(String method, [Object? arguments]) =>
      _harness.nativeCalls.add(MethodCall(method, arguments));

  @override
  Future<void> donateRelevantEntities(
    String entityIdentifier,
    List<Map<String, dynamic>> entities, {
    String? context,
    RelevantEntitiesOperation operation = RelevantEntitiesOperation.update,
  }) async => _record('donateRelevantEntities', {
    'entityIdentifier': entityIdentifier,
    'entities': entities,
    'context': ?context,
    'operation': operation.wireName,
  });

  @override
  Future<void> donateRelevantIntents(
    List<RelevantIntentDonation> donations,
  ) async => _record('donateRelevantIntents', {
    'donations': [for (final d in donations) d.toMap()],
  });

  @override
  Future<void> donateIntent(
    String identifier,
    Map<String, dynamic> params,
  ) async =>
      _record('donateIntent', {'identifier': identifier, 'params': params});

  @override
  Future<void> setOnscreenEntity(
    String entityIdentifier,
    String entityId, {
    String? title,
  }) async => _record('setOnscreenEntity', {
    'entityIdentifier': entityIdentifier,
    'entityId': entityId,
    'title': ?title,
  });

  @override
  Future<void> clearOnscreenEntity() async => _record('clearOnscreenEntity');

  @override
  Future<void> updateAppShortcutParameters() async =>
      _record('updateAppShortcutParameters');

  @override
  Future<dynamic> getCachedValue(String key) async => _harness.cache[key];

  @override
  Future<void> setCachedValue(String key, dynamic value) async =>
      _harness.cache[key] = value;

  @override
  Future<void> clearCachedValue(String key) async => _harness.cache.remove(key);

  @override
  Future<void> configureStorage({
    required String appGroupIdentifier,
    String? storageIdentifier,
  }) async => _record('configureStorage', {
    'appGroupIdentifier': appGroupIdentifier,
    'storageIdentifier': ?storageIdentifier,
  });

  @override
  Future<bool> processPendingActions() async => false;

  @override
  Stream<String> get pendingActionsStream => const Stream.empty();
}
