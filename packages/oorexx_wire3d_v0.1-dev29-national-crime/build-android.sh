#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/android-env.sh"
command -v clang++ >/dev/null || { echo 'Install Termux clang: pkg install clang' >&2; exit 2; }
[ -f "$PREFIX/lib/libcrypto.so" ] || { echo 'Termux OpenSSL missing: pkg install openssl' >&2; exit 2; }
[ -f "$PREFIX/include/ffi.h" ] || { echo 'Termux libffi missing: pkg install libffi' >&2; exit 2; }
[ -f "$OOREXX_INCLUDE/oorexxapi.h" ] || { echo "Missing $OOREXX_INCLUDE/oorexxapi.h" >&2; exit 2; }
[ -d "$OOREXX_LIB" ] || { echo "Missing ooRexx library directory $OOREXX_LIB" >&2; exit 2; }
FR="$(find "$HERE/vendor/oorexx_foreign_runtime_v0.22.6" -type f -name foreign_runtime.cpp -printf '%h\n' -quit)/.."
FR="$(cd "$FR" && pwd)"
mkdir -p "$FR/build"
clang++ -std=c++17 -O2 -fPIC -Wall -Wextra -I"$OOREXX_INCLUDE" -I"$OOREXX_PLATFORM_INCLUDE" -shared -o "$FR/build/libforeign_runtime.so" "$FR/src/foreign_runtime.cpp" -ldl -lffi
CR="$(find "$HERE/vendor/oorexx_crypto_v0.8.3" -type f -name crypto_compat.c -printf '%h\n' -quit)"
CC=clang CFLAGS='-O2 -fPIC -Wall -Wextra -Wpedantic' "$CR/build_crypto_compat.sh"
if command -v readelf >/dev/null 2>&1; then
  readelf -h "$FR/build/libforeign_runtime.so" | grep -E 'Class:|Machine:' || true
  readelf -h "$CR/libcrypto_compat.so" | grep -E 'Class:|Machine:' || true
fi
printf 'Android native build complete. OpenSSL direct provider resolves %s/lib/libcrypto.so\n' "$PREFIX"
