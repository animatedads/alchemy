#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
for id in current-head xtp-capability xtp-receipts xtp-capacity xtp-outstanding; do
  test -s "packs/queue-fabric/articles/queue-fabric.$id.json"
  grep -Fq '"sphere": "queue-fabric"' "packs/queue-fabric/articles/queue-fabric.$id.json"
done
grep -Fq 'DESIGN_NOT_RUNTIME' contracts/queue-fabric-xtp-integration-v0.1.json
grep -Fq 'legacy_tcp_compatibility' contracts/queue-fabric-xtp-integration-v0.1.json
grep -Fq 'multicast_quorum_as_durable_commit' contracts/queue-fabric-xtp-integration-v0.1.json
grep -Fq 'not an executable Queue Fabric adapter' README.md
echo 'PASS: Queue Fabric v0.2 XTP source contract (static only)'
