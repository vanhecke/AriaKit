#!/usr/bin/env bash
# Apply the repo's GitHub security settings. Idempotent. Run once the repo is public
# (GitHub refuses most of these for private repos on a free plan).
#   ./Scripts/github-settings.sh
# - Fork PRs: CI waits for "Approve and run" for every outside contributor.
# - Actions: read-only GITHUB_TOKEN by default, actions must be pinned to a full SHA.
# - Private vulnerability reporting, Dependabot alerts + security updates,
#   secret scanning + push protection.
# - Rulesets: main cannot be deleted or force-pushed; release tags cannot be
#   moved or deleted (SwiftPM pins a tag's commit, so a moved tag breaks clients).
set -euo pipefail

REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
if [[ "$(gh repo view --json visibility -q .visibility)" != PUBLIC ]]; then
  echo "$REPO is not public yet; make it public, then rerun." >&2
  exit 1
fi

put() { gh api --method PUT "repos/$REPO/$1" --input - >/dev/null; }

echo '{"approval_policy":"all_external_contributors"}' | put actions/permissions/fork-pr-contributor-approval
echo '{"enabled":true,"allowed_actions":"all","sha_pinning_required":true}' | put actions/permissions
echo '{"default_workflow_permissions":"read","can_approve_pull_request_reviews":false}' | put actions/permissions/workflow
gh api --method PUT "repos/$REPO/private-vulnerability-reporting" >/dev/null
gh api --method PUT "repos/$REPO/vulnerability-alerts" >/dev/null
gh api --method PUT "repos/$REPO/automated-security-fixes" >/dev/null
gh api --method PATCH "repos/$REPO" --input - >/dev/null <<'JSON'
{"security_and_analysis": {
  "secret_scanning": {"status": "enabled"},
  "secret_scanning_push_protection": {"status": "enabled"}}}
JSON

existing=$(gh api "repos/$REPO/rulesets" -q '.[].name')
ruleset() {
  local name=$1 body=$2
  if grep -qxF "$name" <<<"$existing"; then return; fi
  gh api --method POST "repos/$REPO/rulesets" --input - >/dev/null <<<"$body"
}
ruleset "main" '{"name":"main","target":"branch","enforcement":"active",
  "conditions":{"ref_name":{"include":["~DEFAULT_BRANCH"],"exclude":[]}},
  "rules":[{"type":"deletion"},{"type":"non_fast_forward"}]}'
ruleset "release tags" '{"name":"release tags","target":"tag","enforcement":"active",
  "conditions":{"ref_name":{"include":["refs/tags/*.*.*"],"exclude":[]}},
  "rules":[{"type":"deletion"},{"type":"non_fast_forward"},{"type":"update"}]}'

echo "GitHub settings applied to $REPO" >&2
