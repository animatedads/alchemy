#!/bin/sh
set -eu

PYTHON=${PYTHON:-python3}
CXX=${CXX:-c++}

# Explicit overrides are preferred when supplied.
OOREXX_SRC=${OOREXX_SRC:-"$HOME/src/ooRexx"}
OOREXX_BUILD=${OOREXX_BUILD:-"$HOME/build/oorexx-xcover-safe"}
OOREXX_API=${OOREXX_API:-"$OOREXX_SRC/api"}
OOREXX_PLATFORM_API=${OOREXX_PLATFORM_API:-"$OOREXX_API/platform/unix"}
OOREXX_LIB=${OOREXX_LIB:-"$OOREXX_BUILD/lib"}

# Backward-compatible installed-prefix fallback.
if [ ! -f "$OOREXX_API/oorexxapi.h" ] && [ -n "${OOREXX_PREFIX:-}" ]; then
    OOREXX_API="$OOREXX_PREFIX/include"
    OOREXX_PLATFORM_API="$OOREXX_PREFIX/include"
fi
if [ ! -d "$OOREXX_LIB" ] && [ -n "${OOREXX_PREFIX:-}" ]; then
    OOREXX_LIB="$OOREXX_PREFIX/lib"
fi

[ -f "$OOREXX_API/oorexxapi.h" ] || {
    echo "error: oorexxapi.h not found under $OOREXX_API" >&2
    echo "set OOREXX_SRC, OOREXX_API, or OOREXX_PREFIX" >&2
    exit 2
}
[ -f "$OOREXX_PLATFORM_API/rexxapitypes.h" ] || {
    echo "error: rexxapitypes.h not found under $OOREXX_PLATFORM_API" >&2
    echo "Android/Termux uses the ooRexx api/platform/unix headers." >&2
    exit 2
}
[ -d "$OOREXX_LIB" ] || {
    echo "error: ooRexx library directory not found: $OOREXX_LIB" >&2
    echo "set OOREXX_BUILD, OOREXX_LIB, or OOREXX_PREFIX" >&2
    exit 2
}

EXT=$($PYTHON-config --extension-suffix 2>/dev/null || $PYTHON -c 'import sysconfig; print(sysconfig.get_config_var("EXT_SUFFIX"))')
PY_INCLUDES=$($PYTHON-config --includes)
PY_LDFLAGS=$($PYTHON-config --ldflags)

# Termux/Android requires the extension to carry an explicit DT_NEEDED for
# libpython.  Current Termux python3-config --ldflags supplies -lpythonX.Y.
# On hosts where ordinary --ldflags omits it, ask for embedding flags.
case " $PY_LDFLAGS " in
  *" -lpython"*) : ;;
  *)
    if $PYTHON-config --embed --ldflags >/dev/null 2>&1; then
      EMBED=$($PYTHON-config --embed --ldflags)
      case " $EMBED " in *" -lpython"*) PY_LDFLAGS=$EMBED ;; esac
    fi
    ;;
esac

# Prefer conventional -l names; if this build tree contains only versioned
# libraries, link those exact files instead.
if [ -e "$OOREXX_LIB/librexxapi.so" ]; then REXXAPI_LIB="-lrexxapi";
elif [ -e "$OOREXX_LIB/librexxapi.so.4" ]; then REXXAPI_LIB="-l:librexxapi.so.4";
else REXXAPI_LIB="-lrexxapi"; fi
if [ -e "$OOREXX_LIB/librexx.so" ]; then REXX_LIB="-lrexx";
elif [ -e "$OOREXX_LIB/librexx.so.4" ]; then REXX_LIB="-l:librexx.so.4";
else REXX_LIB="-lrexx"; fi

OUT="python/_rexxpython_poc$EXT"
rm -f "$OUT"

# shellcheck disable=SC2086
$CXX ${CPPFLAGS:-} ${CXXFLAGS:--O2} -fPIC -shared \
  $PY_INCLUDES \
  -I"$OOREXX_API" -I"$OOREXX_PLATFORM_API" \
  native/rexxpython_poc.cpp \
  -L"$OOREXX_LIB" -Wl,-rpath,"$OOREXX_LIB" \
  $REXXAPI_LIB $REXX_LIB \
  $PY_LDFLAGS ${LDFLAGS:-} \
  -o "$OUT"

echo "built $OUT"
echo "ooRexx API:      $OOREXX_API"
echo "ooRexx platform: $OOREXX_PLATFORM_API"
echo "ooRexx libs:     $OOREXX_LIB"

# On Android, unresolved Python C-API symbols cannot be left for the executable.
if command -v readelf >/dev/null 2>&1; then
    echo "native dependencies:"
    readelf -d "$OUT" 2>/dev/null | grep NEEDED || true
    case "$(uname -o 2>/dev/null || true)" in
      Android*)
        if ! readelf -d "$OUT" 2>/dev/null | grep NEEDED | grep -q 'libpython'; then
            echo "error: Android build has no DT_NEEDED libpython; Python C API would fail at dlopen" >&2
            exit 3
        fi
        ;;
    esac
fi
