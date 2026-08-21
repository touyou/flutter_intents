# WidgetConfigurationIntent codegen (issue #98)

`GeneratedIntents/GeneratedWidgetIntents.swift` is generated from
`app/lib/widgets/select_task_widget_config.dart` by:

```bash
make widget-gen
```

which runs:

```bash
cd app && dart run app_intents_codegen:generate_widget_swift \
  -o ios/TaskWidget/GeneratedIntents \
  --app-group group.com.example.app \
  --storage-identifier com.example.app
```

It contains a `WidgetConfigurationIntent` plus a cache-backed `AppEntity` and
`EnumerableEntityQuery`, so a Home Screen widget can be configured
("long-press → Edit Widget") with a task picker.

## Status

- **Compile-verified only** (`swiftc -typecheck` against both the stable
  Xcode 26.5 and the Xcode 27 beta iPhoneOS SDKs, with `AppIntentsBridge`
  built as a module). It is **not** wired into an Xcode Widget Extension
  target — creating one requires an extension target, an entitlement, and a
  widget bundle, which is out of scope for the example app.
- No Dart code is generated for a `@WidgetConfigurationSpec`: nothing runs in
  Dart, so there is no handler and no `part` directive.

## Why this file is separate

A Widget Extension **cannot start a Flutter engine**, so the `FlutterBridge`
round-trip the app target's `GeneratedAppIntents.swift` uses is unavailable
there. The generated query instead reads the App Group cache that
`TaskRepository` already writes (`com.example.taskapp.cache.tasks`) through
`AppIntentsEntityCache` (issue #97).

Separation is also **mandatory for correctness**: including the same App Intent
type in both the app target and an extension target duplicates it in
`Metadata.appIntents`, and iOS then fails to resolve the intent at runtime.
That is why the generated entity is named `TaskEntitySpecWidgetEntity` rather
than reusing the app target's `TaskEntitySpec` — if both files ever land in one
target, you get a compile error instead of a silent runtime failure.

## Wiring it up

1. In Xcode, add a **Widget Extension** target (e.g. `TaskWidget`) to
   `Runner.xcworkspace`. Set its minimum deployment to iOS 17.0.
2. Add `GeneratedIntents/GeneratedWidgetIntents.swift` to that target —
   **and only that target**.
3. Add the `AppIntentsBridge` Swift package to the Widget Extension target
   (`File → Add Package Dependencies`, or the local `ios-spm/AppIntentsBridge`
   package).
4. Give the extension the **App Groups** entitlement for
   `group.com.example.app` — the same group the app passes to
   `AppIntentsPlugin.configure(appGroupIdentifier:)`. Without it the cache is
   unreadable and the picker silently shows no options.
5. Write the widget itself (not generated — it differs per app):

   ```swift
   struct TaskWidget: Widget {
       var body: some WidgetConfiguration {
           AppIntentConfiguration(
               kind: "TaskWidget",
               intent: SelectTaskWidgetConfig.self,
               provider: TaskTimelineProvider()
           ) { entry in
               TaskWidgetView(entry: entry)
           }
       }
   }
   ```

   In `TaskTimelineProvider`, `configuration.task` is `nil` for an unconfigured
   instance — decide the fallback there. See `generateDefaultResult` in
   `@WidgetConfigurationSpec` for why no default is baked in by default.

## Storage identifier

`--storage-identifier` must be the **host app's** bundle identifier
(`com.example.app`), or whatever explicit `storageIdentifier` the app passes to
`AppIntentsPlugin.configure`. The extension's own
`Bundle.main.bundleIdentifier` is `com.example.app.TaskWidget`, which would
namespace the cache key differently and read nothing.
