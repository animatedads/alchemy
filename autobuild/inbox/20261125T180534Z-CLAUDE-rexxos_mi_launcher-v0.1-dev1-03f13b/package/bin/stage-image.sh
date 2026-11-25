#!/bin/sh
# R3: run in Jammy build environment only, never on cats.
# Input is an already prepared, reviewed, offline Jammy minimal root tree
# including the approved RTO2 runner, libraries and registration adapter.
set -eu
[ "$#" = 3 ] || { echo 'usage: stage-image.sh prepared-root output.tar runner-sha256' >&2; exit 64; }
. /etc/os-release
[ "${ID:-}" = ubuntu ] && [ "${VERSION_ID:-}" = 22.04 ] || { echo 'R3 requires Ubuntu 22.04 build host' >&2; exit 77; }
root=$(readlink -f -- "$1"); out=$(readlink -m -- "$2"); expected=$3
case "$out" in "$root"|"$root"/*) exit 65;; esac
[ "$root" != / ] && [ -d "$root" ] && [ ! -e "$out" ] || exit 65
case "$expected" in *[!0-9a-f]*|'') exit 64;; esac
[ "${#expected}" = 64 ] || exit 64
[ -f "$root/opt/rexxos-mi/bin/runner" ] && [ ! -L "$root/opt/rexxos-mi/bin/runner" ] && [ -x "$root/opt/rexxos-mi/bin/runner" ] || exit 65
[ "$(sha256sum "$root/opt/rexxos-mi/bin/runner" | cut -d' ' -f1)" = "$expected" ] || exit 65
[ -f "$root/etc/rexxos-mi/contract-v1" ] && [ ! -L "$root/etc/rexxos-mi/contract-v1" ] || exit 65
# Prepared root is trusted and frozen. No credentials should be baked in.
# Avoid a partial archive becoming the requested final path.
tmp=$(mktemp -- "${out}.XXXXXX")
trap 'rm -f -- "$tmp"' EXIT HUP INT TERM
tar --one-file-system --numeric-owner -C "$root" -cf "$tmp" .
ln -- "$tmp" "$out"
sha256sum -- "$out"
