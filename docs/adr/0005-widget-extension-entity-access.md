# ADR 0005: App Extension からのエンティティ参照と WidgetConfigurationIntent codegen (#97 / #98)

- **ステータス**: Accepted — 実装済み
- **関連 issue**: #97（永続キャッシュの公開 Swift API）、#98（`WidgetConfigurationIntent` の codegen）
- **前提**: #26（EntityQuery cold-start fallback の永続化）

## コンテキスト

App Extension（特に WidgetKit の Widget Extension）は **Flutter エンジンを起動できない**。
したがって `FlutterBridge` 経由で Dart の EntityQuery ハンドラを呼ぶ既存の経路は
Extension からは一切使えない。

一方 `app_intents` は cold-start fallback（#26）のために、エンティティ一覧を
App Group の `UserDefaults` に永続化している。**このデータは Extension からも読める場所にある**。
つまり Extension 向けには「Dart 往復なし・キャッシュ読み取りのみの静的な Swift」が
唯一かつ十分な解になる。

問題はキー命名がパッケージの内部実装だったこと。利用者は Widget 側に
`"app_intents.entities.<identifier>"` 相当の文字列を手書きするしかなく、パッケージが
命名を変えると**静かに壊れる**（クラッシュせず、ウィジェット設定 UI の候補が空になるだけ）。

## 決定 1（#97）: キャッシュ読み取りを `AppIntentsBridge` の public API にする

`ios-spm/AppIntentsBridge` に read-only の `AppIntentsEntityCache` / `AppIntentsCachedEntity`
を追加する。

**なぜ `AppIntentsBridge` なのか**: 3 つの候補があった。

| 置き場所 | 可否 | 理由 |
|----------|------|------|
| `app_intents` プラグイン（`AppIntentsPlugin`） | ✗ | `import Flutter` するので Extension ターゲットにリンクできない |
| 新規の薄いモジュール | △ | Extension が追加で 1 モジュール取り込む必要があり、配布経路が増える |
| **`ios-spm/AppIntentsBridge`** | ✓ | 既に Flutter 非依存（`FlutterBridge` の executor は `String` / `[String: Any]` で型付け）。SPM product なので Extension ターゲットに素で追加できる |

### `storageIdentifier` を必須にする

生の `UserDefaults` キーは `app_intents.<storageId>.cache.<cacheKey>` で、`<storageId>` は
メインアプリ側で次の順に解決される（`AppIntentsPlugin.cachePrefix`）:

1. `configure(storageIdentifier:)` に明示された値
2. なければ **メインアプリの** `Bundle.main.bundleIdentifier`

Extension の `Bundle.main.bundleIdentifier` は `com.example.app.MyWidget` であって
アプリのものではない。**実行時に推論する手段がない**ので、`AppIntentsEntityCache` の
イニシャライザで明示必須にした。ここを「推論して既定値を入れる」設計にすると、
issue が問題視した「静かに空になる」挙動をそのまま再生産する。

### モジュール分離のトレードオフ

プラグイン本体は意図的に `AppIntentsBridge` に依存しない（ADR 0003 と同じ方針）。
そのためキー書式は**2 箇所に重複**する。乖離を検知するために:

- `AppIntentsPlugin.cachePrefix` に「この書式は public API surface であり、変更するなら
  `AppIntentsEntityCache.storageKey(forCacheKey:storageIdentifier:)` も変える必要がある」旨の
  相互参照コメントを置いた
- `EntityCacheTests` がリテラル書式
  （`app_intents.com.example.app.cache.app_intents.entities.…`）を assert する

Dart 側にも対称の `AppIntentsEntityCacheKey.forEntity(identifier)` を追加し、
`setCachedValue` のキーを文字列直書きしなくて済むようにした。

## 決定 2（#98）: `@WidgetConfigurationSpec` から Extension 専用ファイルを生成する

`@WidgetConfigurationSpec` / `@WidgetParameter` を追加し、`WidgetSwiftGenerator` が
次を **別ファイル・別 CLI** で生成する:

- `<Entity>WidgetEntity`（`AppEntity`）
- `<Entity>WidgetQuery`（`EnumerableEntityQuery`、App Group キャッシュのみ参照）
- `<Config>`（`WidgetConfigurationIntent`）

ウィジェット本体（`AppIntentConfiguration` / `AppIntentTimelineProvider`）はアプリごとに
異なるため生成対象外。

### 生成先ターゲットの分離が必須

同じ App Intent 型をアプリ本体ターゲットと Widget Extension ターゲットの両方に含めると
`Metadata.appIntents` が重複し、実行時に Intent を解決できなくなる
（WWDC23「Explore enhancements to App Intents」）。そのため:

- `generate_swift` とは別の `generate_widget_swift` コマンドにし、出力先ディレクトリを分ける
- 生成物のヘッダに「Widget Extension ターゲットにのみ追加すること」を明記する
- 型名を `<Entity>WidgetEntity` にして本体側の `<Entity>` と衝突させない。
  **誤って両方を同一ターゲットに入れた場合、実行時の静かな失敗ではなくコンパイルエラーになる**

### App Group / storageIdentifier は CLI オプション

`--app-group` / `--storage-identifier` を必須オプションにし、生成 Swift に `let` として
焼き込む。アノテーションに持たせると configuration ごとに重複し、実行時設定にすると
Extension 側に初期化タイミングの問題を持ち込む。ビルド時に確定させるのが最も単純で確実。

### `defaultResult()` は既定で生成しない

`defaultResult()` を実装すると、未編集のウィジェットインスタンスの設定値が
**「ウィジェットを追加した時点の値」で埋まる**。これは「アプリ内のグローバル設定を変えたら
未設定のウィジェットが全部追従する」という一般的なフォールバック設計と両立しない。
`@WidgetConfigurationSpec(generateDefaultResult: true)` で opt-in。

### `isDiscoverable` は既定 `false`

ウィジェット設定専用の Intent がショートカットアプリのアクション一覧に出るのはノイズ。
単体で意味がある場合のみ `true` にする。

### エンティティ側の前提を生成時に検証する

参照されたエンティティが `persistedCacheKey` も `enumerable`/`indexed` も持たない場合、
生成しても**キャッシュが存在しないので必ず空になる**。これは issue が問題視した
「静かに壊れる」そのものなので、`InvalidGenerationSourceError` で生成時に落とす。
検証する条件は次のとおり:

| 条件 | 落とす理由 |
|------|-----------|
| 参照先エンティティが未定義 | 生成できない |
| 永続キャッシュを持たない | ピッカーが必ず空になる（静かな失敗） |
| `@EntityId` / `@EntityTitle` 欠落 | キャッシュからエンティティを組み立てられない |
| role フィールドの型が `String` / `String?` でない | キャッシュは文字列しか運ばないので、`var id: Int` に `cached.id`（`String`）を代入する非コンパイル出力になる |
| id 以外の role フィールド名が `id` | 下記の identifier 正規化と衝突して `var id` の二重宣言になる |
| 同一エンティティを共有する configuration が `generateDefaultResult` で食い違う | query はエンティティ単位で1つしか生成しないため、片方が黙ってもう片方の挙動を引き継ぐ |

いずれも「Xcode でしか気づけない」か「実行時に静かに空になる」失敗を、生成時の
明示的なエラーに前倒しするためのもの。

### App Group が開けない場合は黙らない

`UserDefaults(suiteName:)` が nil を返す（= 読み取り側ターゲットに App Groups
entitlement が無い / 識別子が違う）と、すべての読み取りが `[]` になる。これは
「アプリがまだ何も書いていない」と見分けがつかず、issue が問題視した
「候補が黙って空になる」状態そのものになる。そこで:

- `AppIntentsEntityCache` のイニシャライザで nil を検知したら NSLog でエラーを出す
  （プラグイン側 `AppIntentsPlugin.configure` / `storage` と同じ扱い）
- `public var isAccessible: Bool` を公開し、呼び出し側が「到達不能」と「空」を
  区別できるようにする

### Swift の identifier プロパティ名は `id` に正規化する

`AppEntity` は `Identifiable` を継承するため、identifier プロパティは **`id` でなければ
コンパイルできない**（`Identifiable.ID` が `ObjectIdentifier` に推論されて準拠に失敗する）。
Dart の `@EntityId` フィールド名は任意なので、Swift 側では常に `id` とし、Dart のフィールド名は
キャッシュ payload のキー名（`idKey:`）としてのみ使う。

> 既存の `SwiftGenerator`（本体ターゲット向け）は同じ正規化をしておらず、`@EntityId` が
> `id` 以外のフィールドに付いた場合にコンパイルできない出力を出す。これは本 ADR の範囲外の
> 既存バグとして別途扱う。

## 検証

golden/unit テストは「出した文字列が出たこと」しか見ないため、コンパイルできない Swift を
通してしまう（CLAUDE.md の "How to verify" 参照）。本件では実際にこの経路で
**2 件のバグを検出した**（optional scalar が `Int??` になる／`Identifiable` 不適合）。

加えてセルフレビューで、著者由来の文字列（title / description / displayImageName /
App Group 識別子）を Swift の文字列リテラルへ未エスケープで埋め込んでいた点を修正した。
`"` を含むタイトルは非コンパイル出力になり、`\(` は Swift の文字列補間として
黙って再解釈される。`_swiftLiteral` で `\` `"` 改行・タブをエスケープする。

生成 Swift は `AppIntentsBridge` をモジュールとしてビルドしたうえで
`swiftc -typecheck` を **Xcode 26.5（安定）と Xcode 27 beta 5 の両 iPhoneOS SDK** に対して実行し、
両方 green を確認した。検証した組み合わせ:

- 例アプリの出力（optional entity param + `bool` scalar、`@EntitySubtitle`/`@EntityImage` あり）
- `@EntityId` が `id` 以外 / `generateDefaultResult: true` / `isDiscoverable: true` /
  非 optional entity param / `int?` `DateTime?` scalar / `displayImageName` フォールバック

さらに `TeamEntitySpecWidgetQuery.DefaultValue.Type = TeamEntitySpecWidgetEntity.self` の
コンパイル時プローブで、`defaultResult()` が（無関係なメソッドではなく）実際に
プロトコル要件の witness になっていることを確認した。

## 先送りした項目

- **ウィジェット本体の生成**（`AppIntentConfiguration` / `AppIntentTimelineProvider`）:
  アプリごとに差が大きく、生成しても手直しが前提になる
- **`@EnumSpec` / `IntentFile` 等の widget パラメータ対応**: 現状は
  `String`/`int`/`double`/`bool`/`DateTime` とエンティティのみ
- **`ControlConfigurationIntent`（Control Center / iOS 18）**: 同じ「Flutter エンジンなし」
  制約を共有するので同じ仕組みで拡張できるが、別 issue とする
- **Extension からの書き込み**: 本 ADR の API は read-only。Extension がエンティティを
  更新する要求はまだない
