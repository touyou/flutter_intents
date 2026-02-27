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
