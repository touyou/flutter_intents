# ADR 0010: 実行中インテントとの双方向経路（#130 / #131）

- **ステータス**: Accepted — 実装済み（進捗・キャンセル・値要求）
- **関連 issue**: #130（LongRunningIntent の進捗とキャンセル）、#131（`$param.requestValue`）
- **対象フラグ**: 進捗/キャンセルは `--experimental=long-running`（iOS 27 シンボル）。
  **値要求はフラグなし**（`requestValue` は iOS 16）

## コンテキスト

`@IntentSpec(longRunning:, cancellable:)` は #52 で生成できるようになっていたが、
生成される `onCancel:` は**コメントだけのスタブ**で、キャンセルは Dart に一切届かず、
進捗も出せなかった。#131 の `$param.requestValue` も「双方向の suspending RPC が要る」
として先送りされていた。

この2件は**同じ配管**で解ける。どちらも「**いま走っている `perform()` のインスタンス**に
Dart から触りたい」という要求だからである。

### 既存ブリッジの形

`FlutterBridge` の executor はすべて **Swift → Dart の一方向**（呼んで、戻る）で、
呼び出しの**途中**に Dart から Swift を叩き返す経路がなかった。ただし MethodChannel
自体は双方向なので、足りなかったのは**宛先の特定**だけである。

## 決定 1: 実行スコープ（executionId）

生成された `perform()` が UUID を作り、`FlutterBridge.beginExecution(_:progress:valueRequester:)`
でフックを登録し、`defer` で `endExecution` する。UUID は params に
`_executionId` として載って Dart に渡る。

```swift
let executionId = UUID().uuidString
nonisolated(unsafe) let progressRef = progress
await FlutterBridge.shared.beginExecution(
    executionId,
    progress: { completed, total in
        progressRef.totalUnitCount = total
        progressRef.completedUnitCount = completed
    },
    valueRequester: { [self] parameter in
        switch parameter {
        case "note": return try await $note.requestValue()
        default: return nil
        }
    }
)
defer { Task { await FlutterBridge.shared.endExecution(executionId) } }
```

**なぜ `progress` をブリッジに持たせないか。** `ProgressReportingIntent` は iOS 27 の
シンボルで、`AppIntentsBridge` は安定 SDK でもコンパイルできねばならない（ADR README
の「判断の軸 2」）。だからブリッジが知るのは `(Int64, Int64)` の数値だけで、
`progress` オブジェクトを名指すのは `#if` の内側にある生成コードだけにした。

**`nonisolated(unsafe)` について。** Foundation の `Progress` は Sendable ではないが、
複数スレッドからの利用は Apple のドキュメントで明示的に安全とされている。ブリッジは
自分の actor 上から sink を呼ぶので、警告を放置するのではなく**意図であることを宣言**する
形にした。

**`valueRequester` が `[self]` をキャプチャする理由。** `requestValue()` は「いま中断している
その `perform()`」を再開させる API なので、同じインテントインスタンスでなければならない。
`AppIntent` は `Sendable` を継承し `IntentParameter` は `@unchecked Sendable` なので、
`@Sendable` クロージャでのキャプチャは合法（SDK 実測）。

## 決定 2: Dart 側は Zone で渡す（ハンドラのシグネチャを変えない）

#130 は「生成される Dart ハンドラのシグネチャ変更」を検討事項に挙げていたが、**変えない**
ことにした。生成ハンドラの引数はインテントのパラメータそのもので、そこにコンテキスト引数を
足すと**既存利用者のハンドラが全部壊れる**。

代わりに、プラグインがハンドラ呼び出しを `runZoned` で包み、
`AppIntentExecution.current` で取得させる:

```dart
Future<void> exportTasksHandler({required String format}) async {
  final execution = AppIntentExecution.current;
  for (var i = 0; i < tasks.length; i++) {
    if (execution?.isCancelled ?? false) return;
    await exportOne(tasks[i]);
    await execution?.reportProgress((i + 1) / tasks.length);
  }
}
```

Zone は非同期呼び出し木を通って伝播するので、ハンドラが更に呼び出した先でも `current` が
効く。`_executionId` はハンドラに渡す前に params から取り除くので、生成された
`…Params.fromMap` は予約キーを知らなくてよい。

**`current` は null になりうる。** 実行スコープを開くのは「長時間実行 / キャンセル可能 /
値要求パラメータを持つ」インテントだけで、しかも進捗とキャンセルは `#if` の内側にしかない。
安定ビルド（フラグ未設定）では `execution?.reportProgress(...)` が**何もしない**で済むよう、
`#else` 側では実行スコープを開かない。エラーにしないのは、利用者が選べないビルド設定の
違いだからである。

## 決定 3: キャンセルは通知、値要求は応答

| | 向き | 待つか | 失敗時 |
|---|---|---|---|
| 進捗 | Dart → Swift | 待たない | スコープが閉じていれば throw（プログラミングエラー） |
| キャンセル | Swift → Dart | 待たない | 通知器未配線でも無害（システムはいつでも kill しうる） |
| 値要求 | Dart → Swift → Dart | **待つ** | `MissingPluginException` を握りつぶさない |

値要求だけは戻り値をハンドラが使うので、他の外向き呼び出しのように
`MissingPluginException` を無視すると**ユーザーが選んでいない null** を渡すことになる。
そこだけ例外を通す。

`onCancel:` の中身は `Task { … }` で包む。SDK が `onCancel` を async として宣言しているか
どうかに関係なく通り、システムが待ってくれないケースでも best-effort で届く。

## 決定 4: `requestValue` は optional パラメータ限定

姉妹プロジェクト（IntentTodo）は `requestValue` を「**非 optional はシステムが自動で
聞き返すので出番がない**」として意図的に不使用と結論している。これは正しいが、
**optional には当てはまらない** — 呼び出し側が正当に省略した値をシステムが勝手に聞くことは
ないので、聞きたければ `requestValue` しかない。

したがって codegen は非 optional への指定を**生成時エラー**にする。併せて、戻り値が
MethodChannel を渡る必要があるので、プリミティブ（String/int/double/bool/DateTime）
以外も拒否する（`DateTime` は他と同じく ISO-8601 文字列に正規化する）。

## 検証

- `scripts/verify_experimental_swift.sh` を Xcode 27.0 で実行し、両ブランチ（`-D` あり/なし）
  が型チェックを通ることを確認。`requestValue` は `#else` 側にも出る
- Dart 単体テスト（`packages/app_intents/test/intent_execution_test.dart`）で Zone 伝播・
  予約キーの除去・キャンセル配送・値要求を確認
- Swift 単体テスト（`FlutterBridgeTests`）で sink 配送・スコープ終了後の throw・
  通知器未配線の無害さを確認
- **未検証**: 実機で Siri が実際に進捗 UI を出すか、キャンセル理由の文字列が何になるか
