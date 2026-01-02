# パッケージ詳細

## app_intents_annotations

Intent/Entityを定義するためのアノテーションとベースクラスを提供する純粋なDartパッケージ。

### 依存関係

- Dart SDK: ^3.10.1
- 外部依存なし（フレームワーク非依存）

### Intent関連

#### IntentSpec

Intentを定義するためのアノテーション。

```dart
@IntentSpec(
  identifier: 'CreateTaskIntent',    // 一意の識別子
  title: 'Create Task',              // 表示タイトル
  description: 'Creates a new task', // 説明文
  implementation: IntentImplementation.dart, // 実装言語
)
class CreateTaskIntentSpec extends IntentSpecBase<Input, Output> {}
```

| プロパティ | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| identifier | String | Yes | Intent一意識別子 |
| title | String | Yes | ユーザー向け表示名 |
| description | String | No | Intent説明文 |
| implementation | IntentImplementation | No | 実装言語（デフォルト: dart） |

#### IntentImplementation

```dart
enum IntentImplementation {
  dart,   // Dart/Flutter側で実装
  swift,  // Swift側で実装
}
```

#### IntentParam

Intentパラメータを定義するアノテーション。

```dart
class MyIntentSpec extends IntentSpecBase<Input, Output> {
  @IntentParam(
    title: 'Task Title',        // パラメータ表示名
    description: 'The title',   // パラメータ説明
    isOptional: false,          // 必須/任意
  )
  final String title;

  @IntentParam(title: 'Due Date', isOptional: true)
  final DateTime? dueDate;
}
```

| プロパティ | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| title | String | Yes | パラメータ表示名 |
| description | String | No | パラメータ説明 |
| isOptional | bool | No | 任意パラメータか（デフォルト: false） |

#### IntentSpecBase

Intent定義の基底クラス。ジェネリクスで入出力型を指定。

```dart
abstract class IntentSpecBase<I, O> {
  const IntentSpecBase();
}

// I = Input型（パラメータ）
// O = Output型（結果）
class MyIntentSpec extends IntentSpecBase<MyInput, MyOutput> {}
```

### Entity関連

#### EntitySpec

Entityを定義するためのアノテーション。

```dart
@EntitySpec(
  identifier: 'TaskEntity',     // 一意の識別子
  title: 'Task',                // 単数形タイトル
  pluralTitle: 'Tasks',         // 複数形タイトル
  description: 'A task entity', // 説明文
)
class TaskEntitySpec extends EntitySpecBase<Task> {}
```

| プロパティ | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| identifier | String | Yes | Entity一意識別子 |
| title | String | Yes | 単数形表示名 |
| pluralTitle | String | No | 複数形表示名 |
| description | String | No | Entity説明文 |

#### Entity Property アノテーション

Entityのプロパティマッピングを定義するアノテーション群。

```dart
class TaskEntitySpec extends EntitySpecBase<Task> {
  // ID取得メソッド（必須）
  @EntityId()
  String id(Task task) => task.id;

  // タイトル取得メソッド（必須）
  @EntityTitle()
  String title(Task task) => task.title;

  // サブタイトル取得メソッド（任意）
  @EntitySubtitle()
  String? subtitle(Task task) => task.description;

  // 画像URL取得メソッド（任意）
  @EntityImage()
  String? imageUrl(Task task) => task.thumbnailUrl;

  // デフォルトクエリ（エンティティ一覧取得）
  @EntityDefaultQuery()
  Future<List<Task>> defaultQuery() async {
    return TaskRepository.instance.getAllTasks();
  }
}
```

| アノテーション | 戻り値型 | 必須 | 説明 |
|---------------|---------|------|------|
| @EntityId() | String | Yes | エンティティの一意ID |
| @EntityTitle() | String | Yes | 表示タイトル |
| @EntitySubtitle() | String? | No | サブタイトル |
| @EntityImage() | String? | No | 画像URL |
| @EntityDefaultQuery() | Future<List<M>> | No | デフォルトクエリ |

#### EntitySpecBase

Entity定義の基底クラス。

```dart
abstract class EntitySpecBase<M> {
  const EntitySpecBase();
}

// M = Model型
class TaskEntitySpec extends EntitySpecBase<Task> {}
```

### ファイル構成

```
app_intents_annotations/
├── lib/
│   ├── app_intents_annotations.dart  # エクスポート
│   └── src/
│       ├── annotations/
│       │   ├── intent_spec.dart      # IntentSpec, IntentImplementation
│       │   ├── intent_param.dart     # IntentParam
│       │   ├── entity_spec.dart      # EntitySpec
│       │   └── entity_params.dart    # Entity*アノテーション
│       └── bases/
│           ├── intent_spec_base.dart # IntentSpecBase<I,O>
│           └── entity_spec_base.dart # EntitySpecBase<M>
├── example/
│   ├── create_task_intent.dart       # Intent使用例
│   ├── task_entity_spec.dart         # Entity使用例
│   └── models/
│       └── task.dart                 # サンプルモデル
└── test/
    └── app_intents_annotations_test.dart
```

---

## app_intents

iOS App Intents連携用Flutterプラグイン。

### 依存関係

- Flutter SDK: >=3.3.0
- plugin_platform_interface: ^2.0.2
- iOS: 13.0+
- Swift: 5.0+

### アーキテクチャ

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

### クラス

#### AppIntents

メインのファサードクラス。

```dart
class AppIntents {
  Future<String?> getPlatformVersion() {
    return AppIntentsPlatform.instance.getPlatformVersion();
  }
}

// 使用例
final appIntents = AppIntents();
final version = await appIntents.getPlatformVersion();
```

#### AppIntentsPlatform

プラットフォームインターフェース。テスト時にモック可能。

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

Method Channel実装。

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

### ファイル構成

```
app_intents/
├── lib/
│   ├── app_intents.dart                    # Public API
│   ├── app_intents_platform_interface.dart # Platform Interface
│   └── app_intents_method_channel.dart     # Method Channel実装
├── ios/
│   ├── Classes/
│   │   └── AppIntentsPlugin.swift          # Swift実装
│   └── app_intents.podspec                 # CocoaPods設定
└── test/
    └── app_intents_test.dart
```

### Podspec設定

```ruby
Pod::Spec.new do |s|
  s.name             = 'app_intents'
  s.platform         = :ios, '13.0'
  s.swift_version    = '5.0'
  s.pod_target_xcconfig = {
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
end
```

---

## app_intents_codegen

Dartアノテーションからコードを生成するツール。

### 依存関係

- Dart SDK: ^3.10.1
- path: ^1.9.0

### 現在の状態

基本構造のみ実装済み。コード生成機能は開発中。

### 計画されている機能

1. **Swiftコード生成**
   - AppIntent準拠型の生成
   - AppEntity準拠型の生成
   - EntityQueryの生成

2. **Dartバインディング生成**
   - Intent Handler登録コード
   - Entity Resolver登録コード

3. **build_runner統合**
   - `Builder`実装
   - インクリメンタルビルド

### 想定される使用方法

```yaml
# pubspec.yaml
dev_dependencies:
  build_runner: ^2.4.0
  app_intents_codegen: ^0.0.1
```

```bash
# コード生成実行
dart run build_runner build
```

### 生成ファイル（想定）

```
lib/
├── intents/
│   └── create_task_intent.dart
├── entities/
│   └── task_entity_spec.dart
└── generated/
    ├── intents.g.dart           # Dart bindings
    └── intents.g.swift          # Swift App Intents
```

### ファイル構成

```
app_intents_codegen/
├── lib/
│   └── app_intents_codegen.dart # エントリポイント
└── test/
    └── app_intents_codegen_test.dart
```

---

## ios-spm (Swift Package)

iOS App Intents統合用のSwift Package。

### Package.swift

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AppIntentsBridge",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "AppIntentsBridge", targets: ["AppIntentsBridge"]),
    ],
    targets: [
        .target(name: "AppIntentsBridge"),
    ]
)
```

### 役割

1. FlutterプラグインとiOS App Intentsフレームワークの橋渡し
2. 生成されたSwift Intentの配置先
3. App Intents関連のSwiftユーティリティ

### ファイル構成

```
ios-spm/
└── AppIntentsBridge/
    ├── Package.swift
    └── Sources/
        └── AppIntentsBridge/
            └── AppIntentsBridge.swift
```
