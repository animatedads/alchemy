#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
"$HERE/tests/test_machine_protocol.sh"
