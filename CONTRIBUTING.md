# Contributing to Flutter Intents

Thank you for your interest in contributing to Flutter Intents! This document provides guidelines and instructions for contributing.

By participating in this project you agree to abide by the project's
[Code of Conduct](CODE_OF_CONDUCT.md). For security issues, please follow
the private reporting process in [SECURITY.md](SECURITY.md) instead of
filing a public issue.

## Development Setup

### Prerequisites

- Flutter SDK 3.3+
- Dart SDK 3.10+
- Xcode 15+ (for iOS development)
- iOS 17+ device or simulator
- Android Studio (for Android development)
- Android API 36+ emulator or device (for AppFunctions)

### Getting Started

1. Fork and clone the repository:
   ```bash
   git clone https://github.com/YOUR_USERNAME/flutter_intents.git
   cd flutter_intents
   ```

2. Install dependencies:
   ```bash
   # Install Flutter dependencies for all packages
   cd packages/app_intents && flutter pub get && cd ../..
   cd packages/app_intents_annotations && dart pub get && cd ../..
   cd packages/app_intents_codegen && dart pub get && cd ../..
   ```

3. Run tests:
   ```bash
   make test
   ```

## Project Structure

```
flutter_intents/
├── packages/
│   ├── app_intents/              # Flutter plugin
│   │   └── ios/app_intents/      # Swift Package: plugin + AppIntentsBridge
│   ├── app_intents_annotations/  # Dart annotations
│   └── app_intents_codegen/      # Code generator
├── app/                          # Example app
└── docs/                         # Documentation
```

## Making Changes

### Coding Standards

- **Dart**: Follow the [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- **Swift**: Follow the [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- **Comments**: Write documentation comments in English
- **Tests**: Add tests for new functionality

### Commit Messages

Use conventional commit format:
- `feat:` - New features
- `fix:` - Bug fixes
- `docs:` - Documentation changes
- `test:` - Test additions/modifications
- `refactor:` - Code refactoring
- `chore:` - Maintenance tasks

Example:
```
feat: Add support for custom entity images
```

### Renaming or removing public API

When a release renames, moves or removes a public Dart API (a class, an
annotation field, a method or a named parameter), ship a
[data-driven fix](https://dart.dev/tools/pub/data-driven-fixes) with it so users
can migrate with `dart fix --apply`. If the change is not expressible (see the
change kinds in step 1), write a manual migration note in `CHANGELOG.md`
instead. Prefer deprecating first (keep the old name
with `@Deprecated(...)` for one minor release) so nothing breaks during the
transition; the fix works the same way once the old API is removed.

1. Add a transform to `lib/fix_data.yaml` of the package that owns the API
   (create the file if it does not exist yet):
   ```yaml
   version: 1
   transforms:
     - title: 'Rename to NewName'
       date: 2026-10-26
       element:
         uris: ['package:app_intents_annotations/app_intents_annotations.dart']
         class: 'OldName'
       changes:
         - kind: 'rename'
           newName: 'NewName'
   ```
   Supported change kinds are `rename`, `renameParameter`, `addParameter`,
   `removeParameter`, `addTypeParameter`, `changeParameterType` and
   `replacedBy`. Removing type arguments is **not** expressible, so that kind of
   change still needs a manual migration note in `CHANGELOG.md`.
2. Add a test under `test_fixes/` in the same package: a `.dart` file using the
   old API and a `.dart.expect` file with the expected result. Keep the `.dart`
   files `dart format`ted — CI's format check covers the whole package directory.
3. The first time a package gets `test_fixes/`, also:
   - exclude it from the package analysis (the files intentionally use removed
     API) in the package `analysis_options.yaml`:
     ```yaml
     analyzer:
       exclude:
         - test_fixes/**
     ```
   - add `test_fixes/analysis_options.yaml` that enables the same-package
     deprecation lint:
     ```yaml
     linter:
       rules:
         - deprecated_member_use_from_same_package
     ```
     Without this file the exclude above also applies to `dart fix`, which then
     computes no fixes and every test fails with "original code was unchanged".
     The lint is what makes a still-`@Deprecated` API fixable inside its own
     package (users' packages get `deprecated_member_use` without it).
4. Verify locally:
   ```bash
   cd packages/<package>
   dart fix --compare-to-golden test_fixes
   ```
   CI runs the same command for every package that has a `test_fixes/` directory.

### Pull Request Process

1. Create a feature branch from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. Make your changes and commit them.

3. Ensure all tests pass:
   ```bash
   make test
   dart analyze packages/app_intents_codegen/lib
   dart analyze packages/app_intents_annotations/lib
   cd packages/app_intents && flutter analyze
   ```

4. Push to your fork and open a Pull Request. GitHub will pre-populate
   the body from [`.github/pull_request_template.md`](.github/pull_request_template.md) —
   please fill in every section so reviewers have full context.

### PR Review

- All PRs require at least one approval.
- CI checks must pass (see [`.github/workflows/ci.yml`](.github/workflows/ci.yml)).
- Documentation must be updated if applicable, including both `README.md`
  **and** `README.ja.md` for any user-visible change.
- Public API changes must be reflected in the relevant `CHANGELOG.md`.

## Reporting issues

- **Bug?** Open a [bug report](https://github.com/touyou/flutter_intents/issues/new?template=bug_report.yml) — the template asks for the platform / version / environment fields we need to triage.
- **Feature idea?** Open a [feature request](https://github.com/touyou/flutter_intents/issues/new?template=feature_request.yml).
- **Security vulnerability?** See [SECURITY.md](SECURITY.md) — do **not** open a public issue.

## Releasing

Release coordination is documented in [RELEASING.md](RELEASING.md). External
contributors should **not** bump package versions in their PRs — the maintainer
handles version bumps and `CHANGELOG.md` updates at release time.

See [MAINTAINERS.md](MAINTAINERS.md) for the current maintainer list.

## Running Tests

```bash
# Run all tests
make test

# Run specific package tests
dart test packages/app_intents_codegen
dart test packages/app_intents_annotations
cd packages/app_intents && flutter test
cd app && flutter test

# Run Swift package tests
# The bridge sources live in the plugin's iOS-only Swift package, so `swift test`
# cannot build them on a Mac host. Run them on a simulator via the root manifest:
xcodebuild test -scheme AppIntentsBridge \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=latest"

# Run iOS example app
make ios
```

## Code Generation

After modifying annotations or generators:

```bash
# Regenerate Dart code
cd app && dart run build_runner build --delete-conflicting-outputs

# Regenerate Swift code
cd app && dart run app_intents_codegen:generate_swift -i lib -o ios/Runner/GeneratedIntents

# Regenerate Kotlin code
make kotlin-gen
```

## Documentation

- API documentation: Use `///` doc comments
- README files: Keep package READMEs up to date
- CLAUDE.md: Update for significant architectural changes

## Questions?

- Bug reports and feature requests: see [Reporting issues](#reporting-issues) above.
- Behavioral concerns: see [Code of Conduct](CODE_OF_CONDUCT.md) for the private reporting flow.

Thank you for contributing!
