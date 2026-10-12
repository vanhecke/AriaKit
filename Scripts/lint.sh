#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
swiftlint --strict
swiftformat Sources Tests Package.swift Scripts --lint
