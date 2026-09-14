# ADR 0009: RelevantIntent ドネーション (#55 残)

- **ステータス**: Accepted — ライブラリ側実装済み（2026-09-14）。example の共有モジュール化は別作業
- **関連 issue**: #55（`RelevantIntentManager` 部分）
- **対象フラグ**: なし（`RelevantIntent` / `RelevantIntentManager` は **iOS 17**）

## コンテキスト

`RelevantIntentManager` は、設定済みのウィジェット Intent を「いま関連がある」ものとして
システムに伝え、Smart Stack での提案に載せるための API。#55 の残課題のうち、
`RelevantEntities`（別系統・実装済み）に対する intent 側の口。

## SDK 事実（iOS 26.5 SDK で確認）

```swift
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
final public class RelevantIntentManager {
  public static let shared: RelevantIntentManager
  final public func updateRelevantIntents(_ relevantIntents: [RelevantIntent]) async throws
}

public struct RelevantIntent {
  public init<IntentType>(_ intent: IntentType, widgetKind: String, relevance: RelevantContext)
    where IntentType : WidgetConfigurationIntent
}
```

**iOS 17 なので `#if` は不要。** `@available` だけで足りる。

`RelevantContext` のファクトリ（`RelevanceKit`。iOS 26 で `AppIntents` へ移動するが import は
どちらでも通る）:

| ファクトリ | 可用性 | 本実装 |
|---|---|---|
| `.date(_:)` | iOS 17 | ✅ |
| `.date(_:kind:)` / `.date(interval:kind:)` / `.date(range:kind:)` | **iOS 26** | ✅ `if #available` で分岐 |
| `.date(from:to:)` | iOS 17・**26 で deprecated** | ⛔ 使わない |
| `.location(inferred:)` | iOS 17 | ✅ home / work / school / commute |
| `.sleep(_:)` | iOS 17 | ✅ wakeup / bedtime |
| `.fitness(_:)` | iOS 17 | ✅ workoutActive / activityRingsIncomplete |
| `.hardware(headphones:)` | iOS 17 | ✅ connected |
| `.location(_ exact: CLRegion)` | iOS 17 | 🚫 **対象外** |

`CLRegion` は辞書から復元できない。中途半端に受け付けると、システムに黙って捨てられる
ドネーションを作ることになるので、Dart 側の型に選択肢自体を置かない。

## 決定

### 1. 壁は「型の可視性」であって「メタデータ探索」ではない

`RelevantIntent.init` は `WidgetConfigurationIntent` の**インスタンス**を取る。つまり
ドネーションを行うターゲットが、その具体型をコンパイル時に名指しできる必要がある。

これは**素の Swift のモジュール可視性の問題**で、App Intents のメタデータ探索とは別の話。
`AppIntentsPackage` も静的リンクも解決しない（[ADR 0008](0008-app-intents-package.md) の
実測のとおり、あちらはメタデータの話）。

したがって要求は1つだけ:

> 生成された設定 Intent が、ドネーションを呼ぶターゲットから見えるモジュールにあること。

共有 Swift パッケージでも動的フレームワークでもよい。**やってはいけないのは同じソースを
両ターゲットにコンパイルすること**で、それは `Metadata.appIntents` 重複で intent 解決が
壊れる（`app/ios/TaskWidget/README.md`）。

### 2. ドネーターは設定ごとではなくファイルにつき1つ

`updateRelevantIntents` は配列を受け取り、**アプリ全体の集合を置き換える**。設定ごとに
登録して各自が update を呼ぶと、後から呼んだものが他を消す。

よって生成されるのは `registerRelevantIntentDonator()` 1本で、ファイル内の全設定を
知っているクロージャが全ドネーションを受け取り、まとめて1回だけ update する。
Dart API `donateRelevantIntents(List<...>)` が毎回**全集合**を要求するのも同じ理由で、
空リストが消去になる。

### 3. `RelevantContext` のデコードは生成コード側に置く

`AppIntentsBridge` は **Foundation しか import していない**。これは App Extension が
軽くリンクできるという設計上の資産なので、`RelevanceKit` を持ち込まない。ブリッジが持つのは
`(sending [[String: Any]]) async throws -> Void` のクロージャ1枠だけで、
`RelevantContext` / `RelevantIntent` を名指しするのは生成コードの側。

### 4. エンティティパラメータはキャッシュ経由で解決する

チャネルを渡るのは識別子だけ。生成コードは、ピッカーが使うのと同じキャッシュ backed な
`<Entity>WidgetQuery().entities(for:)` で引き直してから Intent に載せる。id だけの
スカスカなエンティティを donate しない。

スカラーパラメータは、ドネーションに値が無ければ**代入しない**。設定パラメータに意味のある
ゼロ値は無く、勝手に既定値を入れるとユーザーが選んでいない設定を donate することになる。

### 5. `RelevantDateKind.standard`

Swift の `.default` に対応する Dart の列挙子は `standard`。`default` が Dart の予約語のため。
生成コードのマッピング関数にその旨をコメントしている。

## 検証

- `swiftc -typecheck`（**デプロイメントターゲット iOS 17.0**、iOS 26.5 / 27.0 SDK 両方）。
  `scripts/verify_experimental_swift.sh` に **Widget Extension 生成物の typecheck を追加**した
  — これまで生成された widget Swift をコンパイルする検証が1つも無く、Xcode ビルドが
  唯一の砦だった。
- Swift パッケージテスト 40 件（うち新規3件: 全集合が渡ること / 空集合でも呼ばれること /
  未登録時に `DONATOR_NOT_REGISTERED`）。
- Dart 側 71 件、codegen 433 件。
- example アプリの `flutter build ios` 成功。

## 未了

- **実機 PoC**: Smart Stack に実際に提案が出るかは未確認。
- **example の共有モジュール化**: example は現状、生成された設定 Intent が Widget Extension
  ターゲットにしか無いので、アプリから `donateRelevantIntents` を呼ぶ配線までは通っていない。
  ライブラリとしては完結しており、これは example 側の構成変更として別途行う。
- `RelevantContext.location(_ exact: CLRegion)`（上記のとおり意図的に対象外）。
