#!/usr/bin/env bash
set -euo pipefail
: "${ED209_GRID_SOURCE:?}" "${ED209_REXX:?}" "${ED209_REXX_LIB:?}"
W=$(cd "$(dirname "$0")/.." && pwd)
G=$ED209_GRID_SOURCE R=$ED209_REXX
T=$(mktemp -d);trap 'rm -rf "$T"' EXIT
export LD_LIBRARY_PATH="$ED209_REXX_LIB:$G/deps/fast/build:$G/xtp/upstream-dev18/lib:${LD_LIBRARY_PATH:-}"
export REXX_PATH="$G/rto2:$G/grid:$G/deps:$G/deps/qf:$G/deps/alchemy:$G/deps/socket-provider-dev14/src:$G/xtp/upstream-dev18/rexx:${REXX_PATH:-}"
cat > "$T/mock-rpc" <<'MOCK'
#!/usr/bin/env python3
import sys
argv=sys.argv
assert '--peer' in argv and argv[argv.index('--peer')+1]=='GRID.MN.MN1-ED209F', 'symbolic route identity required'
print('UNAUTHENTICATED:PEER_NOT_TRUSTED',end='')
MOCK
chmod 0700 "$T/mock-rpc"
python3 -c 'print("ab"*32)' > "$T/fixture-key";chmod 0600 "$T/fixture-key"
export GRID_RTO2_KEY_HEX=$(cat "$T/fixture-key")
set +e
"$R" "$W/rexx/mu-rto2-submit.rex" TESTCASE MN1-ED209F MU-ED209F 1000 1 02:52:00:09:01:01 17 "$T/routes.tsv" "$T/mock-rpc" @env > "$T/out" 2> "$T/err"
RC=$?
set -e
if [[ $RC -ne 71 ]] || ! grep -qx 'RTO2_MI_CONTROLLER_GRANT_ABSENT_OR_STALE' "$T/out"; then
  echo "FAIL controller redacted plaintext detection rc=$RC" >&2;cat "$T/out" >&2;cat "$T/err" >&2;exit 1
fi
printf '%s\n' 'PASS symbolic route identity and redacted untrusted response classification'
