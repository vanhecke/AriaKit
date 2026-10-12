#!/usr/bin/env bash
# Tag and publish a release. SwiftPM clients resolve `from: "X.Y.Z"` against these tags.
#   ./Scripts/release.sh 0.1.0
# Requires: clean tree on main, pushed to origin; the APP_VERSION default in
# Sources/AriaKitCLI/AppConfig.swift already set to the version (so `--version` matches);
# ./Scripts/ci.sh green. Then pushes an annotated tag and creates a GitHub release.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

die() { echo "release: $*" >&2; exit 1; }

VERSION=${1:-}
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  sed -n '2,6p' "$0" >&2
  exit 64
fi

[[ -z "$(git status --porcelain)" ]] || die "working tree is not clean"
[[ "$(git branch --show-current)" == main ]] || die "not on main"
git fetch --quiet origin main --tags
[[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] || die "main is not the same as origin/main; push or pull first"
! git rev-parse -q --verify "refs/tags/$VERSION" >/dev/null || die "tag $VERSION already exists"
grep -qF "default: \"$VERSION\"" Sources/AriaKitCLI/AppConfig.swift \
  || die "set the APP_VERSION default in Sources/AriaKitCLI/AppConfig.swift to \"$VERSION\" and commit it first"

./Scripts/ci.sh
git tag -a "$VERSION" -m "AriaKit $VERSION"
git push origin "refs/tags/$VERSION"
gh release create "$VERSION" --verify-tag --generate-notes --title "$VERSION"
