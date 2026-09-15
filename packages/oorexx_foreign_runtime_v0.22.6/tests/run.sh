#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
MODE="auto"
case "${1:-}" in
  "") ;;
  --mode=auto) MODE=auto ;;
  --mode=source) MODE=source ;;
  --mode=binary) MODE=binary ;;
  *) echo "usage: $0 [--mode=auto|--mode=source|--mode=binary]" >&2; exit 2 ;;
esac

OOREXX="${OOREXX:-}"
if [[ -z "$OOREXX" ]]; then
  if command -v rexx >/dev/null 2>&1; then
    REXX_BIN="$(command -v rexx)"
    OOREXX="$(cd "$(dirname "$REXX_BIN")/.." && pwd)"
  else
    echo "FAIL: ooRexx not found; set OOREXX to its installation prefix" >&2
    exit 2
  fi
fi
REXX="$OOREXX/bin/rexx"
[[ -x "$REXX" ]] || { echo "FAIL: no executable $REXX" >&2; exit 2; }

HAVE_HEADERS=0
[[ -f "$OOREXX/include/oorexxapi.h" ]] && HAVE_HEADERS=1
HAVE_CXX=0
command -v "${CXX:-g++}" >/dev/null 2>&1 && HAVE_CXX=1

BUILT=0
if [[ "$MODE" == source || ( "$MODE" == auto && $HAVE_HEADERS -eq 1 && $HAVE_CXX -eq 1 ) ]]; then
  if [[ $HAVE_HEADERS -ne 1 ]]; then echo "FAIL: source mode requires $OOREXX/include/oorexxapi.h" >&2; exit 2; fi
  if [[ $HAVE_CXX -ne 1 ]]; then echo "FAIL: source mode requires a C++ compiler" >&2; exit 2; fi
  make -C "$ROOT" clean all OOREXX="$OOREXX"
  BUILT=1
else
  [[ -f "$ROOT/build/libforeign_runtime.so" ]] || { echo "FAIL: no prebuilt runtime at $ROOT/build/libforeign_runtime.so" >&2; exit 2; }
  [[ -f "$ROOT/examples/libforeign_test.so" ]] || { echo "FAIL: no prebuilt test library at $ROOT/examples/libforeign_test.so" >&2; exit 2; }
  [[ -f "$ROOT/examples/libtensor_probe.so" ]] || { echo "FAIL: no prebuilt tensor probe at $ROOT/examples/libtensor_probe.so" >&2; exit 2; }
fi

cd "$HERE"
LIBDIR="$OOREXX/lib"
[[ -d "$OOREXX/lib64" ]] && LIBDIR="$OOREXX/lib64"
export LD_LIBRARY_PATH="$ROOT/build:$ROOT/examples:$LIBDIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
"$REXX" test_threads.rex
"$REXX" test.rex
"$REXX" test_i8_u8_v0224.rex
"$REXX" test_abi_profile_v0225.rex
"$REXX" test_abi_native_scalars_v0226.rex
"$REXX" test_managed_struct_graph_v0223.rex
"$REXX" test_names.rex
"$REXX" test_unknown.rex
"$REXX" test_serialized.rex
"$REXX" test_callback_thread_policy.rex
if [[ "$(uname -s)" != "Windows_NT" ]]; then "$REXX" test_pty.rex; else echo "OPTIONAL PTY SKIP reason=non-posix"; fi
if [[ "$(uname -s)" != "Windows_NT" && -f "$ROOT/examples/libforeign_vulkan.so" ]] && (ldconfig -p 2>/dev/null | grep -q "libvulkan.so.1" || [[ -e /lib64/libvulkan.so.1 || -e /usr/lib64/libvulkan.so.1 || -e /lib/x86_64-linux-gnu/libvulkan.so.1 ]]); then
  set +e
  "$REXX" test_vulkan_hardware.rex
  VKRC=$?
  set -e
  if [[ $VKRC -ne 0 && $VKRC -ne 77 ]]; then exit $VKRC; fi
else
  echo "OPTIONAL Vulkan-hardware SKIP reason=provider-or-loader-unavailable"
fi
if [[ -f "$ROOT/build/libforeign_python.so" ]] && command -v python3 >/dev/null 2>&1; then
  export PYTHONPATH="$HERE${PYTHONPATH:+:$PYTHONPATH}"
  "$REXX" test_python_provider.rex
  "$REXX" test_python_provider_v016.rex
  "$REXX" test_python_provider_v017.rex
  "$REXX" test_python_provider_v018.rex
  "$REXX" test_python_proxy_args_v0221.rex
  "$REXX" test_python_indexing_v0222.rex
  if "$REXX" probe_python_import.rex numpy >/dev/null 2>&1; then "$REXX" test_python_numpy_zero_copy.rex; "$REXX" test_python_numpy_import_v018.rex; else echo "OPTIONAL NumPy-zero-copy/import SKIP reason=numpy-not-importable-by-embedded-python"; fi
  if "$REXX" probe_python_import.rex numpy >/dev/null 2>&1; then "$REXX" test_python_tensor_native_v020.rex; "$REXX" test_python_tensor_native_threads_v020.rex; if "$REXX" probe_python_import.rex torch >/dev/null 2>&1; then "$REXX" test_python_tensor_v019.rex; else echo "OPTIONAL Python-DLPack Torch SKIP reason=torch-not-importable-by-embedded-python"; fi; else echo "OPTIONAL native-tensor SKIP reason=numpy-not-importable-by-embedded-python"; fi
  if "$REXX" probe_python_import.rex numpy >/dev/null 2>&1; then "$REXX" test_tensor_device_v021.rex; "$REXX" test_python_tensor_native_threads_v020.rex; if "$REXX" probe_python_import.rex torch >/dev/null 2>&1; then "$REXX" test_python_tensor_v019.rex; else echo "OPTIONAL Python-DLPack Torch SKIP reason=torch-not-importable-by-embedded-python"; fi; else echo "OPTIONAL native-tensor SKIP reason=numpy-not-importable-by-embedded-python"; fi
  "$REXX" test_python_threads.rex
else
  echo "OPTIONAL Python-provider SKIP reason=provider-not-built-or-python-missing"
fi

OPENSSL_AVAILABLE=0
if command -v ldconfig >/dev/null 2>&1 && ldconfig -p 2>/dev/null | grep -qE "libcrypto\.so(\.3)?"; then OPENSSL_AVAILABLE=1; fi
if [[ $OPENSSL_AVAILABLE -eq 0 ]]; then
  for d in /lib /lib64 /usr/lib /usr/lib64 /lib/x86_64-linux-gnu /usr/lib/x86_64-linux-gnu; do
    [[ -e "$d/libcrypto.so.3" || -e "$d/libcrypto.so" ]] && OPENSSL_AVAILABLE=1 && break
  done
fi
if [[ $OPENSSL_AVAILABLE -eq 1 ]]; then
  (cd optional && "$REXX" test_openssl.rex)
  (cd optional && "$REXX" test_openssl_sha256.rex)
  (cd optional && "$REXX" test_openssl_sha256_auto.rex)
  (cd optional && "$REXX" test_openssl_sha_oneshot.rex)
else
  echo "OPTIONAL OpenSSL SKIP reason=libcrypto-not-discovered"
  echo "OPTIONAL OpenSSL-EVP-SHA256 SKIP reason=libcrypto-not-discovered"
  echo "OPTIONAL OpenSSL-EVP-SHA256-AUTO SKIP reason=libcrypto-not-discovered"
  echo "OPTIONAL OpenSSL-ONESHOT-SHA SKIP reason=libcrypto-not-discovered"
fi

FFMPEG_AVAILABLE=0
if command -v ldconfig >/dev/null 2>&1 && ldconfig -p 2>/dev/null | grep -qE "libavformat\.so(\.61)?"; then FFMPEG_AVAILABLE=1; fi
if [[ $FFMPEG_AVAILABLE -eq 0 ]]; then
  for d in /lib /lib64 /usr/lib /usr/lib64 /lib/x86_64-linux-gnu /usr/lib/x86_64-linux-gnu; do
    [[ -e "$d/libavformat.so.61" || -e "$d/libavformat.so" ]] && FFMPEG_AVAILABLE=1 && break
  done
fi
if [[ $FFMPEG_AVAILABLE -eq 1 ]]; then
  (cd optional && "$REXX" test_ffmpeg_avformat.rex)
  (cd optional && "$REXX" test_ffmpeg_channel_layout.rex)
  (cd optional && "$REXX" test_ffmpeg_planar.rex)
else
  echo "OPTIONAL FFmpeg-avformat SKIP reason=libavformat-not-discovered"
  echo "OPTIONAL FFmpeg-channel-layout SKIP reason=libavformat-not-discovered"
  echo "OPTIONAL FFmpeg-planar SKIP reason=libavformat-not-discovered"
fi

if [[ $BUILT -eq 1 ]]; then
  echo "QUALIFICATION source-built interpreter=$($REXX -v 2>&1 | head -n 1)"
else
  echo "QUALIFICATION prebuilt-binary interpreter=$($REXX -v 2>&1 | head -n 1)"
  if [[ $HAVE_HEADERS -eq 0 ]]; then echo "SOURCE_BUILD not-tested reason=missing-oorexxapi.h"; fi
fi
