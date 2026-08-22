#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
BASE="${LIVE_REPUTATION_EFFECT_ROOT:?}"
OUT="$ROOT/prepared/reputation_effect_v0.2"
PATCH_ROOT="${ALCHEMY_REPO_ROOT:?}/autobuild/inbox/20260822T054100Z-CHATGPT-shannon-reputation-v02-stage/package/patches"
OVERLAY_ROOT="${ALCHEMY_REPO_ROOT:?}/autobuild/inbox/20260822T055300Z-CHATGPT-reputation-effect-v02-publish/package/overlays"

[[ -f "$BASE/src/ReputationEffect.cls" ]]
[[ -f "$BASE/runtime/ReputationRuntimeModule.cls" ]]
grep -q '::constant API_VERSION "reputation.effect/0.1"' "$BASE/src/ReputationEffect.cls"
if grep -q '::class ReputationCommunicationFailure public' "$BASE/src/ReputationEffect.cls"; then
  echo 'FAIL base already contains communication surface while declaring v0.1' >&2
  exit 1
fi

rm -rf "$ROOT/prepared"
mkdir -p "$ROOT/prepared"
cp -a "$BASE" "$OUT"
patch --batch --fuzz=0 -d "$OUT" -p0 < "$PATCH_ROOT/reputation_effect_src_v01_to_v02.patch"
patch --batch --fuzz=0 -d "$OUT" -p0 < "$PATCH_ROOT/reputation_runtime_v01_to_v02.patch"
printf '0.2\n' > "$OUT/VERSION.txt"

# Version-coupled regression expectations move with the runtime/API generation.
sed -i \
  -e 's/REPUTATION-EFFECT-V0\.1/REPUTATION-EFFECT-V0.2/g' \
  -e 's/reputation\.effect\/0\.1/reputation.effect\/0.2/g' \
  "$OUT/tests/test_reputation_runtime_registry.rex"

grep -q '::constant VERSION "0.2"' "$OUT/src/ReputationEffect.cls"
grep -q '::constant API_VERSION "reputation.effect/0.2"' "$OUT/src/ReputationEffect.cls"
grep -q 'REPUTATION-EFFECT-V0.2' "$OUT/runtime/ReputationRuntimeModule.cls"
grep -q 'REPUTATION-EFFECT-V0.2' "$OUT/tests/test_reputation_runtime_registry.rex"
grep -q '::class ReputationCommunicationFailure public' "$OUT/src/ReputationEffect.cls"

if [[ -f "$OUT/README.md" ]]; then mv "$OUT/README.md" "$OUT/README_v0.1.md"; fi
cat "$OVERLAY_ROOT/README_V02_HEADER.md" > "$OUT/README.md"
if [[ -f "$OUT/README_v0.1.md" ]]; then
  printf '\n---\n\n## v0.1 architecture background\n\n' >> "$OUT/README.md"
  cat "$OUT/README_v0.1.md" >> "$OUT/README.md"
fi
if [[ -f "$OUT/CHANGELOG.md" ]]; then mv "$OUT/CHANGELOG.md" "$OUT/CHANGELOG_v0.1.md"; fi
cat "$OVERLAY_ROOT/CHANGELOG_V02_ENTRY.md" > "$OUT/CHANGELOG.md"
if [[ -f "$OUT/CHANGELOG_v0.1.md" ]]; then
  printf '\n---\n\n' >> "$OUT/CHANGELOG.md"
  cat "$OUT/CHANGELOG_v0.1.md" >> "$OUT/CHANGELOG.md"
fi
for f in VALIDATION.txt VALIDATION_TRANSCRIPT.txt; do
  if [[ -f "$OUT/$f" ]]; then mv "$OUT/$f" "$OUT/${f%.txt}_v0.1.txt"; fi
done
cp "$OVERLAY_ROOT/test_reputation_communication_surface_smoke.rex" "$OUT/tests/"
cp "$OVERLAY_ROOT/AUTOBUILD_PROVENANCE.md" "$OUT/"
cat > "$OUT/VALIDATION.txt" <<'EOF'
Reputation Effect v0.2 publication candidate
============================================

This tree is prepared for Alchemy Autobuild v0.4 validation. Publication is permitted only when the overall Autobuild result is PASS. The authoritative result records each effective dependency root and replace-mode REXX_PATH.
EOF
(
  cd "$OUT"
  rm -f MANIFEST.sha256
  find . -type f ! -name MANIFEST.sha256 -print0 | LC_ALL=C sort -z | xargs -0 sha256sum > MANIFEST.sha256
  sha256sum -c MANIFEST.sha256
)
echo 'PASS PREPARE_REPUTATION_EFFECT_V02_R3'
