#!/usr/bin/env bash
set -euo pipefail

HTTPS_SHA='d38ddd049e5d8f5683e4ebf09e09a870c9c562bd3663db32950df711f7040fbe'
WEBDAV_SHA='8129e50b20efdaf03980eed8e9f10f09edfec45aae82a27be6a1732c1c98299e'

: "${HTTPS_ZIP:?set HTTPS_ZIP to oorexx_https_server_v0.4.8.zip}"
: "${WEBDAV_ZIP:?set WEBDAV_ZIP to oorexx_webdav_v0.1-dev6.zip}"
: "${OOREXX:?set OOREXX to the exact ooRexx 5.3.0 r13196 prefix}"
: "${FOREIGN_RUNTIME_ROOT:?set FOREIGN_RUNTIME_ROOT to exact v0.17.1 root}"
: "${WEBDAV_DEP_PATH:?colon-separated directories containing StorageFabric.cls, StorageStreaming.cls, StorageSequentialMedia.cls and StorageHerculesSequentialMedia.cls}"

HERE="$(cd "$(dirname "$0")" && pwd)"
REXX="$OOREXX/bin/rexx"
[[ -x "$REXX" ]] || { echo "FAIL missing $REXX" >&2; exit 2; }
"$REXX" -v 2>&1 | grep -q 'Open Object Rexx Version 5.3.0 r13196' || { echo 'FAIL exact ooRexx 5.3.0 r13196 required' >&2; exit 2; }
[[ -f "$FOREIGN_RUNTIME_ROOT/rexx/foreign.cls" ]] || { echo 'FAIL Foreign Runtime rexx/foreign.cls missing' >&2; exit 2; }

actual_https="$(sha256sum "$HTTPS_ZIP" | awk '{print $1}')"
actual_webdav="$(sha256sum "$WEBDAV_ZIP" | awk '{print $1}')"
[[ "$actual_https" == "$HTTPS_SHA" ]] || { echo "FAIL HTTPS candidate SHA $actual_https" >&2; exit 2; }
[[ "$actual_webdav" == "$WEBDAV_SHA" ]] || { echo "FAIL WebDAV candidate SHA $actual_webdav" >&2; exit 2; }

tmp="$(mktemp -d)"
pids=()
cleanup(){
  for p in "${pids[@]:-}"; do kill "$p" 2>/dev/null || true; done
  for p in "${pids[@]:-}"; do wait "$p" 2>/dev/null || true; done
  rm -rf "$tmp"
}
trap cleanup EXIT

unzip -q "$HTTPS_ZIP" -d "$tmp/https"
unzip -q "$WEBDAV_ZIP" -d "$tmp/webdav"
HTTPS_ROOT="$tmp/https/oorexx_https_server_v0.4.8"
WEBDAV_ROOT="$tmp/webdav/oorexx_webdav_v0.1-dev6"
(cd "$HTTPS_ROOT" && sha256sum -c SHA256SUMS.txt >/dev/null)
(cd "$WEBDAV_ROOT" && sha256sum -c SHA256SUMS.txt >/dev/null)
mkdir -p "$HTTPS_ROOT/vendor"
ln -s "$FOREIGN_RUNTIME_ROOT" "$HTTPS_ROOT/vendor/foreign_runtime_v0.17.1"

echo '== HTTPS v0.4.8 complete suite =='
OOREXX="$OOREXX" timeout 420 bash "$HTTPS_ROOT/tests/run.sh"

echo '== WebDAV dev6 inherited/runtime suite =='
LIBDIR="$OOREXX/lib"; [[ -d "$OOREXX/lib64" ]] && LIBDIR="$OOREXX/lib64"
export LD_LIBRARY_PATH="$FOREIGN_RUNTIME_ROOT/build:$LIBDIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$WEBDAV_ROOT/src:$HTTPS_ROOT/rexx:$FOREIGN_RUNTIME_ROOT/rexx:$WEBDAV_DEP_PATH:$OOREXX/bin${REXX_PATH:+:$REXX_PATH}"
REXX="$REXX" timeout 180 bash "$WEBDAV_ROOT/tests/run.sh"

echo '== Live TLS WebDAV streaming forcing cases =='
command -v curl >/dev/null || { echo 'FAIL curl required' >&2; exit 2; }
command -v openssl >/dev/null || { echo 'FAIL openssl required' >&2; exit 2; }
mkdir -p "$tmp/stage"
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$tmp/server.key" -out "$tmp/server.pem" -days 1 -subj '/CN=localhost' >/dev/null 2>&1
PORT=$((24000 + RANDOM % 12000))
export HTTPS_BRIDGE_DIR="$HTTPS_ROOT/bridge"
"$REXX" "$HERE/live_webdav_streaming_server.rex" "$tmp/server.pem" "$tmp/server.key" "$PORT" "$tmp/stage" >"$tmp/server.log" 2>&1 &
server_pid=$!; pids+=("$server_pid")
for _ in $(seq 1 100); do
  grep -q 'OOREXX_HTTPS_READY' "$tmp/server.log" && break
  kill -0 "$server_pid" 2>/dev/null || { cat "$tmp/server.log" >&2; echo 'FAIL live server exited' >&2; exit 1; }
  sleep 0.1
done
grep -q 'OOREXX_HTTPS_READY' "$tmp/server.log" || { cat "$tmp/server.log" >&2; echo 'FAIL live server not ready' >&2; exit 1; }

dd if=/dev/urandom of="$tmp/large.bin" bs=1048576 count=16 status=none
input_sha="$(sha256sum "$tmp/large.bin" | awk '{print $1}')"
curl -skS --http1.1 -H 'Content-Type: application/octet-stream' -H 'Expect: 100-continue' --data-binary @"$tmp/large.bin" \
  -D "$tmp/put.headers" -o "$tmp/put.body" "https://127.0.0.1:$PORT/dav/data/large.bin"
grep -Eq '^HTTP/1.1 (201 Created|204 No Content)' "$tmp/put.headers" || { cat "$tmp/put.headers" >&2; echo 'FAIL large streaming PUT status' >&2; exit 1; }
echo 'PASS live TLS ordinary PUT exceeds legacy maxBodyBytes'

curl -skS --http1.1 "https://127.0.0.1:$PORT/dav/data/large.bin" -o "$tmp/get.bin"
[[ "$(sha256sum "$tmp/get.bin" | awk '{print $1}')" == "$input_sha" ]] || { echo 'FAIL streamed full GET digest mismatch' >&2; exit 1; }
echo 'PASS live TLS full GET is byte-identical'

mkdir -p "$tmp/concurrent"
cpids=()
for n in $(seq 1 6); do
  (curl -skS --http1.1 "https://127.0.0.1:$PORT/dav/data/large.bin" -o "$tmp/concurrent/$n.bin") & cpids+=("$!")
done
for p in "${cpids[@]}"; do wait "$p"; done
for n in $(seq 1 6); do
  [[ "$(sha256sum "$tmp/concurrent/$n.bin" | awk '{print $1}')" == "$input_sha" ]] || { echo "FAIL concurrent GET $n digest mismatch" >&2; exit 1; }
done
echo 'PASS concurrent GETs are byte-identical'

set +e
{ printf 'PUT /dav/data/aborted.bin HTTP/1.1\r\nHost: localhost\r\nContent-Type: application/octet-stream\r\nContent-Length: 8388608\r\nConnection: close\r\n\r\n'; head -c 524288 /dev/zero; } \
  | timeout 8 openssl s_client -quiet -connect "127.0.0.1:$PORT" >/dev/null 2>&1
set -e
sleep 0.3
code="$(curl -skS --http1.1 -o /dev/null -w '%{http_code}' "https://127.0.0.1:$PORT/dav/data/aborted.bin")"
[[ "$code" == '404' ]] || { echo "FAIL aborted PUT published resource: HTTP $code" >&2; exit 1; }
if find "$tmp/stage" -type f -name '*stage' -size +0c | grep -q .; then
  echo 'FAIL aborted upload left non-empty staging file' >&2
  find "$tmp/stage" -type f -ls >&2
  exit 1
fi
echo 'PASS disconnected PUT leaves no published resource or non-empty stage'

grep -q '^ERROR ' "$tmp/server.log" && { cat "$tmp/server.log" >&2; echo 'FAIL live qualification logged server ERROR' >&2; exit 1; }
echo 'PASS HTTPS v0.4.8 + WebDAV dev6 LIVE STREAMING QUALIFICATION'
