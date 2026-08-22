#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)/prepared/reputation_effect_v0.2"
[[ -d "$ROOT" ]]
cat > "$ROOT/VALIDATION.txt" <<'EOF'
Reputation Effect v0.2 publication validation
=============================================

This tree was promoted only after all preceding Alchemy Autobuild v0.4 tests passed:
- preparation from the live v0.1 baseline with exact-context v0.2 source/runtime patches;
- inherited component regression tests plus v0.2 communication-surface smoke;
- Shannon reputation gate with reputation.effect/0.2;
- Shannon communication behavior with reputation.effect/0.2;
- Shannon Reputation Feed compatibility with reputation.feed/0.1.

The Autobuild result is the authoritative execution evidence and records the effective per-test dependency roots and replace-mode REXX_PATH values.
EOF
(
  cd "$ROOT"
  rm -f MANIFEST.sha256
  find . -type f ! -name MANIFEST.sha256 -print0 | LC_ALL=C sort -z | xargs -0 sha256sum > MANIFEST.sha256
  sha256sum -c MANIFEST.sha256
)
echo 'PASS FINALIZE_REPUTATION_EFFECT_V02_PUBLICATION'
