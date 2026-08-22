#!/bin/sh
set -eu
cd "$(dirname "$0")"
echo '=== test_git_mesh_transport.rex ==='
rexx tests/test_git_mesh_transport.rex
