# Releasing Flutter Intents

This document describes how a maintainer cuts a new release of the three
published packages (`app_intents`, `app_intents_annotations`,
`app_intents_codegen`). It is **maintainer-facing**: external contributors
should not bump versions in their PRs.

## Versioning policy

- All three packages are released together with the **same version number**
  to avoid skew across the plugin / annotations / codegen surface.
- Until `1.0.0`, semver is interpreted as **`0.MINOR.PATCH`**:
  - **MINOR** bump (e.g. `0.10.0` → `0.11.0`) for new features and any
    breaking change.
  - **PATCH** bump (e.g. `0.10.0` → `0.10.1`) for fixes only.
- Each release is tagged in the repository as `vX.Y.Z` (without a package prefix).

## Pre-flight checks

Before starting the release process:

1. `main` is green on CI.
2. All three packages have a `## [Unreleased]` section in their `CHANGELOG.md`
   summarising the changes since the previous release. Move those entries
   under the new version heading.
3. The example app under `app/` builds for both iOS and Android, and the
   integration smoke-test from `docs/usage.md` still works.

## Bumping versions

In a single commit, update:

- `packages/app_intents/pubspec.yaml` → `version:`
- `packages/app_intents_annotations/pubspec.yaml` → `version:`
- `packages/app_intents_codegen/pubspec.yaml` → `version:` **and**
  `dependencies.app_intents_annotations:` to the same version
- `packages/app_intents/CHANGELOG.md` — add new release heading
- `packages/app_intents_annotations/CHANGELOG.md` — add new release heading
- `packages/app_intents_codegen/CHANGELOG.md` — add new release heading
- `packages/app_intents/ios/app_intents.podspec` → `s.version`
- `packages/app_intents/ios/app_intents_bridge.podspec` → `s.version`
- `README.md` and `README.ja.md` — bump the `^X.Y.Z` numbers in the Quick
  Start dependency block
- `docs/usage.md`, `docs/usage.ja.md`, `docs/packages.md`,
  `docs/packages.ja.md` — bump the `^X.Y.Z` numbers in their dependency blocks

Nothing verifies the two podspec versions, so they are the easiest thing here to
forget: `app_intents.podspec` was left at `0.11.0` through the entire 0.12.0
release. Check with:

```bash
grep -rn "s.version" packages/app_intents/ios/*.podspec
grep -rn "^version:" packages/*/pubspec.yaml
```

Commit with `chore: Release vX.Y.Z`.

## Publishing to pub.dev

```bash
# Dry-run each package first to surface validation errors.
cd packages/app_intents_annotations && dart pub publish --dry-run && cd ../..
cd packages/app_intents_codegen     && dart pub publish --dry-run && cd ../..
cd packages/app_intents             && dart pub publish --dry-run && cd ../..
```

If all dry-runs pass, publish in dependency order (annotations → codegen →
plugin), since `codegen` depends on `annotations` and the plugin's example
ultimately pulls in all three:

```bash
cd packages/app_intents_annotations && dart pub publish && cd ../..
cd packages/app_intents_codegen     && dart pub publish && cd ../..
cd packages/app_intents             && dart pub publish && cd ../..
```

## Tagging

```bash
git tag vX.Y.Z
git push origin main vX.Y.Z
```

## Post-release

- Verify the three packages appear on pub.dev at the new version and that
  the package score / topics look correct.
- Create a GitHub Release from the new tag, pasting the combined changelog
  entries.
- Update any open issues that asked for the now-released change.
