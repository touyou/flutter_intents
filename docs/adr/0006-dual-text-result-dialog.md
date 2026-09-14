# ADR 0006: 読み上げと画面表示を分けた結果ダイアログ

- **ステータス**: Accepted — 実装済み（2026-09-14）
- **関連 issue**: #59 の deferred punch list（matsudate review #4）
- **対象フラグ**: なし（experimental ではない）

## コンテキスト

`@IntentSpec(resultDialogTemplate:)` は 1 本の文字列しか取れず、生成コードは常に
`.result(dialog: .init("…"))` を出していた。

Siri は結果を**読み上げるだけ**のこともあれば、**画面にも出す**こともある。1 本しか
無いと、読み上げ向けに文脈を足した文言（「そのタスクを完了にしました」）にすると画面では
冗長になり、画面向けに短くする（「完了」）と音声だけの時に何の話か分からなくなる。

## SDK 事実（Xcode 26.5 SDK / Xcode 27.0 RC の `.swiftinterface` で確認）

```swift
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct IntentDialog : ExpressibleByStringInterpolation, Sendable {
  public init(_ string: LocalizedStringResource)
  public init(full: LocalizedStringResource, supporting: LocalizedStringResource)
  @available(macOS 14.2, iOS 17.2, watchOS 10.2, tvOS 17.2, *)
  public init(full: LocalizedStringResource, systemImageName: String)
  @available(macOS 14.2, iOS 17.2, watchOS 10.2, tvOS 17.2, *)
  public init(full: LocalizedStringResource, supporting: LocalizedStringResource, systemImageName: String)
}
```

**重要**: `full:supporting:` は **iOS 16** で、安定 SDK にもある。punch list では
「WWDC26 の新機能」として `#if` ゲート側に分類していたが、それは誤りだった。
experimental フラグは不要で、これは通常機能として出せる。

`systemImageName` を伴う 2 つだけが **iOS 17.2**。本プラグインの生成 Intent は
`@available(iOS 17.0, *)` なので、ここだけランタイム分岐が要る。

## 決定

`@IntentSpec` に兄弟フィールドを 2 本足す（`resultDialogTemplate` は非推奨にしない）。

| フィールド | 生成 |
|---|---|
| `resultDialogTemplate` のみ | `.result(dialog: .init("…"))`（従来どおりバイト一致） |
| `+ resultDialogSupportingTemplate` | `IntentDialog(full:supporting:)` |
| `+ resultDialogSystemImageName` | `if #available(iOS 17.2, *)` でシンボル付き、`else` でシンボル無し |

```swift
let dialog: IntentDialog
if #available(iOS 17.2, *) {
    dialog = IntentDialog(full: "…", supporting: "…", systemImageName: "checkmark.circle")
} else {
    dialog = IntentDialog(full: "…", supporting: "…")
}
return .result(dialog: dialog)
```

`@available(iOS 17.2)` をイントネーション単位で付けて Intent 自体の下限を上げる案は採らない。
ダイアログの飾りのためにその Intent が iOS 17.0/17.1 で使えなくなるのは割に合わない。

### 付随する決定

- **片方だけの指定はエラー**。`resultDialogTemplate` 無しで supporting / symbol を
  指定した場合、黙って捨てると「Siri が supporting を出さない仕様」に見えてしまうので
  `InvalidGenerationSourceError` にする。
- **supporting も String Catalog に載せる**。読み上げだけ翻訳されて画面表示が英語のまま、
  という状態を作らない。

## 検証

- `swiftc -typecheck` を **デプロイメントターゲット iOS 17.0** で実行（iOS 26.5 SDK /
  iOS 27.0 SDK の両方）。この「SDK ではなく下限で型チェックする」点が load-bearing で、
  SDK バージョンでコンパイルすると `@available` が全部満たされてしまい、ガード漏れを
  検出できない（`scripts/verify_experimental_swift.sh` はこの理由で下限固定に変更した。
  ガード無しの `IntentDialog(full:supporting:systemImageName:)` が iOS 17.0 ターゲットで
  実際にエラーになることを確認済み）。
- example アプリの `CompleteTaskIntentSpec` を dual-text 化し、`flutter build ios` 成功。

## 対象外

- `ShowsSnippetView` によるカスタムスニペット（別 ADR）。
- `requestConfirmation(actionName:snippetIntent:)` 等、ダイアログ以外の対話 API。
