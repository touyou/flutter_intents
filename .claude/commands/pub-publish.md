# Publish Packages to pub.dev

Publish Flutter Intents packages to pub.dev in the correct order.

## Prerequisites

1. Login to pub.dev: `dart pub login`
2. Ensure all tests pass: `make test`
3. Update version numbers in all `pubspec.yaml` files
4. Update `CHANGELOG.md` files

## Publish Order (respecting dependencies)

Packages must be published in this order due to dependencies:

1. **app_intents_annotations** (no dependencies)
2. **app_intents** (no internal dependencies)
3. **app_intents_codegen** (depends on app_intents_annotations)

## Steps

### 1. Pre-publish Checks

```bash
# Run dry-run for each package
cd packages/app_intents_annotations && dart pub publish --dry-run
cd packages/app_intents && flutter pub publish --dry-run
cd packages/app_intents_codegen && dart pub publish --dry-run
```

### 2. Update path dependencies (if using)

Before publishing `app_intents_codegen`, update the dependency:

```yaml
# Change from:
app_intents_annotations:
  path: ../app_intents_annotations

# To:
app_intents_annotations: ^X.Y.Z
```

### 3. Publish

```bash
# 1. Publish annotations
cd packages/app_intents_annotations
dart pub publish --force

# 2. Publish plugin
cd packages/app_intents
flutter pub publish --force

# 3. Update path dependency and publish codegen
cd packages/app_intents_codegen
# Edit pubspec.yaml to use hosted dependency
dart pub get
dart pub publish --force
```

### 4. Post-publish

```bash
# Commit dependency changes
git add -A
git commit -m "chore: Update dependencies for pub.dev release vX.Y.Z"
git push
```

## Version Bump Checklist

When bumping versions, update:

- [ ] `packages/app_intents/pubspec.yaml`
- [ ] `packages/app_intents/ios/app_intents.podspec`
- [ ] `packages/app_intents/CHANGELOG.md`
- [ ] `packages/app_intents_annotations/pubspec.yaml`
- [ ] `packages/app_intents_annotations/CHANGELOG.md`
- [ ] `packages/app_intents_codegen/pubspec.yaml`
- [ ] `packages/app_intents_codegen/CHANGELOG.md`
- [ ] `README.md` and `README.ja.md` version references
- [ ] `docs/usage.md` and `docs/usage.ja.md` version references

## Troubleshooting

### "path dependencies not allowed"
Update `app_intents_codegen/pubspec.yaml` to use hosted dependency instead of path.

### Package not found after publish
Wait up to 10 minutes for pub.dev to index the new package.

### Authentication error
Run `dart pub login` and complete browser authentication.
