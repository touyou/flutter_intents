<!--
  Thanks for contributing to Flutter Intents!
  Please fill in the sections below so reviewers have the context they need.
  See CONTRIBUTING.md for project conventions.
-->

## Summary

<!-- One or two sentences describing what this PR does and why. -->

## Related issues

<!-- e.g. "Closes #123" / "Refs #456". Leave blank if none. -->

## Type of change

- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature that changes existing API or behavior)
- [ ] Documentation only
- [ ] Build / CI / tooling
- [ ] Other (please describe):

## Affected packages

- [ ] `app_intents` (Flutter plugin)
- [ ] `app_intents_annotations`
- [ ] `app_intents_codegen`
- [ ] iOS native (`ios-spm/AppIntentsBridge` or `packages/app_intents/ios`)
- [ ] Android native (`packages/app_intents/android`)
- [ ] Example app (`app/`)
- [ ] Docs / repo meta

## Test plan

<!--
  Describe how the change was verified. Examples:
  - `make test`
  - `dart test packages/app_intents_codegen`
  - Manually invoked CreateTask Intent from Siri on iOS 17.5 simulator
  - Triggered AppFunction from Gemini on Pixel 8 emulator (API 36)
-->

- [ ]

## Checklist

- [ ] Tests added or updated where applicable
- [ ] `make test` passes locally
- [ ] `dart analyze` / `flutter analyze` is clean for touched packages
- [ ] Public API changes are reflected in the relevant `CHANGELOG.md`
- [ ] User-visible doc changes are mirrored in **both** `README.md` **and** `README.ja.md` (and the matching `docs/*.md` / `docs/*.ja.md` pairs)
- [ ] `CLAUDE.md` updated if architecture or non-obvious conventions changed
- [ ] Generated code (Swift / Kotlin / Dart `part` files) regenerated if generators changed
- [ ] Version bumps and `CHANGELOG.md` updates are left to the maintainer at release time — please do **not** bump versions in feature PRs unless explicitly asked
