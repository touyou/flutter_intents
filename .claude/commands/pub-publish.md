---
description: Release all Flutter Intents packages to pub.dev with version bump, commit, tag, and publish
---

# Publish Packages to pub.dev

Release all Flutter Intents packages as version `$ARGUMENTS` (e.g., `0.3.0`).

If no version is provided, ask the user for the target version.

## Full Release Flow

Execute the following steps in order. Stop and report if any step fails.

### 1. Run All Tests

```bash
cd packages/app_intents_codegen && dart test
cd packages/app_intents_annotations && dart test
cd packages/app_intents && flutter test
```

All tests must pass before proceeding.

### 2. Version Bump

Update the version in ALL of these files (replace the old version with `$ARGUMENTS`):

- `packages/app_intents_annotations/pubspec.yaml` → `version: $ARGUMENTS`
- `packages/app_intents/pubspec.yaml` → `version: $ARGUMENTS`
- `packages/app_intents/ios/app_intents.podspec` → `s.version = '$ARGUMENTS'`
- `packages/app_intents_codegen/pubspec.yaml` → `version: $ARGUMENTS`
- `packages/app_intents_codegen/pubspec.yaml` → `app_intents_annotations: ^$ARGUMENTS`

### 3. Update Version References in README/Docs

Update `^OLD_VERSION` → `^$ARGUMENTS` in ALL these files:

- `README.md`
- `README.ja.md`
- `docs/usage.md`
- `docs/usage.ja.md`
- `docs/packages.md`
- `docs/packages.ja.md`
- `packages/app_intents/README.md`
- `packages/app_intents_annotations/README.md`
- `packages/app_intents_codegen/README.md`

### 4. Update CHANGELOGs

Add a `## $ARGUMENTS` section at the top of each CHANGELOG.md with the new features/fixes:

- `packages/app_intents_annotations/CHANGELOG.md`
- `packages/app_intents/CHANGELOG.md`
- `packages/app_intents_codegen/CHANGELOG.md`

Summarize changes from `git log` since the last tag. Use bullet points.

### 5. Dry-Run Validation

```bash
cd packages/app_intents_annotations && dart pub publish --dry-run
cd packages/app_intents && flutter pub publish --dry-run
cd packages/app_intents_codegen && dart pub publish --dry-run
```

All must show `Package has 0 warnings.` (hints are OK).

### 6. Commit and Tag

```bash
git add <all changed files>
git commit -m "chore: Release v$ARGUMENTS"
git tag v$ARGUMENTS
git push origin main --tags
```

### 7. Publish to pub.dev

Publish in dependency order. Each must succeed before the next:

```bash
# 1. annotations (no dependencies)
cd packages/app_intents_annotations && dart pub publish --force

# 2. plugin (no internal dependencies)
cd packages/app_intents && flutter pub publish --force

# 3. codegen (depends on annotations)
cd packages/app_intents_codegen && dart pub publish --force
```

### 8. Create the GitHub Release

`RELEASING.md` requires this — it is **not** optional, and it is the step most
easily forgotten because pub.dev already looks done at this point. The v0.13.0
release was missed this way.

Write the notes by combining the new `## $ARGUMENTS` sections from all three
CHANGELOGs into one document organised by theme (not by package), matching the
prose style of the previous releases — read `gh release view <previous tag>`
first. Lead with anything that requires action from existing users.

```bash
gh release create v$ARGUMENTS --verify-tag \
  --title "v$ARGUMENTS" \
  --notes-file <path to the drafted notes>
```

End the notes with a compare link:
`**Full Changelog**: https://github.com/touyou/flutter_intents/compare/v<PREVIOUS>...v$ARGUMENTS`

Before creating, verify every link resolves — `ls docs/adr/` rather than
guessing ADR filenames, which do not match their titles.

If you are backfilling an **older** release, pass `--latest=false`, or GitHub
moves the "Latest" badge off the current version.

### 9. Report

Print a summary:
- Version released
- Packages published (with pub.dev URLs)
- Git tag created
- GitHub Release URL

## Publish Order (dependency chain)

1. **app_intents_annotations** — no internal deps
2. **app_intents** — no internal deps
3. **app_intents_codegen** — depends on `app_intents_annotations`

## Troubleshooting

- **"path dependencies not allowed"**: Ensure `app_intents_codegen/pubspec.yaml` uses `app_intents_annotations: ^X.Y.Z`, not a path dependency
- **Package not found after publish**: Wait up to 10 minutes for pub.dev indexing
- **Authentication error**: Run `dart pub login` first
- **podspec version mismatch**: Always update `app_intents.podspec` alongside `pubspec.yaml`
