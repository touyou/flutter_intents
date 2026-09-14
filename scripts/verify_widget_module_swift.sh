#!/usr/bin/env bash
# Verifies that `generate_widget_swift --public` output actually works as a
# SHARED MODULE — the setup ADR 0009 documents for donating relevant intents.
#
# A plain `swiftc -typecheck` of the file cannot show this: Swift's default
# `internal` compiles perfectly well on its own and only hides the types when
# another target imports them. So this builds the generated file as a module and
# then compiles a separate consumer that imports it and uses the declarations an
# app target would actually touch.
#
# Usage: scripts/verify_widget_module_swift.sh
#        DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
#          scripts/verify_widget_module_swift.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$REPO_ROOT/app"
BRIDGE="$REPO_ROOT/packages/app_intents/ios/app_intents/Sources/AppIntentsBridge"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
MOD="$WORK/mod"
mkdir -p "$MOD" "$WORK/gen"

SDK="$(xcodebuild -showsdks 2>/dev/null | sed -n 's/.*-sdk \(iphonesimulator[0-9.]*\).*/\1/p' | tail -1)"
DEPLOYMENT_TARGET="17.0"
TARGET="arm64-apple-ios${DEPLOYMENT_TARGET}-simulator"

echo "==> Xcode: $(xcodebuild -version | head -1) (SDK: $SDK, deployment target: iOS $DEPLOYMENT_TARGET)"

echo "==> Generating widget Swift with --public"
( cd "$APP" && dart run app_intents_codegen:generate_widget_swift \
    -o "$WORK/gen" \
    --app-group group.com.example.app \
    --storage-identifier com.example.app \
    --public \
    --app-intents-package SharedIntentsPackage >/dev/null )

echo "==> Building AppIntentsBridge module"
xcrun --sdk "$SDK" swiftc -target "$TARGET" -emit-module -module-name AppIntentsBridge \
  -emit-module-path "$MOD/AppIntentsBridge.swiftmodule" "$BRIDGE"/*.swift

echo "==> Building the generated file as module 'SharedIntents'"
xcrun --sdk "$SDK" swiftc -target "$TARGET" -emit-module -module-name SharedIntents \
  -emit-module-path "$MOD/SharedIntents.swiftmodule" -I "$MOD" \
  "$WORK/gen"/*.swift

# What an app target and a widget target actually reach for.
cat > "$WORK/consumer.swift" <<'SWIFT'
import AppIntents
import SharedIntents

@available(iOS 17.0, *)
func consume() {
    // The app target registers the donator...
    registerRelevantIntentDonator()

    // ...and the widget target builds its configuration and reads a parameter.
    let configuration = SelectTaskWidgetConfig()
    _ = SelectTaskWidgetConfig.title
    _ = configuration.task?.id
    _ = configuration.task?.title

    // Consuming targets list the package in their own includedPackages.
    let packages: [any AppIntentsPackage.Type] = [SharedIntentsPackage.self]
    _ = packages
}
SWIFT

echo "==> Compiling a consumer that imports it"
if xcrun --sdk "$SDK" swiftc -typecheck -target "$TARGET" -I "$MOD" "$WORK/consumer.swift"; then
  echo "    OK"
else
  echo "    FAILED: the generated declarations are not reachable from an" >&2
  echo "    importing target. --public is not covering everything a consumer" >&2
  echo "    needs." >&2
  exit 1
fi

echo "==> Shared-module output verified."
