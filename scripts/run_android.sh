#!/bin/bash
# Flutter Intents - Android Build & Run Script
# Usage: ./scripts/run_android.sh [--device DEVICE_ID] [--release] [--no-run]

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
            echo "  -d, --device DEVICE_ID   Specify emulator/device ID"
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

echo -e "${BLUE}=== Flutter Intents Android Build ===${NC}"
echo ""

cd "$APP_DIR"

# Step 1: Flutter pub get
echo -e "${YELLOW}[1/4] Getting Flutter dependencies...${NC}"
flutter pub get

# Step 2: Run build_runner for Dart code generation
echo -e "${YELLOW}[2/4] Running build_runner...${NC}"
dart run build_runner build --delete-conflicting-outputs

# Step 3: Generate Kotlin code
echo -e "${YELLOW}[3/4] Generating Kotlin code...${NC}"
dart run app_intents_codegen:generate_kotlin \
    -i lib \
    -o android/app/src/main/kotlin/com/example/app/generated \
    -p com.example.app.generated

# Step 4: Build/Run
if [ "$RUN_APP" = true ]; then
    echo -e "${YELLOW}[4/4] Building and running on Android...${NC}"

    # Build device args
    DEVICE_ARGS=""
    if [ -n "$DEVICE_ID" ]; then
        DEVICE_ARGS="-d $DEVICE_ID"
    fi

    if [ "$BUILD_MODE" = "release" ]; then
        flutter run $DEVICE_ARGS --release
    else
        flutter run $DEVICE_ARGS
    fi
else
    echo -e "${YELLOW}[4/4] Building Android APK...${NC}"
    if [ "$BUILD_MODE" = "release" ]; then
        flutter build apk --release
    else
        flutter build apk --debug
    fi
    echo -e "${GREEN}Build complete!${NC}"
fi
