# Flutter Intents

[![CI](https://github.com/touyou/flutter_intents/actions/workflows/ci.yml/badge.svg)](https://github.com/touyou/flutter_intents/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

| パッケージ | pub.dev |
| --- | --- |
| [`app_intents`](packages/app_intents/) | [![pub package](https://img.shields.io/pub/v/app_intents.svg)](https://pub.dev/packages/app_intents) |
| [`app_intents_annotations`](packages/app_intents_annotations/) | [![pub package](https://img.shields.io/pub/v/app_intents_annotations.svg)](https://pub.dev/packages/app_intents_annotations) |
| [`app_intents_codegen`](packages/app_intents_codegen/) | [![pub package](https://img.shields.io/pub/v/app_intents_codegen.svg)](https://pub.dev/packages/app_intents_codegen) |

[English README](README.md)

FlutterアプリケーションからiOS App IntentsおよびAndroid AppFunctionsフレームワークを利用するためのパッケージ群です。

## 概要

このプロジェクトは、FlutterアプリでiOSのApp Intents（Siri、Shortcuts、Spotlight連携）とAndroidのAppFunctions（Gemini等AIエージェント連携）を宣言的に定義し、自動生成されたネイティブコードを通じてプラットフォーム連携を実現することを目指しています。

### 主な目標

1. **宣言的なIntent定義**: Dartアノテーションを使用してApp Intentsを定義
2. **型安全**: 生成される型安全なParamsクラスによる型チェック
3. **コード生成**: Dart定義からSwift/Kotlinコードを自動生成
4. **クロスプラットフォーム**: 1つのDart定義からiOS・Android両方のネイティブコードを生成

## プロジェクト構成

```
flutter_intents/
├── packages/
│   ├── app_intents_annotations/  # アノテーション定義
│   ├── app_intents/              # Flutterプラグイン
│   │   └── ios/app_intents/      # iOS Swift Package（プラグイン + AppIntentsBridge）
│   └── app_intents_codegen/      # コード生成ツール
├── app/                          # サンプルアプリ
└── docs/                         # ドキュメント
```

## パッケージ

| パッケージ | 説明 |
|-----------|------|
| [app_intents](packages/app_intents/) | iOS/Android連携用Flutterプラグイン |
| [app_intents_annotations](packages/app_intents_annotations/) | Intent/Entityを定義するためのアノテーションとベースクラス |
| [app_intents_codegen](packages/app_intents_codegen/) | Swift/Kotlinコードジェネレーター |

## クイックスタート

### 1. 依存関係の追加

```yaml
dependencies:
  app_intents: ^0.14.0
  app_intents_annotations: ^0.14.0

dev_dependencies:
  app_intents_codegen: ^0.14.0
  build_runner: ^2.4.0
```

### 2. Intentの定義

```dart
import 'package:app_intents_annotations/app_intents_annotations.dart';

@IntentSpec(
  identifier: 'CreateTaskIntent',
  title: 'Create Task',
  description: 'Create a new task',
)
class CreateTaskIntentSpec extends IntentSpecBase {
  @IntentParam(title: 'Title')
  final String title;

  @IntentParam(title: 'Due Date', isOptional: true)
  final DateTime? dueDate;

  CreateTaskIntentSpec({required this.title, this.dueDate});
}
```

### 3. Entityの定義

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
}
```

### 4. コード生成

```bash
# Dartコード生成
dart run build_runner build --delete-conflicting-outputs

# Swiftコード生成 (iOS)
dart run app_intents_codegen:generate_swift -i lib -o ios/Runner/GeneratedIntents

# Kotlinコード生成 (Android)
dart run app_intents_codegen:generate_kotlin -i lib -o android/app/src/main/kotlin/com/example/app/generated -p com.example.app.generated
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

## コントリビュート

コントリビュートのガイドラインは [CONTRIBUTING.md](CONTRIBUTING.md) を参照してください。
すべての参加者は [行動規範（Code of Conduct）](CODE_OF_CONDUCT.md) に従うことが求められます。

セキュリティ脆弱性の報告手順は [SECURITY.md](SECURITY.md) を参照してください。

## ライセンス

MIT License - 詳細は [LICENSE](LICENSE) ファイルを参照してください。
