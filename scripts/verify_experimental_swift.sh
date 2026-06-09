#!/usr/bin/env bash
# Verifies that the WWDC26 experimental Swift output actually compiles against
# the beta iOS SDK — the load-bearing check that golden/unit tests cannot do
# (they only assert the emitted strings).
#
# It type-checks the generated Swift TWICE: once with `-D APP_INTENTS_WWDC26`
# (the WWDC26 form) and once without (the stable `#else` fallback). Both must
# pass: a project that enables experimental codegen but hasn't set the build
# flag must still get compiling stable Swift.
#
# Requires a beta Xcode with the iOS 27 SDK selected (xcode-select).
#
# Usage: scripts/verify_experimental_swift.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CODEGEN="$REPO_ROOT/packages/app_intents_codegen"
BRIDGE="$REPO_ROOT/ios-spm/AppIntentsBridge/Sources/AppIntentsBridge"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
GEN="$WORK/GeneratedExperimental.swift"
MOD="$WORK/mod"
mkdir -p "$MOD"

# Pick an iOS Simulator SDK + matching target (no codesigning needed).
SDK="$(xcodebuild -showsdks 2>/dev/null | sed -n 's/.*-sdk \(iphonesimulator[0-9.]*\).*/\1/p' | tail -1)"
SDK_VER="${SDK#iphonesimulator}"
TARGET="arm64-apple-ios${SDK_VER}-simulator"

echo "==> Xcode: $(xcodebuild -version | head -1) (SDK: $SDK, target: $TARGET)"

echo "==> Emitting experimental Swift"
( cd "$CODEGEN" && dart run tool/emit_experimental_swift.dart "$GEN" >/dev/null )

echo "==> Building AppIntentsBridge module"
xcrun --sdk "$SDK" swiftc -target "$TARGET" -emit-module -module-name AppIntentsBridge \
  -emit-module-path "$MOD/AppIntentsBridge.swiftmodule" \
  "$BRIDGE/FlutterBridge.swift" "$BRIDGE/ErrorHandling.swift" \
  "$BRIDGE/EntityImage.swift" "$BRIDGE/AppIntentsBridge.swift"

typecheck() {
  local label="$1"; shift
  echo "==> typecheck: $label"
  if xcrun --sdk "$SDK" swiftc -typecheck -target "$TARGET" -I "$MOD" "$@" "$GEN"; then
    echo "    OK"
  else
    echo "    FAILED ($label)" >&2
    exit 1
  fi
}

typecheck "stable fallback (no -D APP_INTENTS_WWDC26)"
typecheck "WWDC26 form (-D APP_INTENTS_WWDC26)" -D APP_INTENTS_WWDC26

echo "==> All experimental Swift type-checks passed (both branches)."
