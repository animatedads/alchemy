#!/bin/sh
set -eu
say(){ printf '%s\n' "$*"; }
die(){ say "ERROR: $*" >&2; exit 1; }
api=${OOREXX_INCLUDE:-}; lib=${OOREXX_LIB:-}; src=${OOREXX_SOURCE_ROOT:-}; bld=${OOREXX_BUILD_ROOT:-${OOREXX_ROOT:-${OOREXX_PREFIX:-}}}
if [ -n "$bld" ] && [ -f "$bld/CMakeCache.txt" ] && [ -z "$src" ]; then src=$(sed -n 's/^CMAKE_HOME_DIRECTORY:INTERNAL=//p' "$bld/CMakeCache.txt" | head -n 1); fi
find_api(){ for d in "$@"; do [ -n "$d" ] || continue; for x in "$d" "$d/api" "$d/include"; do [ -f "$x/oorexxapi.h" ] && { printf '%s\n' "$x"; return; }; done; done; return 1; }
find_lib(){ for d in "$@"; do [ -n "$d" ] || continue; for x in "$d" "$d/lib" "$d/lib64"; do { [ -e "$x/librexx.so" ] || [ -e "$x/librexx.so.4" ]; } && { printf '%s\n' "$x"; return; }; done; done; return 1; }
rexx_bin=$(command -v rexx 2>/dev/null || true); rexx_parent=; if [ -n "$rexx_bin" ]; then rexx_parent=$(dirname "$(dirname "$rexx_bin")"); fi
home=${HOME:-}; prefix=${PREFIX:-}
[ -n "$api" ] || api=$(find_api "$src" "$bld" "$home/src/ooRexx" "$home/src/oorexx" "$rexx_parent" "$prefix" /usr/local /usr 2>/dev/null || true)
[ -n "$lib" ] || lib=$(find_lib "$bld" "$rexx_parent" "$prefix" "$home/build/oorexx-xcover-safe" "$home/build/oorexx" /usr/local /usr 2>/dev/null || true)
[ -f "$api/oorexxapi.h" ] || die "oorexxapi.h not found. Set OOREXX_SOURCE_ROOT or OOREXX_INCLUDE."
platform_inc=; case "$(uname -s 2>/dev/null || echo unknown)" in Linux|Android|Darwin|FreeBSD|OpenBSD|NetBSD) platform_inc="$api/platform/unix" ;; esac
[ -f "$platform_inc/rexxapitypes.h" ] || die "rexxapitypes.h not found at $platform_inc. Set OOREXX_INCLUDE to the ooRexx api directory."
{ [ -e "$lib/librexx.so" ] || [ -e "$lib/librexx.so.4" ]; } || die "librexx.so not found. Set OOREXX_BUILD_ROOT or OOREXX_LIB."
cxx=${CXX:-}; if [ -z "$cxx" ]; then for x in clang++ c++ g++; do if command -v "$x" >/dev/null 2>&1; then cxx=$x; break; fi; done; fi
[ -n "$cxx" ] || die "no C++ compiler found"
platform=$(uname -s 2>/dev/null || echo unknown); case "$platform:${PREFIX:-}" in Linux:/data/data/com.termux/*) platform="Android/Termux";; esac
say "ooRexx API:       $api"; say "ooRexx platform:  $platform_inc"; say "ooRexx library:   $lib"; say "compiler:         $cxx"; say "platform:         $platform"
mkdir -p build
for source in alchemy_rexx_bridge alchemy_clr_package; do $cxx ${CPPFLAGS:-} ${CXXFLAGS:-} -std=c++17 -fPIC -shared "native/$source.cpp" -I"$api" -I"$platform_inc" -L"$lib" -Wl,-rpath,"$lib" ${LDFLAGS:-} -lrexx -o "build/lib$source.so"; done
say "native-build-ok"
