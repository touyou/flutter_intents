# 使用方法

## セットアップ

### 1. 依存関係の追加

```yaml
# pubspec.yaml
dependencies:
  app_intents: ^0.11.0
  app_intents_annotations: ^0.11.0

dev_dependencies:
  app_intents_codegen: ^0.11.0
  build_runner: ^2.4.0
```

### 2. プラットフォーム設定

#### iOS

`ios/Podfile`でiOSバージョンを17.0以上に設定（App Intentsフレームワーク要件）:

```ruby
platform :ios, '17.0'
```

> **Note**: App Intentsフレームワークは iOS 17.0 以上が必須です。

#### Android

`appfunctions:1.0.0-alpha10` は **Android Gradle Plugin 9.1.0+**、**Gradle 9.3.1+**、**compileSdk 37** を必要とします。
`android/app/build.gradle.kts` を更新します（`minSdk = 36` は AppFunctions が Android 16 を必要とするため）:

```kotlin
android {
    compileSdk = 37
    defaultConfig {
        minSdk = 36
        targetSdk = 37
    }
}
```

KSPとAppFunctionsの依存関係を追加:

```kotlin
// android/settings.gradle.kts
id("com.android.application") version "9.2.1" apply false
id("org.jetbrains.kotlin.android") version "2.2.20" apply false
id("com.google.devtools.ksp") version "2.3.9" apply false

// android/app/build.gradle.kts
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.devtools.ksp")
    id("dev.flutter.flutter-gradle-plugin")
}
dependencies {
    implementation("androidx.appfunctions:appfunctions:1.0.0-alpha10")
    // appfunctions-service の alpha10 は2026年7月時点でまだ Google Maven に公開されていない
    // （リリースノートには記載があるがアーティファクトが404）ため、公開されるまで1つ前のバージョンに固定する。
    implementation("androidx.appfunctions:appfunctions-service:1.0.0-alpha09")
    ksp("androidx.appfunctions:appfunctions-compiler:1.0.0-alpha10")
}

ksp {
    arg("appfunctions:aggregateAppFunctions", "true")
}
```

`android/gradle.properties` に AGP 9 互換性のための shim を追加します:

```properties
# Flutter Gradle plugin はまだ AGP 9 の new DSL をサポートしていないため legacy DSL を使う
android.newDsl=false
# KSP は AGP 9 の built-in Kotlin と非互換のため kotlin-android プラグインを維持する
android.builtInKotlin=false
```

`android/gradle/wrapper/gradle-wrapper.properties` の Gradle wrapper を 9.3.1+ に更新します:

```properties
distributionUrl=https\://services.gradle.org/distributions/gradle-9.5.1-all.zip
```

> **Note**: AppFunctionsは Android 16（API 36）以上が必須です。`compileSdk 37` の要求は `appfunctions:1.0.0-alpha10` の AAR メタデータに由来します。

### 3. iOSネイティブ設定 (AppIntentsBridge)

`AppIntentsBridge` Swiftパッケージは、FlutterアプリとiOS App Intentsのネイティブブリッジを提供します。Swift Package Manager (SPM) で追加できます:

1. Xcodeプロジェクト（`ios/Runner.xcworkspace`）を開く
2. **File → Add Package Dependencies** を選択
3. リポジトリURL: `https://github.com/touyou/flutter_intents` を入力
4. `AppIntentsBridge` パッケージプロダクトを選択
5. `Runner` ターゲットに追加

続いて、プロセス間ストレージのための App Groups を設定します（cache モードで必須）:

1. Xcode で Runner ターゲットを選択 → **Signing & Capabilities** → **+ Capability** → **App Groups**
2. 識別子を追加（例: `group.com.example.app`）

`AppDelegate.swift` に以下を追加:

```swift
import app_intents
import AppIntentsBridge

// AppDelegate内 (FlutterImplicitEngineDelegateを使用):
if #available(iOS 17.0, *) {
  // App Group ストレージを設定 — cache モードの Intent がメインアプリと
  // App Intent 拡張プロセス間でデータを共有するために必須。
  // これがないと、キャッシュしたデータがプロセスをまたいで「リセット」されたように見える。
  AppIntentsPlugin.configure(appGroupIdentifier: "group.com.example.app")

  Task { @MainActor in
    // Intent executor
    await FlutterBridge.shared.setIntentExecutor { identifier, params in
      guard let plugin = AppIntentsPlugin.shared else {
        throw AppIntentError.intentNotFound(identifier)
      }
      return try await plugin.executeIntentAsync(identifier: identifier, params: params)
    }

    // Entity query executor
    await FlutterBridge.shared.setEntityQueryExecutor { entityIdentifier, identifiers in
      guard let plugin = AppIntentsPlugin.shared else {
        throw AppIntentError.entityQueryNotConfigured
      }
      return try await plugin.queryEntitiesAsync(
        entityIdentifier: entityIdentifier, identifiers: identifiers)
    }

    // Suggested entities executor
    await FlutterBridge.shared.setSuggestedEntitiesExecutor { entityIdentifier in
      guard let plugin = AppIntentsPlugin.shared else {
        throw AppIntentError.entityQueryNotConfigured
      }
      return try await plugin.getSuggestedEntitiesAsync(entityIdentifier: entityIdentifier)
    }
  }
}
```

#### FlutterBridge waitForPlugin パターン

App IntentsがFlutterBridgeモードで実行される場合、Flutterエンジンがまだ初期化されていない可能性があります。生成されたEntityクエリコードは内部的にリトライパターンを使用します（`FlutterBridge`はexecutorが設定されるまで最大5秒待機します）。`AppIntentsPlugin.shared`にアクセスする必要があるカスタムSwiftコードでは、以下のパターンを使用してください:

```swift
private static func waitForPlugin() async throws -> AppIntentsPlugin {
    if let plugin = AppIntentsPlugin.shared { return plugin }
    // 100ms間隔で最大20回リトライ（合計最大2秒）。
    // Flutterエンジンは最新デバイスで通常0.5〜1.5秒で初期化されます。
    // 2秒は低速デバイスやデバッグビルドに対する安全マージンです。
    for _ in 0..<20 {
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        if let plugin = AppIntentsPlugin.shared { return plugin }
    }
    // 2秒経過後もプラグインがnilの場合、Flutterエンジンの
    // 起動に失敗しています。Intentはエラーで失敗します。
    throw AppIntentError.custom(
        code: "PLUGIN_UNAVAILABLE",
        message: "Flutter engine did not initialize in time"
    )
}
```

> **タイムアウトの根拠**: 100ms間隔 x 20回リトライ = 最大2秒の待機。iOSでのFlutterエンジン起動は通常0.5〜1.5秒です。2秒のタイムアウトは低速デバイスやデバッグビルドに対して十分なマージンを提供しつつ、ユーザー体験のレスポンシブ性を保ちます。

> **失敗時の挙動**: タイムアウトを超過すると、Intentはエラーをスローします。Siri/Shortcutsはユーザーに汎用的なエラーメッセージを表示します。本番アプリでは、このタイミング問題を完全に回避するURL Schemeモードを推奨します。

## Intentの定義

### 基本的なIntent

```dart
import 'package:app_intents_annotations/app_intents_annotations.dart';

@IntentSpec(
  identifier: 'CreateTaskIntent',
  title: 'Create Task',
  description: 'Create a new task in your task list',
  implementation: IntentImplementation.dart,
)
class CreateTaskIntentSpec extends IntentSpecBase {
  @IntentParam(title: 'Task Title', description: 'The title of the task')
  final String title;

  @IntentParam(
    title: 'Due Date',
    description: 'Optional due date for the task',
    isOptional: true,
  )
  final DateTime? dueDate;

  const CreateTaskIntentSpec({required this.title, this.dueDate});
}
```

### 実装言語の選択

#### Dart実装 (推奨)

Flutter機能（UI、データベース、状態管理）へのアクセスが必要な場合:

```dart
@IntentSpec(
  identifier: 'ShowTaskDetailIntent',
  title: 'Show Task',
  implementation: IntentImplementation.dart, // Dartで実装
)
class ShowTaskDetailIntentSpec extends IntentSpecBase {
  @IntentParam(title: 'Task ID')
  final String taskId;

  const ShowTaskDetailIntentSpec({required this.taskId});
}
```

#### Swift実装

iOS固有APIやパフォーマンスが重要な場合:

```dart
@IntentSpec(
  identifier: 'QuickActionIntent',
  title: 'Quick Action',
  implementation: IntentImplementation.swift, // Swiftで実装
)
class QuickActionIntentSpec extends IntentSpecBase {}
```

#### Kotlin実装

Android固有APIが必要な場合:

```dart
@IntentSpec(
  identifier: 'AndroidShareIntent',
  title: 'Share',
  implementation: IntentImplementation.kotlin, // Kotlinで実装
)
class AndroidShareIntentSpec extends IntentSpecBase {}
```

## Entityの定義

### 基本的なEntity

```dart
import 'package:app_intents_annotations/app_intents_annotations.dart';

// モデルクラス
class Task {
  final String id;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final bool isCompleted;
  final String? thumbnailUrl;

  Task({
    required this.id,
    required this.title,
    this.description,
    this.dueDate,
    this.isCompleted = false,
    this.thumbnailUrl,
  });
}

// Entity定義
@EntitySpec(
  identifier: 'TaskEntity',
  title: 'Task',
  pluralTitle: 'Tasks',
  description: 'A task in your task list',
)
class TaskEntitySpec extends EntitySpecBase<Task> {
  // 必須: エンティティの一意ID
  @EntityId()
  String id(Task task) => task.id;

  // 必須: 表示タイトル
  @EntityTitle()
  String title(Task task) => task.title;

  // 任意: サブタイトル
  @EntitySubtitle()
  String? subtitle(Task task) {
    if (task.dueDate != null) {
      return 'Due: ${_formatDate(task.dueDate!)}';
    }
    return task.description;
  }

  // 任意: サムネイル画像
  @EntityImage()
  String? imageUrl(Task task) => task.thumbnailUrl;

  // 任意: デフォルトクエリ（エンティティ一覧取得）
  @EntityDefaultQuery()
  Future<List<Task>> defaultQuery() async {
    return TaskRepository.instance.getAllTasks();
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }
}
```

### カスタムクエリの追加

```dart
@EntitySpec(
  identifier: 'TaskEntity',
  title: 'Task',
  pluralTitle: 'Tasks',
)
class TaskEntitySpec extends EntitySpecBase<Task> {
  @EntityId()
  String id(Task task) => task.id;

  @EntityTitle()
  String title(Task task) => task.title;

  @EntitySubtitle()
  String? subtitle(Task task) => task.description;

  // デフォルトクエリ: 全タスク
  @EntityDefaultQuery()
  Future<List<Task>> defaultQuery() async {
    return TaskRepository.instance.getAllTasks();
  }

}
```

## App Shortcutsの定義

App Shortcutsを定義すると、アプリインストール直後からSiri/Shortcutsで利用可能になります。

### AppShortcutsProviderの定義

```dart
import 'package:app_intents_annotations/app_intents_annotations.dart';

// ショートカットプロバイダを定義
@AppShortcutsProvider()
class MyAppShortcuts {
  // 各ショートカットを定義
  @AppShortcut(
    intentIdentifier: 'CreateTaskIntent',
    phrases: [
      'Create a task in {applicationName}',
      'Add task to {applicationName}',
    ],
    shortTitle: 'Create Task',
    systemImageName: 'plus.circle',
  )
  static const createTask = null;

  @AppShortcut(
    intentIdentifier: 'ShowTasksIntent',
    phrases: [
      'Show my tasks in {applicationName}',
      'List tasks in {applicationName}',
    ],
    shortTitle: 'Show Tasks',
    systemImageName: 'list.bullet',
  )
  static const showTasks = null;
}
```

### 生成されるSwiftコード

```swift
// Generated: AppShortcuts.swift
import AppIntents

@available(iOS 17.0, *)
struct AppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateTaskIntent(),
            phrases: [
                "Create a task in \(.applicationName)",
                "Add task to \(.applicationName)"
            ],
            shortTitle: "Create Task",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: ShowTasksIntent(),
            phrases: [
                "Show my tasks in \(.applicationName)",
                "List tasks in \(.applicationName)"
            ],
            shortTitle: "Show Tasks",
            systemImageName: "list.bullet"
        )
    }
}
```

## コード生成

### 生成の実行

```bash
# 一度だけ生成
dart run build_runner build

# 継続的に監視・生成
dart run build_runner watch
```

### 生成されるファイル（想定）

#### Swiftコード

```swift
// GeneratedAppIntents.swift内（すべての生成型は1ファイルに出力）
import AppIntents

struct TaskEntitySpec: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Task",
        numericFormat: "\(placeholder: .int) Tasks"
    )

    static var defaultQuery = TaskQuery()

    var id: String
    var title: String
    var subtitle: String?
    var imageUrl: String?

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: subtitle.map { "\($0)" },
            image: imageUrl.map { .init(url: URL(string: $0)!) }
        )
    }
}

struct TaskQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [TaskEntity] {
        // Flutter経由でDartのdefaultQuery()を呼び出し
        return try await FlutterBridge.queryEntities(identifiers: identifiers)
    }

    func suggestedEntities() async throws -> [TaskEntity] {
        return try await FlutterBridge.suggestedEntities()
    }
}
```

```swift
// 同じくGeneratedAppIntents.swift内
import AppIntents
import UIKit

@available(iOS 17.0, *)
struct CreateTaskIntentSpec: AppIntent {
    static var title: LocalizedStringResource = "Create Task"
    static var description: IntentDescription =
        IntentDescription("Create a new task in your task list")
    static var openAppWhenRun: Bool { true }

    // ParameterSummary: Shortcuts UIでの表示を制御
    static var parameterSummary: some ParameterSummary {
        Summary("Create task \(\.$title)")
    }

    @Parameter(title: "Task Title", description: "The title of the task")
    var title: String

    @Parameter(title: "Due Date", description: "Optional due date for the task")
    var dueDate: Date?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        var components = URLComponents()
        components.scheme = "taskapp"
        components.host = "create"
        var queryItems = [URLQueryItem]()
        queryItems.append(URLQueryItem(name: "title", value: String(describing: title)))
        if let dueDate {
            queryItems.append(URLQueryItem(name: "dueDate", value: ISO8601DateFormatter().string(from: dueDate)))
        }
        if !queryItems.isEmpty { components.queryItems = queryItems }
        guard let url = components.url else {
            throw AppIntentError.custom(code: "URL_CONSTRUCTION_FAILED", message: "Failed to construct URL for intent")
        }
        await UIApplication.shared.open(url)
        // ProvidesDialog: Siri/Shortcutsでフィードバックを表示
        return .result(dialog: .init("Created task \"\(title)\""))
    }
}
```

> **Note**: URL schemeを使用する理由は、App IntentsがiOSの分離プロセスで実行される場合があり、直接MethodChannelを呼び出せないためです。URL schemeならアプリが完全に起動してからFlutter側で処理が実行されます。

### 高度な機能

#### Result Dialog Template

Intent実行後にSiri/Shortcutsでユーザーにフィードバックを表示：

```dart
@IntentSpec(
  identifier: 'CreateTaskIntent',
  title: 'Create Task',
  urlScheme: 'taskapp',
  urlAction: 'create',
  resultDialogTemplate: 'Created task "{title}"',  // Siriがこのメッセージを表示
)
```

`{paramName}` プレースホルダーは生成されたSwiftコードで実際のパラメータ値に置換されます。戻り値の型に `ProvidesDialog` が追加されます。

#### Parameter Summary

Shortcutsエディタでの表示を制御：

```dart
@IntentSpec(
  identifier: 'CreateTaskIntent',
  title: 'Create Task',
  parameterSummary: 'Create task {title}',  // Shortcuts UIで表示
)
```

`{paramName}` プレースホルダーは生成Swiftの `ParameterSummary` で `\(\.$paramName)` に変換されます。

#### AppEnum サポート

選択式パラメータ用の列挙型定義：

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

`@IntentParam` と組み合わせて使用：

```dart
@IntentParam(title: 'Priority', enumType: 'TaskPriority')
final TaskPriority priority;
```

適切な `typeDisplayRepresentation` と `caseDisplayRepresentations` を持つSwift `AppEnum` が生成されます。

## 実行モード

コードジェネレータは `@IntentSpec` の設定に基づいて、3つの実行モードのいずれかを自動選択します。各モードは、生成されるSwiftコードがFlutterアプリとどのように通信するかを決定します。

### モード選択

| 設定 | モード | ファイルパラメータ | ユースケース |
|------|--------|------------------|------------|
| `urlScheme` 設定あり | **URL Scheme** | 非対応 | 最も一般的。Deep linkでアプリを起動して処理。 |
| `supportedModes: foreground`、`urlScheme` なし | **Cache** | 対応 | `IntentFile`パラメータ（画像、ファイル）が必要な場合。 |
| どちらも未設定 | **FlutterBridge** | 対応 | バックグラウンド実行（Flutterエンジンが起動済みであることが前提）。 |

### URL Schemeモード

最も一般的なモードです。`urlScheme` と `urlAction` を設定すると有効になります:

```dart
@IntentSpec(
  identifier: 'com.example.createTask',
  title: 'Create Task',
  urlScheme: 'taskapp',    // アプリのURLスキーム
  urlAction: 'create',     // アクションセグメント (taskapp://create?...)
  resultDialogTemplate: 'Created task "{title}"',
)
class CreateTaskIntentSpec extends IntentSpecBase {
  @IntentParam(title: 'Title')
  final String title;

  const CreateTaskIntentSpec({required this.title});
}
```

生成されるSwiftコードは `UIApplication.shared.open(url)` で `taskapp://create?title=xxx` を開きます。Flutter側は `app_links` パッケージでこのURLを受信します（下記の [Deep Link受信](#deep-link受信-flutter側) を参照）。

**制限事項**: ファイルデータはURLクエリパラメータに含められません。ファイルパラメータが必要な場合はCacheモードを使用してください。

### Cacheモード (Foreground)

Intentのファイルパラメータ（`IntentFile`）を受け取る場合に使用します。`urlScheme` を設定せずに `supportedModes: IntentMode.foreground` を設定します:

```dart
@IntentSpec(
  identifier: 'com.example.createTaskWithImage',
  title: 'Create Task with Image',
  description: 'Create a new task with an optional image attachment',
  supportedModes: IntentMode.foreground,
  parameterSummary: 'Create task {title} {image}',
)
class CreateTaskWithImageIntentSpec extends IntentSpecBase {
  @IntentParam(title: 'Title', description: 'The title of the task')
  final String title;

  @IntentParam(
    title: 'Image',
    description: 'An image to attach to the task',
    isOptional: true,
    fileType: 'public.image',
  )
  final IntentFile? image;

  CreateTaskWithImageIntentSpec({required this.title, this.image});
}

Future<void> createTaskWithImageHandler({
  required String title,
  IntentFile? image,
}) async {
  // image?.path にはSwift側が書き込んだ一時ファイルのパスが入る
  await TaskRepository.instance.createTask(
    title: title,
    imagePath: image?.path,
  );
}
```

**動作フロー**:

```
Siri/Shortcuts → 生成されたAppIntent.perform()
  → IntentFileデータを一時ファイルに書き込み
  → AppIntentsPlugin.setPendingAction(identifier, params) を呼び出し
  → .result() を返す → iOS がアプリを起動 (supportedModes: .foreground)
  → Flutterエンジン起動 → ハンドラー登録
  → processPendingActions() がUserDefaultsから読み出し
  → 登録済みハンドラーにパラメータを配信
```

**必須**:
- AppDelegate で `AppIntentsPlugin.configure(appGroupIdentifier:)` を呼び出す（[iOSネイティブ設定](#3-iosネイティブ設定-appintentsbridge) を参照）
- `main()` で `configureStorage()` と `processPendingActions()` を呼び出す（[プラグインの使用](#プラグインの使用) を参照）

### FlutterBridgeモード (Background)

`urlScheme` も `supportedModes` も設定しない場合のデフォルトモードです:

```dart
@IntentSpec(
  identifier: 'com.example.quickLookup',
  title: 'Quick Lookup',
)
class QuickLookupIntentSpec extends IntentSpecBase {
  @IntentParam(title: 'Query')
  final String query;

  const QuickLookupIntentSpec({required this.query});
}
```

生成されるSwiftコードは `FlutterBridge.shared.invoke()` を通じて直接MethodChannelを呼び出します。

> **注意**: このモードはFlutterエンジンが既に起動していることが前提です。App Intentsは分離プロセス（`WFIsolatedShortcutRunner`）で実行される場合があり、その場合Flutterエンジンは利用できません。ほとんどのユースケースでは、URL SchemeモードまたはCacheモードを推奨します。

### ファイルパラメータ (IntentFile)

`@IntentParam(fileType:)` を使用してSiri/Shortcutsからファイル入力を受け取ります:

```dart
@IntentParam(
  title: 'Photo',
  isOptional: true,
  fileType: 'public.image',  // UTType識別子
)
final IntentFile? photo;
```

`IntentFile` クラスのプロパティ:
- `path` — 一時ファイルパス（Swift側が書き込み）
- `mimeType` — MIMEタイプ（例: `image/jpeg`）、nullable
- `filename` — 元のファイル名、nullable

一般的なUTType識別子: `public.image`, `public.movie`, `public.audio`, `public.data`, `public.pdf`

ファイルパラメータは **Cacheモード** (`urlScheme` なしの `supportedModes: IntentMode.foreground`) が必要です。Androidでは、生成されるKotlinコードで `IntentFile` は `String`（ファイルURI）にマッピングされます。

## Deep Link受信 (Flutter側)

生成されたSwift IntentからのURL schemeを受信するため、`app_links`パッケージを使用します。

### セットアップ

```yaml
# pubspec.yaml
dependencies:
  app_links: ^6.3.3
```

### Info.plist設定

```xml
<!-- ios/Runner/Info.plist -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.example.app</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>taskapp</string>  <!-- アプリ固有のスキーム -->
        </array>
    </dict>
</array>
<key>FlutterDeepLinkingEnabled</key>
<false/>  <!-- app_linksパッケージを使う場合はfalse -->
```

### Flutter実装

```dart
import 'package:app_links/app_links.dart';

class _MyAppState extends State<MyApp> {
  late AppLinks _appLinks;

  @override
  void initState() {
    super.initState();
    _initAppLinks();
  }

  Future<void> _initAppLinks() async {
    _appLinks = AppLinks();

    // アプリ起動時の初期リンク
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      _handleDeepLink(initialUri);
    }

    // アプリ実行中のリンク
    _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    switch (uri.host) {
      case 'create':
        // taskapp://create?title=xxx&dueDate=xxx
        _handleCreateTask(uri.queryParameters);
        break;
      case 'complete':
        // taskapp://complete?taskId=xxx
        _handleCompleteTask(uri.queryParameters);
        break;
    }
  }
}
```

## プラグインの使用

### ハンドラーの初期化

`main.dart`で生成された初期化関数を呼び出します。各specファイルは独自の `initializeXxxAppIntents()` 関数を生成し、Intentハンドラー、Entityクエリハンドラー、推奨Entityハンドラーを登録します。

```dart
import 'package:app_intents/app_intents.dart';
import 'intents/create_task_intent.dart';
import 'intents/create_task_with_image_intent.dart';
import 'entities/task_entity.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // App Group ストレージを設定（iOS、cache モードで必須）。
  // AppDelegate.swift の appGroupIdentifier と一致させること。
  await AppIntents().configureStorage(
    appGroupIdentifier: 'group.com.example.app',
  );

  // Intent/Entityハンドラーを登録（生成コード）
  initializeCreateTaskAppIntents();
  initializeCreateTaskWithImageAppIntents();
  initializeTaskEntityAppIntents();

  // Cache実行モードに必要:
  // setPendingAction()によりUserDefaultsに保存されたアクションを読み出し、
  // 登録済みハンドラーにexecuteIntent経由で配信する。
  AppIntents().processPendingActions();

  // アプリ実行中に到着するペンディングアクションを監視。
  // Flutter初期化後にIntentが発火した場合に対応。
  AppIntents().pendingActionsStream.listen((identifier) {
    AppIntents().processPendingActions();
  });

  runApp(MyApp());
}
```

> **Note**: `processPendingActions()` はCache実行モード（`urlScheme` なしの `supportedModes: IntentMode.foreground`）を使用する場合に必要です。ペンディングアクションが存在しなくても呼び出しは安全です。

### 初期化順序 (コールドスタート)

`processPendingActions()` を使用する場合、`main()` での初期化順序が重要です。Intentハンドラーは `processPendingActions()` を呼び出す**前に**登録する必要があります。そうしないと、ペンディングアクションがディスパッチされてもハンドラーが受信できません。

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 0. App Group ストレージを設定（最初に行う必要がある）
  await AppIntents().configureStorage(
    appGroupIdentifier: 'group.com.example.app',
  );

  // 1. すべてのハンドラーを先に登録
  initializeCreateTaskAppIntents();
  initializeTaskEntityAppIntents();

  // 2. その後でペンディングアクションを処理（登録済みハンドラーにディスパッチ）
  AppIntents().processPendingActions();

  // 3. 今後のペンディングアクションをリッスン
  AppIntents().pendingActionsStream.listen((_) {
    AppIntents().processPendingActions();
  });

  runApp(MyApp());
}
```

> **警告**: Cacheモードを使用する場合、ウィジェットの `initState()` やその他のライフサイクルコールバック内でIntentハンドラーを登録しないでください。コールドスタート時、`processPendingActions()` はウィジェットツリーが構築される前に実行されるため、ウィジェットレベルのハンドラーはまだ登録されていません。常に `main()` で `processPendingActions()` を呼ぶ前にハンドラーを登録してください。

> **バッファリング**: `pendingActionsStream` はネイティブ側で `FlutterEventChannel` のバッファードプッシュを使用するため、Dartリスナーがアタッチされる前に到着したイベントは失われません。ただし、`registerIntentHandler` で登録された `onIntentExecution` コールバックはバッファリングされません — `processPendingActions()` がディスパッチした時点でハンドラーが未登録の場合、イベントはサイレントにドロップされます。

### App Shortcutsパラメータの更新

他のApp Intentsライブラリ（例: `intelligence`）から移行する場合、`AppShortcuts.updateAppShortcutParameters()` の明示的な呼び出しが必要だったかもしれません。本ライブラリではエンティティ更新を異なる方法で処理します:

- **エンティティクエリ**（`suggestedEntities()` / `entities(for:)`）は、ショートカットエディタやSiriがエンティティデータを必要とする際にシステムによってオンデマンドで呼び出されます。明示的に更新をプッシュする必要はありません。
- `@AppShortcutsProvider` で定義された **App Shortcuts** はアプリインストール時に自動的に登録されます。システムは最新データが必要な場合に `suggestedEntities()` を呼び出します。
- ショートカットパラメータの**強制リフレッシュ**が必要な場合（例: ユーザーが新しいチームに参加した後）、SwiftコードでAPIを直接呼び出せます:

```swift
// AppDelegateまたはエンティティデータが変更される場所で:
if #available(iOS 17.0, *) {
    AppShortcuts.updateAppShortcutParameters()
}
```

これはコードジェネレータでは自動生成されません — エンティティデータが変更される場所でSwiftコードに手動で追加してください。

## WWDC26 実験的機能（opt-in）

codegen は WWDC26 の App Intents API（iOS 26.4 / iOS 27+）を出力できます。これらの
シンボルは**安定 SDK に存在しない**ため、**opt-in・デフォルト OFF** であり、生成された
Swift は `#if APP_INTENTS_WWDC26` で囲まれビルド設定からも切り替えられます。既存の安定
出力は変わりません。

### 実験的生成の有効化

```bash
# マスタースイッチ + 機能選択（カンマ区切り）。マスター OFF なら一切出力しない。
dart run app_intents_codegen:generate_swift \
  --experimental-wwdc26 \
  --experimental=value-query,value-representation,donation,long-running,app-schema,ownership,rich-types
```

出力された WWDC26 形をコンパイルするには、Xcode のターゲットの **Active Compilation
Conditions**（Swift フラグ）に `APP_INTENTS_WWDC26` を追加します。未設定なら生成された
`#else`（安定）分岐がコンパイルされる — つまり実験的 codegen を有効にしてもフラグ未設定の
プロジェクトはそのままビルドできます。

| フラグ | 機能 |
|------|---------|
| `app-schema` | `@AppEntity/@AppIntent/@AppEnum(schema:)` ドメイン準拠 (#49) |
| `ownership` | `@EntitySpec(ownership:)` による `OwnershipProvidingEntity` 準拠 (#55) |
| `long-running` | `LongRunningIntent` / `CancellableIntent` / 実行ターゲット (#52) |
| `rich-types` | ネイティブ `Duration` / `PersonNameComponents` / `EntityCollection` / `@UnionValue` パラメータ (#53) |
| `value-query` | `IntentValueQuery` 構造化検索 (#51) |
| `value-representation` | `ValueRepresentation` によるアプリ間エンティティ export (#54) |
| `donation` | `SyncableEntity` + `RelevantEntities` ドネーション (#55) |

### App Schema (#49) — カタログの利用

スキーマを渡すと、Siri/Apple Intelligence が既知の語彙でエンティティ/インテントを理解
します。ライブラリは型付きカタログを同梱しており、マジック文字列を手書きせずに済みます:

```dart
import 'package:app_intents_annotations/app_intents_annotations.dart';

@EntitySpec(
  identifier: 'com.example.app.MessageEntity',
  title: 'Message',
  pluralTitle: 'Messages',
  schema: AppSchemas.messages.message, // == 'messages.message'
)
class MessageEntitySpec extends EntitySpecBase<Message> { /* ... */ }

@IntentSpec(
  identifier: 'com.example.app.sendMessage',
  title: 'Send Message',
  schema: AppSchemas.messages.sendMessage,
)
class SendMessageIntentSpec extends IntentSpecBase { /* ... */ }
```

- `AppSchemaDomain` は iOS 27 の既知ドメインを列挙（`messages`, `mail`, `photos`,
  `calendar`, `maps`, `imageGeneration`, `visualIntelligence` など）。
- `AppSchemas.<domain>.<schema>` は検証済み識別子を公開（現状 `messages` / `mail` /
  `photos`、順次拡充）。
- カタログは**非網羅**です — システムは生文字列で照合するため、任意の `'domain.schema'`
  が使えます。未収録のスキーマは
  `schema: AppSchemas.of(AppSchemaDomain.calendar, 'event')` → `'calendar.event'`。

### IntentValueQuery (#51) — 構造化検索

事前インデックスが難しいコンテンツ（大規模・サーバーサイド・高頻度更新）向けに、
`IntentValueQuery` は検索入力を受け取り一致エンティティを返します。エンティティ単位で
`valueQuery: true` を指定し、`<entity>ValueQuery` という名前のハンドラを定義します:

```dart
@EntitySpec(
  identifier: 'com.example.app.ProductEntity',
  title: 'Product',
  pluralTitle: 'Products',
  valueQuery: true,
)
class ProductEntitySpec extends EntitySpecBase<Product> { /* ... */ }

// 同じ spec ファイル内のハンドラ（システムのテキストクエリを受け取る）:
Future<List<Product>> productEntityValueQuery(String input) async {
  return ProductRepository.instance.search(input);
}
```

生成 Dart がハンドラを自動登録します。ネイティブ側では value-query executor を配線します
（[ネイティブ配線](#実験的ブリッジのネイティブ配線)参照）。ビジュアル（カメラ/スクリーン
ショット、`SemanticContentDescriptor`）版は**対象外**で、ネイティブ完結（別途管理）です。

### アプリ間エンティティ export (#54)

エンティティをシステム標準型として export し、他アプリが受け取れるようにします。MVP は
`IntentPerson`（エンティティの id/title から構築）として export します:

```dart
@EntitySpec(
  identifier: 'com.example.app.ContactEntity',
  title: 'Contact',
  pluralTitle: 'Contacts',
  exportAs: EntityExportType.person,
)
class ContactEntitySpec extends EntitySpecBase<Contact> { /* ... */ }
```

`ValueRepresentation` を伴う `Transferable` 準拠が生成されます。export はシステム向き
（Flutter 往復なし）のため、ネイティブ配線は不要です。

### ドネーションと発見性 (#55)

**SyncableEntity** — エンティティの `@EntityId` が既にデバイス間で安定（例: サーバー
UUID）な場合に `syncable: true` を指定すると、会話がデバイス間を移動しても Siri が一貫
して参照できます:

```dart
@EntitySpec(identifier: '…', title: '…', pluralTitle: '…', syncable: true)
```

**RelevantEntities ドネーション** — `relevantEntities: true` で
`register<Entity>RelevantEntitiesDonator()` 関数が生成されます。起動時に一度呼び（ネイ
ティブ配線参照）、ユーザーの文脈変化に応じて Dart から donate します:

```dart
@EntitySpec(identifier: 'com.example.app.SongEntity', title: '…',
    pluralTitle: '…', relevantEntities: true)
// …
await AppIntents().donateRelevantEntities(
  'com.example.app.SongEntity',
  currentlyPlaying.map((s) => s.toJson()).toList(),
  context: 'audio.nowPlaying', // ステートフル上書き; [] でクリア
);
```

### オンスクリーン認識 (#56)

画面に表示中の主要エンティティを `NSUserActivity` に紐付け、Siri が「これ」を解決できる
ようにします。画面遷移に合わせて呼びます:

```dart
await AppIntents().setOnscreenEntity(
  'com.example.app.TaskEntity', task.id, title: task.title,
);
// 画面を離れるとき:
await AppIntents().clearOnscreenEntity();
```

このスキャフォルドは安定 API（`becomeCurrent` / `targetContentIdentifier`）を使います。
iOS 26+ の `appEntityIdentifier` による AppEntity 関連付けは具体エンティティ型が必要で
`AppDelegate` で配線します（ネイティブ配線参照）。依存する前に実機検証を推奨します。
個別ビュー注釈（`.appEntityIdentifier`）は Flutter では**非対応**です（SwiftUI ビュー
ツリーが無いため）。

### 実験的ブリッジのネイティブ配線

新しい inbound/outbound 経路は、既存の executor と並べて `AppDelegate` で配線します。
iOS-27 シンボルを参照するものは `#if APP_INTENTS_WWDC26` でゲートします:

```swift
Task { @MainActor in
  // … 既存の intent/entity/suggested executor …

  // #51 IntentValueQuery
  await FlutterBridge.shared.setValueQueryExecutor { entityIdentifier, input in
    guard let plugin = AppIntentsPlugin.shared else {
      throw AppIntentError.entityQueryNotConfigured
    }
    return try await plugin.queryValuesAsync(entityIdentifier: entityIdentifier, input: input)
  }
}

#if APP_INTENTS_WWDC26
// #55 RelevantEntities ドネーション: Dart → 生成 donator へ転送。
AppIntentsPlugin.relevantEntitiesDonationForwarder = { id, entities, context in
  try await FlutterBridge.shared.donateRelevantEntities(
    entityIdentifier: id, entities: entities, context: context)
}
// 各エンティティの生成 donator を登録（relevantEntities エンティティごとに1回）:
if #available(iOS 27.0, *) {
  registerSongEntityRelevantEntitiesDonator()
}

// #56 オンスクリーン関連付け: 具体エンティティ型から appEntityIdentifier を設定。
if #available(iOS 26.0, *) {
  AppIntentsPlugin.onscreenEntityBinder = { activity, entityIdentifier, entityId in
    // entityIdentifier を具体 AppEntity 型にマップしてから:
    // activity.appEntityIdentifier = EntityIdentifier(for: SongEntity.self, identifier: entityId)
  }
}
#endif
```

> 生成 Swift の検証: `scripts/verify_experimental_swift.sh` を実行（iOS 27 SDK の beta
> Xcode が必要）。生成出力を `-D APP_INTENTS_WWDC26` の有/無の両方で type-check するため、
> WWDC26 形と安定フォールバック形の両方がコンパイル可能であることが保証されます。

## WidgetKit の Widget Extension

Widget Extension は **Flutter エンジンを起動できない**ため、アプリ本体ターゲットの
生成 Intent が使う `FlutterBridge` 往復は Extension からは使えません。Extension が必要とする
データは、`app_intents` が cold-start fallback のために永続化している
**App Group のエンティティキャッシュ**から取るしかありません。

これを支える仕組みが 2 つあります。

- `AppIntentsEntityCache` — キャッシュを読む read-only の Swift API。手書きの Extension
  コードがキー命名をハードコードしなくて済みます（issue #97）
- `@WidgetConfigurationSpec` — `WidgetConfigurationIntent` とキャッシュ参照のエンティティ
  ピッカーを codegen。手書き自体が不要になります（issue #98）

### 前提条件

キャッシュはアプリが書き込んで初めて存在します。

1. アプリ本体と Extension の**両方**のターゲットで App Groups を設定
   （Signing & Capabilities → App Groups）。識別子は同一にすること
2. アプリ側で `AppIntentsPlugin.configure(appGroupIdentifier:)`（Swift）と
   `AppIntents().configureStorage(appGroupIdentifier:)`（Dart）を呼ぶ
3. エンティティに永続キャッシュを持たせる（`@EntitySpec(enumerable: true)` または
   明示的な `persistedCacheKey:`）。そして Dart からエンティティ一覧を書き込む:

   ```dart
   await AppIntents().setCachedValue(
     AppIntentsEntityCacheKey.forEntity('com.example.joinedTeam'),
     jsonEncode(teams.map((t) => {'id': t.id, 'name': t.name}).toList()),
   );
   ```

   `AppIntentsEntityCacheKey.forEntity` は codegen が使う既定キー
   （`app_intents.entities.<identifier>`）と同じ文字列を返します。リテラル直書きより
   こちらを使ってください。

### 手書き Swift からキャッシュを読む (#97)

Widget Extension ターゲットに `AppIntentsBridge` Swift Package を追加してから:

```swift
import AppIntentsBridge

let cache = AppIntentsEntityCache(
    appGroupIdentifier: "group.com.example.app",
    storageIdentifier: "com.example.app"  // ホストアプリ の bundle identifier
)

let teams = cache.entities(
    forEntityIdentifier: "com.example.joinedTeam",
    idKey: "id",
    titleKey: "name"
)
// -> [AppIntentsCachedEntity]（id / title / subtitle / imageName / values を持つ）
```

`storageIdentifier` は**ホストアプリの** bundle identifier
（または `AppIntentsPlugin.configure` に明示的に渡した `storageIdentifier`）でなければ
なりません。Extension 自身の `Bundle.main.bundleIdentifier` は
`com.example.app.MyWidget` のように異なり、キーの名前空間がずれます。推論せず**必須引数に
している**のはこのためです。

値を自前で読む・監視したい場合のメンバー:

| メンバー | 戻り値 |
|----------|--------|
| `AppIntentsEntityCache.defaultCacheKey(forEntityIdentifier:)` | `app_intents.entities.<identifier>` |
| `AppIntentsEntityCache.storageKey(forCacheKey:storageIdentifier:)` | 生の `UserDefaults` キー |
| `cache.storageKey(forEntityIdentifier:)` | このインスタンスの storage identifier を使った生キー |
| `cache.entries(forCacheKey:)` | 生の `[[String: Any]]` ペイロード |
| `cache.isAccessible` | App Group を開けなかった場合に `false` |

`isAccessible` が要るのは、空の結果だけでは区別がつかないためです。Extension に
App Groups の entitlement が無いと `UserDefaults(suiteName:)` は nil を返し、
すべての読み取りが `[]` になります。これは「アプリがまだ何も書いていない」状態と
同じ見た目です。この場合はエラーログを出しますが、空リストを正常扱いする前に
`isAccessible` を確認してください。


`AppIntentsEntityCache(userDefaults:storageIdentifier:)` は解決済みの suite を受け取るので、
テストで便利です。

### 設定 Intent の生成 (#98)

Dart 側で設定を宣言します。ハンドラも `part` ディレクティブもありません
（Dart では何も動かないので、Dart コードは生成されません）:

```dart
import 'package:app_intents_annotations/app_intents_annotations.dart';

@WidgetConfigurationSpec(
  identifier: 'com.example.selectTeam',
  title: 'Displayed team',
  description: 'Choose which team this widget shows.',
)
class SelectTeamWidgetConfig extends WidgetConfigurationSpecBase {
  @WidgetParameter(title: 'Team')
  final TeamEntitySpec? team;

  @WidgetParameter(title: 'Show completed')
  final bool showCompleted;

  const SelectTeamWidgetConfig({this.team, this.showCompleted = false});
}
```

Extension ターゲット用のディレクトリへ生成します:

```bash
cd app && dart run app_intents_codegen:generate_widget_swift \
  -o ios/MyWidget/GeneratedIntents \
  --app-group group.com.example.app \
  --storage-identifier com.example.app
```

| オプション | 説明 |
|-----------|------|
| `-i, --input` | 入力ディレクトリ（既定: `lib`） |
| `-o, --output` | 出力ディレクトリ（必須） |
| `-f, --file` | 出力ファイル名（既定: `GeneratedWidgetIntents.swift`） |
| `--app-group` | App Group 識別子（必須） |
| `--storage-identifier` | ホストアプリの bundle identifier（必須） |

生成物は `<Entity>WidgetEntity`（`AppEntity`）、
`<Entity>WidgetQuery`（`EnumerableEntityQuery`、キャッシュのみ参照）、
そして `WidgetConfigurationIntent` 本体です。

> **生成ファイルは Widget Extension ターゲットにのみ追加してください。**
> 同じ App Intent 型をアプリ本体ターゲットと Extension ターゲットの両方に含めると
> `Metadata.appIntents` が重複し、実行時に Intent を解決できなくなります。
> 生成エンティティを本体側の `<Entity>` ではなく `<Entity>WidgetEntity` という名前に
> しているのはこのためで、誤って同一ターゲットに入れた場合は実行時の静かな失敗ではなく
> コンパイルエラーになります。

ウィジェット本体はアプリごとに違うため生成しません:

```swift
struct TeamWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "TeamWidget",
            intent: SelectTeamWidgetConfig.self,
            provider: TeamTimelineProvider()
        ) { entry in
            TeamWidgetView(entry: entry)
        }
    }
}
```

### 知っておきたい 2 つの既定値

**`isDiscoverable` の既定は `false`。** 設定 Intent はウィジェットを設定するためのもので、
ショートカットアプリの単独アクションとして出るのは大抵ノイズです。単体でも意味がある場合のみ
`isDiscoverable: true` にしてください。

**`defaultResult()` は既定で生成しません。** 実装すると、未編集のウィジェットインスタンスの
設定値が*ウィジェットを追加した時点の値*で埋まります。これは「未設定のウィジェットは
アプリ内のグローバル設定に追従する」という一般的なフォールバック設計と両立しません
（値が焼き付いた後はアプリ内設定を変えてもウィジェットが動かない）。追加時点のスナップショットを
既定値にしたい場合のみ `@WidgetConfigurationSpec(generateDefaultResult: true)` で
opt-in してください。既定では未設定パラメータは `nil` で届き、フォールバックは
timeline provider が決めます。
エンティティごとに query は1つしか生成しないため、同じエンティティを参照する
configuration はこのフラグの値を揃える必要があります。食い違いは codegen が
エラーで落とします（片方が黙ってもう片方の挙動を引き継ぐのを防ぐため）。

### 対応パラメータ型

`String` / `int` / `double` / `bool` / `DateTime`（および nullable 形）と、
`@EntitySpec` を付けたクラス。エンティティパラメータは常に optional で出力されます
（必須にするとユーザーが選ぶまでウィジェットが描画されなくなるため）。

参照先エンティティの role フィールドは `String` である必要があります
（`@EntitySubtitle` / `@EntityImage` は `String?` も可）。App Group のキャッシュは
文字列しか運ばないためです。

セットアップが成立しない場合は codegen が明示的なエラーで落ちます:

- 参照先のエンティティが存在しない / 永続キャッシュを持たない
- エンティティが `@EntityId` / `@EntityTitle` を欠く
- role フィールドの型が `String` / `String?` でない
- id 以外の role フィールドの名前が `id`（生成される `Identifiable` プロパティと衝突する）
- 同じエンティティを共有する configuration が `generateDefaultResult` で食い違う

これは意図的で、放置すると「候補が何も出ないピッカー」という静かな失敗になるか、
Xcode でしか気づけないコンパイルエラーになるためです。

## ベストプラクティス

### 1. Intent識別子の命名

```dart
// Good: 明確で一意な識別子
@IntentSpec(identifier: 'com.myapp.CreateTaskIntent', ...)

// Good: シンプルな識別子（小規模アプリ向け）
@IntentSpec(identifier: 'CreateTaskIntent', ...)

// Avoid: 曖昧な識別子
@IntentSpec(identifier: 'Create', ...)
```

### 2. パラメータの設計

```dart
// Good: 適切なオプショナル設定
@IntentParam(title: 'Title')  // 必須
final String title;

@IntentParam(title: 'Due Date', isOptional: true)  // 任意
final DateTime? dueDate;

// Good: 説明的なタイトル
@IntentParam(
  title: 'Task Priority',
  description: 'Set the priority level (1-5)',
)
final int priority;
```

### 3. Entityのプロパティマッピング

```dart
// Good: 意味のあるサブタイトル
@EntitySubtitle()
String? subtitle(Task task) {
  if (task.isOverdue) return 'Overdue!';
  if (task.dueDate != null) return 'Due: ${formatDate(task.dueDate!)}';
  return task.description;
}

// Good: フォールバック付きの画像
@EntityImage()
String? imageUrl(Task task) {
  return task.thumbnailUrl ?? task.categoryIconUrl;
}
```

### 4. エラーハンドリング

```dart
@EntityDefaultQuery()
Future<List<Task>> defaultQuery() async {
  try {
    return await TaskRepository.instance.getAllTasks();
  } catch (e) {
    // エラーログを記録
    debugPrint('Failed to fetch tasks: $e');
    // 空リストを返す（クラッシュを防ぐ）
    return [];
  }
}
```

## トラブルシューティング

### ビルドエラー

**問題**: `undefined class 'IntentSpec'`

**解決**: `app_intents_annotations`パッケージをインポート

```dart
import 'package:app_intents_annotations/app_intents_annotations.dart';
```

### iOSビルドエラー

**問題**: `Deployment target below iOS 17.0`

**解決**: `ios/Podfile`を更新

```ruby
platform :ios, '17.0'
```

> **Note**: App Intentsフレームワークは iOS 17.0 以上が必須です。

### コード生成が動作しない

**問題**: 生成ファイルが作成されない

**解決**:
1. `build_runner`が`dev_dependencies`にあることを確認
2. `dart run build_runner build --delete-conflicting-outputs`を実行
3. アノテーションが正しく適用されているか確認
