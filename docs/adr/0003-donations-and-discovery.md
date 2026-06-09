# ADR 0003: ドネーションと発見性の設計 (#55 残)

- **ステータス**: Proposed
- **関連 issue**: #55（`OwnershipProvidingEntity` は #62 で対応済、残りが本 ADR）
- **対象フラグ（案）**: `--experimental=donation`

## コンテキスト

Apple Intelligence がユーザーの嗜好を学習し、文脈に応じてエンティティ/アクションを提案できるよう、
ドネーション系 API に対応する。#55 は性質の異なる4つの API を束ねており、**コストが大きく違う**ため
本 ADR で**3つの独立した意思決定**に分解する（4つ目は対応済）。

| サブ機能 | 状態 | 本 ADR の扱い |
|----------|------|---------------|
| `OwnershipProvidingEntity` | **#62 で対応済**（生成コード、`#if` ゲート） | 対象外（参考のみ） |
| `IntentDonationManager` / `AppIntent.donate()` | 未対応 | 決定 1 |
| `RelevantEntities`（文脈付きドネーション） | 未対応 | 決定 2 |
| `SyncableEntity`（安定 ID） | 未対応 | 決定 3 |

### SDK 検証済の事実

```swift
// [SDK検証済] 既存・安定（iOS 16+）。同期/非同期の donate を提供
struct IntentDonationManager { static let shared: IntentDonationManager }
extension AppIntent { @discardableResult func donate() -> IntentDonationIdentifier }

// [SDK検証済] 文脈付きドネーション。各呼び出しは「ステートフル上書き」（append ではない）
try await RelevantEntities.shared.updateEntities(songs, for: .audio(.nowPlaying))
try await RelevantEntities.shared.removeAllEntities(for: .audio(.nowPlaying))
// 旧 API（フラットなおすすめ）: RelevantEntities.shared.updateSuggestedEntities(_:)

// [SDK検証済] 安定 ID。既に安定なら無変更で準拠可
struct Article: AppEntity, SyncableEntity { var id: UUID }           // 変更不要
struct Photo:   AppEntity, SyncableEntity {                          // ローカル≠安定 の場合
    var id: SyncableEntityIdentifier<String, String>                // ← id 型が変わる
    init(localID: String, stableID: String) { self.id = .init(local: localID, stable: stableID) }
}
```

- **[要検証]** `RelevantEntities.updateEntities(_:for:)` / `AppEntityContext` / `SyncableEntity`
  プロトコルの iOS バージョン（iOS 26 安定か iOS 27 か）。`IntentDonationManager`/`donate()` は
  既存の安定 API である点はほぼ確実だが、`swiftc -typecheck` 二分岐で全体を確定する。

## 設計上の核心: outbound のゲート問題と、その回避策

これまでの3 ADR と違い、ドネーションは **Dart がランタイムで Swift の API を呼ぶ outbound**:

```
Dart (アプリ状態変化) → plugin MethodChannel → Swift: RelevantEntities.shared.updateEntities(...)
```

素朴に「プラグイン本体に `donateRelevantEntities` を実装」すると、**2つの壁**にぶつかる:

1. **シンボル存在の壁**: プラグイン（`app_intents`）は安定 SDK でもコンパイルできねばならない。
   `RelevantEntities.updateEntities(_:for:)` が iOS 27 シンボルなら、`@available` では救えない
   （`@available` はランタイム OS を切るだけで、未定義シンボルのコンパイル不可は救わない）。
   codegen の `#if APP_INTENTS_WWDC26` は**プラグイン本体には届かない**（プラグインは別パッケージで先にコンパイルされる）。
2. **型の壁**: `updateEntities` は `[any AppEntity]` を取るが、**プラグインは具体的なエンティティ型を知らない**。
   具体型は生成コード／利用者アプリ側にある。プラグインからは `AppEntity` インスタンスを構築できない。

### 回避策: 「ドネーション呼び出しは生成コードに置き、プラグインは逆向き executor で受ける」

壁2が解決の鍵になる。**具体型が存在するのは生成コード**だから、ドネーションの**呼び出し本体も
生成コードに置く**のが自然。プラグインは executor を**逆向き**（plugin → generated）に保持する:

```swift
// プラグイン本体（ゲート不要 — ジェネリックなクロージャ型のみ。iOS 27 シンボル不在）
private var donationHandler:
    (@Sendable (sending String, sending [[String: Any]], sending String?) async throws -> Void)?
public func setDonationHandler(_ h: @escaping ...) { donationHandler = h }
// Dart からの MethodChannel "donateRelevantEntities" を受け、登録済み handler に委譲

// 生成コード（利用者アプリがコンパイル、#if ゲート可、具体型を知っている）
#if APP_INTENTS_WWDC26
@available(iOS 27.0, *)
func _registerSongDonation() {
    AppIntentsPlugin.shared?.setDonationHandler { entityId, dicts, context in
        let songs = dicts.compactMap { SongEntity(from: $0) }   // 具体型構築（ここだけ iOS 27 シンボル）
        try await RelevantEntities.shared.updateEntities(songs, for: .audio(.nowPlaying))
    }
}
#endif
```

iOS 27 シンボルを名指すのは `#if`-ゲートされた生成クロージャの内側だけ。プラグインはジェネリックに保てる。

#### 既存 forward executor との非対称性（このパターンの肝）

逆向き executor は既存の forward executor（`entityQueryExecutor` 等）の単純な鏡像**ではない**:

- forward executor は AppDelegate で**一度だけ設定する単一クロージャ**。型非依存のフォワーダで、
  dict を Dart に渡すだけ。識別子ごとのディスパッチは Dart 側（`_entityQueryHandlers[id]`）で行う。
- ドネーションのクロージャは型非依存のフォワーダに**できない**。`[any AppEntity]` を作るために
  **具体的な `AppEntity` インスタンスを構築**する必要があり、その具体型ロジックはエンティティ型ごとに
  異なり、生成 Swift にしか存在しない。単一クロージャで全エンティティ型を賄うには内部で型分岐が要る。

→ **プラグインは識別子→クロージャの map**（`[entityIdentifier: closure]`）を持ち、
**各生成エンティティが自分のクロージャを登録する**。これが forward executor との決定的な違いであり、
この ADR の中心的な仕組み。

## 提案する設計（3つの決定）

### 決定 1: `IntentDonationManager` / `donate()`（安定 API）

- これらは安定シンボルなので、**`@available(iOS 16, *)` でプラグイン本体に直接実装する**ことも可能。
  ただし「ドネーションするインテント」も具体型（生成コード）なので、決定 2 と同じ
  逆向き executor パターンで統一するのが一貫性が高い。
- Dart API: `AppIntents().donateIntent(identifier, params)` → 生成クロージャが intent を構築し `.donate()`。
- フラグ無効/未ゲートでも安定 SDK で通るため、**最初に通せる**部分。

### 決定 2: `RelevantEntities`（文脈付きドネーション）

- 上記「逆向き executor」で実装。生成クロージャ本体を `#if APP_INTENTS_WWDC26` でゲート。
- Dart API: `AppIntents().donateRelevantEntities(entityIdentifier, entityDicts, context)` /
  `clearRelevantEntities(entityIdentifier, context)`。`context` は `AppEntityContext` の
  限定カタログ（初期は `.audio(.nowPlaying)` のみ）を文字列キーで表現。
- **ステートフル上書き**のセマンティクスを Dart ドキュメントに明記（各呼び出しが前回を置換）。
- 既存の `registerSuggestedEntitiesHandler`（pull 型・クエリ応答）との**役割分担**を整理:
  - suggested entities = システムが**引きに来る**（パラメータピッカー等）
  - RelevantEntities = アプリが**文脈付きで押し込む**（プロアクティブ提案）
  両者は別物。ドキュメントで明確化する。

### 決定 3: `SyncableEntity`（安定 ID）

- **波及が最も大きい**。2ケースに分ける:
  - **(3a) 既に安定 ID（UUID 等）を持つエンティティ**: `: SyncableEntity` を付けるだけ。
    生成コードで `#if`-ゲートして付与。**安価**。`@EntitySpec(syncable: true)` で opt-in。
  - **(3b) ローカル ID と安定 ID が別**: `id` の型を `SyncableEntityIdentifier<Local, Stable>` に変える。
    これは **EntityQuery の `entities(for: [ID])`、cache 射影の id フィールド、Dart 側の ID 管理**
    すべてに波及する。**別建て**で慎重に。
- 推奨: **(3a) のみ本フェーズで対応**し、(3b) は独立タスクに切る。

## 検討した代替案

- **プラグイン本体に `@available(iOS 27, *)` で直接ドネーション実装**: 却下。シンボル存在の壁
  （iOS 27 シンボルは安定 SDK に無い）＋型の壁（具体型を知らない）の両方に抵触する。
- **別コンパイルの iOS 27 専用シム**: 過剰。逆向き executor パターンで十分に解決でき、
  既存の配線様式とも一貫する。
- **(3b) も同時対応**: 却下。id 型変更の波及がビルド全体に及び、リスクが高い。

## 影響範囲

- プラグイン本体に**ジェネリックな逆向き executor**と MethodChannel メソッドを追加（ゲート不要）。
- Dart 側 part 出力が変わる（ドネーションハンドラ登録の生成）→ `build.yaml`/`builder.dart` 配線が必要
  （ADR 0001 と同様）。
- `@EntitySpec` に `syncable` / ドネーション関連フィールドを追加。
- Android: ドネーションは iOS 専用。AppFunctions 側は no-op。

## 未解決点（実装前に確認）

- **[要検証]** `RelevantEntities.updateEntities(_:for:)` / `AppEntityContext` / `SyncableEntity` の iOS バージョン。
- `AppEntityContext` の対応カタログ（`.audio` 以外に何が安定して使えるか）。

## 推奨

3つに分けて段階的に進める:
1. **決定 1（donate）を最初に**通す（安定 API、逆向き executor の配線を確立）。
2. **決定 2（RelevantEntities）**を同じパターンで `#if`-ゲートして積む。SDK バージョン確定が前提。
3. **決定 3 は (3a) のみ**（安価な conformance）対応し、**(3b) dual-id は別建て**で先送り。

いずれも「ドネーション呼び出し本体を生成コードへ、プラグインは逆向きジェネリック executor」という
一つの原則で統一し、プラグイン本体が iOS 27 シンボルを名指さない状態を保つ。
