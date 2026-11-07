/// Run the registered App Intents / AppFunctions handlers under
/// `flutter test`, without a simulator or a native host.
///
/// See [AppIntentsHarness]. The manifest it optionally reads comes from
/// `dart run app_intents_codegen:describe -o test/app_intents.json`.
library;

export 'src/testing/harness.dart'
    show
        AppIntentsHarness,
        AppIntentsInventory,
        AppIntentsSchemaViolation,
        HarnessProgress,
        HarnessRun;
export 'src/testing/manifest.dart'
    show AppIntentsManifest, DeclaredEntity, DeclaredEnum, DeclaredIntent;
export 'src/testing/schema_validator.dart' show validateJsonSchema;
