#!/usr/bin/env bash
set -euo pipefail
ROOT="/tmp/osc-v023-md5-scale"
BIN="/tmp/osc-v023-md5-bin"
COUNT="/tmp/osc-v023-md5-count"
rm -rf "$ROOT" "$BIN" "$COUNT" /tmp/osc-v023-md5-scale.rex
mkdir -p "$ROOT" "$BIN"
{
  echo '::class SqlMany public'
  for i in $(seq 1 200); do
    echo "::method write$i"
    echo "  sql = \"INSERT INTO audit_events (event_id, event_kind) VALUES (?, ?)\""
    echo "  return sql"
  done
} > "$ROOT/SqlMany.cls"
cat > "$BIN/md5sum" <<'EOF2'
#!/usr/bin/env bash
echo 1 >> /tmp/osc-v023-md5-count
exec /usr/bin/md5sum "$@"
EOF2
chmod +x "$BIN/md5sum"
cat > /tmp/osc-v023-md5-scale.rex <<'REX'
a = .OoRexxSourceAnalyzer~new(.nil)
s = a~analyzeTree("/tmp/osc-v023-md5-scale", "SqlMany", "MAIN", 1)
if s~methods~items <> 200 then do
  say "FAIL md5 scale method count" s~methods~items
  exit 1
end
if s~candidates~items <> 200 then do
  say "FAIL md5 scale candidate count" s~candidates~items
  exit 1
end
say "MD5_SCALE candidates=" || s~candidates~items
::requires "src/SemanticSourceControl.cls"
REX
PATH="$BIN:$PATH" timeout 60 rexx /tmp/osc-v023-md5-scale.rex
calls=$(wc -l < "$COUNT")
if [ "$calls" -ne 1 ]; then
  echo "FAIL expected one batched md5sum invocation, got $calls" >&2
  exit 1
fi
echo "PASS test_v023_md5_batch md5Invocations=$calls"
