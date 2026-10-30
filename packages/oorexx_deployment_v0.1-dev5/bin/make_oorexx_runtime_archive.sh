#!/bin/sh
set -eu
if [ "$#" -ne 2 ]; then echo "usage: $0 OOREXX.deb OUT.tar.gz" >&2; exit 2; fi
deb=$1; out=$2
case "$out" in /*) ;; *) out="$(pwd)/$out";; esac
command -v dpkg-deb >/dev/null 2>&1 || { echo 'FAIL dpkg-deb required on controller' >&2; exit 3; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT INT TERM
dpkg-deb -x "$deb" "$T"
[ -x "$T/usr/local/bin/rexx" ] || { echo 'FAIL .deb does not contain usr/local/bin/rexx' >&2; exit 4; }
( cd "$T/usr/local" && tar -czf "$out" . )
sha256sum "$out"
