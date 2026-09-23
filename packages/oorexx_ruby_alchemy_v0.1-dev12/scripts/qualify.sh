#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="${TMPDIR:-/tmp}/ruby-alchemy-dev12.$$"; mkdir -p "$TMP"; trap 'rm -rf "$TMP"' EXIT
echo "[1/6] Ruby projection behavior"; ruby "$ROOT/tests/test_ruby_projection.rb"
echo "[2/6] discover ooRexx/Ruby roots"
OREXX_ROOT="${OREXX_ROOT:-}"
if [[ -z "$OREXX_ROOT" ]]; then for r in /usr/local /usr /opt/oorexx; do [[ -f "$r/include/oorexxapi.h" ]] && OREXX_ROOT="$r" && break; done; fi
[[ -n "$OREXX_ROOT" ]] || { echo "Set OREXX_ROOT"; exit 2; }
RUBY_HDR="$(ruby -rrbconfig -e 'print RbConfig::CONFIG["rubyhdrdir"]')"
RUBY_ARCH="$(ruby -rrbconfig -e 'print RbConfig::CONFIG["rubyarchhdrdir"]')"
RUBY_LIBARG="$(ruby -rrbconfig -e 'print RbConfig::CONFIG["LIBRUBYARG_SHARED"]')"
RUBY_LIBS="$(ruby -rrbconfig -e 'print [RbConfig::CONFIG["LIBS"],RbConfig::CONFIG["MAINLIBS"]].join(" ")')"
echo "[3/6] compile resident native package"
CXX="${CXX:-c++}"
# shellcheck disable=SC2086
"$CXX" -std=c++17 -Wall -Wextra -fPIC -shared -I"$OREXX_ROOT/include" -I"$RUBY_HDR" -I"$RUBY_ARCH" "$ROOT/native/ruby_alchemy.cpp" -o "$TMP/libruby_alchemy.so" $RUBY_LIBARG $RUBY_LIBS
REXX="${REXX:-$OREXX_ROOT/bin/rexx}"; [[ -x "$REXX" ]] || REXX="$(command -v rexx)"
echo "[4/6] resident dispatch regression"
LD_LIBRARY_PATH="$TMP:$OREXX_ROOT/lib:${LD_LIBRARY_PATH:-}" "$REXX" "$ROOT/tests/test_native_resident.rex"
LD_LIBRARY_PATH="$TMP:$OREXX_ROOT/lib:${LD_LIBRARY_PATH:-}" REXX_PATH="$ROOT/src/rexx${REXX_PATH:+:$REXX_PATH}" "$REXX" "$ROOT/tests/test_rexx_condition_to_ruby.rex"
LD_LIBRARY_PATH="$TMP:$OREXX_ROOT/lib:${LD_LIBRARY_PATH:-}" REXX_PATH="$ROOT/src/rexx${REXX_PATH:+:$REXX_PATH}" "$REXX" "$ROOT/tests/test_rexx_projection_lifecycle.rex"
echo "[5/6] authoritative Alchemy integration"
: "${ALCHEMY_OBJECTS_SRC:?Set ALCHEMY_OBJECTS_SRC}"; : "${ALCHEMY_FOREIGN_SRC:?Set ALCHEMY_FOREIGN_SRC}"
: "${CRYPTO_SRC:?Set CRYPTO_SRC}"; : "${FOREIGN_SRC:?Set FOREIGN_SRC}"; : "${RUNTIME_REFERENCE_SRC:?Set RUNTIME_REFERENCE_SRC}"
export REXX_PATH="$ROOT/src/rexx:$OREXX_ROOT/bin:$ALCHEMY_FOREIGN_SRC:$ALCHEMY_OBJECTS_SRC:$CRYPTO_SRC:$FOREIGN_SRC:$RUNTIME_REFERENCE_SRC${REXX_PATH:+:$REXX_PATH}"
LD_LIBRARY_PATH="$TMP:$OREXX_ROOT/lib:${LD_LIBRARY_PATH:-}" "$REXX" "$ROOT/tests/test_alchemy_integration.rex"
echo "[6/6] maintainability/static checks"
grep -q 'subclass AlchemyForeignObject' "$ROOT/src/rexx/AlchemyRubyObject.cls"
grep -q 'installForeignUnknownComposition("RUBYUNKNOWN")' "$ROOT/src/rexx/AlchemyRubyObject.cls"
grep -q '"0.1-dev12"' "$ROOT/native/ruby_alchemy.cpp"
! grep -R -E 'popen|Open3|JSON\.generate|JSON\.parse' "$ROOT/src" "$ROOT/native"
echo "QUALIFIED dev12"
