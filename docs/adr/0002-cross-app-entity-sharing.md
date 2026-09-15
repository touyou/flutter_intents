# ADR 0002: アプリ間エンティティ共有設計 (#54)

- **ステータス**: Accepted — export 部分実装済み（`IntentPerson` のみ、`--experimental=value-representation`）。`PlaceDescriptor` 等カタログ拡張と import 経路は後続
- **関連 issue**: #54。import 経路は [ADR 0001](0001-intent-value-query-bridge.md)（#51）に依存
- **対象フラグ（案）**: `--experimental=value-representation`

## コンテキスト

エンティティをアプリ間で**共有/移動**できるようにする。`ValueRepresentation` /
`TransferRepresentation` でエンティティをシステム標準の構造化型として書き出し（export）、
他アプリ（Maps 等）がシステム理解可能な形で受け取れるようにする。逆向き（import）では、
受け取った構造化型を既存コンテンツに**マッチング**するか、**新規作成**する。

### SDK 検証済の事実

```swift
// [SDK検証済] AppIntents / IntentValueRepresentation: Key Path-Based Export
struct LocationEntity: TransientAppEntity, Transferable {
    @Property var place: PlaceDescriptor
    static var transferRepresentation: some TransferRepresentation {
        ValueRepresentation(exporting: \.place)        // ← 構造化型を key path で書き出し
    }
}

// [SDK検証済] 既存の Transferable も併用可（PNG など）
static var transferRepresentation: some TransferRepresentation {
    DataRepresentation(exportedContentType: .png) { entity in try await entity.pngData() }
}
```

- `IntentValueRepresentation` は「app entity ↔ system intent value の**双方向変換**」[SDK検証済]
- システム標準型の例: `PlaceDescriptor`、`IntentPerson`（プロキシ転送表現として利用可、
  `.contact` / `.applicationDefined` / `.unknown` の識別子）、`IntentCurrencyAmount` 等 [SDK検証済]
- **[要検証]** 各 `ValueRepresentation` / 個別の標準型の iOS バージョン（iOS 26 安定か iOS 27 か）。
  `swiftc -typecheck` の二分岐検証で確定する。

## 設計上の核心: export と import で性質が割れる（混在）

| 経路 | 向き | iOS 27 シンボルの所在 | 難度 |
|------|------|----------------------|------|
| **export** | entity → system | 生成コード（`transferRepresentation` + `@Property var place: PlaceDescriptor`） | 中（生成コード側で閉じる、`#if` ゲート可） |
| **import** | system → entity（マッチング/作成） | 生成コード＋**Dart 往復**（IntentValueQuery を再利用） | 高（0001 基盤＋構造化型の Dart 表現が必要） |

export は [ADR 0001] の inbound 原則と同じく**生成コード側で完結**できる。
import はシステムが渡す構造化型を Dart ハンドラに渡してマッチング/作成させるため、
**0001 の value query ブリッジを再利用**する（ここで二重設計しない）。

## 提案する設計

### A. export（先行・自己完結）

1. **アノテーション**: `@EntitySpec` に「どのフィールドを/どの標準型として export するか」を追加。

   ```dart
   @EntitySpec(
     identifier: 'com.example.app.LocationEntity',
     // 案: フィールド単位で標準型マッピングを宣言
   )
   class LocationEntitySpec {
     @EntityExport(systemType: SystemValueType.placeDescriptor)
     final PlaceDescriptorValue place;   // Dart 等価表現（後述）
   }
   ```

2. **システム標準型カタログ**: codegen が知っている標準型の**有限カタログ**を定義する
   （`PlaceDescriptor` / `IntentPerson` / `IntentCurrencyAmount` …）。各エントリは
   「Swift の型名」「Dart 等価表現」「フィールドマッピング」を持つ。SDK 確定後に拡充。

3. **SwiftGenerator**: `#if APP_INTENTS_WWDC26` 内に `transferRepresentation` と
   `@Property var place: PlaceDescriptor` を生成。`#else` は出力しない
   （export 表現が無くてもエンティティは従来どおり機能する）。

### B. import（後続・0001 依存）

- import 時のマッチングは `IntentValueQuery`（ADR 0001）そのもの:
  システムが渡す構造化型を **0001 の value query executor** で Dart に渡し、
  既存エンティティとの突合を Dart ハンドラに任せる。
- 新規作成（`IntentValueRepresentation(importing:)`）は、Dart 側に
  「この構造化型からエンティティを作る」ハンドラが要る → 0001 のハンドラ種別を流用、
  もしくは intent handler に委譲する。
- **構造化型の Dart 往復が要点**: `PlaceDescriptor`（緯度経度・名称等）を MethodChannel で
  渡せる `Map` に落とすシリアライザ／デシリアライザを、カタログの各エントリに持たせる。

## 検討した代替案

- **任意の Dart クラスを自動で標準型にマップ**: 却下。システム標準型は**有限カタログ**であり、
  どのフィールドがどの意味（緯度/経度/名称）かは機械推論できない。明示宣言が必要。
- **export と import を1つの機能として同時実装**: 却下。export は自己完結で価値が出る一方、
  import は 0001 と構造化型 Dart 表現に依存し重い。**export を先に出荷**し、import は後続。

## 影響範囲

- export のみなら **Swift 出力＋アノテーション**で閉じる（プラグイン本体は無改変）→ 安定リリース同梱可。
- import は ADR 0001 のブリッジ（`registerValueQueryHandler` / `queryValuesAsync`）に乗る。
  追加で構造化型ごとの (de)serializer が必要。
- 標準型カタログは SDK 確定で要素が固まる。初期は `PlaceDescriptor` 1 種から始め、検証して広げる。

## 未解決点（実装前に確認）

- **[要検証]** `ValueRepresentation` / 各標準型の iOS バージョンと、`TransientAppEntity` を
  使わず通常の `AppEntity` でも `ValueRepresentation(exporting:)` が成立するか。
- 標準型の Dart 等価表現を annotations パッケージに置くか（`PlaceDescriptorValue` 等の値型）。
- import の「マッチング」と「新規作成」をハンドラ shape でどう区別するか。

## 推奨

**export を先行実装する**（生成コード側で閉じ、標準型カタログは `PlaceDescriptor` 1 種から）。
**import は [ADR 0001] の実装完了を前提に後続**とし、value query ブリッジを再利用する。
標準型カタログと構造化型の Dart 表現は、SDK で対応型が固まり次第、段階的に拡張する。

## 追記（2026-09-15）: カタログは SDK 側で閉じている（#128 / #129）

### export カタログは `_SystemIntentValue` で決まる

iOS 27.0 SDK の `.swiftinterface` を読むと、`ValueRepresentation(exporting:)` の
イニシャライザは**2つの extension にしか無い**:

```swift
extension IntentValueRepresentation where IntentValue : _SystemIntentValue { init(exporting:) … }
extension IntentValueRepresentation where IntentValue == IntentPerson      { init(exporting:) … }
```

つまり export できるのは **`IntentPerson`（特例オーバーロード）** と
**`_SystemIntentValue` 準拠型**だけ。27.0 SDK 全体で後者に準拠しているのは
`GeoToolbox.PlaceDescriptor` / `LinkPresentation.LinkMetadata` /
`MediaIntents.AudioSearch` / `Photos.PHAsset` /
`VisualIntelligence.SemanticContentDescriptor` / `IntentPrompt` / `SystemShortcut` である。

**`IntentCurrencyAmount` は準拠していない**（`_IntentValue` 止まり）。#128 はこれを
「iOS 26.5 SDK に存在する」を根拠にカタログ候補に挙げていたが、**型が存在することと
export できることは別**で、実際に生成して型チェックすると

```
error: referencing initializer 'init(exporting:)' on 'IntentValueRepresentation'
       requires that 'IntentCurrencyAmount' conform to '_SystemIntentValue'
```

で落ちる。よって `EntityExportType` に currency のケースは**作らない**。
`IntentFile` / `EntityCollection` も同じ理由で不可。

### `PlaceDescriptor` に必要なフィールドの受け渡し

`PlaceDescriptor` は `init(representations:commonName:supportingRepresentations:)` で、
`.address(String)` と `.coordinate(CLLocationCoordinate2D)` のどちらか（または両方）が要る。
表示ロール（id/title/subtitle/image）ではこれを表現できないので、新しい
`@EntityExportField(EntityExportRole.latitude / .longitude / .address)` を足した。

このフィールドは生成エンティティの**通常の格納プロパティ**になり、エンティティ辞書
（Dart のキャッシュ投影やクエリ結果）から読み戻される。読み戻し側は数値型も扱えるように
拡張した（`NSNumber` は要求された Swift 数値型に条件付きブリッジするので、Dart が `int` で
書いた緯度も `Double` として読める）。

エクスポートできる値が無いときは `throw` する。`Transferable` がその表現を辞退する正しい
方法で、システムはそのフレーバーを提示しなくなる（空の場所を他アプリに渡すより良い）。

### import は value-query ブリッジに相乗りする

`ValueRepresentation(exporting:importing:)` の import 側は Dart 往復が要る
（他アプリから来た `IntentPerson` が既存の誰にマッチするか、あるいは新規作成するかは
アプリのデータ次第）。ADR 本文の想定どおり **#51 の value-query ブリッジを再利用**し、
新しいラウンドトリップ形状は追加しなかった。

区別はクエリ識別子で行う: エンティティ識別子に **`#import` を付ける**。Dart 側は
`AppIntents().registerValueImportHandler(<identifier>, handler)` が同じ接尾辞で
value query ハンドラを登録するので、利用者はこの規約を意識しなくてよい。
接尾辞は codegen（`SwiftGenerator._importQuerySuffix`）とプラグイン
（`valueImportQuerySuffix`）の**両方に重複して定義**されている（キャッシュキー形式と同じ扱い）
ので、変えるときは両方直すこと。

システム値は `kind` 付きの `Map` に平坦化して渡す（`person` / `place`）。
`IntentPerson.Identifier` / `.Name` / `.Handle.Value` は resilient enum なので、
生成する `switch` には `@unknown default` を必ず付ける（Swift 6 でエラーになる）。

一致するエンティティが無ければ `throw`。null を返してシステムに空を渡すより、
import を辞退させるほうが正しい。
