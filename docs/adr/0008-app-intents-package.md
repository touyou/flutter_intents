# ADR 0008: AppIntentsPackage 対応

- **ステータス**: Accepted — 実装済み（2026-09-14）
- **関連 issue**: #59 の deferred punch list。#55 `RelevantIntent` の前提整理も兼ねる
- **対象フラグ**: なし（`AppIntentsPackage` は iOS 17）

## コンテキスト

生成した Intent / Entity を**共有 Swift パッケージ**に置き、アプリターゲットと
App Extension（Widget 等）の両方から使いたい。この構成が取れると、
`WidgetConfigurationIntent` の具体型をアプリ側からも名指しでき、#55 の
`RelevantIntent`（`init(_:widgetKind:relevance:)` が具体型を要求する）が成立する。

一方で本リポジトリには「同じ App Intent 型をアプリターゲットと Extension ターゲットの
**両方にコンパイル**すると `Metadata.appIntents` に重複して intent 解決が壊れる」という
確定事実がある（`app/ios/TaskWidget/README.md`）。この2つは矛盾しない。前者は
**1つの共有モジュールを両方がリンクする**話で、後者は**同じソースを2回コンパイルする**話。

## 実測事実（SDK 27 / tools `27A266a`）

姉妹プロジェクト（IntentTodo, 7 パッケージ構成）のビルド生成物を突き合わせた結果:

| バンドル | `AppIntentsPackage` 宣言 | `extract.packagedata` | actions / entities / queries |
|---|---|---|---|
| `TodoAppIntents.appintents` | あり（`includedPackages` 無し） | `{"includes":[]}` | 24 / 5 / 4 |
| `UI.appintents` | **無し** | **ファイルごと無し** | 24 / 5 / 4 |
| `IntentTodo.app/Metadata.appintents` | あり（`includedPackages` あり） | `{"includes":["14TodoAppIntents0aC7PackageV"]}` | 24 / 7 / 4 |

**メタデータが集約される条件は「リンクの形」であって `AppIntentsPackage` の有無ではない。**
静的リンクした依存先の抽出結果は宣言ゼロで利用側の `extract.actionsdata` にマージされる
（`UI` は宣言ゼロで 24 actions が載っている）。宣言が生むのは `extract.packagedata` の
`includes`（`includedPackages` に並べた型のマングル名）だけ。

Apple の言い方も条件付き:
> "You should use App Intents Package when referencing code not compiled into a static library."
> （wwdc2025-244 `24:00`）

Xcode の SPM は既定で静的リンクなので、**共有パッケージ構成そのものは宣言なしでも動く**。
宣言が効き始めるのは、どれかを動的プロダクト（framework / dynamic library）に変えた時。

## 決定

両 CLI にオプションを足す。生成するのは宣言だけで、ターゲット構成は利用者の Xcode 側の話。

```bash
# 共有パッケージ側
dart run app_intents_codegen:generate_swift \
  -o ../SharedIntents/Sources/SharedIntents \
  --app-intents-package SharedIntentsPackage

# 利用側（アプリ / Widget Extension）
dart run app_intents_codegen:generate_widget_swift … \
  --app-intents-package TaskWidgetAppIntentsPackage \
  --include-package SharedIntents.SharedIntentsPackage
```

`--include-package` はモジュール修飾名を取り、接頭辞を `import` に変換する。
`--include-package` 単独指定は（`includedPackages` の置き場が無いので）エラー。

### 意図的にやらないこと

- **「メタデータに型が出てこない」を `includedPackages` の足し引きで直させない。** 上の実測の
  とおりそこは効かない。見るべきはターゲットメンバシップとリンク形態。生成器のドキュメント
  コメントと CLI ヘルプの両方にこれを書いた。
- **ターゲット構成の自動生成はしない。** 共有パッケージの作成・リンクは Xcode プロジェクト側の
  作業で、codegen の責務外。

### 既知の落とし穴（姉妹プロジェクトの実測）

- **メインターゲットでの `AppIntentsPackage` 重複宣言**が Shortcuts の intent ルーティングを
  壊した事例がある。ターゲットにつき1つ。
- **`AppShortcutsProvider` はアプリターゲット直下に置く。** パッケージ内に移すと
  `autoShortcuts` が 0 になる（パッケージ→アプリターゲットへ戻した時点で 0→8 に変化するのを実測）。

## 検証

- 生成される宣言の形を `swiftc -typecheck`（デプロイメントターゲット iOS 17.0）で確認。
- ユニットテスト（宣言の有無 / `includedPackages` / モジュール import の重複排除 /
  非修飾名は import しない）。
- **未検証**: 実際に共有パッケージ構成へ切り出した example アプリのビルド。example は現状
  単一ターゲット構成のままで、この構成変更は別作業。
