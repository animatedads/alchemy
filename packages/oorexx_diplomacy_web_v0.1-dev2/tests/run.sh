#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
export REXX_PATH="$PWD/src:${OOREXX_CRYPTO_ROOT:+$OOREXX_CRYPTO_ROOT/src:}${REXX_PATH:-}"
rexx tests/domain.rex
rexx tests/tasks.rex
testdir=$(mktemp -d)
trap 'rm -rf "$testdir"' EXIT HUP INT TERM
mkdir -p "$testdir/data" "$testdir/src"
printf 'Exact rules\n' > "$testdir/data/rules.conf"
printf 'Game controller source\n' > "$testdir/src/DiplomacyGame.cls"
(cd "$testdir" && sha256sum ./data/rules.conf ./src/DiplomacyGame.cls > manifest)
rexx tests/bundle.rex "$testdir" "$testdir/manifest" "Exact rules"
if [ -n "${ALCHEMY_REPO_ROOT:-}" ]; then
  OOREXX_DIPLOMACY_ROOT="${ALCHEMY_REPO_ROOT}/packages/oorexx_diplomacy_v0.1-dev7r1"
fi
if [ -n "${OOREXX_DIPLOMACY_ROOT:-}" ]; then
  (cd "$OOREXX_DIPLOMACY_ROOT" && sha256sum -c "$OLDPWD/data/designer-source.sha256")
  # Native pure-Rexx full bundle hashing can be slow; optional qualification.
  if [ "${FULL_DESIGN_BUNDLE_TEST:-0}" = 1 ]; then
    rexx tests/bundle.rex "$OOREXX_DIPLOMACY_ROOT" "$PWD/data/designer-source.sha256"
  fi
  export REXX_PATH="$PWD/src:$OOREXX_DIPLOMACY_ROOT/src:${OOREXX_LOGGING_ROOT:?}/src:$REXX_PATH"
  mkdir -m 700 "$testdir/game"
  (umask 077; rexx tests/worker.rex "$OOREXX_DIPLOMACY_ROOT" "$testdir/game/game.log")
fi
if [ -n "${WIRE_SERVER_ROOT:-}" ]; then
  export REXX_PATH="$PWD/src:$WIRE_SERVER_ROOT/src:${QUEUE_FABRIC_ROOT:?}/src:${ALCHEMY_OBJECTS_ROOT:?}/src:$REXX_PATH"
  rexx tests/ingress.rex
fi
