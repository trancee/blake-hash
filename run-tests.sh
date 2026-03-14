#!/usr/bin/env bash
#
# Runs the shared test-vector parity tests on both platforms.
# Execute from the repository root:  ./run-tests.sh
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }

bold "═══════════════════════════════════════════════════════"
bold " Android (Kotlin/JVM)"
bold "═══════════════════════════════════════════════════════"
cd "$REPO_ROOT/android"
gradle :lib:test --quiet

bold ""
bold "═══════════════════════════════════════════════════════"
bold " iOS (Swift)"
bold "═══════════════════════════════════════════════════════"
cd "$REPO_ROOT/ios"
swift test --quiet

bold ""
bold "✅  All tests passed on both platforms."
