# Package Details

## app_intents_annotations

A pure Dart package that provides annotations and base classes for defining Intents/Entities.

### Dependencies

- Dart SDK: ^3.10.1
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
class CreateTaskIntentSpec extends IntentSpecBase<Input, Output> {}
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

#### IntentImplementation

```dart
enum IntentImplementation {
  dart,   // Implement on Dart/Flutter side
  swift,  // Implement on Swift side
}
```

#### IntentParam

Annotation for defining intent parameters.

```dart
class MyIntentSpec extends IntentSpecBase<Input, Output> {
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
| entityType | Type | No | Entity type for picker parameters |
| enumType | Type | No | AppEnum type for selection parameters |

#### IntentSpecBase

Base class for intent definitions. Specify input/output types via generics.

```dart
abstract class IntentSpecBase<I, O> {
  const IntentSpecBase();
}

// I = Input type (parameters)
// O = Output type (result)
class MyIntentSpec extends IntentSpecBase<MyInput, MyOutput> {}
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
| pluralTitle | String | No | Plural display name |
| description | String | No | Entity description |

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
@EnumSpec(title: 'Priority')
enum TaskPriority {
  @EnumCaseDisplay(title: 'High', subtitle: 'Urgent tasks')
  high,
  @EnumCaseDisplay(title: 'Medium')
  medium,
  @EnumCaseDisplay(title: 'Low')
  low,
}
```

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| title | String | Yes | Enum type display name |

#### EnumCaseDisplay

Annotation for defining display properties of enum cases.

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| title | String | Yes | Case display name |
| subtitle | String | No | Case subtitle |

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
│       │   └── enum_spec.dart        # EnumSpec, EnumCaseDisplay
│       └── bases/
│           ├── intent_spec_base.dart # IntentSpecBase<I,O>
│           └── entity_spec_base.dart # EntitySpecBase<M>
├── example/
│   ├── create_task_intent.dart       # Intent example
│   ├── task_entity_spec.dart         # Entity example
│   └── models/
│       └── task.dart                 # Sample model
└── test/
    └── app_intents_annotations_test.dart
```

---

## app_intents

Flutter plugin for iOS App Intents integration.

### Dependencies

- Flutter SDK: >=3.3.0
- plugin_platform_interface: ^2.0.2
- iOS: 17.0+
- Swift: 5.9+

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

Main facade class.

```dart
class AppIntents {
  Future<String?> getPlatformVersion() {
    return AppIntentsPlatform.instance.getPlatformVersion();
  }
}

// Usage
final appIntents = AppIntents();
final version = await appIntents.getPlatformVersion();
```

#### AppIntentsPlatform

Platform interface. Can be mocked for testing.

```dart
abstract class AppIntentsPlatform extends PlatformInterface {
  static AppIntentsPlatform get instance => _instance;
  static set instance(AppIntentsPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion();
}
```

#### MethodChannelAppIntents

Method Channel implementation.

```dart
class MethodChannelAppIntents extends AppIntentsPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('app_intents');

  @override
  Future<String?> getPlatformVersion() async {
    return methodChannel.invokeMethod<String>('getPlatformVersion');
  }
}
```

### iOS Native (Swift)

#### AppIntentsPlugin.swift

```swift
public class AppIntentsPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "app_intents",
      binaryMessenger: registrar.messenger()
    )
    let instance = AppIntentsPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
```

### File Structure

```
app_intents/
├── lib/
│   ├── app_intents.dart                    # Public API
│   ├── app_intents_platform_interface.dart # Platform Interface
│   └── app_intents_method_channel.dart     # Method Channel implementation
├── ios/
│   ├── Classes/
│   │   └── AppIntentsPlugin.swift          # Swift implementation
│   └── app_intents.podspec                 # CocoaPods config
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

- Dart SDK: ^3.10.1
- analyzer: ^7.4.5
- build: ^2.4.2
- source_gen: ^2.0.0
- path: ^1.9.0

### Implemented Features

1. **Swift Code Generation** ✅
   - AppIntent conforming types with `ProvidesDialog` and `ParameterSummary`
   - AppEntity conforming types with SF Symbol image in `DisplayRepresentation`
   - AppEnum conforming types with `typeDisplayRepresentation` and `caseDisplayRepresentations`
   - EntityQuery generation (FlutterBridge-backed)
   - AppShortcutsProvider generation (result builder pattern)
   - Proper error handling (`throw` on URL construction failure)

2. **Dart Binding Generation** ✅
   - Intent Handler registration code (part file format)
   - Entity Query Handler registration code
   - Suggested Entities Handler registration code

3. **build_runner Integration** ✅
   - `PartBuilder` implementation (`.intent.dart` file generation)
   - Incremental build support

4. **CLI Command** ✅
   - `dart run app_intents_codegen:generate_swift` for Swift file generation

### Usage

```yaml
# pubspec.yaml
dev_dependencies:
  build_runner: ^2.4.0
  app_intents_codegen: ^0.2.0
```

```bash
# Generate Dart bindings
dart run build_runner build

# Generate Swift App Intents
dart run app_intents_codegen:generate_swift -i lib -o ios/Runner/GeneratedIntents
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
│       │   └── enum_analyzer.dart
│       ├── generator/              # Code generation
│       │   ├── swift_generator.dart
│       │   └── dart_generator.dart
│       ├── models/                 # Data models
│       │   ├── intent_info.dart
│       │   ├── entity_info.dart
│       │   └── enum_info.dart
│       └── builder.dart            # build_runner integration
├── bin/
│   └── generate_swift.dart         # CLI command
└── test/                           # 114 tests
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

Common error type.

```swift
public enum AppIntentError: Error {
    case executorNotSet
    case channelNotAvailable
    case custom(code: String, message: String)
}
```

### File Structure

```
ios-spm/
└── AppIntentsBridge/
    ├── Package.swift
    └── Sources/
        └── AppIntentsBridge/
            ├── FlutterBridge.swift     # Main communication bridge
            ├── AppIntentError.swift    # Error type
            └── EntityImageSource.swift # Entity image source
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
