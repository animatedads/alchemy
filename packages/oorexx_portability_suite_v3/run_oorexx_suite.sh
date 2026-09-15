#!/data/data/com.termux/files/usr/bin/bash
#
# Convenience runner for Termux/Linux.  The .rex files themselves are the
# portable part; this wrapper only supplies the Android build-tree paths.
#
set -euo pipefail

HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

if [ -n "${REXX:-}" ]; then
    REXX_BIN="$REXX"
elif [ -x "$HOME/bin/rexx-xcover" ]; then
    REXX_BIN="$HOME/bin/rexx-xcover"
elif command -v rexx >/dev/null 2>&1; then
    REXX_BIN="$(command -v rexx)"
elif [ -x "$HOME/build/oorexx-xcover-safe/bin/rexx" ]; then
    REXX_BIN="$HOME/build/oorexx-xcover-safe/bin/rexx"
else
    echo "Cannot find ooRexx. Set REXX=/path/to/rexx." >&2
    exit 2
fi

if [ -d "$HOME/build/oorexx-xcover-safe/lib" ]; then
    export LD_LIBRARY_PATH="$HOME/build/oorexx-xcover-safe/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

add_rexx_path() {
    [ -d "$1" ] || return 0
    if [ -n "${REXX_PATH:-}" ]; then
        REXX_PATH="$1:$REXX_PATH"
    else
        REXX_PATH="$1"
    fi
}

add_rexx_path "$HERE"
add_rexx_path "$HOME/build/oorexx-xcover-safe/bin"
add_rexx_path "$HOME/src/ooRexx/extensions/csvStream"
add_rexx_path "$HOME/src/ooRexx/extensions/yaml"
export REXX_PATH

case "${1:-suite}" in
    suite)
        exec "$REXX_BIN" "$HERE/oorexx_portability_suite.rex"
        ;;
    flops)
        shift || true
        exec "$REXX_BIN" "$HERE/rexxflops.rex" "$@"
        ;;
    *)
        echo "Usage: $0 [suite | flops [seconds-per-trial]]" >&2
        exit 2
        ;;
esac
