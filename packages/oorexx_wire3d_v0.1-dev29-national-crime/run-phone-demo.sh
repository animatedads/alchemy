#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/android-env.sh"
MATHROOT="$HERE/.runtime/maths"
HTTPSROOT="$HERE/.runtime/https"
FOREIGNROOT="$HERE/.runtime/foreign"
[ -f "$MATHROOT/oorexx_maths_v0.8/rexx/Maths.cls" ] || { mkdir -p "$MATHROOT"; unzip -q "$HERE/dependencies/oorexx_maths_v0.8.zip" -d "$MATHROOT"; }
[ -f "$HTTPSROOT/oorexx_https_server_v0.4.5-http/rexx/https_server.cls" ] || { mkdir -p "$HTTPSROOT"; unzip -q "$HERE/dependencies/oorexx_https_server_v0.4.5-http.zip" -d "$HTTPSROOT"; }
[ -f "$FOREIGNROOT/oorexx_foreign_runtime_v0.22.6/rexx/foreign.cls" ] || { mkdir -p "$FOREIGNROOT"; unzip -q "$HERE/dependencies/oorexx_foreign_runtime_v0.22.6.zip" -d "$FOREIGNROOT"; }
export REXX_PATH="$HERE/src:$MATHROOT/oorexx_maths_v0.8/rexx:$HTTPSROOT/oorexx_https_server_v0.4.5-http/rexx:$FOREIGNROOT/oorexx_foreign_runtime_v0.22.6/rexx:${REXX_PATH:-}"
export WIRE3D_SCENE_OUT="$HERE/web/scene.json"
DEMO="${WIRE3D_DEMO:-crime}"
if [ "$DEMO" = "corporate" ]; then rexx "$HERE/examples/corporate_city.rex"; else rexx "$HERE/examples/crime_enterprise_space.rex"; fi
[ -s "$HERE/web/scene.json" ] || { echo 'scene generation failed' >&2; exit 3; }
grep -q '"trackingField"' "$HERE/web/scene.json" || { echo 'tracking field missing from generated scene' >&2; exit 4; }
echo 'Wire3D: ooRexx HTTPS Server running in HTTP mode at http://127.0.0.1:8080/'
echo 'Tracking field: wire3d-tracking/1 seed=4A91C37D'
exec rexx "$HERE/server/wire3d_http_server.rex" "$HERE/web" 8080
