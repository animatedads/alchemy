#!/bin/sh
# kit.sh -- run ooRexx with the browser UI kit's paths:  bin/kit.sh rexx some.rex [args]
# Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 8 November 2026.
# Machine-specific locations live in var/kit.env (copy etc/kit.env.example there).
KIT=$(cd "$(dirname "$0")/.." && pwd)
if [ ! -f "$KIT/var/kit.env" ]; then
  echo "kit.sh: no $KIT/var/kit.env -- copy etc/kit.env.example there and set the paths" >&2
  exit 2
fi
set -a
. "$KIT/var/kit.env"
set +a
P=$ALCHEMY_PACKAGES
export KIT CHROME CHROME_FLAGS BROWSER_PROFILES AGENT_REQUESTED_BY AGENT_CONTACT BOSTON_CRAB_DIR
export REXX_PATH="$KIT/src:$KIT/fixtures:$P/oorexx_websocket_access/src:$P/oorexx_socket_provider/src:$P/oorexx_crypto_auth/src:$P/oorexx_crypto_v0.8.3/src:$P/oorexx_https_server/rexx:$P/oorexx_logging_v0.7/src:$P/legal_effect_v0.14/src:$P/alchemy_objects_v0.8/src:$FOREIGN_RUNTIME_REXX:$OOREXX_CLS${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$FOREIGN_RUNTIME_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "$@"
