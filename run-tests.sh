#!/usr/bin/env bash
#
# Run tests and/or benchmarks on both platforms.
#
# Usage:
#   ./run-tests.sh              # tests only (default)
#   ./run-tests.sh --bench      # benchmarks only
#   ./run-tests.sh --all        # tests + benchmarks
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }

MODE="${1:-}"
RUN_TESTS=true
RUN_BENCH=false

case "$MODE" in
    --bench) RUN_TESTS=false; RUN_BENCH=true ;;
    --all)   RUN_TESTS=true;  RUN_BENCH=true ;;
    "")      RUN_TESTS=true;  RUN_BENCH=false ;;
    *)       echo "Usage: $0 [--bench|--all]"; exit 1 ;;
esac

if $RUN_TESTS; then
    bold "═══════════════════════════════════════════════════════"
    bold " Tests — Android (Kotlin/JVM)"
    bold "═══════════════════════════════════════════════════════"
    cd "$REPO_ROOT/android"
    gradle :lib:test

    bold ""
    bold "═══════════════════════════════════════════════════════"
    bold " Tests — iOS (Swift)"
    bold "═══════════════════════════════════════════════════════"
    cd "$REPO_ROOT/ios"
    swift test --skip Bench --quiet

    bold ""
    bold "✅  All tests passed on both platforms."
fi

if $RUN_BENCH; then
    bold ""
    bold "═══════════════════════════════════════════════════════"
    bold " Benchmarks — iOS (Swift)"
    bold "═══════════════════════════════════════════════════════"
    cd "$REPO_ROOT/ios"
    swift test --filter Bench --quiet

    bold ""
    bold "✅  Benchmarks complete."
fi
