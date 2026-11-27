#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
export REXX_PATH="$PWD/src:${OOREXX_CRYPTO_ROOT:+$OOREXX_CRYPTO_ROOT/src:}${REXX_PATH:-}"
rexx tests/domain.rex
rexx tests/tasks.rex
# Exact byte framing test using a minimal synthetic engine and the estate crypto.
testdir=$(mktemp -d)
trap 'rm -rf "$testdir"' EXIT HUP INT TERM
mkdir -p "$testdir/data" "$testdir/src"
printf 'Exact rules\n' > "$testdir/data/rules.conf"
printf 'Game controller source\n' > "$testdir/src/DiplomacyGame.cls"
(cd "$testdir" && sha256sum ./data/rules.conf ./src/DiplomacyGame.cls > manifest)
rexx tests/bundle.rex "$testdir" "$testdir/manifest"
# Production manifest checks exact pinned estate engine bytes independently.
if [ -n "${ALCHEMY_REPO_ROOT:-}" ]; then
  (cd "$ALCHEMY_REPO_ROOT/packages/oorexx_diplomacy_v0.1-dev6" && sha256sum -c "$OLDPWD/data/designer-source.sha256")
fi
