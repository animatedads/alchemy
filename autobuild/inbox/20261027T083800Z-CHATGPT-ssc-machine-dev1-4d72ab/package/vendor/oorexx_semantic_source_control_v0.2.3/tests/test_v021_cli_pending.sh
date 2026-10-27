#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
repo=/tmp/osc-v021-cli-pending
rm -rf "$repo"
bin/osc scan tests/fixtures_v021/relocate_v1 --repo "$repo" --component Bank >/tmp/osc-v021-cli-v1.out
while IFS='|' read -r id rest; do
  [ -n "$id" ] || continue
  bin/osc proposal accept "$id" --repo "$repo" --reason "fixture tracked operation" >/dev/null
done < "$repo/proposals.osc"
bin/osc scan tests/fixtures_v021/relocate_v2 --repo "$repo" --component Bank >/tmp/osc-v021-cli-v2.out
grep -q 'trackingProposalsPending= 0' /tmp/osc-v021-cli-v2.out
[ "$(wc -l < "$repo/proposals.osc")" -eq 2 ]
echo "PASS test_v021_cli_pending"
