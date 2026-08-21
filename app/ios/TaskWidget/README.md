# TaskWidget — WidgetConfigurationIntent example (issues #98 / #102)

A real WidgetKit **app-extension target** in `Runner.xcodeproj`. It exists to
exercise the generated `WidgetConfigurationIntent` the way a downstream app
would: in an extension process, with no Flutter engine, reading the App Group
entity cache.

| File | Generated? | What it is |
|---|---|---|
| `GeneratedIntents/GeneratedWidgetIntents.swift` | yes (`make widget-gen`) | `SelectTaskWidgetConfig` + cache-backed `AppEntity` / `EnumerableEntityQuery` |
| `TaskWidget.swift` | no | Minimal `Widget` + `AppIntentTimelineProvider` + `WidgetBundle` |
| `Info.plist`, `TaskWidget.entitlements` | no | Extension point + the `group.com.example.app` App Group |

Regenerate the first one with:

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

No Dart code is generated for a `@WidgetConfigurationSpec`: nothing runs in
Dart, so there is no handler and no `part` directive.

## How the extension gets `AppIntentsBridge`

The generated file opens with `import AppIntentsBridge`. The target links the
**`AppIntentsBridge` product of the plugin's own Swift package**, added as a
local package at:

```
ios/Flutter/ephemeral/Packages/.packages/app_intents
```

Flutter's Swift Package Manager integration creates that symlink, so the path
needs no Podfile and survives `app_intents` upgrades. It links only
`AppIntentsBridge` — **not** `app-intents`, which imports Flutter and must never
be linked into an extension. See `docs/usage.md` →
"Consuming AppIntentsBridge" for the other routes.

## Why this file set is separate from the app target

A Widget Extension **cannot start a Flutter engine**, so the `FlutterBridge`
round-trip that the app target's `GeneratedAppIntents.swift` uses is unavailable
here. The generated query instead reads the App Group cache that
`TaskRepository` already writes (`com.example.taskapp.cache.tasks`) through
`AppIntentsEntityCache` (issue #97).

Separation is also **mandatory for correctness**: including the same App Intent
type in both the app target and an extension target duplicates it in
`Metadata.appIntents`, and iOS then fails to resolve the intent at runtime. That
is why the generated entity is named `TaskEntitySpecWidgetEntity` rather than
reusing the app target's `TaskEntitySpec` — if both files ever land in one
target, you get a compile error instead of a silent runtime failure.

## Two things to know about the widget itself

- `configuration.task` is `nil` for an unconfigured instance; `TaskTimelineProvider`
  falls back rather than baking in an add-time snapshot. See `generateDefaultResult`
  in `@WidgetConfigurationSpec` for why no default is generated.
- The extension carries its **own** App Groups entitlement. It is separate from
  the app's, and without it `UserDefaults(suiteName:)` returns nil and the
  configuration picker is silently empty (`AppIntentsEntityCache.isAccessible`
  is how you tell that apart from an empty cache).

## Status

Build-verified: `flutter build ios --debug --no-codesign` produces
`Runner.app/PlugIns/TaskWidget.appex`. Not exercised on a device or simulator
home screen — placing the widget and confirming the picker populates is still
a manual step.
