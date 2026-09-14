# Architecture Decision Records (ADR)

このディレクトリは、`app_intents` プラグインに対する**設計上の意思決定**を記録します。
当初は WWDC26 App Intents の残課題（issue #59 のうち、純 codegen では閉じず、
**ブリッジ/ランタイム設計の判断が必要**な項目）の設計案を扱っていましたが、
以降は同種の判断を要する設計記録全般を置きます。

0001〜0004 は当初、実装に先行する提案として書かれましたが、現在はいずれも
**Accepted — 実装済み**です。0005 以降は個別の設計判断の記録で、各 ADR の Status 欄が
最新の状態を示します（意図的に先送り（deferred）した項目は各 ADR 内に明記）。

> 言語について: 既存の `docs/*.md` / `*.ja.md` はユーザー向けガイドのため二言語ペアですが、
> ADR は内部の設計記録のため日本語のみで記述します。

> パスについて: 各 ADR は執筆時点の記録なので本文は書き換えていません。`AppIntentsBridge`
> の Swift Package は issue #102 の対応で `ios-spm/AppIntentsBridge` から
> **`packages/app_intents/ios/app_intents/Sources/AppIntentsBridge`** へ移動しています（pub パッケージに同梱して
> 下流アプリ・App Extension から参照できるようにするため）。ADR 本文中の `ios-spm/...` は
> この新しいパスに読み替えてください。

## 判断の軸

### 1. そもそもゲートが要るのか（2026-09-14 追記）

**最初に確かめるのは「そのシンボルがリリース済み SDK に本当に無いか」です。**
`#if APP_INTENTS_WWDC26` が正当なのは、安定 SDK にシンボルが**存在しない**場合だけ。
WWDC で発表された年は availability ではありません。

Xcode 27 RC と安定版 Xcode 26.6（**iOS 26.5** SDK）を突き合わせた結果、`IntentValueQuery`
(iOS 26.0) / `ShowsSnippetView` (iOS 16) / `AppIntentsPackage` (iOS 17) /
`IntentDialog(full:supporting:)` (iOS 16) / `RelevantIntentManager` (iOS 17) は
**いずれも安定 SDK にあり**、`#if` は不要でした（#51 はそれで卒業した）。

逆の罠もあります。`IntentValueRepresentation` は `@available(anyAppleOS 26.4, *)` と
宣言されているのに **26.5 SDK に実体がありません**。availability の数字だけを見ず、
実体の有無を確認すること。判定表は CLAUDE.md にあります。

### 2. iOS 27 シンボルはどちら側に置けるのか

ゲートが要ると判明した場合、次の問いに答えます:

> **iOS 27 シンボルの参照は、ゲートされた生成コード（利用者がコンパイル）に置けるのか、
> それともプラグイン本体ソース（常にコンパイルされる）に侵入するのか？**

- **生成コード側に置ける** → `#if APP_INTENTS_WWDC26` で安全に分岐できる（容易）
- **プラグイン本体に侵入する** → codegen の `#if` ゲートが届かない。プラグインは安定 SDK でも
  コンパイルできねばならず、`@available` は「シンボルの存在」を救えない（容易でない）
  → 0001 / 0003 の**逆向き executor**、0009 の**クロージャ1枠**がこのパターンの解法

`app_intents` / `AppIntentsBridge` は iOS 27 シンボルを一切名指しません。特に
`AppIntentsBridge` は **Foundation しか import しない**（App Extension が軽くリンクできる
ための資産）ので、そこを崩さない形を選ぶこと。

### 3. メタデータ探索と型の可視性は別問題（0008 / 0009）

「アプリターゲットから生成された型が見えない」は2種類あります。混同しないこと。

| | 何の話か | 効くもの |
|---|---|---|
| メタデータ探索 | `Metadata.appIntents` に型が載るか | **リンクの形**。静的リンクなら宣言ゼロで自動マージ |
| 型の可視性 | Swift コードがその型名を書けるか | **モジュール構成とアクセス修飾子** |

`AppIntentsPackage` は前者、`generate_widget_swift --public` は後者の話です。

## 一覧

| ADR | issue | 概要 | 難度 | 依存 |
|-----|-------|------|------|------|
| [0001](0001-intent-value-query-bridge.md) | #51 | IntentValueQuery ブリッジ（構造化検索・inbound） | 中（生成コード側） | — |
| [0002](0002-cross-app-entity-sharing.md) | #54 | アプリ間エンティティ共有（export / import） | 中〜高 | export: 単独 / import: 0001 |
| [0003](0003-donations-and-discovery.md) | #55残 | ドネーションと発見性（RelevantEntities / IntentDonationManager / SyncableEntity） | 高（本体侵入） | — |
| [0004](0004-onscreen-awareness-feasibility.md) | #56 | オンスクリーン認識・スニペットビューの実現可能性 | 調査（GO/NO-GO） | — |
| [0005](0005-widget-extension-entity-access.md) | #97 / #98 | App Extension からのエンティティ参照と WidgetConfigurationIntent codegen | 中 | #26 |
| [0006](0006-dual-text-result-dialog.md) | #59 | 読み上げ/画面表示を分けた結果ダイアログ（`IntentDialog(full:supporting:)`） | 低（純 codegen・非 experimental） | — |
| [0007](0007-declarative-snippet-view.md) | #56 | 宣言的スニペットビュー（`ShowsSnippetView`） | 中（codegen + ハンドラ戻り値の配線） | 0004 |
| [0008](0008-app-intents-package.md) | #59 | `AppIntentsPackage`（共有パッケージ構成の宣言生成） | 低（宣言のみ・構成は利用者側） | — |
| [0009](0009-relevant-intents.md) | #55残 | `RelevantIntent` ドネーション（Smart Stack 提案） | 中（ブリッジ + codegen） | 0008 の区別整理 |

関連: #58（ビジュアルインテリジェンス）は #51 の `Input` を `SemanticContentDescriptor`
（ピクセルバッファ）に特殊化したケースで、ネイティブ完結が前提。0001 で線引きを示し、
本格設計は #58 側で行う。ただし `VisualIntelligence.framework` は**実機 SDK にのみ存在**する
ため、このリポジトリの Simulator ベースの検証手段では扱えない（`blocked: needs-device`）。

## API 事実の出典について

WWDC のセッションページから抽出した API 要約は下書きであって仕様ではありません。各 ADR では
API シェイプを次のタグで区別します:

- **[SDK検証済]** — `.swiftinterface` または Apple Developer Documentation で確認済み
- **[要検証]** — セッション要約由来。実装前に SDK で確認が必要

**確認は `.swiftinterface` を直接読むこと。** ドキュメントの availability 表記と SDK の実体が
食い違う例が実際にあった（`IntentValueRepresentation`）。

## 検証コマンド

```bash
# 生成 Swift の dual-branch 型チェック。両方の Xcode で回す。
# デプロイメントターゲット iOS 17.0 で型チェックするので、@available のガード漏れが落ちる。
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/verify_experimental_swift.sh
DEVELOPER_DIR=/Applications/Xcode-27.0.0-release.candidate.app/Contents/Developer scripts/verify_experimental_swift.sh

# generate_widget_swift --public の出力が共有モジュールとして成立するか。
# モジュールとしてビルドしてから、それを import する利用側をコンパイルする。
scripts/verify_widget_module_swift.sh
```
