#!/usr/bin/env bash
set -euo pipefail
ROOT=/tmp/osc-v023-legacy-src
REPO=/tmp/osc-v023-legacy-repo
rm -rf "$ROOT" "$REPO"
mkdir -p "$ROOT"
cat > "$ROOT/Store.cls" <<'SRC'
::class Store public
::method write
  sql = "INSERT INTO audit_events (event_id, event_kind) VALUES (?, ?)"
  return sql
SRC
echo 'release evidence added by newer analyzer' > "$ROOT/README.md"

rexx bin/osc.rex baseline "$ROOT" --repo "$REPO" --component LegacyDemo --level 1 > /tmp/osc-v023-legacy-b1.txt
proposal=$(awk -F'|' 'NR==1 {print $1}' "$REPO/proposals.osc")
[ -n "$proposal" ]
rexx bin/osc.rex proposal accept "$proposal" --repo "$REPO" --reason 'real persistence boundary' > /dev/null

snap="$REPO/components/LegacyDemo/levels/1/snapshot.osc"
# Simulate a pre-v0.2 snapshot: no schema marker/package/use records and only
# the source file evidence the old analyzer knew about.
awk -F'|' '($1=="V"||$1=="K"||$1=="A"||$1=="N"||$1=="U"||$1=="D"){next} $1=="F" && $2 !~ /Store\.cls/{next} {print}' "$snap" > "$snap.legacy"
mv "$snap.legacy" "$snap"
before=$(sha256sum "$snap" | awk '{print $1}')

rexx bin/osc.rex baseline "$ROOT" --repo "$REPO" --component LegacyDemo --level 1 > /tmp/osc-v023-legacy-b1-again.txt
after=$(sha256sum "$snap" | awk '{print $1}')
[ "$before" = "$after" ] || { echo 'FAIL legacy accepted level was rewritten' >&2; exit 1; }
grep -q 'externalTracked= 1' /tmp/osc-v023-legacy-b1-again.txt
grep -q 'trackingProposalsPending= 0' /tmp/osc-v023-legacy-b1-again.txt

rexx bin/osc.rex baseline "$ROOT" --repo "$REPO" --component LegacyDemo --level 2 > /tmp/osc-v023-legacy-b2.txt
grep -q 'externalTracked= 1' /tmp/osc-v023-legacy-b2.txt
grep -q 'trackingProposalsPending= 0' /tmp/osc-v023-legacy-b2.txt
[ "$(cat "$REPO/components/LegacyDemo/LATEST")" = 2 ]
echo 'PASS test_v023_legacy_identity immutableOldLevel=true nextLevel=2 tracked=1'
