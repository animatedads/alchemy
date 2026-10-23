#!/usr/bin/env bash
set -euo pipefail

MOUNT=${1:?usage: fuse-soak.sh MOUNTPOINT [ITERATIONS]}
ITERATIONS=${2:-0}              # 0 = forever
SLEEP_BETWEEN=${SLEEP_BETWEEN:-1}
ROOT="$MOUNT/.storage-fuse-soak"
LOG=${STORAGE_FUSE_SOAK_LOG:-/tmp/storage-fuse-soak.log}

mkdir -p "$ROOT"

log() { printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" | tee -a "$LOG"; }
fail() { log "FAIL iteration=$iter $*"; exit 1; }

iter=0
while :; do
  iter=$((iter+1))
  if [[ "$ITERATIONS" -gt 0 && "$iter" -gt "$ITERATIONS" ]]; then break; fi

  # Base unlink drops the logical file and all its application named streams.
  rm -f "$ROOT/busy.bin" "$ROOT/stable.txt" "$ROOT/post-barrier.txt" 2>/dev/null || true

  printf 'stable-%08d\n' "$iter" > "$ROOT/stable.txt"
  printf 'side-%08d\n' "$iter" > "$ROOT/stable.txt:side"
  dd if=/dev/zero of="$ROOT/busy.bin" bs=1 count=256 status=none

  ready=$(mktemp)
  go=$(mktemp)
  rm -f "$ready" "$go"

  # This handle exists before the snapshot barrier and therefore belongs to S.
  python3 - "$ROOT/busy.bin" "$ready" "$go" <<'PY' &
import os,sys,time
path,ready,go=sys.argv[1:]
f=open(path,'r+b',buffering=0)
f.seek(0); f.write(b'OLD-BEFORE')
open(ready,'w').close()
for _ in range(300):
    if os.path.exists(go): break
    time.sleep(.01)
f.seek(64); f.write(b'OLD-AFTER')
f.close()
PY
  oldpid=$!

  for _ in {1..300}; do [[ -e "$ready" ]] && break; sleep .01; done
  [[ -e "$ready" ]] || fail "pre-barrier writer did not become ready"

  # First directory read installs the generation barrier.  Because busy.bin
  # has a pre-existing writer, a complete frozen directory must not yet appear.
  if ls "$ROOT:frozen" >/dev/null 2>&1; then
    fail ":frozen published while an S writer was still open"
  fi

  # New handle after the barrier belongs only to S+1.
  python3 - "$ROOT/busy.bin" <<'PY'
import sys
with open(sys.argv[1],'r+b',buffering=0) as f:
    f.seek(128); f.write(b'NEW-HANDLE')
PY
  printf 'created-after-barrier\n' > "$ROOT/post-barrier.txt"

  # Let the old S writer finish.  Its OLD-AFTER write must appear in both
  # frozen S and live S+1; NEW-HANDLE must appear only in live S+1.
  : > "$go"
  wait "$oldpid"
  rm -f "$ready" "$go"

  published=0
  for _ in {1..300}; do
    if ls "$ROOT:frozen" >/dev/null 2>&1; then published=1; break; fi
    sleep .01
  done
  [[ "$published" -eq 1 ]] || fail "frozen generation did not publish after old writer close"

  status=$(cat "$ROOT:\$status")
  gen=$(printf '%s\n' "$status" | sed -n 's/.*state=PUBLISHED generation=\([0-9][0-9]*\).*/\1/p' | tail -1)
  [[ -n "$gen" ]] || fail "could not obtain published generation from :\$status: $status"
  frozen="$ROOT:g$gen"

  [[ ! -e "$frozen/post-barrier.txt" ]] || fail "post-barrier file leaked into frozen membership"

  python3 - "$frozen/busy.bin" "$ROOT/busy.bin" <<'PY' || exit $?
import sys
frozen=open(sys.argv[1],'rb').read(); live=open(sys.argv[2],'rb').read()
if b'OLD-BEFORE' not in frozen or b'OLD-AFTER' not in frozen:
    print('frozen generation lost pre-barrier handle writes',file=sys.stderr); raise SystemExit(21)
if b'NEW-HANDLE' in frozen:
    print('new S+1 handle contaminated frozen S',file=sys.stderr); raise SystemExit(22)
for token in (b'OLD-BEFORE',b'OLD-AFTER',b'NEW-HANDLE'):
    if token not in live:
        print('live S+1 missing '+repr(token),file=sys.stderr); raise SystemExit(23)
PY
  rc=$?; [[ "$rc" -eq 0 ]] || fail "generation content assertion rc=$rc"

  [[ "$(cat "$frozen/stable.txt:side")" == "side-$(printf '%08d' "$iter")" ]] || fail "named stream not frozen with object generation"

  # Mutation after publication must not alter exact :gN bytes.
  before=$(sha256sum "$frozen/stable.txt" | awk '{print $1}')
  printf 'live-mutated-%08d\n' "$iter" > "$ROOT/stable.txt"
  after=$(sha256sum "$frozen/stable.txt" | awk '{print $1}')
  [[ "$before" == "$after" ]] || fail "exact generation changed after live mutation"

  # Explicit release removes only the snapshot pin, never the live directory.
  rmdir "$ROOT:frozen"
  [[ -d "$ROOT" ]] || fail "snapshot release removed live directory"

  log "PASS iteration=$iter generation=$gen"
  sleep "$SLEEP_BETWEEN"
done

log "PASS completed iterations=$ITERATIONS"
