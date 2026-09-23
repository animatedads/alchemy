#!/bin/sh
set -eu
: "${REXX:=rexx}"
: "${FOREIGN_RUNTIME_ROOT:?set FOREIGN_RUNTIME_ROOT to ooRexx Foreign Runtime package root}"
cd "$(dirname "$0")"
rm -rf work-foreign-zstd
mkdir work-foreign-zstd

libzstd=$(ldconfig -p 2>/dev/null | awk '/libzstd\.so\.1 .*=>/ {print $NF; exit}')
if [ -z "${libzstd:-}" ] || [ ! -f "$libzstd" ]; then
  echo 'SKIP: libzstd.so.1 not discoverable by qualification host'
  exit 0
fi
sed "s#\"path\": \"libzstd.so.1\"#\"path\": \"$libzstd\"#" ../foreign/libzstd.bridge.json > work-foreign-zstd/libzstd.bridge.json

old_rexx_path=${REXX_PATH-}
export REXX_PATH="../src:../foreign:$FOREIGN_RUNTIME_ROOT/rexx${old_rexx_path:+:$old_rexx_path}"
old_ld=${LD_LIBRARY_PATH-}
export LD_LIBRARY_PATH="$FOREIGN_RUNTIME_ROOT/build${old_ld:+:$old_ld}"

"$REXX" ./test_foreign_provider.rex "$PWD/work-foreign-zstd/libzstd.bridge.json" "$PWD/work-foreign-zstd/foreign.zst"
zstd -t work-foreign-zstd/foreign.zst >/dev/null
zstd -lv work-foreign-zstd/foreign.zst 2>&1 | grep -q 'Check: XXH64'
echo 'PASS Foreign Runtime/libzstd reference-tool interoperability'
