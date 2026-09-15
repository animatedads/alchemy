#!/usr/bin/env bash
set -euo pipefail
log=${FAKE_COLAB_LOG:?}
printf '%q ' "$@" >> "$log"; printf '\n' >> "$log"
cmd=""
for a in "$@"; do case "$a" in new|upload|download|install|exec|log|rm|stop|status) cmd=$a; break;; esac; done
if [[ "${FAKE_COLAB_FAIL_CMD:-}" == "$cmd" ]]; then echo "forced failure: $cmd" >&2; exit 7; fi
if [[ "$cmd" == "exec" ]]; then
  prev=""
  for a in "$@"; do
    if [[ "$prev" == "-f" ]]; then python3 -m py_compile "$a"; break; fi
    prev="$a"
  done
fi
case "$cmd" in
  download)
    remote="${@: -2:1}"; local="${@: -1}"; mkdir -p "$(dirname "$local")"
    if [[ "$remote" == */.oorexx-results.sha256 ]]; then
      printf '6f7574707574732f747261696e696e672d7265706f72742e6a736f6e\t9\t5b3513f580c8397212ff2c8f459c199efc0c90e4354a5f3533adf0a3fff3a530\n' > "$local"
    else
      printf 'artifact\n' > "$local"
    fi;;
  log)
    local="${@: -1}"; mkdir -p "$(dirname "$local")"; printf '{"event":"fake"}\n' > "$local";;
  *) :;;
esac
exit 0
