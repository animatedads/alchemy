#!/bin/sh
set -eu
cd "$(dirname "$0")"
: "${NEWSHELL_HOME:?set NEWSHELL_HOME to the extracted opt/newshell directory}"
: "${REXX:=rexx}"
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT HUP INT TERM
mkdir "$root/sub" "$root/movable"
printf marker > "$root/movable/marker"
printf abc > "$root/sub/f"
chmod 0644 "$root/sub/f"
ln -s /etc/passwd "$root/link"
ln -s /etc "$root/escape"
export REXX_PATH="$PWD/src:$NEWSHELL_HOME/src${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$PWD/lib:$NEWSHELL_HOME/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
"$REXX" tests/test.rex "$root"
"$REXX" tests/test-registry.rex "$root"
"$REXX" tests/test-pidfd.rex
mkdir -p "$root/watchdir/child"
"$REXX" tests/test-watch.rex "$root"
mkdir "$root/eventdir"
"$REXX" tests/test-events.rex "$root"
# Isolated fixture, not an upstream dev7 qualification.
REXX_PATH="$PWD/tests/marker-fixture:$REXX_PATH" "$REXX" tests/test-marker.rex
