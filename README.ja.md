# Flutter Intents

FlutterアプリケーションからiOS App IntentsおよびAndroid AppFunctionsフレームワークを利用するためのパッケージ群です。

## 概要

このプロジェクトは、FlutterアプリでiOSのApp Intents（Siri、Shortcuts、Spotlight連携）とAndroidのAppFunctions（Gemini等AIエージェント連携）を宣言的に定義し、自動生成されたネイティブコードを通じてプラットフォーム連携を実現することを目指しています。

### 主な目標

1. **宣言的なIntent定義**: Dartアノテーションを使用してApp Intentsを定義
2. **型安全**: ジェネリクスによる入出力の型チェック
3. **コード生成**: Dart定義からSwift/Kotlinコードを自動生成
4. **クロスプラットフォーム**: 1つのDart定義からiOS・Android両方のネイティブコードを生成

## プロジェクト構成

```
flutter_intents/
├── packages/
│   ├── app_intents_annotations/  # アノテーション定義
│   ├── app_intents/              # Flutterプラグイン
│   └── app_intents_codegen/      # コード生成ツール
├── app/                          # サンプルアプリ
├── ios-spm/                      # iOS Swift Package
└── docs/                         # ドキュメント
```

## パッケージ

| パッケージ | 説明 |
|-----------|------|
| [app_intents_annotations](docs/packages.md#app_intents_annotations) | Intent/Entityを定義するためのアノテーションとベースクラス |
| [app_intents](docs/packages.md#app_intents) | iOS/Android連携用Flutterプラグイン |
| [app_intents_codegen](docs/packages.md#app_intents_codegen) | Swift/Kotlinコードジェネレーター |

## クイックスタート

### 1. 依存関係の追加

```yaml
dependencies:
  app_intents: ^0.2.1
  app_intents_annotations: ^0.2.1

dev_dependencies:
  app_intents_codegen: ^0.2.1
  build_runner: ^2.4.0
```

### 2. Intentの定義

```dart
import 'package:app_intents_annotations/app_intents_annotations.dart';

@IntentSpec(
  identifier: 'CreateTaskIntent',
  title: 'Create Task',
  description: 'Create a new task',
  implementation: IntentImplementation.dart,
)
class CreateTaskIntentSpec extends IntentSpecBase<CreateTaskInput, Task> {
  @IntentParam(title: 'Title')
  final String title;

  @IntentParam(title: 'Due Date', isOptional: true)
  final DateTime? dueDate;
}
```

### 3. Entityの定義

```dart
@EntitySpec(
  identifier: 'TaskEntity',
  title: 'Task',
  pluralTitle: 'Tasks',
  description: 'A task entity',
)
class TaskEntitySpec extends EntitySpecBase<Task> {
  @EntityId()
  String id(Task task) => task.id;

  @EntityTitle()
  String title(Task task) => task.title;

  @EntitySubtitle()
  String? subtitle(Task task) => task.description;
}
```

## ドキュメント

- [アーキテクチャ](docs/architecture.ja.md) - 設計思想と全体構成
- [パッケージ詳細](docs/packages.ja.md) - 各パッケージの詳細仕様
- [使用方法](docs/usage.ja.md) - 実装ガイドとサンプル

## 技術スタック

- **Dart SDK**: ^3.10.0
- **Flutter**: 3.3+
- **iOS**: 17.0+（App Intents）、Swift 5.9+
- **Android**: API 36+（Android 16、AppFunctions）

## ライセンス

MIT License
