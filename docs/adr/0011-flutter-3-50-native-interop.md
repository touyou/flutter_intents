# ADR 0011: Flutter 3.50 のネイティブ相互運用をどこまで使うか

- **ステータス**: Accepted（2026-11-12）。最小 Flutter は 3.44 のまま据え置く
  （サンプルアプリは 3.50 で非推奨になった `material.dart` の代わりに `material_ui` を使う。制約は 3.44 でも解決できる `^1.3.0`）
- **対象**: `app_intents`（iOS / Android のプラグイン本体）

## コンテキスト

Flutter 3.50 / Dart 3.14（2026-11-11）で、ネイティブとの相互運用に次の変更が入った。

| 変更 | 状態 | このプラグインへの関係 |
|---|---|---|
| FFIgen（C / Objective-C）と JNIgen（Java / Kotlin）が stable | stable | 下記「不採用」 |
| Pigeon の native interop モード（FFI / JNI で同期呼び出し・バックグラウンド isolate から呼べる） | **preview**（「本番利用には安定していない」と明記） | 下記「不採用」 |
| `package:swiftgen`（Obj-C 注釈なしの Swift を直接呼ぶ） | experimental | 不採用 |
| プラグインの登録口に engine id: Android `FlutterPluginBinding.getEngineId()` / iOS・macOS `FlutterPluginRegistrar.engineIdentifier` | 3.50.0 stable に入っている（タグで確認） | 下記「最小 3.50 まで保留」 |
| SPM を無効にすると CLI が毎回警告 | stable | プラグインは SPM 対応済み。対応不要 |
| リリースビルドで外部 Intent の `cached_engine_id` 等を無視 | stable | 例のアプリは `getCachedEngineId()` の override で渡しており影響なし |

## 判断

### 不採用: Pigeon native interop / FFIgen / JNIgen / swiftgen

このプラグインの詰まりどころは**チャンネルの速さや同期性ではなく、エンジンがまだ動いていないこと**
（iOS は `WFIsolatedShortcutRunner` で別プロセス、Android は Activity なしでプロセスが起きる）。
FFI / JNI に置き換えても、Dart のハンドラを呼ぶにはエンジンと isolate が要る点は変わらない。
呼び出しは Intent 1 回につき数往復で、MethodChannel のコストは問題になっていない。

加えて Pigeon native interop は preview で、`createWithNativeInteropApi()` が
「呼び出し元のエンジンではなく、同じ `name` で最後に登録されたホストに結び付く」既知の制約がある。
プラグインが MethodChannel 用に組んだ受け口（`handlerRegistrationTimeout` の待ち、
`AppIntentsHarness` がチャンネルバッファに積んで端末と同じ経路を通すテスト）も作り直しになる。

見直す条件: Pigeon native interop が stable になり、かつ「Dart 側からネイティブを同期で読みたい」
需要が出たとき（例: App Group の UserDefaults を `await` なしで読む）。

### 最小 3.50 まで保留: engine id でインスタンスを引く

`AppIntentsPlugin.shared` は「最後に登録されたエンジンのインスタンス」で、エンジンが複数あると
後から来たものに上書きされる。engine id があればエンジンごとに引き分けられるが、
iOS の `engineIdentifier` は 3.50 で足されたプロパティなので、使うと Swift が 3.49 以前で
コンパイルできない。今は最小 3.44 を保ち、engine id は使わない。

代わりに Android は、**取り外されたエンジンのインスタンスだけを外し、残っているエンジンの
インスタンスに戻す**ようにした（以前はどのエンジンが外れても `shared` が null になった）。
特定のエンジンに届けたいときは、これまでどおり `startEngine` が渡すチャンネルを使う。

最小を 3.50 に上げるとき（Flutter が KGP 適用プラグインを落とすなど、別の理由で上げるときに
まとめる）に、iOS にも `detachFromEngine(for:)` と engine id ごとの登録を入れる。
