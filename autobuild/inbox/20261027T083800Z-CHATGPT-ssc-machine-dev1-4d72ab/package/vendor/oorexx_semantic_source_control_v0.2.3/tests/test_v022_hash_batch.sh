#!/usr/bin/env bash
set -euo pipefail
ROOT="/tmp/osc-v022-hash-scale"
BIN="/tmp/osc-v022-hash-bin"
COUNT="/tmp/osc-v022-sha-count"
rm -rf "$ROOT" "$BIN" "$COUNT" /tmp/osc-v022-hash-scale.rex
mkdir -p "$ROOT" "$BIN"
{
  echo '::class Many public'
  for i in $(seq 1 1200); do
    echo "::method m$i"
    echo '  use arg x'
    echo "  return x + $i"
  done
} > "$ROOT/Many.cls"
cat > "$BIN/sha256sum" <<'EOF'
#!/usr/bin/env bash
echo 1 >> /tmp/osc-v022-sha-count
exec /usr/bin/sha256sum "$@"
EOF
chmod +x "$BIN/sha256sum"
cat > /tmp/osc-v022-hash-scale.rex <<'REX'
a = .OoRexxSourceAnalyzer~new(.nil)
s = a~analyzeTree("/tmp/osc-v022-hash-scale", "Many", "MAIN", 1)
if s~methods~items <> 1200 then do
  say "FAIL hash scale method count" s~methods~items
  exit 1
end
say "HASH_SCALE methods=" || s~methods~items
::requires "src/SemanticSourceControl.cls"
REX
PATH="$BIN:$PATH" timeout 60 rexx /tmp/osc-v022-hash-scale.rex
calls=$(wc -l < "$COUNT")
if [ "$calls" -ne 1 ]; then
  echo "FAIL expected one batched sha256sum invocation, got $calls" >&2
  exit 1
fi
echo "PASS test_v022_hash_batch sha256Invocations=$calls"
