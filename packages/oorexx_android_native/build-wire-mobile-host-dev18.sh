#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
OREXX="${OREXX:-$HOME/build/oorexx-xcover-safe}"
SRCROOT="${SRCROOT:-$HOME/src/ooRexx}"
EXPECTED_COMMIT="${EXPECTED_COMMIT:-135409288aaf8bbd8fe35945bab95fc830b3443d}"
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="/storage/emulated/0/Download/wire-mobile-host-dev18"
LOG="/storage/emulated/0/Download/wire-mobile-host-dev18-build.log"
TMP="${TMPDIR:-$PREFIX/tmp}/wire-mobile-dev18"
mkdir -p "$TMP"
exec > >(tee "$LOG") 2>&1
fail(){ echo "FAIL: $*" >&2; exit 1; }
step(){ echo; echo "==> $*"; }
step environment
date; uname -a
getprop ro.product.cpu.abi 2>/dev/null || true
getprop ro.build.version.release 2>/dev/null || true
getprop ro.build.version.sdk 2>/dev/null || true
echo "OREXX=$OREXX"; echo "SRCROOT=$SRCROOT"
for c in clang++ readelf sha256sum zip; do command -v "$c" >/dev/null || fail "$c missing"; done
test -x "$OREXX/bin/rexx" || fail "missing $OREXX/bin/rexx"
test -f "$OREXX/lib/librexx.so.4" || fail "missing librexx.so.4"
test -f "$OREXX/lib/librexxapi.so.4" || fail "missing librexxapi.so.4"
test -f "$SRCROOT/api/oorexxapi.h" || fail "missing oorexxapi.h"
step 'source provenance'
if test -d "$SRCROOT/.git"; then
 ACTUAL_COMMIT="$(git -C "$SRCROOT" rev-parse HEAD)"; echo "source commit=$ACTUAL_COMMIT"
 test "$ACTUAL_COMMIT" = "$EXPECTED_COMMIT" || fail "ooRexx source revision is not qualified Android revision"
fi
step 'runtime dependency qualification'
readelf -d "$OREXX/lib/librexx.so.4" | tee "$TMP/librexx.dynamic.txt"
grep -q 'libandroid-posix-semaphore.so' "$TMP/librexx.dynamic.txt" || fail 'librexx lacks libandroid-posix-semaphore dependency'
step 'runtime language qualification'
cat > "$TMP/preflight.rex" <<'REXX'
x = 'ok'
a.1 = 'one'
b.foo = 'bar'
addr.!family = 'AF_INET'
if x <> 'ok' then exit 11
if a.1 <> 'one' then exit 12
if b.foo <> 'bar' then exit 13
if addr.!family <> 'AF_INET' then exit 14
parse source platform invocation source
if platform <> 'ANDROID' then exit 15
if .rexxinfo~platform <> 'ANDROID' then exit 16
say 'ANDROID OOREXX PREFLIGHT PASS'
exit 0
REXX
LD_LIBRARY_PATH="$OREXX/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" "$OREXX/bin/rexx" "$TMP/preflight.rex"
step 'build JNI host'
rm -rf "$OUT"; mkdir -p "$OUT"
clang++ -std=c++17 -O1 -fPIC -shared -I"$SRCROOT/api" -I"$SRCROOT/api/platform/unix" "$HERE/wire_mobile_host_dev18.cpp" -L"$OREXX/lib" -Wl,--no-undefined -Wl,-soname,libwire_mobile_host.so -Wl,-rpath,'$ORIGIN' -Wl,--enable-new-dtags -Wl,-z,max-page-size=16384 -l:librexx.so.4 -l:librexxapi.so.4 -landroid -llog -ldl -o "$OUT/libwire_mobile_host.so"
step 'host ELF qualification'
{ readelf -h "$OUT/libwire_mobile_host.so"; readelf -d "$OUT/libwire_mobile_host.so"; readelf -l "$OUT/libwire_mobile_host.so"; readelf -Ws "$OUT/libwire_mobile_host.so" | grep 'Java_org_oorexx_wire_mobile_WireOoRexxRuntime_native'; } | tee "$OUT/qualification.txt"
grep -q 'Java_org_oorexx_wire_mobile_WireOoRexxRuntime_nativeStart' "$OUT/qualification.txt" || fail 'nativeStart JNI export missing'
step 'stage exact APK-native inputs'
cp "$HERE/mobile_main.rex" "$OUT/"
cp "$OREXX/lib/librexx.so.4" "$OUT/"
cp "$OREXX/lib/librexxapi.so.4" "$OUT/"
SEM="$(find "$PREFIX/lib" -maxdepth 1 -name 'libandroid-posix-semaphore.so*' -type f 2>/dev/null | head -1 || true)"
test -n "$SEM" || fail 'cannot locate libandroid-posix-semaphore.so'
cp "$SEM" "$OUT/libandroid-posix-semaphore.so"
CXX="$(find "$PREFIX" -name libc++_shared.so -type f 2>/dev/null | head -1 || true)"
if test -n "$CXX"; then cp "$CXX" "$OUT/libc++_shared.so"; fi
sha256sum "$OUT"/* > "$OUT/SHA256SUMS"
cat > "$OUT/PROVENANCE.txt" <<PROV
ooRexx source commit: $EXPECTED_COMMIT
ooRexx build: $OREXX
Host source: wire_mobile_host_dev18.cpp
Rexx asset: mobile_main.rex
Purpose: APK input bundle; Android -> JNI -> RexxCreateInterpreter -> CallProgram
PROV
step bundle
cd /storage/emulated/0/Download
rm -f wire-mobile-host-dev18.zip wire-mobile-host-dev18.zip.sha256
zip -qr wire-mobile-host-dev18.zip wire-mobile-host-dev18
sha256sum wire-mobile-host-dev18.zip | tee wire-mobile-host-dev18.zip.sha256
echo "READY /storage/emulated/0/Download/wire-mobile-host-dev18.zip"
echo "LOG $LOG"
