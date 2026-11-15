#!/usr/bin/env bash
# Source from the demo directory; supports an existing ooRexx install or the
# bundled r13196 Debian package, unpacked without sudo into this demo tree.
set -e
ROOT=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
if [ -z "${OOREXX_HOME:-}" ]; then
  if [ -x "$ROOT/runtime/usr/local/bin/rexx" ]; then
    OOREXX_HOME="$ROOT/runtime/usr/local"
  elif [ -x /usr/local/bin/rexx ]; then
    OOREXX_HOME=/usr/local
  elif [ -f "$ROOT/ooRexx-r13196.deb" ]; then
    command -v dpkg-deb >/dev/null || { echo 'dpkg-deb is required to unpack the bundled ooRexx interpreter' >&2; return 1; }
    mkdir -p "$ROOT/runtime"
    dpkg-deb -x "$ROOT/ooRexx-r13196.deb" "$ROOT/runtime"
    OOREXX_HOME="$ROOT/runtime/usr/local"
  else
    echo 'ooRexx 5.3.0 r13196 is not installed; set OOREXX_HOME' >&2
    return 1
  fi
fi
export OOREXX_HOME
export PATH="$OOREXX_HOME/bin:$PATH"
export LD_LIBRARY_PATH="$OOREXX_HOME/lib:$OOREXX_HOME/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$ROOT/src:$ROOT/vendor/notnotes:$ROOT/vendor/intention:$ROOT/vendor/nosql:$ROOT/vendor/cliui/rexx:$ROOT/vendor/pdf/src:$ROOT/vendor/spreadsheet:$ROOT/wire_ui_builder_v0.6/examples/notnotes:$ROOT/wire_ui_server_v0.17/src:$ROOT/oorexx_queue_fabric_web_gateway_v0.2/src:$ROOT/oorexx_queue_fabric_v0.9-dev6/src:$ROOT/alchemy_objects_v0.8/src:$ROOT/oorexx_crypto_v0.8.3/src:$OOREXX_HOME/bin"
