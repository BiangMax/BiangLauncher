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
