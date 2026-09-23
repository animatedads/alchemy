#!/bin/sh
set -eu

BUILD_TARGET=${BUILD_TARGET:-android}
PYTHON=${PYTHON:-python3}
CXX=${CXX:-c++}

case "$BUILD_TARGET" in
  android)
    OOREXX_SRC=${OOREXX_SRC:-"$HOME/src/ooRexx"}
    OOREXX_BUILD=${OOREXX_BUILD:-"$HOME/build/oorexx-xcover-safe"}
    OOREXX_API=${OOREXX_API:-"$OOREXX_SRC/api"}
    OOREXX_PLATFORM_API=${OOREXX_PLATFORM_API:-"$OOREXX_API/platform/unix"}
    OOREXX_LIB=${OOREXX_LIB:-"$OOREXX_BUILD/lib"}
    ;;
  host)
    if [ -n "${OOREXX_PREFIX:-}" ]; then
      OOREXX_API=${OOREXX_API:-"$OOREXX_PREFIX/include"}
      OOREXX_PLATFORM_API=${OOREXX_PLATFORM_API:-"$OOREXX_PREFIX/include"}
      OOREXX_LIB=${OOREXX_LIB:-"$OOREXX_PREFIX/lib"}
    else
      OOREXX_API=${OOREXX_API:-"/usr/include"}
      OOREXX_PLATFORM_API=${OOREXX_PLATFORM_API:-"$OOREXX_API"}
      if [ -d /usr/lib64 ] && ls /usr/lib64/librexx* >/dev/null 2>&1; then
        OOREXX_LIB=${OOREXX_LIB:-"/usr/lib64"}
      else
        OOREXX_LIB=${OOREXX_LIB:-"/usr/lib"}
      fi
    fi
    ;;
  *)
    echo "error: BUILD_TARGET must be android or host" >&2
    exit 2
    ;;
esac

[ -f "$OOREXX_API/oorexxapi.h" ] || {
  echo "error: oorexxapi.h not found under $OOREXX_API" >&2
  echo "set OOREXX_API/OOREXX_PREFIX (BUILD_TARGET=$BUILD_TARGET)" >&2
  exit 2
}
[ -f "$OOREXX_PLATFORM_API/rexxapitypes.h" ] || {
  echo "error: rexxapitypes.h not found under $OOREXX_PLATFORM_API" >&2
  exit 2
}
[ -d "$OOREXX_LIB" ] || {
  echo "error: ooRexx library directory not found: $OOREXX_LIB" >&2
  exit 2
}

PYCONFIG=${PYCONFIG:-"$PYTHON-config"}
EXT=$($PYCONFIG --extension-suffix 2>/dev/null || $PYTHON -c 'import sysconfig; print(sysconfig.get_config_var("EXT_SUFFIX"))')
PY_INCLUDES=$($PYCONFIG --includes)
PY_LDFLAGS=$($PYCONFIG --ldflags)
case " $PY_LDFLAGS " in
  *" -lpython"*) : ;;
  *) if $PYCONFIG --embed --ldflags >/dev/null 2>&1; then
       EMBED=$($PYCONFIG --embed --ldflags)
       case " $EMBED " in *" -lpython"*) PY_LDFLAGS=$EMBED ;; esac
     fi ;;
esac

if [ -e "$OOREXX_LIB/librexxapi.so" ]; then REXXAPI_LIB="-lrexxapi"
elif [ -e "$OOREXX_LIB/librexxapi.so.4" ]; then REXXAPI_LIB="-l:librexxapi.so.4"
else REXXAPI_LIB="-lrexxapi"; fi
if [ -e "$OOREXX_LIB/librexx.so" ]; then REXX_LIB="-lrexx"
elif [ -e "$OOREXX_LIB/librexx.so.4" ]; then REXX_LIB="-l:librexx.so.4"
else REXX_LIB="-lrexx"; fi

OUT="python/_rexxpython_poc$EXT"
rm -f "$OUT"
# shellcheck disable=SC2086
$CXX ${CPPFLAGS:-} ${CXXFLAGS:--O2} -fPIC -shared \
  $PY_INCLUDES -I"$OOREXX_API" -I"$OOREXX_PLATFORM_API" \
  native/rexxpython_poc.cpp \
  -L"$OOREXX_LIB" -Wl,-rpath,"$OOREXX_LIB" \
  $REXXAPI_LIB $REXX_LIB $PY_LDFLAGS ${LDFLAGS:-} -o "$OUT"

echo "built $OUT"
echo "build target:    $BUILD_TARGET"
echo "ooRexx API:      $OOREXX_API"
echo "ooRexx platform: $OOREXX_PLATFORM_API"
echo "ooRexx libs:     $OOREXX_LIB"

if command -v readelf >/dev/null 2>&1; then
  echo "native dependencies:"
  readelf -d "$OUT" 2>/dev/null | grep NEEDED || true
  if [ "$BUILD_TARGET" = android ]; then
    if ! readelf -d "$OUT" 2>/dev/null | grep NEEDED | grep -q 'libpython'; then
      echo "error: Android build has no DT_NEEDED libpython" >&2
      exit 3
    fi
  fi
fi
