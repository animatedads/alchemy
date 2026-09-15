#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/build.sh >/dev/null
exec java -jar build/federationbank-atm.jar --transport=demo "$@"
