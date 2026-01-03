# 使用方法

## セットアップ

### 1. 依存関係の追加

```yaml
# pubspec.yaml
dependencies:
  app_intents: ^0.0.1
  app_intents_annotations: ^0.0.1

dev_dependencies:
  app_intents_codegen: ^0.0.1
  build_runner: ^2.4.0
```

### 2. iOS設定

`ios/Podfile`でiOSバージョンを16.0以上に設定（App Intentsフレームワーク要件）:

```ruby
platform :ios, '16.0'
```

> **Note**: App Intentsフレームワークは iOS 16.0 以上が必須です。

## Intentの定義

### 基本的なIntent

```dart
import 'package:app_intents_annotations/app_intents_annotations.dart';

// 入力モデル
class CreateTaskInput {
  final String title;
  final DateTime? dueDate;

  CreateTaskInput({required this.title, this.dueDate});
}

// 出力モデル
class Task {
  final String id;
  final String title;
  final DateTime? dueDate;

  Task({required this.id, required this.title, this.dueDate});
}

// Intent定義
@IntentSpec(
  identifier: 'CreateTaskIntent',
  title: 'Create Task',
  description: 'Create a new task in your task list',
  implementation: IntentImplementation.dart,
)
class CreateTaskIntentSpec extends IntentSpecBase<CreateTaskInput, Task> {
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
class ShowTaskDetailIntentSpec extends IntentSpecBase<String, void> {
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
class QuickActionIntentSpec extends IntentSpecBase<void, String> {}
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

  // 今後対応予定: カスタムクエリ
  // @EntityQuery(title: 'Incomplete Tasks')
  // Future<List<Task>> incompleteTasks() async {
  //   return TaskRepository.instance.getIncompleteTasks();
  // }
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

@available(iOS 16.0, *)
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
// Generated: TaskEntity.swift
import AppIntents

struct TaskEntity: AppEntity {
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
// Generated: CreateTaskIntent.swift
import AppIntents
import UIKit

@available(iOS 16.0, *)
struct CreateTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Task"
    static var description = IntentDescription("Create a new task in your task list")
    static var openAppWhenRun: Bool = true  // アプリ起動を保証

    @Parameter(title: "Task Title", description: "The title of the task")
    var title: String

    @Parameter(title: "Due Date", description: "Optional due date for the task")
    var dueDate: Date?

    @MainActor
    func perform() async throws -> some IntentResult {
        // URL schemeでFlutterアプリに処理を委譲
        var urlString = "taskapp://create?title=\(title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? title)"
        if let dueDate = dueDate {
            let formatter = ISO8601DateFormatter()
            urlString += "&dueDate=\(formatter.string(from: dueDate))"
        }
        if let url = URL(string: urlString) {
            await UIApplication.shared.open(url)
        }
        return .result()
    }
}
```

> **Note**: URL schemeを使用する理由は、App IntentsがiOSの分離プロセスで実行される場合があり、直接MethodChannelを呼び出せないためです。URL schemeならアプリが完全に起動してからFlutter側で処理が実行されます。

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

### 基本的な使用方法

```dart
import 'package:app_intents/app_intents.dart';

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _appIntents = AppIntents();
  String _platformVersion = 'Unknown';

  @override
  void initState() {
    super.initState();
    _initPlatformState();
  }

  Future<void> _initPlatformState() async {
    String? platformVersion;
    try {
      platformVersion = await _appIntents.getPlatformVersion();
    } catch (e) {
      platformVersion = 'Failed to get platform version.';
    }

    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion ?? 'Unknown';
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Running on: $_platformVersion'),
        ),
      ),
    );
  }
}
```

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

**問題**: `Deployment target below iOS 16.0`

**解決**: `ios/Podfile`を更新

```ruby
platform :ios, '16.0'
```

> **Note**: App Intentsフレームワークは iOS 16.0 以上が必須です。

### コード生成が動作しない

**問題**: 生成ファイルが作成されない

**解決**:
1. `build_runner`が`dev_dependencies`にあることを確認
2. `dart run build_runner build --delete-conflicting-outputs`を実行
3. アノテーションが正しく適用されているか確認
