#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
export CLANG_MODULE_CACHE_PATH="$PROJECT_DIR/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PROJECT_DIR/.build/ModuleCache"
# Command Line Tools ships no XCTest runtime. Run the same test cases using a
# tiny standalone assertion harness; Xcode users can also run `swift test`.
mkdir -p .build
swiftc -swift-version 5 -D STANDALONE_TESTS \
    Sources/LauncherCore/LauncherPreferences.swift \
    Tests/LauncherCoreTests/LauncherPreferencesTests.swift \
    scripts/TestRunner.swift -o .build/CoreTests
.build/CoreTests

# Compile the actual model against an isolated core module for interaction checks.
TEST_BUILD_DIR="$PROJECT_DIR/.build/InteractionTests"
mkdir -p "$TEST_BUILD_DIR"
swiftc -swift-version 5 -parse-as-library -emit-module -emit-object -module-name LauncherCore \
    Sources/LauncherCore/LauncherPreferences.swift \
    -emit-module-path "$TEST_BUILD_DIR/LauncherCore.swiftmodule" -o "$TEST_BUILD_DIR/LauncherCore.o"
swiftc -swift-version 5 -parse-as-library -I "$TEST_BUILD_DIR" \
    "$TEST_BUILD_DIR/LauncherCore.o" Sources/BiangLauncher/AppCatalog.swift \
    Sources/BiangLauncher/LauncherModel.swift scripts/DragTestRunner.swift -o "$TEST_BUILD_DIR/DragTests"
"$TEST_BUILD_DIR/DragTests"
