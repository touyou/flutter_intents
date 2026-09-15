# ADR 0008: AppIntentsPackage 対応

- **ステータス**: Accepted — 実装済み（2026-09-14）
- **関連 issue**: #59 の deferred punch list。#55 `RelevantIntent` の前提整理も兼ねる
- **対象フラグ**: なし（`AppIntentsPackage` は iOS 17）

## コンテキスト

生成した Intent / Entity を**共有 Swift パッケージ**に置き、アプリターゲットと
App Extension（Widget 等）の両方から使いたい。この構成が取れると、
`WidgetConfigurationIntent` の具体型をアプリ側からも名指しでき、#55 の
`RelevantIntent`（`init(_:widgetKind:relevance:)` が具体型を要求する）が成立する。

一方で本リポジトリには「同じ App Intent 型をアプリターゲットと Extension ターゲットの
**両方にコンパイル**すると `Metadata.appIntents` に重複して intent 解決が壊れる」という
確定事実がある（`app/ios/TaskWidget/README.md`）。この2つは矛盾しない。前者は
**1つの共有モジュールを両方がリンクする**話で、後者は**同じソースを2回コンパイルする**話。

## 実測事実（SDK 27 / tools `27A266a`）

姉妹プロジェクト（IntentTodo, 7 パッケージ構成）のビルド生成物を突き合わせた結果:

| バンドル | `AppIntentsPackage` 宣言 | `extract.packagedata` | actions / entities / queries |
|---|---|---|---|
| `TodoAppIntents.appintents` | あり（`includedPackages` 無し） | `{"includes":[]}` | 24 / 5 / 4 |
| `UI.appintents` | **無し** | **ファイルごと無し** | 24 / 5 / 4 |
| `IntentTodo.app/Metadata.appintents` | あり（`includedPackages` あり） | `{"includes":["14TodoAppIntents0aC7PackageV"]}` | 24 / 7 / 4 |

**メタデータが集約される条件は「リンクの形」であって `AppIntentsPackage` の有無ではない。**
静的リンクした依存先の抽出結果は宣言ゼロで利用側の `extract.actionsdata` にマージされる
（`UI` は宣言ゼロで 24 actions が載っている）。宣言が生むのは `extract.packagedata` の
`includes`（`includedPackages` に並べた型のマングル名）だけ。

Apple の言い方も条件付き:
> "You should use App Intents Package when referencing code not compiled into a static library."
> （wwdc2025-244 `24:00`）

Xcode の SPM は既定で静的リンクなので、**共有パッケージ構成そのものは宣言なしでも動く**。
宣言が効き始めるのは、どれかを動的プロダクト（framework / dynamic library）に変えた時。

## 決定

両 CLI にオプションを足す。生成するのは宣言だけで、ターゲット構成は利用者の Xcode 側の話。

```bash
# 共有パッケージ側
dart run app_intents_codegen:generate_swift \
  -o ../SharedIntents/Sources/SharedIntents \
  --app-intents-package SharedIntentsPackage

# 利用側（アプリ / Widget Extension）
dart run app_intents_codegen:generate_widget_swift … \
  --app-intents-package TaskWidgetAppIntentsPackage \
  --include-package SharedIntents.SharedIntentsPackage
```

`--include-package` はモジュール修飾名を取り、接頭辞を `import` に変換する。
`--include-package` 単独指定は（`includedPackages` の置き場が無いので）エラー。

### 意図的にやらないこと

- **「メタデータに型が出てこない」を `includedPackages` の足し引きで直させない。** 上の実測の
  とおりそこは効かない。見るべきはターゲットメンバシップとリンク形態。生成器のドキュメント
  コメントと CLI ヘルプの両方にこれを書いた。
- **ターゲット構成の自動生成はしない。** 共有パッケージの作成・リンクは Xcode プロジェクト側の
  作業で、codegen の責務外。

### 既知の落とし穴（姉妹プロジェクトの実測）

- **メインターゲットでの `AppIntentsPackage` 重複宣言**が Shortcuts の intent ルーティングを
  壊した事例がある。ターゲットにつき1つ。
- **`AppShortcutsProvider` はアプリターゲット直下に置く。** パッケージ内に移すと
  `autoShortcuts` が 0 になる（パッケージ→アプリターゲットへ戻した時点で 0→8 に変化するのを実測）。

## 検証

- 生成される宣言の形を `swiftc -typecheck`（デプロイメントターゲット iOS 17.0）で確認。
- ユニットテスト（宣言の有無 / `includedPackages` / モジュール import の重複排除 /
  非修飾名は import しない）。
- **未検証**: 実際に共有パッケージ構成へ切り出した example アプリのビルド。example は現状
  単一ターゲット構成のままで、この構成変更は別作業。

## 追記（2026-09-15）: 配布ビルドで App Intents が丸ごと読み込まれなくなった実測

姉妹プロジェクト（IntentTodo）で、**TestFlight / App Store 経由でインストールしたときだけ**
アプリの App Intents がショートカット・Spotlight に一切出なくなる事象が起き、ビルド二分で
**`AppIntentsPackage` 宣言の追加コミット**まで絞り込まれた。

| 構成 | インストール経路 | 結果 |
|---|---|---|
| Debug | Xcode | 出る |
| Release | Xcode | 出る |
| Release | App Store / TestFlight | **出ない（アプリ名すら一覧に出ない）** |

出荷バンドルの `Metadata.appintents` 自体は健全だった（actions 26 / entities 9 /
autoShortcuts 8、tools `27A266a`）。`AppIntentsPackage` 宣言が足すのは
`extract.packagedata` ただ1つで、中身は `includedPackages` に並べた型の**マングル名**:

```json
{"includes":["14TodoAppIntents0aC7PackageV"],"version":1}
```

App Intents のメタデータの中で**型を実行時にマングル名で引く唯一の経路**がここで、解決に
失敗したときの巻き添え範囲がバンドル全体になる。「アプリ名すら出ない」という症状の形と
一致し、`STRIP_INSTALLED_PRODUCT` / `STRIP_SWIFT_SYMBOLS` が効くのが配布側だけである点とも
整合する。向こうは宣言を全廃し、`actions` / `entities` / `autoShortcuts` の件数も
`nlu.appintents` も**据え置き**であることを確認している（失うものが無い）。

### 本 ADR の判断への影響

**この ADR の結論（「静的リンクなら宣言は不要」）は変わらない。** むしろ補強される:
静的リンクで宣言が不要なら、**宣言を足すのは利得ゼロでリスクだけ**ということになる。

`--app-intents-package` / `--include-package` は**残す**。害があるのは
`AppIntentsPackage` という API そのものではなく、**静的リンク構成でそれを宣言すること**で、
動的リンク境界を跨ぐ構成では依然として必要な宣言だからである。オプションを消すと、
本当に必要な構成の利用者に逃げ道が無くなる。

代わりに周知する:

- CLI ヘルプと生成器のドキュメントコメントに、**まずリンク形態を確認すること**と
  **配布ビルドでの実測事故**を書く。
- 「メタデータに出てこない」の対処としてこのフラグに手を出さない（ADR 本文のとおり効かない）。

### 教訓（このリポジトリの検証手順にも効く）

> **ローカルビルドの生成物が正しいことは、配布したものが読まれることを意味しない。**

向こうの 2026-08-12 の「害が無い」判断は**生成物の件数を数えて**出したもので、配布経路を
通した実機は一度も測っていなかった。本リポジトリの検証も `swiftc -typecheck` と
生成物の文字列比較が中心なので、**同じ穴が開いている**。App Intents まわりの「動く」は、
配布経路を通した実機まで含めて初めて成立する。

なお向こうも**「`c4f20ef` が原因」までが確定で、TestFlight での復帰確認はこれから**である。
断定ではなく強い警告として扱う。
