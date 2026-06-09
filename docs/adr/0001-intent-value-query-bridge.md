# ADR 0001: IntentValueQuery ブリッジ設計 (#51)

- **ステータス**: Proposed
- **関連 issue**: #51（基盤）、#54 import 経路 / #58 ビジュアルが依存
- **対象フラグ（案）**: `--experimental=value-query`

## コンテキスト

`IntentValueQuery` は WWDC26 で追加された新しいクエリプロトコルで、
**事前インデックスが難しいコンテンツ**（大規模・サーバーサイド・高頻度更新）や
ビジュアル検索結果を、システムからの検索入力に対して返すために使う。

既存の `EntityQuery`（`entities(for:)` / `suggestedEntities()`）は
「id リストから引く」「おすすめを出す」だけで、**任意の検索入力**を受け取れない。
`IntentValueQuery` はその穴を埋める。

### SDK 検証済の事実

```swift
// [SDK検証済] Apple Developer Documentation / AppIntents
protocol IntentValueQuery : PersistentlyIdentifiable, _SupportsAppDependencies, Sendable {
    associatedtype Input : _IntentValue          // ← 入力はジェネリック
    associatedtype ResultValue = Self.Result.Result.ValueType
    func values(for input: Input) async throws -> Result
}
```

ここが設計の分岐点:

- **`Input` はジェネリックな `_IntentValue`**。固定で「ピクセルバッファ」ではない。
  - **構造化／テキスト検索**: `Input` は `String` など **MethodChannel で直列化できる型**
  - **ビジュアル検索**: `Input` は `SemanticContentDescriptor`
    （`VisualIntelligence` フレームワーク、`pixelBuffer: CVPixelBuffer` + `labels` を保持）[SDK検証済]

issue #51 ドラフトは「構造化検索入力（クエリ/条件/URL）」、issue #58 ドラフトは
「ピクセルバッファ入力」と書いており**一見矛盾**するが、これは**同じプロトコルの異なる `Input` 型**
だった。本 ADR は **直列化可能な `Input` のみ**を扱い、ピクセルバッファ版は #58（ネイティブ完結）へ切り出す。

## 設計上の核心: ゲート問題 → 「inbound なので生成コード側で閉じる」

データの向きは **system → 生成された準拠型 → ブリッジ → Dart**（inbound）。

- `IntentValueQuery` を名指すのは **生成された準拠型だけ**。これは利用者アプリが
  コンパイルする `GeneratedAppIntents.swift` に出るので、`#if APP_INTENTS_WWDC26` で囲める。
- ブリッジに足す executor は **ジェネリック（`String` / `[String: Any]` のみ）** にできるので、
  **プラグイン本体は iOS 27 シンボルを名指さない**。既存の `entityQueryExecutor` と同じ構造。

→ 既存の EntityQuery 経路の素直な拡張で済む。**残り4項目の中で最も容易**。

## 提案する設計

### 1. ネイティブブリッジ: 新しいジェネリック executor

`FlutterBridge`（`ios-spm/AppIntentsBridge/Sources/AppIntentsBridge/FlutterBridge.swift`）に、
`entityQueryExecutor` と同じパターンで追加する。iOS 27 シンボルは登場しない:

```swift
// プラグイン本体ソース（ゲート不要 — ジェネリック型のみ）
private var valueQueryExecutor:
    (@Sendable (sending String, sending [String: Any]) async throws -> sending [[String: Any]])?

public func setValueQueryExecutor(
    _ executor: @escaping @Sendable (sending String, sending [String: Any]) async throws -> sending [[String: Any]]
) { valueQueryExecutor = executor }

// (queryIdentifier, serializedInput) → [entityDict]
public func queryValues(
    queryIdentifier: String, input: [String: Any]
) async throws -> [[String: Any]] {
    let executor = try await waitForValueQueryExecutor()   // 既存の5秒ポーリングと同型
    return try await executor(queryIdentifier, input)
}
```

`AppIntentsPlugin.swift` に `queryValuesAsync(queryIdentifier:input:)` を追加し、
`AppDelegate` の `setupFlutterBridgeExecutorsIfNeeded()` で executor を配線する
（既存の3 executor と同じ手書きパターン）。

### 2. Dart プラットフォームインターフェース: 新ハンドラ種別

```dart
// app_intents_platform_interface.dart
typedef ValueQueryHandler =
    Future<List<Map<String, dynamic>>> Function(Map<String, dynamic> input);

void registerValueQueryHandler(String queryIdentifier, ValueQueryHandler handler);
```

`MethodChannelAppIntents` に `_valueQueryHandlers` マップと `_onQueryValues` を足し、
`_handleMethodCall` の switch に `case 'queryValues':` を追加する
（`queryEntities` の実装と対称）。**iOS 27 シンボルは Dart 側にも登場しない**。

### 3. アノテーション: `@IntentValueQuerySpec`

`@EntityDefaultQuery` の隣に、検索入力を取るクエリを宣言する新アノテーションを追加する。

```dart
@IntentValueQuerySpec(
  entityType: ProductEntitySpec,     // どのエンティティを返すか
  // input フィールドはハンドラ引数の型から推論、もしくは明示
)
Future<List<Product>> searchProductsHandler(String query) async { ... }
```

入力型 `String` → MethodChannel で `{'query': ...}` として直列化。
複数フィールドの構造化入力も `Map` 化できる。

### 4. SwiftGenerator: `#if`-ゲートされた準拠型の生成

```swift
#if APP_INTENTS_WWDC26
@available(iOS 27.0, *)
struct ProductValueQuery: IntentValueQuery {
    func values(for input: String) async throws -> [ProductEntity] {
        let results = try await FlutterBridge.shared.queryValues(
            queryIdentifier: "com.example.app.ProductValueQuery",
            input: ["query": input]
        )
        return results.compactMap { /* dict → ProductEntity */ }
    }
}
#endif
// #else は出力しない（IntentValueQuery 無効時は単に value query 型を生成しない）
//          エンティティ本来の EntityQuery は従来どおり生成される
```

`#else` フォールバックは**不要**: value query はエンティティの追加経路であり、
無効時に生成しなければよいだけ。既存の EntityQuery 生成は無関係に維持される。
（実行制御 #52 のような「同じ struct を2形態出す」分岐は不要。）

## 検討した代替案

- **既存 `registerEntityQueryHandler` を流用**: 却下。`entities(for:)` は id リスト前提で、
  任意の検索入力を表現できない。ハンドラのシグネチャが本質的に違う。
- **ピクセルバッファも MethodChannel で往復**: 却下（#58 で詳述）。
  `CVPixelBuffer` の base64 往復はパフォーマンス・メモリ上現実的でなく、
  Vision の feature print 計算もネイティブで重い。ビジュアルは Swift 完結が筋。

## 影響範囲

- プラグイン本体（`app_intents` Dart + iOS Swift）に**新メソッドを追加するが、ゲート不要**。
  → これらの変更は安定リリースに同梱可能（既存と同じく iOS 27 非依存）。
- `build.yaml` / `builder.dart` の配線が初めて必要になる:
  本機能は**Dart の part 出力も変える**（`registerValueQueryHandler` 呼び出しの生成）ため、
  CLAUDE.md 記載のとおり「Dart 出力を変える機能が出た時点で `build.yaml`/`builder.dart` を配線」に該当する。
- Android: `IntentValueQuery` は iOS 専用概念。AppFunctions 側は no-op（既存の iOS 専用 API と同じ扱い）。

## 未解決点（実装前に確認）

- **[要検証]** `IntentValueQuery` の正確な `Result` 連想型と、返却を `[Entity]` にするための
  最小準拠形（`values(for:)` の戻り値型）。`swiftc -typecheck` を beta SDK で二分岐検証する。
- **[要検証]** `@UnionValue` で複数エンティティ型を返すケース（#51 ドラフト）。
  単一エンティティ型を先に通し、union は #53 の `@UnionValue` 基盤の上に後付けする。
- `queryIdentifier` の命名規則を EntityQuery と衝突しない形で確定する。

## 推奨

**単一エンティティ型・直列化可能 `Input`（テキスト/構造化）の IntentValueQuery を実装する。**
inbound でブリッジがジェネリックに保てるため、プラグイン本体をゲートせず安全に拡張できる。
ビジュアル（`SemanticContentDescriptor`）と `@UnionValue` 返却は本 ADR のスコープ外とし、
それぞれ #58 / #53 連携で段階的に積む。これは #54 import 経路と #58 の**共通基盤**になる。
