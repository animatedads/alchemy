#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
bash -n "$ROOT/libexec/firewall-nft"
grep -Fq 'EXACT_BLOCK_MINUTES 1440' "$ROOT/src/FirewallControl.cls"
grep -Fq 'NET24_BLOCK_MINUTES 10' "$ROOT/src/FirewallControl.cls"
grep -Fq 'SECURITY_DOMAIN "FIREWALL"' "$ROOT/src/FirewallControl.cls"
grep -Fq 'BLOCK_HOSTILE_SOURCE' "$ROOT/src/FirewallControl.cls"
grep -Fq 'DENIED_PROTECTED_SOURCE' "$ROOT/src/FirewallControl.cls"
grep -Fq 'PEER_IDENTITY_MISMATCH' "$ROOT/src/FirewallControl.cls"
printf 'PASS static/helper checks\n'
