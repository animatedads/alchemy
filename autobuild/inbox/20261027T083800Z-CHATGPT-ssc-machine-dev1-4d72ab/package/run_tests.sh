#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
(
  cd "$ROOT/vendor/oorexx_semantic_source_control_v0.2.3"
  sha256sum -c MANIFEST.sha256 >/dev/null
)
"$ROOT/tests/test_machine_protocol.sh"
