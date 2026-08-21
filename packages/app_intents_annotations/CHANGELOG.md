## 0.15.0

- No user-facing changes; released in lockstep with `app_intents` 0.15.0.

## 0.14.0

- No user-facing changes; released in lockstep with `app_intents` 0.14.0 (#102).

## 0.13.0

- `@WidgetConfigurationSpec` / `@WidgetParameter` + `WidgetConfigurationSpecBase` — declare a WidgetKit `WidgetConfigurationIntent` in Dart so a widget's configuration UI can offer entity pickers (#98). The widget itself is native SwiftUI; these annotations only describe the configuration surface that `app_intents_codegen` lowers to Swift.

## 0.12.0

- `@IntentSpec(donatable: true)` — opt-in for `AppIntent.donate()` so Siri / Apple Intelligence learns the user performed the action in-app (#55). Inert unless the `donation` experimental feature is enabled in `app_intents_codegen`. MVP restricts to primitive parameter types (`String` / `int` / `double` / `bool` / `DateTime`, optionals allowed); entity / file / enum / union / collection params are rejected at codegen time.
- `@IntentParam(useValueState: true)` — opt-in for `IntentParameter.ValueState` (`@available(iOS 18.2, *)` **stable** — no `#if` gating required). Distinguishes `unset` / `set` / `cleared` for an optional update parameter so the Dart handler can tell "don't touch" from "explicitly cleared." Only valid on a nullable Dart type; analyzer rejects use on non-optional params.
- `AppSchemas.system.searchInApp` — typed accessor for the iOS 27 system search-in-app schema (iOS 17 used `.system.search`; iOS 27 renamed it). The iOS-17 identifier remains reachable via `AppSchemas.of(AppSchemaDomain.system, 'search')`. Also adds `AppSchemas.system.open`.

## 0.11.0

- WWDC26 App Intents annotation surfaces (opt-in; inert unless experimental code generation is enabled in `app_intents_codegen`):
  - Intent execution control (#52): `@IntentSpec(longRunning:, cancellable:, executionTargets:)` + the `IntentExecutionTarget` enum.
  - App Schema (#49): `schema:` on `@EntitySpec` / `@IntentSpec` / `@EnumSpec`, plus the `AppSchemas` catalog (`messages` / `mail` / `photos`).
  - Semantic indexing (#50): `@EntityProperty(title:, indexingKey:)`.
  - Entity ownership (#55): `@EntitySpec(ownership:)` + `EntityOwnershipState`.
  - Rich parameter types (#53): `Duration` parameters, the new `PersonName` value type, `@IntentParam(entityCollectionType:)`, and `@UnionValueSpec` / `@UnionCase` (which codegen lowers to a native `@UnionValue` enum).
  - Cross-app export (#54): `@EntitySpec(exportAs:)` + `EntityExportType`.
  - IntentValueQuery (#51) and donations/discovery (#55): `@EntitySpec(valueQuery:, syncable:, relevantEntities:)`.
- Docs: documentation consistency fixes across the repository guides.

## 0.10.1

- No annotation changes; version bump aligns with `app_intents` 0.10.1 (Android `compilerOptions` DSL fix for Kotlin 2.3+ / AGP 9.1.0+, #20)

## 0.10.0

- No annotation changes; version bump aligns with `app_intents` 0.10.0 (Swift Package Manager support for the iOS plugin, #29)

## 0.9.0

- Add `@EntitySpec.persistedCacheKey` for EntityQuery cold-start fallback (#26)

## 0.8.0

- No API changes; version bump to align with the AppFunctions alpha09 upgrade in `app_intents_codegen` (#23)

## 0.7.8

- No API changes; version bump to align with plugin fix release (Android cache no-op handlers)

## 0.7.7

- No API changes; version bump to align with plugin fix release

## 0.7.6

- No API changes; version bump to align with plugin bug fix release (App Group storage fix)

## 0.7.5

- No API changes; version bump to align with codegen bug fix release

## 0.7.4

- No API changes; version bump to align with codegen bug fix release

## 0.7.3

- No API changes; version bump to align with codegen bug fix release

## 0.7.2

- No API changes; version bump to align with codegen bug fix release

## 0.7.1

- No API changes; version bump to align with codegen bug fix release

## 0.7.0

- No API changes; version bump to align with codegen package (xcstrings generation feature)

## 0.6.2

- No API changes; version bump to align with codegen/plugin packages

## 0.6.1

- Documentation fixes: correct outdated code examples and API references

## 0.6.0

- **BREAKING**: Remove generic type parameters from `IntentSpecBase`
  - Before: `class MyIntent extends IntentSpecBase<Input, Output>`
  - After: `class MyIntent extends IntentSpecBase`
  - Input/Output types were unused by the framework and can be removed safely

## 0.5.2

- No API changes; version bump to align with other packages

## 0.5.1

- No API changes; version bump to align with codegen package

## 0.5.0

- Add `imageName` field to `@EnumCaseDisplay` for AppEnum case icon support
- Add `displayImageName` field to `@EntitySpec` for entity type-level display image
- Add `indexed` field to `@EntitySpec` for `IndexedEntity` Spotlight integration (iOS 26+)
- Add `enumerable` field to `@EntitySpec` for `EnumerableEntityQuery` support

## 0.4.0

- Add `IntentMode` enum for intent execution mode control (`foreground`/`background`)
- Add `supportedModes` field to `@IntentSpec` for iOS 26+ `IntentModes` support
- Add `IntentFile` model class for file/image parameter handling
- Add `fileType` field to `@IntentParam` for UTType-based file parameters

## 0.3.0

- Add Android AppFunctions support (annotations shared across iOS and Android)
- Update documentation for cross-platform (iOS App Intents + Android AppFunctions)

## 0.2.1

- Documentation updates to reflect v0.2.0 features
- No API changes

## 0.2.0

- **BREAKING**: Raise iOS minimum to 17.0
- Add `resultDialogTemplate` to `@IntentSpec` for Siri/Shortcuts dialog feedback
- Add `parameterSummary` to `@IntentSpec` for Shortcuts UI parameter display
- Add `enumType` to `@IntentParam` for AppEnum parameter support
- Add `@EnumSpec` and `@EnumCaseDisplay` annotations for AppEnum definitions
- Update `@AppShortcut` phrase docs: all phrases require `{applicationName}`

## 0.1.0

- Initial release
- `@IntentSpec` and `@IntentParam` annotations for intent definitions
- `@EntitySpec`, `@EntityId`, `@EntityTitle`, `@EntitySubtitle`, `@EntityImage` annotations for entity definitions
- `@AppShortcut` and `@AppShortcutsProvider` annotations for Spotlight shortcuts
- `IntentSpecBase` and `EntitySpecBase` base classes
