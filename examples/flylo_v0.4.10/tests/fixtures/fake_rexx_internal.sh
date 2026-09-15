#!/usr/bin/env bash
set -euo pipefail
case "${1##*/}" in
  flylo_runtime_probe.rex)
    echo FLYLO_RUNTIME_PROBE_OK
    exit 0
    ;;
  flylo_assistant_turn.rex)
    cat >/dev/null || true
    printf '%s\n' '{"ok":false,"code":"FLYLO_ASSISTANT_INTERNAL_INTERPRET_PROVIDER","detail":"The FlyLo assistant hit an internal structured-runtime condition.","diagnostic":{"stage":"INTERPRET_PROVIDER","conditionCode":"97.1","position":"44"}}'
    exit 4
    ;;
  *)
    echo "unexpected fake rexx program: $1" >&2
    exit 91
    ;;
esac
