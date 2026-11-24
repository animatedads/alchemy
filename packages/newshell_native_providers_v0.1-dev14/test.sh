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
mkdir "$root/persistentdir"
"$REXX" tests/test-persistent.rex "$root"
mkdir "$root/runtime" "$root/runtime/runtimedir"
printf 'allow llm JOBBOARD submit *\nallow llm WORKSPACE run:echo %s\n' "$root/runtime" > "$root/runtime/allow.policy"
printf 'deny llm JOBBOARD submit *\n' > "$root/runtime/deny.policy"
NEWSHELL_POLICY="$root/runtime/allow.policy" NEWSHELL_ECHO=0 "$REXX" tests/test-event-runtime.rex "$root/runtime"
# Disposable localhost process/socket and synthetic audit-log fixture.
mkdir "$root/security"
${CXX:-g++} -std=c++11 -Wall -Wextra -Werror tests/security-fixture.cpp -o "$root/security/fixture"
printf 'allow llm JOBBOARD submit *\nallow llm WORKSPACE run:echo %s\n' "$root/security" > "$root/security/allow.policy"
NEWSHELL_POLICY="$root/security/allow.policy" NEWSHELL_ECHO=0 "$REXX" tests/test-security-observation.rex "$root/security" "$root/security/fixture"
# Compound observation, current process lineage, and optional actual TCP_INFO.
mkdir "$root/correlation" "$root/tcplive"
printf 'allow llm JOBBOARD submit *\nallow llm WORKSPACE run:echo %s\n' "$root/correlation" > "$root/correlation/allow.policy"
NEWSHELL_POLICY="$root/correlation/allow.policy" NEWSHELL_ECHO=0 "$REXX" tests/test-security-correlation.rex "$root/correlation"
"$REXX" tests/test-tcp-live.rex "$root/tcplive" "$root/security/fixture"
# Isolated fixture, not an upstream dev7 qualification.
REXX_PATH="$PWD/tests/marker-fixture:$REXX_PATH" "$REXX" tests/test-marker.rex
