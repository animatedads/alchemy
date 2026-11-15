#!/usr/bin/env bash
# Architecture: Tom Dyer. Code: ChatGPT (GPT-6).
# The test owns its disposable root; caller paths are never traversed.
set -euo pipefail
db_lab_root="$(mktemp -d /tmp/ood-db-lab.XXXXXXXX)"
trap 'if [[ -n "$db_lab_root" && -d "$db_lab_root" ]]; then rm -r -- "$db_lab_root"; fi' EXIT
rexx tests/database_lab_smoke.rex "$db_lab_root"
