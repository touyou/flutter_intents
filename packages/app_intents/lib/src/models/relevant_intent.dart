/// One relevant-intent donation: a configured widget intent the system may
/// surface in the Smart Stack when [relevance] holds.
///
/// The system replaces its whole picture of an app's relevant intents on every
/// donation, so these are always sent as a complete set — see
/// `AppIntents.donateRelevantIntents`.
class RelevantIntentDonation {
  /// The `@WidgetConfigurationSpec` identifier whose intent to configure.
  final String configurationIdentifier;

  /// The widget's kind string, as declared in its `Widget` definition.
  final String widgetKind;

  /// Values for the configuration intent's parameters, keyed by field name.
  final Map<String, Object?> parameters;

  /// When this configuration is worth surfacing.
  final RelevantContextSpec relevance;

  const RelevantIntentDonation({
    required this.configurationIdentifier,
    required this.widgetKind,
    required this.relevance,
    this.parameters = const {},
  });

  /// The wire form sent over the method channel.
  Map<String, Object?> toMap() => {
    'configurationIdentifier': configurationIdentifier,
    'widgetKind': widgetKind,
    'parameters': {
      for (final entry in parameters.entries)
        entry.key: _encodeParameter(entry.value),
    },
    'relevance': relevance.toMap(),
  };

  /// Encodes one parameter value for the method channel.
  ///
  /// Flutter's standard codec has no `DateTime`, so a `DateTime` parameter —
  /// which widget configurations do support — would throw on the way out. It
  /// travels as an ISO-8601 string and the generated Swift parses it back.
  static Object? _encodeParameter(Object? value) =>
      value is DateTime ? value.toUtc().toIso8601String() : value;
}

/// A context in which a donated intent becomes relevant.
///
/// Mirrors the `RelevantContext` factories that can be expressed over the
/// method channel. `RelevantContext.location(_ exact: CLRegion)` is deliberately
/// absent: a `CLRegion` cannot be reconstructed from a plain map, and pretending
/// otherwise would produce a donation the system quietly ignores.
class RelevantContextSpec {
  const RelevantContextSpec._(this._kind, this._values);

  final String _kind;
  final Map<String, Object?> _values;

  /// Relevant at a moment in time.
  ///
  /// [kind] refines how the system reads the date and needs iOS 26; on earlier
  /// versions the date is used without it.
  factory RelevantContextSpec.date(DateTime date, {RelevantDateKind? kind}) =>
      RelevantContextSpec._('date', {
        'date': date.toUtc().toIso8601String(),
        'dateKind': kind?.name,
      });

  /// Relevant throughout a time range.
  ///
  /// The range form needs iOS 26; below that the system falls back to [start].
  factory RelevantContextSpec.dateRange(
    DateTime start,
    DateTime end, {
    RelevantDateKind? kind,
  }) => RelevantContextSpec._('dateRange', {
    'start': start.toUtc().toIso8601String(),
    'end': end.toUtc().toIso8601String(),
    'dateKind': kind?.name,
  });

  /// Relevant at a place the system infers for the user.
  factory RelevantContextSpec.inferredLocation(InferredLocation location) =>
      RelevantContextSpec._('inferredLocation', {'value': location.name});

  /// Relevant around the user's sleep schedule.
  factory RelevantContextSpec.sleep(SleepCondition condition) =>
      RelevantContextSpec._('sleep', {'value': condition.name});

  /// Relevant around the user's activity.
  factory RelevantContextSpec.fitness(FitnessCondition condition) =>
      RelevantContextSpec._('fitness', {'value': condition.name});

  /// Relevant while headphones are connected.
  factory RelevantContextSpec.headphonesConnected() =>
      const RelevantContextSpec._('headphones', {'value': 'connected'});

  /// The wire form sent over the method channel.
  Map<String, Object?> toMap() => {'kind': _kind, ..._values};
}

/// How the system should read a date context (iOS 26+).
enum RelevantDateKind {
  /// Shown for information, not because something happens then.
  informational,

  /// The system's default weighting.
  standard,

  /// Something is scheduled at that time.
  scheduled,
}

/// A place the system infers for the user, rather than an explicit region.
enum InferredLocation { home, work, school, commute }

/// A point in the user's sleep schedule.
enum SleepCondition { wakeup, bedtime }

/// A state of the user's activity.
enum FitnessCondition { workoutActive, activityRingsIncomplete }

/// What a `donateRelevantEntities` call does to the system's picture of an
/// entity type's relevant entities (#55, extended in #133).
enum RelevantEntitiesOperation {
  /// Replaces the entities for the given context.
  ///
  /// This is a stateful overwrite, so an empty list clears that one context.
  update('update'),

  /// Removes the given entities — from one context when a context is passed,
  /// from every context otherwise.
  remove('remove'),

  /// Removes **all** donated entities of this type — from one context when a
  /// context is passed, from every context otherwise.
  ///
  /// The entity list is ignored. Before the Xcode 27 SDK the only way to drop a
  /// donation was an empty [update], which cannot express a clear that spans
  /// every context.
  removeAll('removeAll');

  const RelevantEntitiesOperation(this.wireName);

  /// The token sent over the MethodChannel.
  final String wireName;
}
