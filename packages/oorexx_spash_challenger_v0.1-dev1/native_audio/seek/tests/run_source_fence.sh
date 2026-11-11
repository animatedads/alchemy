#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
: "${CC:=cc}"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
"$CC" -std=c11 -O2 -Wall -Wextra -Werror -pedantic tests/test_source_fence.c -o "$work/source_fence_test"
"$work/source_fence_test"
