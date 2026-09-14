# ADR 0007: 宣言的スニペットビュー

- **ステータス**: Accepted — 実装済み（2026-09-14）
- **関連 issue**: #56（ADR 0004 で「カスタムスニペット = 宣言的テンプレートのみなら条件付き GO」と判定した分の実装）
- **対象フラグ**: なし（experimental ではない）

## コンテキスト

ADR 0004 は、Flutter アプリに SwiftUI のビューツリーが無いことを理由に
`.appEntityIdentifier` のような**ビュー単位**の API を NO-GO とし、カスタムスニペットは
「**宣言的テンプレートなら条件付き GO**、任意の Flutter ウィジェットは NO-GO」と結論して
別 issue 送りにしていた。本 ADR はその「宣言的テンプレート」を具体化する。

Siri の結果カードは SwiftUI ビューで描かれる。Flutter アプリはそれを渡せないので、
**ビューを受け取る代わりに固定レイアウトの記述を受け取り、codegen が具体的な SwiftUI
ビューに変換する**。汎用 UI 言語にはしない。これ以上の表現が要るならアプリ本体を開く
（`openAppWhenRun`）のが正しい。

## SDK 事実（Xcode 26.5 SDK / 27.0 RC で確認）

```swift
// _AppIntents_SwiftUI overlay
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension AppIntents.IntentResult {
  public static func result<Content>(dialog: IntentDialog, view: Content = EmptyView()) -> Self
    where Self == IntentResultContainer<Never, Never, _SnippetViewContainer, IntentDialog>,
          Content : SwiftUICore.View
}
public protocol ShowsSnippetView : IntentResult where Snippet == _SnippetViewContainer  // iOS 16
```

- **`ShowsSnippetView` は iOS 16**。安定 SDK にあるので `#if` も experimental フラグも不要。
- `.result(view:)` は `AppIntents` 本体ではなく **`_AppIntents_SwiftUI` オーバーレイ**にある。
  生成ファイルに `import SwiftUI` が要る（無いと「そんなオーバーロードは無い」と言われる）。
- `SnippetIntent`（iOS 26）は別物。`reload()` やボタン付きの**対話**スニペット用で、本 ADR の
  対象外。

## 決定

`@IntentSpec(snippet: SnippetTemplate(...))`。レイアウトは固定:

```
[SF Symbol] タイトル
            サブタイトル
LabeledContent(ラベル) 値
LabeledContent(ラベル) 値
```

生成物は intent ごとの自己完結した `struct <Intent>SnippetView: View`。動的な部分は
**格納された `String` プロパティ**として入る（共有ランタイム型を増やさないため）。
ラベルはリテラルのまま置くので `LabeledContent` が `LocalizedStringKey` として扱い、
String Catalog 経由でローカライズされる。

### プレースホルダの2系統

| 記法 | 出典 | 使える実行モード |
|---|---|---|
| `{paramName}` | Intent のパラメータ | 全モード |
| `{result.key}` | Dart ハンドラの戻り値 | **FlutterBridge のみ** |

`{result.key}` は `perform()` が `FlutterBridge.shared.invoke` の戻り値を受け取れる時しか
成立しない。URL scheme / cache（foreground）モードはアプリに引き渡して即 return するため、
ハンドラはまだ何も返していない。**この2モードでの `{result.…}` は生成時エラー**にした。
黙って空文字を描くと、Siri の中でしか見えない場所で静かに壊れる。

ダイアログ側（`resultDialogTemplate` / `resultDialogSupportingTemplate`）でも同じ
`{result.key}` を受け付ける。カードとダイアログは同じ結果を説明しているのに片方だけ
ハンドラの値を参照できないのは不自然なため。

### Dart ハンドラの戻り値の扱い

従来、生成された登録コードはハンドラの戻り値を捨てて `<String, dynamic>{}` を返していた。
`{result.…}` を使う intent に限り、戻り値を `intentResultPayload()`（`app_intents` に追加）
に通して返す。それ以外の intent の生成出力は**従来どおり**。

`intentResultPayload` は `Map` / `toJson()` を持つ値 / `null` を受け付ける。それ以外は
`ArgumentError` を投げる。生成された entity ハンドラが既に `toJson()` 規約に依存している
ので、それに揃えた。**黙って空マップにはしない** — 空のカードは Siri 上からは原因を追えない。

## 検証

- `swiftc -typecheck`（デプロイメントターゲット iOS 17.0、iOS 26.5 / 27.0 SDK 両方）。
- example アプリに **FlutterBridge モードの `TaskSummaryIntentSpec` を新設**し（既存3本は
  すべて URL scheme / foreground だったので `{result.…}` を実演できなかった）、
  `flutter build ios` 成功。
- 教訓: 実装途中、生成された View 本体にインデント用ヘルパーの識別子が literal `$i5$_indent`
  として漏れていたが、**golden テストは全て緑のままだった**。文字列比較では壊れた
  インデントヘルパーは見えない。`swiftc` だけが捕まえた。回帰用に「Dart の補間が漏れて
  いないこと」を確認するテストを1本足したが、本質的な担保は typecheck 側にある。

## 対象外

- 任意の Flutter ウィジェットのスニペット（ADR 0004 のとおり NO-GO）。
- `SnippetIntent`（iOS 26）による対話スニペット・`reload()`・スニペット内 `Button(intent:)`。
- スニペット内でのエンティティ画像表示（現状 SF Symbol のみ）。
