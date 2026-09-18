#!/usr/bin/env bash
set -euo pipefail
: "${UNIX_SOCKET_SRC:?UNIX_SOCKET_SRC is required}"
: "${FOREIGN_RUNTIME_SRC:?FOREIGN_RUNTIME_SRC is required}"
: "${REXX_BIN:=rexx}"
ROOT=$(cd "$(dirname "$0")/.." && pwd)
SOCK=$(mktemp -u /tmp/storage-fuse-rpc-test.XXXXXX.sock)
LOG=$(mktemp /tmp/storage-fuse-rpc-test.XXXXXX.log)
export REXX_PATH="$FOREIGN_RUNTIME_SRC/rexx:$UNIX_SOCKET_SRC${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$FOREIGN_RUNTIME_SRC/build${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
cd "$ROOT"
"$REXX_BIN" bin/storage-fuse-rpcd.rex "$SOCK" >"$LOG" 2>&1 &
pid=$!
cleanup(){ kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; rm -f "$SOCK" "$LOG"; }
trap cleanup EXIT
for _ in {1..100}; do [[ -S "$SOCK" ]] && break; sleep .05; done
[[ -S "$SOCK" ]] || { cat "$LOG" >&2; exit 1; }
[[ "$(stat -c '%a' "$SOCK")" == 600 ]] || { echo "RPC socket is not mode 0600" >&2; exit 1; }
python3 - "$SOCK" <<'PY'
import socket,sys
p=sys.argv[1]
def h(s): return s.encode().hex().upper()
def q(*fields):
    s=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM); s.connect(p)
    s.sendall(('\t'.join(map(str,fields))+'\n').encode())
    b=b''
    while b'\n' not in b:
        x=s.recv(65536)
        if not x: break
        b+=x
    s.close(); return b.decode().rstrip('\r\n').split('\t')
r=q('SF1','PING'); assert r[:2]==['SF1','0'] and bytes.fromhex(r[2])==b'PONG',r
assert q('SF1','MKDIR',h('/it'))[1]=='0'
r=q('SF1','CREATE',h('/it/a'),h('RW')); assert r[1]=='0',r; fh=bytes.fromhex(r[2]).decode()
r=q('SF1','WRITE',h(fh),0,h('abc')); assert r[1]=='0' and r[2]=='3',r
assert q('SF1','RELEASE',h(fh))[1]=='0'
r=q('SF1','READDIR',h('/it')); assert r[1]=='0' and r[2]=='1' and bytes.fromhex(r[3])==b'a',r
PY
echo "PASS FUSE RPC daemon over ooRexx Unix Socket"