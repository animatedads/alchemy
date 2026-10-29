#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
REXX_PATH=src rexx tests/test_draft_gate.rex
