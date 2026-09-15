#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${OOREXX_LOCAL:?set OOREXX_LOCAL to extracted ooRexx /usr/local root}"
: "${BSF4OOREXX_HOME:?set BSF4OOREXX_HOME to extracted bsf4oorexx root}"
: "${BSF4OOREXX_LOCAL_LIB:?set BSF4OOREXX_LOCAL_LIB to directory containing libBSF4ooRexx850.so}"
JAVA_HOME="${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")}" 
export PATH="$OOREXX_LOCAL/bin:$PATH"
"$ROOT/scripts/build.sh"
export LD_LIBRARY_PATH="$BSF4OOREXX_LOCAL_LIB:$OOREXX_LOCAL/lib:$JAVA_HOME/lib/server:${LD_LIBRARY_PATH:-}"
export CLASSPATH="$BSF4OOREXX_HOME/lib/bsf4ooRexx-v850-20260326-bin.jar:$ROOT/build/wire-ui-swing-v0.2-dev3.jar${CLASSPATH:+:$CLASSPATH}"
export REXX_PATH="$ROOT/integration:$BSF4OOREXX_HOME${REXX_PATH:+:$REXX_PATH}"
export BSF4Rexx_JavaStartupOptions="-Djava.awt.headless=false"
if command -v xvfb-run >/dev/null 2>&1; then
  exec xvfb-run -a rexx "$ROOT/integration/test_bsf_desktop_window.rex"
fi
exec rexx "$ROOT/integration/test_bsf_desktop_window.rex"
