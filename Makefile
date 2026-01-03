# Flutter Intents - Development Commands
# Usage: make <target>

.PHONY: help ios ios-build codegen swift-gen test clean

# Default target
help:
	@echo "Flutter Intents - Available Commands"
	@echo ""
	@echo "  make ios          Build and run Example App on iOS simulator"
	@echo "  make ios-build    Build iOS app only (no run)"
	@echo "  make codegen      Run Dart code generation (build_runner)"
	@echo "  make swift-gen    Generate Swift code from annotations"
	@echo "  make test         Run all tests"
	@echo "  make clean        Clean build artifacts"
	@echo ""

# Build and run on iOS simulator
ios:
	@./scripts/run_ios.sh

# Build iOS app only
ios-build:
	@./scripts/run_ios.sh --no-run

# Run Dart code generation
codegen:
	@cd app && dart run build_runner build --delete-conflicting-outputs

# Generate Swift code
swift-gen:
	@cd app && dart run app_intents_codegen:generate_swift

# Run all tests
test:
	@echo "Running codegen tests..."
	@cd packages/app_intents_codegen && dart test
	@echo ""
	@echo "Running annotations tests..."
	@cd packages/app_intents_annotations && dart test
	@echo ""
	@echo "Running plugin tests..."
	@cd packages/app_intents && flutter test
	@echo ""
	@echo "Running app tests..."
	@cd app && flutter test

# Clean build artifacts
clean:
	@echo "Cleaning app..."
	@cd app && flutter clean
	@echo "Cleaning codegen..."
	@cd packages/app_intents_codegen && dart run build_runner clean 2>/dev/null || true
	@echo "Done!"
