# Package Details

## app_intents_annotations

A pure Dart package that provides annotations and base classes for defining Intents/Entities.

### Dependencies

- Dart SDK: ^3.10.0
- No external dependencies (framework-independent)

### Intent Related

#### IntentSpec

Annotation for defining an Intent.

```dart
@IntentSpec(
  identifier: 'CreateTaskIntent',    // Unique identifier
  title: 'Create Task',              // Display title
  description: 'Creates a new task', // Description
  implementation: IntentImplementation.dart, // Implementation language
  urlScheme: 'taskapp',              // URL scheme for intent execution
  urlAction: 'create',              // URL host/action
  resultDialogTemplate: 'Created task "{title}"', // Siri dialog feedback
  parameterSummary: 'Create task {title}',        // Shortcuts UI display
)
class CreateTaskIntentSpec extends IntentSpecBase {}
```

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| identifier | String | Yes | Intent unique identifier |
| title | String | Yes | User-facing display name |
| description | String | No | Intent description |
| implementation | IntentImplementation | No | Implementation language (default: dart) |
| urlScheme | String | No | URL scheme for intent execution |
| urlAction | String | No | URL host/action path |
| resultDialogTemplate | String | No | Dialog feedback template (e.g., `'Created "{title}"'`) |
| parameterSummary | String | No | Shortcuts UI summary (e.g., `'Create {title}'`) |
| supportedModes | IntentMode? | No | Execution mode (`foreground` or `background`) |

#### IntentImplementation

```dart
enum IntentImplementation {
  dart,    // Implement on Dart/Flutter side
  swift,   // Implement on Swift side
  kotlin,  // Implement on Kotlin side
}
```

#### IntentParam

Annotation for defining intent parameters.

```dart
class MyIntentSpec extends IntentSpecBase {
  @IntentParam(
    title: 'Task Title',        // Parameter display name
    description: 'The title',   // Parameter description
    isOptional: false,          // Required/optional
  )
  final String title;

  @IntentParam(title: 'Due Date', isOptional: true)
  final DateTime? dueDate;
}
```

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| title | String | Yes | Parameter display name |
| description | String | No | Parameter description |
| isOptional | bool | No | Whether optional (default: false) |
| entityType | String? | No | Entity type identifier for picker parameters |
| enumType | String? | No | AppEnum type identifier for selection parameters |
| fileType | String? | No | UTI for file parameters (e.g., `'public.image'`) |

#### IntentSpecBase

Base class for intent definitions.

```dart
abstract class IntentSpecBase {
  const IntentSpecBase();
}

class MyIntentSpec extends IntentSpecBase {}
```

### Entity Related

#### EntitySpec

Annotation for defining an Entity.

```dart
@EntitySpec(
  identifier: 'TaskEntity',     // Unique identifier
  title: 'Task',                // Singular title
  pluralTitle: 'Tasks',         // Plural title
  description: 'A task entity', // Description
)
class TaskEntitySpec extends EntitySpecBase<Task> {}
```

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| identifier | String | Yes | Entity unique identifier |
| title | String | Yes | Singular display name |
| pluralTitle | String | Yes | Plural display name |
| description | String | No | Entity description |
| displayImageName | String? | No | Static image name for entity type |
| indexed | bool | No | Enable Spotlight indexing (iOS 26+, default: false) |
| enumerable | bool | No | Generate EnumerableEntityQuery (default: false) |

#### Entity Property Annotations

Annotations for defining entity property mappings.

```dart
class TaskEntitySpec extends EntitySpecBase<Task> {
  // ID getter method (required)
  @EntityId()
  String id(Task task) => task.id;

  // Title getter method (required)
  @EntityTitle()
  String title(Task task) => task.title;

  // Subtitle getter method (optional)
  @EntitySubtitle()
  String? subtitle(Task task) => task.description;

  // Image URL getter method (optional)
  @EntityImage()
  String? imageUrl(Task task) => task.thumbnailUrl;

  // Default query (entity list retrieval)
  @EntityDefaultQuery()
  Future<List<Task>> defaultQuery() async {
    return TaskRepository.instance.getAllTasks();
  }
}
```

| Annotation | Return Type | Required | Description |
|------------|-------------|----------|-------------|
| @EntityId() | String | Yes | Entity unique ID |
| @EntityTitle() | String | Yes | Display title |
| @EntitySubtitle() | String? | No | Subtitle |
| @EntityImage() | String? | No | Image URL |
| @EntityDefaultQuery() | Future<List<M>> | No | Default query |

#### EntitySpecBase

Base class for entity definitions.

```dart
abstract class EntitySpecBase<M> {
  const EntitySpecBase();
}

// M = Model type
class TaskEntitySpec extends EntitySpecBase<Task> {}
```

### Enum Related

#### EnumSpec

Annotation for defining an AppEnum.

```dart
@EnumSpec(identifier: 'com.example.taskapp.TaskPriority', title: 'Priority')
enum TaskPriority {
  @EnumCaseDisplay(title: 'High')
  high,
  @EnumCaseDisplay(title: 'Medium')
  medium,
  @EnumCaseDisplay(title: 'Low')
  low,
}
```

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| identifier | String | Yes | Unique identifier for the enum |
| title | String | Yes | Enum type display name |

#### EnumCaseDisplay

Annotation for defining display properties of enum cases.

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| title | String | Yes | Case display name |
| imageName | String | No | Asset/SF Symbol name for `.init(named:isTemplate:)` image |

### File Structure

```
app_intents_annotations/
├── lib/
│   ├── app_intents_annotations.dart  # Exports
│   └── src/
│       ├── annotations/
│       │   ├── intent_spec.dart      # IntentSpec, IntentImplementation
│       │   ├── intent_param.dart     # IntentParam
│       │   ├── entity_spec.dart      # EntitySpec
│       │   ├── entity_params.dart    # Entity* annotations
│       │   ├── enum_spec.dart        # EnumSpec, EnumCaseDisplay
│       │   ├── app_shortcut.dart     # AppShortcut, AppShortcutsProvider
│       │   └── intent_mode.dart      # IntentMode enum
│       ├── bases/
│       │   ├── intent_spec_base.dart # IntentSpecBase
│       │   └── entity_spec_base.dart # EntitySpecBase<M>
│       └── models/
│           └── intent_file.dart      # IntentFile model
├── example/
│   ├── create_task_intent.dart       # Intent example
│   ├── task_entity_spec.dart         # Entity example
│   └── models/
│       └── task.dart                 # Sample model
└── test/
    └── app_intents_annotations_test.dart
```

### WWDC26 experimental annotations

`@EntitySpec` / `@IntentSpec` carry opt-in WWDC26 fields (emitted only when the
matching `--experimental` flag is on, gated by `#if APP_INTENTS_WWDC26`):

- `@EntitySpec(schema:)` / `@IntentSpec(schema:)` / `@EnumSpec(schema:)` — App
  Schema domain conformance (#49). Pass a `'domain.schema'` string, ideally via
  the **App Schema catalog**: `AppSchemaDomain` (known iOS 27 domains) and
  `AppSchemas` (verified identifiers, e.g. `AppSchemas.messages.message`;
  `AppSchemas.of(domain, name)` for unlisted ones). See `src/schema/app_schema.dart`.
- `@EntitySpec(valueQuery:)` — generate an `IntentValueQuery` (#51).
- `@EntitySpec(exportAs:)` — cross-app export via `ValueRepresentation`
  (`EntityExportType.person`) (#54).
- `@EntitySpec(syncable:)` — `SyncableEntity` conformance (stable-id case) (#55).
- `@EntitySpec(ownership:)` — `OwnershipProvidingEntity` (#55).
- `@EntitySpec(relevantEntities:)` — `RelevantEntities` donator generation (#55).

See `docs/usage.md` → "WWDC26 Experimental Features" for full examples.

---

## app_intents

Flutter plugin for iOS App Intents and Android AppFunctions integration.

### Dependencies

- Flutter SDK: >=3.3.0
- plugin_platform_interface: ^2.0.2
- iOS: 17.0+, Swift 5.9+
- Android: API 36+ (AppFunctions)

### Architecture

```
AppIntents (Public API)
     │
     ▼
AppIntentsPlatform (Interface)
     │
     ├─► MethodChannelAppIntents (Default)
     │         │
     │         ▼
     │   MethodChannel('app_intents')
     │         │
     │         ▼
     │   AppIntentsPlugin.swift
     │
     └─► MockAppIntentsPlatform (Testing)
```

### Classes

#### AppIntents

Main facade class providing the full plugin API.

```dart
class AppIntents {
  // Platform info
  Future<String?> getPlatformVersion();

  // Intent handler registration
  void registerIntentHandler(String identifier, IntentHandler handler);
  void registerEntityQueryHandler(String entityIdentifier, EntityQueryHandler handler);
  void registerSuggestedEntitiesHandler(String entityIdentifier, SuggestedEntitiesHandler handler);

  // Streams
  Stream<IntentExecutionRequest> get onIntentExecution;
  Stream<String> get pendingActionsStream;

  // Caching API (for foreground/cache execution mode)
  Future<dynamic> getCachedValue(String key);
  Future<void> setCachedValue(String key, dynamic value);
  Future<void> clearCachedValue(String key);
  Future<bool> processPendingActions();
}
```

#### AppIntentsPlatform

Platform interface. Can be mocked for testing.

```dart
abstract class AppIntentsPlatform extends PlatformInterface {
  static AppIntentsPlatform get instance => _instance;
  // All AppIntents methods are defined here as abstract
}
```

### iOS Native (Swift)

#### AppIntentsPlugin.swift

Handles MethodChannel communication for iOS. Key methods:

```swift
public class AppIntentsPlugin: NSObject, FlutterPlugin {
  public static var shared: AppIntentsPlugin?

  // MethodChannel handler for:
  // - "executeIntent"         → Invoke Dart intent handlers
  // - "queryEntities"         → Query entities by identifiers
  // - "getSuggestedEntities"  → Get suggested entity list
  // - "getCachedValue"        → Read from UserDefaults cache
  // - "setCachedValue"        → Write to UserDefaults cache
  // - "clearCachedValue"      → Clear cached value
  // - "processPendingActions" → Process queued intent actions
  // - "configureStorage"      → Set App Group identifier for cross-process storage

  // Storage configuration (required for cache mode):
  // AppIntentsPlugin.configure(appGroupIdentifier: "group.com.example.app")
  // Uses App Group UserDefaults instead of .standard to share data between
  // the main app and App Intent extension processes.
}
```

### File Structure

```
app_intents/
├── lib/
│   ├── app_intents.dart                    # Public API
│   ├── app_intents_platform_interface.dart # Platform Interface
│   ├── app_intents_method_channel.dart     # Method Channel implementation
│   └── src/models/
│       ├── app_intent_error.dart           # Error model
│       └── intent_execution_request.dart   # Intent request model
├── ios/
│   ├── app_intents/
│   │   ├── Package.swift                    # Swift Package Manager manifest
│   │   └── Sources/app_intents/
│   │       ├── AppIntentsPlugin.swift       # iOS Swift implementation
│   │       └── PrivacyInfo.xcprivacy        # Privacy manifest
│   └── app_intents.podspec                  # CocoaPods config (shares Sources/ files)
├── android/
│   └── src/main/kotlin/.../
│       └── AppIntentsPlugin.kt             # Android Kotlin implementation
└── test/
    └── app_intents_test.dart
```

### Podspec Configuration

```ruby
Pod::Spec.new do |s|
  s.name             = 'app_intents'
  s.platform         = :ios, '17.0'
  s.swift_version    = '5.9'
  s.pod_target_xcconfig = {
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
end
```

---

## app_intents_codegen

Tool for generating code from Dart annotations.

### Dependencies

- Dart SDK: ^3.10.0
- analyzer: ">=7.0.0 <14.0.0"
- args: ^2.5.0
- build: ">=2.4.0 <5.0.0"
- source_gen: ">=2.0.0 <5.0.0"
- code_builder: ^4.10.0
- dart_style: ^3.0.0
- glob: ^2.1.0
- path: ^1.9.0
- yaml: ^3.1.0
- app_intents_annotations: ^0.11.0

### Implemented Features

1. **Swift Code Generation (iOS)** ✅
   - AppIntent conforming types with `ProvidesDialog` and `ParameterSummary`
   - AppEntity conforming types with SF Symbol image in `DisplayRepresentation`
   - AppEnum conforming types with `typeDisplayRepresentation` and `caseDisplayRepresentations`
   - EntityQuery generation (FlutterBridge-backed)
   - AppShortcutsProvider generation (result builder pattern)
   - Proper error handling (`throw` on URL construction failure)

2. **Kotlin Code Generation (Android)** ✅
   - `@AppFunction` annotated methods for AppFunctions framework
   - `@AppFunctionSerializable` data classes for entities
   - `AppFunctionsBridge` singleton for MethodChannel communication
   - Enum class generation with `fromValue()` companion

3. **Dart Binding Generation** ✅
   - Intent Handler registration code (part file format)
   - Entity Query Handler registration code
   - Suggested Entities Handler registration code

4. **build_runner Integration** ✅
   - `PartBuilder` implementation (`.intent.dart` file generation)
   - Incremental build support

5. **CLI Commands** ✅
   - `dart run app_intents_codegen:generate_swift` for Swift file generation
   - `dart run app_intents_codegen:generate_kotlin` for Kotlin file generation

6. **WWDC26 experimental generation (opt-in, default OFF)** ✅
   - Master switch `--experimental-wwdc26` + per-feature `--experimental=<flag>`
     (`app-schema`, `ownership`, `long-running`, `rich-types`, `value-query`,
     `value-representation`, `donation`). Output wrapped in `#if APP_INTENTS_WWDC26`.
   - App Schema (#49), execution control (#52), rich parameter types (#53),
     `IntentValueQuery` (#51), cross-app export (#54), `SyncableEntity` /
     `RelevantEntities` donation (#55). See `docs/usage.md` and `docs/adr/`.
   - Verification: `scripts/verify_experimental_swift.sh` dual-branch
     `swiftc -typecheck` (beta iOS 27 SDK).

### Usage

```yaml
# pubspec.yaml
dev_dependencies:
  build_runner: ^2.4.0
  app_intents_codegen: ^0.11.0
```

```bash
# Generate Dart bindings
dart run build_runner build

# Generate Swift App Intents (iOS)
dart run app_intents_codegen:generate_swift -i lib -o ios/Runner/GeneratedIntents

# Generate Kotlin AppFunctions (Android)
dart run app_intents_codegen:generate_kotlin -i lib -o android/app/src/main/kotlin/com/example/app/generated -p com.example.app.generated
```

### Generated Files

**Dart Files** (via build_runner):
```
lib/
├── intents/
│   ├── create_task_intent.dart
│   └── create_task_intent.intent.dart  # Generated part file
├── entities/
│   ├── task_entity.dart
│   └── task_entity.intent.dart         # Generated part file
```

**Swift Files** (via CLI command):
```
ios/Runner/GeneratedIntents/
└── GeneratedAppIntents.swift           # All Intents/Entities/AppShortcuts
```

### File Structure

```
app_intents_codegen/
├── lib/
│   ├── app_intents_codegen.dart    # Entry point
│   └── src/
│       ├── analyzer/               # Annotation analysis
│       │   ├── intent_analyzer.dart
│       │   ├── entity_analyzer.dart
│       │   ├── enum_analyzer.dart
│       │   └── shortcut_analyzer.dart
│       ├── generator/              # Code generation
│       │   ├── swift_generator.dart
│       │   ├── kotlin_generator.dart
│       │   └── dart_generator.dart
│       ├── models/                 # Data models
│       │   ├── intent_info.dart
│       │   ├── entity_info.dart
│       │   └── enum_info.dart
│       └── builder.dart            # build_runner integration
├── bin/
│   ├── generate_swift.dart         # Swift CLI command
│   └── generate_kotlin.dart        # Kotlin CLI command
└── test/                           # 150+ tests
```

---

## ios-spm (Swift Package)

Swift Package for iOS App Intents integration.

### Package.swift

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AppIntentsBridge",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "AppIntentsBridge", targets: ["AppIntentsBridge"]),
    ],
    targets: [
        .target(name: "AppIntentsBridge"),
    ]
)
```

### Role

1. Bridge between Flutter plugin and iOS App Intents framework
2. Communication from generated Swift Intents to Flutter
3. Thread-safe FlutterBridge actor

### Key Components

#### FlutterBridge

Thread-safe singleton actor that manages communication from App Intents to Flutter.

```swift
public actor FlutterBridge {
    public static let shared = FlutterBridge()

    // For intent execution (mainly for Entity Query after URL scheme migration)
    public func setIntentExecutor(_ executor: @escaping @Sendable (...) async throws -> Any)

    // For Entity Query
    public func setEntityQueryExecutor(_ executor: @escaping @Sendable (...) async throws -> [[String: Any]])
    public func setSuggestedEntitiesExecutor(_ executor: @escaping @Sendable (...) async throws -> [[String: Any]])
}
```

#### AppIntentError

Common error type (defined in `ErrorHandling.swift`).

```swift
public enum AppIntentError: LocalizedError {
    case intentNotFound(String)
    case handlerFailed(String)
    case custom(code: String, message: String)
    case entityQueryNotConfigured
}
```

### File Structure

```
ios-spm/
└── AppIntentsBridge/
    ├── Package.swift
    └── Sources/
        └── AppIntentsBridge/
            ├── AppIntentsBridge.swift  # Module entry point
            ├── FlutterBridge.swift     # Main communication bridge
            ├── ErrorHandling.swift     # AppIntentError type
            └── EntityImage.swift       # EntityImageSource enum
```

### Integration Steps

1. Copy files from `ios-spm/AppIntentsBridge/Sources/AppIntentsBridge/` to `ios/Runner/AppIntentsBridge/`
2. Add to Xcode project
3. Set executor in AppDelegate:

```swift
if #available(iOS 17.0, *) {
    Task {
        await FlutterBridge.shared.setIntentExecutor { identifier, params in
            // Call Dart handler via AppIntentsPlugin
        }
    }
}
```
