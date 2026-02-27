## 0.2.1

- Documentation updates to reflect v0.2.0 features
- No code changes

## 0.2.0

- **BREAKING**: Raise iOS minimum to 17.0
- Add `IntentResult & ProvidesDialog` support via `resultDialogTemplate`
- Add `ParameterSummary` generation via `parameterSummary`
- Add `AppEnum` code generation (`@EnumSpec`, `EnumAnalyzer`, `_generateEnumBody`)
- Add entity image support in `DisplayRepresentation` (SF Symbol icons)
- Add `{applicationName}` to `\(.applicationName)` phrase conversion for AppShortcuts
- Fix AppShortcutsProvider to use Swift result builder pattern (no array literals)
- Fix error handling: `throw AppIntentError.custom(...)` instead of silent `return .result()`
- Fix double-quote escaping in dialog templates
- Fix shortcut `intentIdentifier` to `className` resolution in CLI
- 116 tests covering all analyzers, generators, and builder

## 0.1.0

- Initial release
- `IntentAnalyzer` and `EntityAnalyzer` for annotation parsing
- `ShortcutAnalyzer` for `@AppShortcut` and `@AppShortcutsProvider` support
- `SwiftGenerator` for iOS 17+ App Intent Swift code generation
- `DartGenerator` for handler initialization code generation
- CLI tool `generate_swift` for Swift code output
- Integration with `build_runner` via `AppIntentsBuilder`
