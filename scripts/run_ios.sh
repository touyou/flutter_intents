#!/bin/bash
# Flutter Intents - iOS Build & Run Script
# Usage: ./scripts/run_ios.sh [--device DEVICE_ID] [--release] [--no-run]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DEVICE_ID=""
BUILD_MODE="debug"
RUN_APP=true
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$PROJECT_ROOT/app"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--device)
            DEVICE_ID="$2"
            shift 2
            ;;
        --release)
            BUILD_MODE="release"
            shift
            ;;
        --no-run)
            RUN_APP=false
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  -d, --device DEVICE_ID   Specify simulator/device ID"
            echo "  --release                Build in release mode"
            echo "  --no-run                 Build only, don't run"
            echo "  -h, --help               Show this help"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}=== Flutter Intents iOS Build ===${NC}"
echo ""

cd "$APP_DIR"

# Step 1: Flutter pub get
echo -e "${YELLOW}[1/5] Getting Flutter dependencies...${NC}"
flutter pub get

# Step 2: Run build_runner for Dart code generation
echo -e "${YELLOW}[2/5] Running build_runner...${NC}"
dart run build_runner build --delete-conflicting-outputs

# Step 3: Generate Swift code
echo -e "${YELLOW}[3/5] Generating Swift code...${NC}"
dart run app_intents_codegen:generate_swift

# Step 4: Pod install (if needed)
echo -e "${YELLOW}[4/5] Installing CocoaPods dependencies...${NC}"
cd ios && pod install --silent && cd ..

# Step 5: Build/Run
if [ "$RUN_APP" = true ]; then
    echo -e "${YELLOW}[5/5] Building and running on iOS...${NC}"

    # Find device if not specified
    if [ -z "$DEVICE_ID" ]; then
        # Try to find a booted simulator
        DEVICE_ID=$(xcrun simctl list devices booted | grep -E "iPhone|iPad" | head -1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/')

        if [ -z "$DEVICE_ID" ]; then
            # Boot first available iPhone simulator
            DEVICE_ID=$(xcrun simctl list devices available | grep "iPhone" | head -1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/')
            if [ -n "$DEVICE_ID" ]; then
                echo -e "${BLUE}Booting simulator: $DEVICE_ID${NC}"
                xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
                open -a Simulator
                sleep 3
            fi
        fi
    fi

    if [ -z "$DEVICE_ID" ]; then
        echo -e "${RED}No iOS simulator found. Please start one manually.${NC}"
        exit 1
    fi

    echo -e "${GREEN}Running on device: $DEVICE_ID${NC}"

    if [ "$BUILD_MODE" = "release" ]; then
        flutter run -d "$DEVICE_ID" --release
    else
        flutter run -d "$DEVICE_ID"
    fi
else
    echo -e "${YELLOW}[5/5] Building iOS app...${NC}"
    if [ "$BUILD_MODE" = "release" ]; then
        flutter build ios --no-codesign
    else
        flutter build ios --simulator --no-codesign
    fi
    echo -e "${GREEN}Build complete!${NC}"
fi
