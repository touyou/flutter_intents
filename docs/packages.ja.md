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
- analyzer: ^7.4.5
- build: ^2.4.2
- source_gen: ^2.0.0
- path: ^1.9.0

### 実装済み機能

1. **Swiftコード生成** ✅
   - AppIntent準拠型の生成
   - AppEntity準拠型の生成
   - EntityQueryの生成
   - AppShortcutsProviderの生成

2. **Dartバインディング生成** ✅
   - Intent Handler登録コード（part file形式）
   - Entity Query Handler登録コード
   - Suggested Entities Handler登録コード

3. **build_runner統合** ✅
   - `PartBuilder`実装（`.intent.dart`ファイル生成）
   - インクリメンタルビルド対応

4. **CLIコマンド** ✅
   - `dart run app_intents_codegen:generate_swift` でSwiftファイル生成

### 使用方法

```yaml
# pubspec.yaml
dev_dependencies:
  build_runner: ^2.4.0
  app_intents_codegen: ^0.1.0
```

```bash
# Dartバインディング生成
dart run build_runner build

# Swift App Intents生成
dart run app_intents_codegen:generate_swift -i lib -o ios/Runner/GeneratedIntents
```

### 生成ファイル

**Dartファイル** (build_runner経由):
```
lib/
├── intents/
│   ├── create_task_intent.dart
│   └── create_task_intent.intent.dart  # 生成されたpart file
├── entities/
│   ├── task_entity.dart
│   └── task_entity.intent.dart         # 生成されたpart file
```

**Swiftファイル** (CLIコマンド経由):
```
ios/Runner/GeneratedIntents/
└── GeneratedAppIntents.swift           # 全Intent/Entity/AppShortcuts
```

### ファイル構成

```
app_intents_codegen/
├── lib/
│   ├── app_intents_codegen.dart    # エントリポイント
│   └── src/
│       ├── analyzer/               # アノテーション解析
│       │   ├── intent_analyzer.dart
│       │   └── entity_analyzer.dart
│       ├── generator/              # コード生成
│       │   ├── swift_generator.dart
│       │   └── dart_generator.dart
│       └── builder.dart            # build_runner統合
├── bin/
│   └── generate_swift.dart         # CLIコマンド
└── test/                           # 70+テスト
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
2. 生成されたSwift IntentからFlutterへの通信
3. スレッドセーフなFlutterBridge actor

### 主要コンポーネント

#### FlutterBridge

スレッドセーフなシングルトンactorで、App IntentsからFlutterへの通信を管理。

```swift
public actor FlutterBridge {
    public static let shared = FlutterBridge()

    // Intent実行用（URL scheme移行後は主にEntity Query用）
    public func setIntentExecutor(_ executor: @escaping @Sendable (...) async throws -> Any)

    // Entity Query用
    public func setEntityQueryExecutor(_ executor: @escaping @Sendable (...) async throws -> [[String: Any]])
    public func setSuggestedEntitiesExecutor(_ executor: @escaping @Sendable (...) async throws -> [[String: Any]])
}
```

#### AppIntentError

共通エラー型。

```swift
public enum AppIntentError: Error {
    case executorNotSet
    case channelNotAvailable
    case custom(code: String, message: String)
}
```

### ファイル構成

```
ios-spm/
└── AppIntentsBridge/
    ├── Package.swift
    └── Sources/
        └── AppIntentsBridge/
            ├── FlutterBridge.swift     # メイン通信ブリッジ
            ├── AppIntentError.swift    # エラー型
            └── EntityImageSource.swift # Entity画像ソース
```

### 統合方法

1. `ios-spm/AppIntentsBridge/Sources/AppIntentsBridge/`のファイルを`ios/Runner/AppIntentsBridge/`にコピー
2. Xcodeプロジェクトに追加
3. AppDelegateでexecutorを設定:

```swift
if #available(iOS 16.0, *) {
    Task {
        await FlutterBridge.shared.setIntentExecutor { identifier, params in
            // AppIntentsPlugin経由でDartハンドラーを呼び出し
        }
    }
}
```
