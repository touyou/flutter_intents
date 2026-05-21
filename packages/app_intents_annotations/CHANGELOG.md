## Unreleased

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
