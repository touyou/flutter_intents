# Architecture Decision Records (ADR)

このディレクトリは、`app_intents` プラグインに対する**設計上の意思決定**を記録します。
当初は WWDC26 App Intents の残課題（issue #59 のうち、純 codegen では閉じず、
**ブリッジ/ランタイム設計の判断が必要**な項目）の設計案を扱っていましたが、
以降は同種の判断を要する設計記録全般を置きます。

0001〜0004 は当初は実装に先行する提案として書かれましたが、現在はいずれも
**Accepted — 実装済み**（PR #68, commit `70306e6`）です。各 ADR の Status 欄が
最新の状態を示します（一部に意図的に先送り（deferred）した項目があり、各 ADR 内に明記）。

> 言語について: 既存の `docs/*.md` / `*.ja.md` はユーザー向けガイドのため二言語ペアですが、
> ADR は内部の設計記録のため日本語のみで記述します。

## 背景: 完了済みとの決定的な違い

issue #59 でこれまでマージ済みの項目（#52 / #49 / #50 / #53 / #57、PR #60〜#67）は
すべて **Swift 出力のみ** の機能でした。codegen が利用者アプリの
`GeneratedAppIntents.swift` に iOS 27 シンボルを吐き、`#if APP_INTENTS_WWDC26` で囲む。
**プラグイン本体（`app_intents` / `ios-spm/AppIntentsBridge`）は iOS 27 シンボルを一切名指さない**
（`FlutterBridge` の executor は `String` / `[String: Any]` で型付けされている）。
だからフラグは CLI + `SwiftGenerator` だけに通せばよかった。

残る4項目はいずれも**プラグインのランタイムコードに触れる**可能性があり、
opt-in ゲートの効き方が「データの向き」で割れます。各 ADR は次の問いに答えます:

> **iOS 27 シンボルの参照は、ゲートされた生成コード（利用者がコンパイル）に置けるのか、
> それともプラグイン本体ソース（常にコンパイルされる）に侵入するのか？**

- **生成コード側に置ける** → 従来どおり `#if APP_INTENTS_WWDC26` で安全に分岐できる（容易）
- **プラグイン本体に侵入する** → codegen の `#if` ゲートが届かない。プラグインは安定 SDK でも
  コンパイルできねばならず、`@available` は「シンボルの存在」を救えない（容易でない）

## 一覧

| ADR | issue | 概要 | 難度 | 依存 |
|-----|-------|------|------|------|
| [0001](0001-intent-value-query-bridge.md) | #51 | IntentValueQuery ブリッジ（構造化検索・inbound） | 中（生成コード側） | — |
| [0002](0002-cross-app-entity-sharing.md) | #54 | アプリ間エンティティ共有（export / import） | 中〜高 | export: 単独 / import: 0001 |
| [0003](0003-donations-and-discovery.md) | #55残 | ドネーションと発見性（RelevantEntities / IntentDonationManager / SyncableEntity） | 高（本体侵入） | — |
| [0004](0004-onscreen-awareness-feasibility.md) | #56 | オンスクリーン認識・スニペットビューの実現可能性 | 調査（GO/NO-GO） | — |
| [0005](0005-widget-extension-entity-access.md) | #97 / #98 | App Extension からのエンティティ参照と WidgetConfigurationIntent codegen | 中 | #26 |

関連: #58（ビジュアルインテリジェンス）は #51 の `Input` を `SemanticContentDescriptor`
（ピクセルバッファ）に特殊化したケースで、ネイティブ完結が前提。0001 で線引きを示し、
本格設計は #58 側で行う。

## API 事実の出典について

issue #59 は「API 要約はセッションページから抽出したもので、正式仕様は SDK/ドキュメント確定後に
検証すること」と明記しています。各 ADR では API シェイプを次のタグで区別します:

- **[SDK検証済]** — Xcode 27 beta の `.swiftinterface` または Apple Developer Documentation で確認済み
- **[要検証]** — issue ドラフト由来。実装前に SDK で確認が必要
