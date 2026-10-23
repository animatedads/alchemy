#!/bin/sh
set -eu
: "${MU_UPSTREAM_ROOT:?Set MU_UPSTREAM_ROOT to job_node_allocator_v0.6-network6 root}"
export REXX_PATH="${PWD}/src:${MU_UPSTREAM_ROOT}/src${REXX_PATH:+:$REXX_PATH}"
rexx tests/test_mu.rex
python3 tests/test_manifest.py
