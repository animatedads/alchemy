#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT INT TERM
mkdir -p "$T/src"; printf 'alpha\n' > "$T/src/a.txt"
"$ROOT/bin/deploy_tree.sh" --source "$T/src" --target-root "$T/target" > "$T/one"
# Simulate post-deployment drift without changing the generation marker.
printf 'corrupt\n' > "$T/target/current/a.txt"
"$ROOT/bin/deploy_tree.sh" --source "$T/src" --target-root "$T/target" > "$T/two"
[ -L "$T/target/current" ]
[ "$(cat "$T/target/current/a.txt")" = alpha ]
[ "$(find "$T/target/releases" -mindepth 1 -maxdepth 1 -type d | wc -l)" -eq 1 ]
grep -q '^STAGED ' "$T/one"; grep -q '^STAGED ' "$T/two"
echo 'PASS local reconcile/idempotence'
