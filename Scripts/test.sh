#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
./Scripts/libaria2.sh
source Scripts/env.sh
swift test --parallel
swift run ariakit --help
swift run ariakit --version
