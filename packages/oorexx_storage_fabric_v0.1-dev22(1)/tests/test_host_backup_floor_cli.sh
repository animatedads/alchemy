#!/usr/bin/env bash
set -euo pipefail
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
REXX_BIN=${REXX_BIN:-rexx}
SRC=$(mktemp -d /tmp/storage-host-cli-src.XXXXXX)
if [[ ! -d /dev/shm || ! -w /dev/shm ]]; then
  echo 'FAIL /dev/shm is required for distinct-filesystem CLI qualification' >&2
  exit 1
fi
DST=$(mktemp -d /dev/shm/storage-host-cli-dst.XXXXXX)
cleanup() { rm -rf -- "$SRC" "$DST"; }
trap cleanup EXIT
printf 'storage host cli qualification\n' > "$SRC/input.txt"
export REXX_BIN
export STORAGE_HOST_COMMIT_HELPER="$ROOT/build/storage-host-commit"
cd "$ROOT"
preflight=$(bin/storage-host-backup-floor preflight "$SRC" "$DST" 0 0)
printf '%s\n' "$preflight"
grep -q $'^SFHOST1\tREADY\t' <<<"$preflight"
copy=$(bin/storage-host-backup-floor copy "$SRC" "$DST" input.txt backup/input.txt cli-qualification)
printf '%s\n' "$copy"
grep -q $'^SFHOST1\tCOMMITTED\t' <<<"$copy"
verify=$(bin/storage-host-backup-floor verify "$SRC" "$DST" input.txt backup/input.txt)
printf '%s\n' "$verify"
grep -q $'^SFHOST1\tMATCH\t' <<<"$verify"
cmp "$SRC/input.txt" "$DST/backup/input.txt"
[[ -d "$DST/.storage-fabric/checkpoints" ]]
echo 'PASS host backup floor CLI preflight/copy/verify'
