#!/bin/sh
set -eu
cd "$(dirname "$0")"
rexx tests/test_semantic_source_control.rex
sh tests/test_cli_intake.sh
rexx tests/test_v02_regressions.rex
rexx tests/test_v021_dogfood.rex
sh tests/test_v021_cli_pending.sh
rexx tests/test_v022_terminal_dogfood.rex
sh tests/test_v022_hash_batch.sh
rexx tests/test_v023_relocation_one_to_one.rex
sh tests/test_v023_md5_batch.sh
sh tests/test_v023_legacy_identity.sh
sh tests/test_v02_performance.sh
