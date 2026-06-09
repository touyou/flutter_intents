# ADR 0004: オンスクリーン認識・スニペットビューの実現可能性 (#56)

- **ステータス**: Proposed（**実現可能性判定**。実装を約束するものではない）
- **関連 issue**: #56
- **形式**: 他の ADR と異なり、これは **GO / NO-GO 判定**であって実装ブループリントではない

## コンテキスト

オンスクリーン認識（「これ」「あれ」の解決）とカスタムスニペットビューに対応できるか調査する。
**これらは SwiftUI のビュー注釈／スニペットビュー API** であり、Flutter は単一の
`FlutterView`（Metal/Impeller の描画サーフェス）に全 UI を描く。SwiftUI のビューツリーが存在しない。
したがって「SwiftUI 前提の API」が Flutter のレンダリングモデルに乗るかどうかが判定の核心になる。

### 対象 API（issue ドラフト）

- オンスクリーン認識
  - `NSUserActivity` — 単一の主要エンティティを画面に紐付け
  - `.appEntityIdentifier` ビュー修飾子 — 個別ビューにエンティティ参照を注釈
  - `.appEntityIdentifier(forSelectionType:)` — コレクション/リスト向け
- カスタムスニペットビュー
  - `ShowsSnippetView` — デフォルトの Siri 結果カードを独自 SwiftUI ビューで置換 [SDK検証済: 名称存在]

## 判定の核心: Flutter は SwiftUI ビューツリーを持たない

| サブ機能 | 仕組み | Flutter での成立性 | 判定 |
|----------|--------|-------------------|------|
| `NSUserActivity` 画面単位の単一エンティティ紐付け | Foundation/UIKit。SwiftUI 非依存 | プラグインで `NSUserActivity` を作り、Flutter の画面遷移に同期できる | **GO（PoC 推奨）** |
| `.appEntityIdentifier` 個別ビュー/コレクション注釈 | **SwiftUI ビュー修飾子**。個々の SwiftUI View に付与 | Flutter は要素ごとの SwiftUI View を持たない。要素単位の PlatformView 化は非現実的（性能/複雑性） | **NO-GO** |
| `ShowsSnippetView` カスタムスニペット | **Swift がレンダリングする独立 SwiftUI ビュー**。Siri がアプリ外文脈で表示 | Flutter ウィジェットをその SwiftUI ビューに描けない | **条件付き / 後続**（下記） |

## サブ機能ごとの判定

### 1. `NSUserActivity` 画面単位の単一エンティティ紐付け — **GO（PoC 推奨）**

- `NSUserActivity` は Foundation/UIKit の仕組みで SwiftUI 非依存。**完全にブリッジ可能**。
- 設計案: プラグインに `setCurrentOnscreenEntity(entityIdentifier, entityType)` /
  `clearCurrentOnscreenEntity()` を追加。Flutter のルート遷移（`NavigatorObserver` 等）で
  「今この画面が表す主要エンティティ」を通知 → ネイティブ側で `NSUserActivity` を生成・
  `becomeCurrent()` し、エンティティ参照を関連付ける。これにより Siri が「これ」を画面の
  主要エンティティとして解決できる。
- iOS 27 シンボルが絡むのは「アクティビティへのエンティティ関連付け」部分のみ。プラグイン本体に
  入れる場合は ADR 0003 と同じ「シンボル存在の壁」を点検し、必要なら逆向き executor で生成コードに逃がす。
- **[要検証]** `NSUserActivity` ↔ `AppEntity` 関連付け API の正確な形と iOS バージョン。

### 2. `.appEntityIdentifier` 個別ビュー/コレクション注釈 — **NO-GO**

- これは SwiftUI の View 修飾子で、画面上の**個々の SwiftUI 要素**にエンティティ参照を付ける。
  Flutter は全 UI を 1 つの `FlutterView` に描くため、注釈できる SwiftUI 要素が存在しない。
- 要素ごとに PlatformView（ネイティブビュー埋め込み）化すれば理屈上は可能だが、
  リスト/コレクションの各セルを PlatformView 化するのは性能・実装複雑性の両面で非現実的。
- → **汎用 Flutter UI では非対応**。画面単位（サブ機能1）でカバーできる範囲に留める。

### 3. `ShowsSnippetView` カスタムスニペット — **条件付き / 後続**

- スニペットは Siri がアプリ外で表示する**独立した SwiftUI ビュー**。Flutter ウィジェットを
  そこに直接描く手段はない。検討した経路:
  - **(a) 宣言的テンプレート方式**: Dart 側で「タイトル/サブタイトル/画像/数行のキー値」など
    **限定的なスニペット仕様**を宣言し、codegen が静的な SwiftUI ビューを生成する。
    任意の Flutter ウィジェットではなく**データ駆動のテンプレート**。→ **現実的な唯一の経路**。
    別機能として後続で検討する価値がある。
  - **(b) Flutter を画像化してスニペット画像に**: ヘッドレス Flutter エンジンの起動タイミング、
    非インタラクティブ、レイアウト不整合の問題が大きい。→ **NO-GO**。
- → **任意の Flutter ウィジェットをスニペット化するのは NO-GO**。宣言的テンプレート (a) のみ
  将来の候補として残す。

## 総合推奨

- **GO**: `NSUserActivity` による**画面単位の単一エンティティ紐付け**。Flutter の画面遷移と同期する
  プラグイン API を PoC で検証してから着手する。#56 の中で唯一、汎用 Flutter で素直に成立する経路。
- **NO-GO**: `.appEntityIdentifier` の**個別ビュー/コレクション注釈**。Flutter のレンダリングモデルと
  非互換。対応しない（画面単位でカバー）。
- **条件付き/後続**: カスタムスニペットは**宣言的テンプレート方式 (a)** に限り将来検討。
  任意ウィジェットのスニペット化は NO-GO。

この ADR は調査結果であり、**実装着手は (1) の PoC 成功を条件**とする。
(2) は対応しないことを明記し、(3) は別途テンプレート機能として再起票するのが妥当。
