#!/usr/bin/env bash
# Isolated fail-red regression for stable NotNotes document identity.
set -euo pipefail
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source "$here/env.sh"
state=$(mktemp -d "${TMPDIR:-/tmp}/notnotes-identity-XXXXXXXX")
cleanup() { if [[ -d $state ]]; then rm -r -- "$state"; fi; }
trap cleanup EXIT
cd "$ROOT"
export MININOTES_DB_BACKEND=file
"$OOREXX_HOME/bin/rexx" "$here/identity-restart-probe.rex" capture "$state/db" "$state/identities.tsv"
"$OOREXX_HOME/bin/rexx" "$here/identity-restart-probe.rex" verify "$state/db" "$state/identities.tsv"
