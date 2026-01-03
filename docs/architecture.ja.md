# アーキテクチャ

## 設計思想

Flutter IntentsはiOS App Intentsフレームワークへのブリッジを提供し、FlutterアプリがSiri、Shortcuts、Spotlightと連携できるようにします。

### 設計原則

1. **宣言的定義**: アノテーションベースでIntent/Entityを宣言
2. **関心の分離**: アノテーション、プラグイン、コード生成を独立パッケージに分離
3. **型安全性**: ジェネリクスによるコンパイル時型チェック
4. **プラットフォーム抽象化**: Platform Interfaceパターンによる疎結合

## 全体アーキテクチャ

```
┌─────────────────────────────────────────────────────────────┐
│                     Flutter Application                      │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Intent/Entity Specifications                         │   │
│  │  @IntentSpec / @EntitySpec アノテーション付きクラス     │   │
│  └──────────────────────┬───────────────────────────────┘   │
│                         │                                    │
│  ┌──────────────────────▼───────────────────────────────┐   │
│  │  app_intents Plugin                                   │   │
│  │  - Platform Interface                                 │   │
│  │  - Method Channel                                     │   │
│  └──────────────────────┬───────────────────────────────┘   │
└─────────────────────────┼───────────────────────────────────┘
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
        ▼                 ▼                 ▼
   ┌─────────┐    ┌──────────────┐    ┌───────────────┐
   │ Dart    │    │ Generated    │    │ iOS Native    │
   │ Handler │◄───│ Swift Code   │───►│ App Intents   │
   └─────────┘    └──────────────┘    │ Framework     │
                         ▲            └───────────────┘
                         │
              ┌──────────┴──────────┐
              │ app_intents_codegen │
              │ (build_runner)      │
              └─────────────────────┘
```

## データフロー

### Intent実行フロー (URL Scheme)

```
[Siri/Shortcuts/Spotlight]
         │
         ▼
[iOS App Intents Framework]
         │
         ▼
[Generated Swift Intent]
         │ openAppWhenRun = true
         ▼
[UIApplication.shared.open(url)]
         │ taskapp://action?params
         ▼
[Flutter App (via app_links)]
         │
         ▼
[Dart Handler → Business Logic]
```

> **Note**: URL schemeを使用する理由は、App IntentsがiOSの分離プロセス（WFIsolatedShortcutRunner）で実行される場合があり、Flutterエンジンが利用できないためです。URL schemeならアプリが完全に起動してから処理が実行されます。

### コード生成フロー

```
[Dart Source Files]
    @IntentSpec
    @EntitySpec
         │
         ▼
[app_intents_codegen]
    - Analyzer
    - Generator
         │
         ▼
[Generated Files]
    - Swift App Intents
    - Swift Entity Queries
    - Dart Bindings
```

## レイヤー構成

### Layer 1: アノテーション層 (app_intents_annotations)

メタデータ定義のみを担当。ランタイム依存なし。

```dart
// Intent定義
@IntentSpec(
  identifier: 'MyIntent',
  title: 'My Intent',
  implementation: IntentImplementation.dart,
)
class MyIntentSpec extends IntentSpecBase<Input, Output> {}

// Entity定義
@EntitySpec(identifier: 'MyEntity', title: 'My Entity')
class MyEntitySpec extends EntitySpecBase<MyModel> {
  @EntityId()
  String id(MyModel m) => m.id;
}
```

### Layer 2: プラグイン層 (app_intents)

Platform Channelを通じたネイティブ通信を担当。

```
AppIntents (Facade)
       │
       ▼
AppIntentsPlatform (Interface)
       │
       ▼
MethodChannelAppIntents (Implementation)
       │
       ▼
FlutterMethodChannel ◄──► AppIntentsPlugin.swift
```

### Layer 3: コード生成層 (app_intents_codegen)

Dartアノテーションを解析し、Swiftコードを生成。

```
Source Analysis
       │
       ▼
AST Processing
       │
       ▼
Template Generation
       │
       ▼
Swift Output
```

## 設計パターン

### 1. アノテーションベースメタデータ

```dart
// 宣言的にメタデータを定義
@IntentSpec(
  identifier: 'CreateTaskIntent',
  title: 'Create Task',
  description: 'Creates a new task',
  implementation: IntentImplementation.dart,
)
class CreateTaskIntentSpec extends IntentSpecBase<String, Task> {}
```

**利点:**
- コードと仕様が同一箇所に存在
- IDEサポート（補完、リファクタリング）
- コンパイル時検証

### 2. ディスクリプタパターン (Entity Property Mapping)

```dart
class TaskEntitySpec extends EntitySpecBase<Task> {
  @EntityId()
  String id(Task task) => task.id;

  @EntityTitle()
  String title(Task task) => task.title;

  @EntitySubtitle()
  String? subtitle(Task task) => task.description;

  @EntityImage()
  String? imageUrl(Task task) => task.thumbnailUrl;
}
```

**利点:**
- モデルクラスを変更せずにマッピング定義
- 柔軟な変換ロジック
- テスト容易性

### 3. Platform Interface パターン

```dart
// 抽象インターフェース
abstract class AppIntentsPlatform extends PlatformInterface {
  static AppIntentsPlatform _instance = MethodChannelAppIntents();

  Future<String?> getPlatformVersion();
}

// Method Channel実装
class MethodChannelAppIntents extends AppIntentsPlatform {
  final methodChannel = MethodChannel('app_intents');

  @override
  Future<String?> getPlatformVersion() {
    return methodChannel.invokeMethod<String>('getPlatformVersion');
  }
}
```

**利点:**
- テスト時のモック差し替えが容易
- プラットフォーム実装の分離
- 将来の拡張性

### 4. 実装言語選択パターン

```dart
enum IntentImplementation {
  dart,   // FlutterでIntent処理を実装
  swift,  // ネイティブSwiftで実装
}
```

**ユースケース:**
- `dart`: UI表示、データベースアクセス等Flutter機能が必要な場合
- `swift`: パフォーマンス重視、iOS固有API使用時

## 型システム

### ジェネリクスによる型安全

```dart
// IntentSpecBase<I, O>
// I = Input型, O = Output型
class IntentSpecBase<I, O> {
  const IntentSpecBase();
}

// 具体的な使用例
class CreateTaskIntentSpec extends IntentSpecBase<CreateTaskInput, Task> {
  // Input: CreateTaskInput
  // Output: Task
}
```

### Entityの型制約

```dart
// EntitySpecBase<M>
// M = Model型
abstract class EntitySpecBase<M> {
  const EntitySpecBase();
}

// 使用例
class TaskEntitySpec extends EntitySpecBase<Task> {
  // Taskモデルに対するEntity定義
}
```

## iOS App Intents 対応

### プラットフォーム要件

| 項目 | 要件 |
|------|------|
| **iOS最小バージョン** | iOS 16.0+ |
| **Swift** | 5.0+ |
| **Xcode** | 14.0+ |

### 設計決定事項

| 項目 | 決定 |
|------|------|
| AppShortcutsProvider | 対応（事前定義ショートカット自動生成） |
| Handler登録方式 | 自動登録（コード生成で登録コード生成） |
| ローカライゼーション | String Catalog（iOS標準） |
| エラーハンドリング | 両対応（iOS標準 + カスタムエラー型） |
| Entity画像形式 | URL + Asset + SF Symbol |

### サポート対象機能

| iOS機能 | 対応状況 | 説明 |
|---------|----------|------|
| AppIntent | ✅ 完了 | Siri/Shortcutsからのアクション実行（URL scheme経由） |
| AppEntity | ✅ 完了 | エンティティ検索・表示 |
| AppShortcut | ✅ 完了 | 事前定義ショートカット |
| EntityQuery | ✅ 完了 | エンティティ検索クエリ（MethodChannel経由） |
| AppShortcutsProvider | ✅ 完了 | ショートカット自動登録 |

### 生成されるSwiftコード

```swift
// Generated from CreateTaskIntentSpec (iOS 16+)
import AppIntents
import UIKit

@available(iOS 16.0, *)
struct CreateTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Task"
    static var description: IntentDescription =
        IntentDescription("Creates a new task")
    static var openAppWhenRun: Bool = true  // アプリを起動してから実行

    @Parameter(title: "Title")
    var title: String

    @Parameter(title: "Due Date")
    var dueDate: Date?

    @MainActor
    func perform() async throws -> some IntentResult {
        // URL schemeでアプリに処理を委譲
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

// Generated AppShortcutsProvider
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
    }
}
```

## 今後の拡張ポイント

1. **Android対応**: Android App Actions/Shortcuts連携 → これは一旦考えない
2. **macOS対応**: macOS Shortcuts連携
3. **ウィジェット連携**: iOS WidgetKit, Interactive Widgets
4. **Focus Filter**: iOS Focus連携
5. **Live Activities**: Dynamic Island / Lock Screen連携
