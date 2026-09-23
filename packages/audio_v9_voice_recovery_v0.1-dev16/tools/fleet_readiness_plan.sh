#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
printf 'worker\taddress\tlogin\tpolicy\n'
tail -n +2 "$ROOT/campaign/WORKERS.tsv" | while IFS="$(printf '\t')" read -r worker start end halo provider address login; do
  printf '%s\t%s\t%s\treconcile-verify-before-start\n' "$worker" "$address" "$login"
done
