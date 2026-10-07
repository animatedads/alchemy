#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
OREXX="${OREXX:-$HOME/build/oorexx-xcover-safe}"; SRCROOT="${SRCROOT:-$HOME/src/ooRexx}"; HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="/storage/emulated/0/Download/wire-mobile-host-dev17"; LOG="/storage/emulated/0/Download/wire-mobile-host-dev17-build.log"
exec > >(tee "$LOG") 2>&1
echo "=== Wire mobile host dev17 build ==="; date; uname -a
command -v clang++ >/dev/null || { echo "FAIL clang++ missing"; exit 10; }
command -v readelf >/dev/null || { echo "FAIL readelf missing"; exit 11; }
test -f "$OREXX/lib/librexx.so.4" || { echo "FAIL missing librexx.so.4"; exit 13; }
test -f "$OREXX/lib/librexxapi.so.4" || { echo "FAIL missing librexxapi.so.4"; exit 14; }
test -f "$SRCROOT/api/oorexxapi.h" || { echo "FAIL missing oorexxapi.h"; exit 15; }
rm -rf "$OUT"; mkdir -p "$OUT"
clang++ -std=c++17 -O1 -fPIC -shared -I"$SRCROOT/api" -I"$SRCROOT/api/platform/unix" "$HERE/wire_mobile_host_dev17.cpp" -L"$OREXX/lib" -Wl,--no-undefined -Wl,-soname,libwire_mobile_host.so -Wl,-rpath,'$ORIGIN' -Wl,--enable-new-dtags -Wl,-z,max-page-size=16384 -l:librexx.so.4 -l:librexxapi.so.4 -landroid -llog -ldl -o "$OUT/libwire_mobile_host.so"
{ readelf -h "$OUT/libwire_mobile_host.so"; readelf -d "$OUT/libwire_mobile_host.so"; readelf -l "$OUT/libwire_mobile_host.so"; readelf -Ws "$OUT/libwire_mobile_host.so"|grep 'Java_org_oorexx_wire_mobile_WireOoRexxRuntime_native'||true; } > "$OUT/qualification.txt"
cp "$HERE/mobile_main.rex" "$OUT/"; sha256sum "$OUT/libwire_mobile_host.so" "$OUT/mobile_main.rex" > "$OUT/SHA256SUMS"
cd /storage/emulated/0/Download; rm -f wire-mobile-host-dev17.zip wire-mobile-host-dev17.zip.sha256; zip -qr wire-mobile-host-dev17.zip wire-mobile-host-dev17; sha256sum wire-mobile-host-dev17.zip | tee wire-mobile-host-dev17.zip.sha256
echo "READY $OUT"; echo "BUILD LOG $LOG"
