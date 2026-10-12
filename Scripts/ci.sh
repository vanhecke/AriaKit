#!/usr/bin/env bash
# Full verification gate. GitHub Actions and agents both run this.
#   ./Scripts/ci.sh        lint (incl. format check) + tests + issues
#   ./Scripts/ci.sh --fix  format in place first, then the rest
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/.."

FIX=0
for arg in "$@"; do
  case "$arg" in
    --fix) FIX=1 ;;
    -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
    *) echo "unknown flag: $arg" >&2; exit 2 ;;
  esac
done

failed=0
step() {
  local name=$1; shift
  echo ""; echo "======== $name ========"
  if "$@"; then echo "======== $name OK ========"
  else echo "======== $name FAILED ========" >&2; failed=1
  fi
}

if [[ "$FIX" == 1 ]]; then step format ./Scripts/format.sh; fi
step lint ./Scripts/lint.sh
step test ./Scripts/test.sh
step issues ./Scripts/issues.sh

echo ""
if [[ "$failed" -eq 0 ]]; then echo "CI OK — lint, format-check, tests, issues"; exit 0; fi
echo "CI FAILED — scroll to the FAILED block above" >&2
exit 1
