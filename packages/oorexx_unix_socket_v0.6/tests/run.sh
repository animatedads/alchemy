#!/usr/bin/env bash
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
pkg=$(cd "$here/.." && pwd)
rexx=${REXX:-/usr/local/bin/rexx}
foreign=${FOREIGN_RUNTIME_HOME:-}
oorexx=${OOREXX_HOME:-/usr/local}
if [[ -z "$foreign" ]]; then
  echo 'FAIL FOREIGN_RUNTIME_HOME must name ooRexx Foreign Runtime v0.22.6 root' >&2
  exit 2
fi
[[ -f "$foreign/rexx/foreign.cls" ]] || { echo "FAIL missing $foreign/rexx/foreign.cls" >&2; exit 2; }
[[ -f "$foreign/build/libforeign_runtime.so" ]] || { echo "FAIL missing $foreign/build/libforeign_runtime.so" >&2; exit 2; }
export LD_LIBRARY_PATH="$foreign/build:$oorexx/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$foreign/rexx:$oorexx/bin:$oorexx/share/ooRexx${REXX_PATH:+:$REXX_PATH}"
# Prove the package-relative default bridge works before setting an explicit test override.
env -u OOREXX_UNIX_SOCKET_BRIDGE REXX_PATH="$pkg:$REXX_PATH" "$rexx" "$here/test_default_bridge.rex"

# Independently compare the executable bridge profile with this host's C ABI.
"$here/test_abi_profile.sh"
export OOREXX_UNIX_SOCKET_BRIDGE="$pkg/bridge/libc-af-unix.bridge.json"
if find "$pkg" -type f -name 'librxunixsocket.so' -print -quit | grep -q .; then
  echo 'FAIL Unix-socket-specific native library present in v0.6 package' >&2
  exit 1
fi
if grep -q "::requires .*rxunixsocket.*LIBRARY" "$pkg/unixsocket.cls"; then
  echo 'FAIL unixsocket.cls still requires rxunixsocket native package' >&2
  exit 1
fi
if grep -Eq 'linux-x86_64|_uxPackLE|_uxAlign8|524288|1073741824|2228224|0100.x' "$pkg/unixsocket.cls"; then
  echo 'FAIL ABI-specific magic remains embedded in unixsocket.cls' >&2
  exit 1
fi

"$rexx" "$here/test_stock_limitation.rex"
(cd "$here" && "$rexx" test_abi_fail_closed.rex)
(cd "$here" && "$rexx" test_foreign_boundary.rex)
(cd "$here" && "$rexx" test_native_scalar_boundary.rex)
(cd "$here" && "$rexx" test_class_smoke.rex)

run_pair() {
  local server=$1 client=$2 endpoint=$3 tag=$4
  local ready="$here/.${tag}.ready"
  local sout="$here/.${tag}.server.out"
  rm -f "$ready" "$sout"
  (cd "$here" && "$rexx" "$server" "$endpoint" "$ready") >"$sout" 2>&1 &
  local spid=$!
  trap 'kill "$spid" 2>/dev/null || true' RETURN
  for _ in $(seq 1 100); do
    [[ -s "$ready" ]] && break
    kill -0 "$spid" 2>/dev/null || { cat "$sout"; wait "$spid"; return 1; }
    sleep 0.02
  done
  [[ -s "$ready" ]] || { echo "FAIL $tag server readiness"; cat "$sout"; return 1; }
  (cd "$here" && "$rexx" "$client" "$endpoint")
  wait "$spid"
  cat "$sout"
  rm -f "$ready" "$sout"
  trap - RETURN
}

path="/tmp/oorexx-unixsocket-v06-$$.sock"
run_pair path_server.rex path_client.rex "$path" pathname
abstract="oorexx-unixsocket-v06-$$"
run_pair abstract_server.rex abstract_client.rex "$abstract" abstract

for t in \
  test_datagram.rex \
  test_unbound_datagram.rex \
  test_datagram_truncation.rex \
  test_scm_rights.rex \
  test_scm_rights_truncation.rex \
  test_cloexec.rex \
  test_socketpair_types.rex \
  test_nonblocking_poll.rex \
  test_socket_options.rex \
  test_path_helpers.rex \
  test_passcred.rex \
  test_abstract_datagram.rex \
  test_binary_abstract.rex; do
  (cd "$here" && "$rexx" "$t")
done

echo 'PASS ALL ooRexx Unix Socket v0.6 Foreign Runtime ABI-native-scalar tests'
