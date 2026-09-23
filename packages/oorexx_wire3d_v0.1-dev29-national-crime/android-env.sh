#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
# Rust dev27 established explicit ooRexx discovery rather than standard Linux paths.
export OOREXX_SRC="${OOREXX_SRC:-$HOME/src/ooRexx}"
export OOREXX_BUILD="${OOREXX_BUILD:-$HOME/build/oorexx-xcover-safe}"
export OOREXX_INCLUDE="${OOREXX_INCLUDE:-$OOREXX_SRC/api}"
export OOREXX_PLATFORM_INCLUDE="${OOREXX_PLATFORM_INCLUDE:-$OOREXX_INCLUDE/platform/unix}"
export OOREXX_LIB="${OOREXX_LIB:-$OOREXX_BUILD/lib}"
export PATH="$OOREXX_BUILD/bin:$PREFIX/bin:$PATH"
export LD_LIBRARY_PATH="$OOREXX_LIB:$PREFIX/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
# Termux OpenSSL is authoritative native SSL/crypto. Never use bundled x86 .so files.
export OPENSSL_ROOT_DIR="$PREFIX"
export OPENSSL_INCLUDE_DIR="$PREFIX/include"
export OPENSSL_LIB_DIR="$PREFIX/lib"
# Build a package-local Rexx search path from every extracted dependency source/rexx directory.
paths=("$HERE/src")
while IFS= read -r d; do paths+=("$d"); done < <(find "$HERE/vendor" -type d \( -name src -o -name rexx \) | sort)
export REXX_PATH="$(IFS=:; echo "${paths[*]}")${REXX_PATH:+:$REXX_PATH}"
export WIRE3D_HOME="$HERE"
printf 'Wire3D Android environment\nPREFIX=%s\nOOREXX_BUILD=%s\nOOREXX_LIB=%s\nOPENSSL_LIB_DIR=%s\n' "$PREFIX" "$OOREXX_BUILD" "$OOREXX_LIB" "$OPENSSL_LIB_DIR"
