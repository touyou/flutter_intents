/// Opt-in WWDC26 experimental code-generation features.
///
/// Each value names a self-contained feature whose generated Swift relies on an
/// unreleased/beta iOS SDK (iOS 26.4 / iOS 27+). Because the symbols do not
/// exist in the stable SDK at all, `@available` cannot guard them — the only
/// safe gate is "do not emit those lines". These features are therefore
/// disabled by default and, when enabled, the generated code is additionally
/// wrapped in a `#if APP_INTENTS_WWDC26` compilation condition so the consuming
/// project can also toggle it from build settings.
///
/// Selected via the CLI `--experimental=<flag>` (comma-separated) and gated by
/// the `--experimental-wwdc26` master switch.
enum ExperimentalFeature {
  /// Intent execution control (#52): `LongRunningIntent`, `CancellableIntent`,
  /// and `allowedExecutionTargets` / `IntentExecutionTargets`.
  longRunning('long-running'),

  /// App Schema domain conformance (#49): `@AppEntity(schema:)` and friends.
  appSchema('app-schema');

  const ExperimentalFeature(this.flag);

  /// The token used on the CLI: `--experimental=<flag>`.
  final String flag;

  /// All CLI flag tokens, in declaration order.
  static List<String> get allFlags =>
      ExperimentalFeature.values.map((f) => f.flag).toList();

  /// Resolves a CLI flag token to its [ExperimentalFeature], or `null` if the
  /// token is not recognized.
  static ExperimentalFeature? fromFlag(String value) {
    for (final feature in ExperimentalFeature.values) {
      if (feature.flag == value) return feature;
    }
    return null;
  }
}

/// Resolved opt-in configuration for WWDC26 experimental code generation.
///
/// Defaults to everything OFF ([none]), which reproduces the stable output
/// byte-for-byte. The master switch combines with the per-feature set:
///
/// - master OFF → nothing experimental is emitted, regardless of [enabled].
/// - master ON with an empty [enabled] set → every feature is emitted
///   (the "just turn it all on" shorthand).
/// - master ON with a non-empty [enabled] set → only the listed features.
class ExperimentalFeatures {
  /// Creates a configuration. Prefer [none] for the default.
  const ExperimentalFeatures({
    this.masterEnabled = false,
    this.enabled = const {},
  });

  /// The default: all experimental generation disabled (stable output).
  static const ExperimentalFeatures none = ExperimentalFeatures();

  /// The master switch (`--experimental-wwdc26`).
  final bool masterEnabled;

  /// The explicitly selected per-feature flags. An empty set with
  /// [masterEnabled] true means "all features".
  final Set<ExperimentalFeature> enabled;

  /// Whether [feature] should be emitted under the current configuration.
  bool isEnabled(ExperimentalFeature feature) {
    if (!masterEnabled) return false;
    if (enabled.isEmpty) return true;
    return enabled.contains(feature);
  }

  /// Whether any experimental output is active at all.
  bool get anyEnabled => masterEnabled;

  @override
  bool operator ==(Object other) =>
      other is ExperimentalFeatures &&
      other.masterEnabled == masterEnabled &&
      _setEquals(other.enabled, enabled);

  @override
  int get hashCode =>
      Object.hash(masterEnabled, Object.hashAllUnordered(enabled));

  @override
  String toString() =>
      'ExperimentalFeatures(masterEnabled: $masterEnabled, enabled: $enabled)';
}

bool _setEquals<T>(Set<T> a, Set<T> b) {
  if (a.length != b.length) return false;
  for (final element in a) {
    if (!b.contains(element)) return false;
  }
  return true;
}
