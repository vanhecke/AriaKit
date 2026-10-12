#!/usr/bin/env bash
# Compiler issues from `swift build` (no Xcode MCP).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
./Scripts/libaria2.sh
source Scripts/env.sh
mkdir -p build
LOG=build/issues.log
set +e
swift build --build-tests -Xswiftc -warnings-as-errors >"$LOG" 2>&1
STATUS=$?
set -e
cat "$LOG"
swift Scripts/print-issues.swift --swift-log "$LOG"
if [[ $STATUS -ne 0 ]]; then
  exit "$STATUS"
fi
