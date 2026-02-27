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
  urlScheme: 'taskapp',              // Intent実行用URLスキーム
  urlAction: 'create',              // URLホスト/アクション
  resultDialogTemplate: 'Created task "{title}"', // Siriダイアログフィードバック
  parameterSummary: 'Create task {title}',        // Shortcuts UI表示
)
class CreateTaskIntentSpec extends IntentSpecBase {}
```

| プロパティ | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| identifier | String | Yes | Intent一意識別子 |
| title | String | Yes | ユーザー向け表示名 |
| description | String | No | Intent説明文 |
| implementation | IntentImplementation | No | 実装言語（デフォルト: dart） |
| urlScheme | String | No | Intent実行用URLスキーム |
| urlAction | String | No | URLホスト/アクションパス |
| resultDialogTemplate | String | No | ダイアログテンプレート（例: `'Created "{title}"'`） |
| parameterSummary | String | No | Shortcuts UIサマリー（例: `'Create {title}'`） |
| supportedModes | IntentMode? | No | 実行モード（`foreground`または`background`） |

#### IntentImplementation

```dart
enum IntentImplementation {
  dart,    // Dart/Flutter側で実装
  swift,   // Swift側で実装
  kotlin,  // Kotlin側で実装
}
```

#### IntentParam

Intentパラメータを定義するアノテーション。

```dart
class MyIntentSpec extends IntentSpecBase {
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
| entityType | String? | No | ピッカー用エンティティ型識別子 |
| enumType | String? | No | 選択式AppEnum型識別子 |
| fileType | String? | No | ファイルパラメータ用UTI（例: `'public.image'`） |

#### IntentSpecBase

Intent定義の基底クラス。

```dart
abstract class IntentSpecBase {
  const IntentSpecBase();
}

class MyIntentSpec extends IntentSpecBase {}
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
| pluralTitle | String | Yes | 複数形表示名 |
| description | String | No | Entity説明文 |
| displayImageName | String? | No | Entity型の静的画像名 |
| indexed | bool | No | Spotlight索引を有効化（iOS 26+、デフォルト: false） |
| enumerable | bool | No | EnumerableEntityQueryを生成（デフォルト: false） |

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

### Enum関連

#### EnumSpec

AppEnumを定義するためのアノテーション。

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

| プロパティ | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| title | String | Yes | 列挙型の表示名 |

#### EnumCaseDisplay

列挙型ケースの表示プロパティを定義するアノテーション。

| プロパティ | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| title | String | Yes | ケース表示名 |
| subtitle | String | No | ケースサブタイトル |

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
│       │   ├── entity_params.dart    # Entity*アノテーション
│       │   ├── enum_spec.dart        # EnumSpec, EnumCaseDisplay
│       │   ├── app_shortcut.dart     # AppShortcut, AppShortcutsProvider
│       │   └── intent_mode.dart      # IntentMode列挙型
│       ├── bases/
│       │   ├── intent_spec_base.dart # IntentSpecBase
│       │   └── entity_spec_base.dart # EntitySpecBase<M>
│       └── models/
│           └── intent_file.dart      # IntentFileモデル
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

iOS App IntentsおよびAndroid AppFunctions連携用Flutterプラグイン。

### 依存関係

- Flutter SDK: >=3.3.0
- plugin_platform_interface: ^2.0.2
- iOS: 17.0+、Swift 5.9+
- Android: API 36+（AppFunctions）

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

プラグインの全APIを提供するメインファサードクラス。

```dart
class AppIntents {
  // プラットフォーム情報
  Future<String?> getPlatformVersion();

  // Intentハンドラー登録
  void registerIntentHandler(String identifier, IntentHandler handler);
  void registerEntityQueryHandler(String entityIdentifier, EntityQueryHandler handler);
  void registerSuggestedEntitiesHandler(String entityIdentifier, SuggestedEntitiesHandler handler);

  // ストリーム
  Stream<IntentExecutionRequest> get onIntentExecution;
  Stream<String> get pendingActionsStream;

  // キャッシングAPI（フォアグラウンド/キャッシュ実行モード用）
  Future<dynamic> getCachedValue(String key);
  Future<void> setCachedValue(String key, dynamic value);
  Future<void> clearCachedValue(String key);
  Future<bool> processPendingActions();
}
```

#### AppIntentsPlatform

プラットフォームインターフェース。テスト時にモック可能。

```dart
abstract class AppIntentsPlatform extends PlatformInterface {
  static AppIntentsPlatform get instance => _instance;
  // 全AppIntentsメソッドが抽象メソッドとして定義
}
```

### iOS Native (Swift)

#### AppIntentsPlugin.swift

iOS向けMethodChannel通信を処理。主なメソッド:

```swift
public class AppIntentsPlugin: NSObject, FlutterPlugin {
  public static var shared: AppIntentsPlugin?

  // MethodChannelハンドラー:
  // - "executeIntent"         → DartのIntentハンドラーを呼び出し
  // - "queryEntities"         → IDでエンティティを検索
  // - "getSuggestedEntities"  → 推薦エンティティリストを取得
  // - "getCachedValue"        → UserDefaultsキャッシュから読み込み
  // - "setCachedValue"        → UserDefaultsキャッシュへ書き込み
  // - "clearCachedValue"      → キャッシュ値をクリア
  // - "processPendingActions" → キューイングされたアクションを処理
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
│   │   └── AppIntentsPlugin.swift          # iOS Swift実装
│   └── app_intents.podspec                 # CocoaPods設定
├── android/
│   └── src/main/kotlin/.../
│       └── AppIntentsPlugin.kt             # Android Kotlin実装
└── test/
    └── app_intents_test.dart
```

### Podspec設定

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

Dartアノテーションからコードを生成するツール。

### 依存関係

- Dart SDK: ^3.10.1
- analyzer: ^7.4.5
- build: ^2.4.2
- source_gen: ^2.0.0
- path: ^1.9.0

### 実装済み機能

1. **Swiftコード生成（iOS）** ✅
   - AppIntent準拠型の生成（`ProvidesDialog`、`ParameterSummary` 対応）
   - AppEntity準拠型の生成（SF Symbol画像付き `DisplayRepresentation`）
   - AppEnum準拠型の生成（`typeDisplayRepresentation`、`caseDisplayRepresentations`）
   - EntityQueryの生成（FlutterBridgeバック）
   - AppShortcutsProviderの生成（result builderパターン）
   - 適切なエラーハンドリング（URL構築失敗時に `throw`）

2. **Kotlinコード生成（Android）** ✅
   - `@AppFunction` アノテーション付きメソッド（AppFunctionsフレームワーク）
   - `@AppFunctionSerializable` データクラス（エンティティ）
   - `AppFunctionsBridge` シングルトン（MethodChannel通信）
   - Enumクラス生成（`fromValue()` companion object）

3. **Dartバインディング生成** ✅
   - Intent Handler登録コード（part file形式）
   - Entity Query Handler登録コード
   - Suggested Entities Handler登録コード

4. **build_runner統合** ✅
   - `PartBuilder`実装（`.intent.dart`ファイル生成）
   - インクリメンタルビルド対応

5. **CLIコマンド** ✅
   - `dart run app_intents_codegen:generate_swift` でSwiftファイル生成
   - `dart run app_intents_codegen:generate_kotlin` でKotlinファイル生成

### 使用方法

```yaml
# pubspec.yaml
dev_dependencies:
  build_runner: ^2.4.0
  app_intents_codegen: ^0.6.1
```

```bash
# Dartバインディング生成
dart run build_runner build

# Swift App Intents生成（iOS）
dart run app_intents_codegen:generate_swift -i lib -o ios/Runner/GeneratedIntents

# Kotlin AppFunctions生成（Android）
dart run app_intents_codegen:generate_kotlin -i lib -o android/app/src/main/kotlin/com/example/app/generated -p com.example.app.generated
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
│       │   ├── entity_analyzer.dart
│       │   ├── enum_analyzer.dart
│       │   └── shortcut_analyzer.dart
│       ├── generator/              # コード生成
│       │   ├── swift_generator.dart
│       │   ├── kotlin_generator.dart
│       │   └── dart_generator.dart
│       ├── models/                 # データモデル
│       │   ├── intent_info.dart
│       │   ├── entity_info.dart
│       │   └── enum_info.dart
│       └── builder.dart            # build_runner統合
├── bin/
│   ├── generate_swift.dart         # Swift CLIコマンド
│   └── generate_kotlin.dart        # Kotlin CLIコマンド
└── test/                           # 150+テスト
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
    platforms: [.iOS(.v17)],
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
public enum AppIntentError: LocalizedError {
    case intentNotFound(String)
    case handlerFailed(String)
    case custom(code: String, message: String)
    case entityQueryNotConfigured
}
```

### ファイル構成

```
ios-spm/
└── AppIntentsBridge/
    ├── Package.swift
    └── Sources/
        └── AppIntentsBridge/
            ├── AppIntentsBridge.swift  # モジュールエントリーポイント
            ├── FlutterBridge.swift     # メイン通信ブリッジ
            ├── ErrorHandling.swift     # AppIntentErrorエラー型
            └── EntityImage.swift       # EntityImageSource列挙型
```

### 統合方法

1. `ios-spm/AppIntentsBridge/Sources/AppIntentsBridge/`のファイルを`ios/Runner/AppIntentsBridge/`にコピー
2. Xcodeプロジェクトに追加
3. AppDelegateでexecutorを設定:

```swift
if #available(iOS 17.0, *) {
    Task {
        await FlutterBridge.shared.setIntentExecutor { identifier, params in
            // AppIntentsPlugin経由でDartハンドラーを呼び出し
        }
    }
}
```
