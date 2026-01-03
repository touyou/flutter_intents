# Contributing to Flutter Intents

Thank you for your interest in contributing to Flutter Intents! This document provides guidelines and instructions for contributing.

## Development Setup

### Prerequisites

- Flutter SDK 3.38+
- Dart SDK 3.10+
- Xcode 15+ (for iOS development)
- iOS 16+ device or simulator

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
│   ├── app_intents_annotations/  # Dart annotations
│   └── app_intents_codegen/      # Code generator
├── ios-spm/                      # Swift Package
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

### Pull Request Process

1. Create a feature branch from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. Make your changes and commit them

3. Ensure all tests pass:
   ```bash
   make test
   dart analyze
   ```

4. Push to your fork and open a Pull Request

5. Fill out the PR template with:
   - Summary of changes
   - Related issues
   - Test plan

### PR Review

- All PRs require at least one approval
- CI checks must pass
- Documentation must be updated if applicable

## Running Tests

```bash
# Run all tests
make test

# Run specific package tests
dart test packages/app_intents_codegen
cd packages/app_intents && flutter test

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
```

## Documentation

- API documentation: Use `///` doc comments
- README files: Keep package READMEs up to date
- CLAUDE.md: Update for significant architectural changes

## Questions?

- Open an issue for bugs or feature requests
- Start a discussion for questions

Thank you for contributing!
