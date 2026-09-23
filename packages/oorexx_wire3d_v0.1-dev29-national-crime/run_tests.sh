#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/android-env.sh"
MATHROOT="$HERE/.runtime/maths"
rm -rf "$MATHROOT"; mkdir -p "$MATHROOT"
unzip -q "$HERE/dependencies/oorexx_maths_v0.8.zip" -d "$MATHROOT"
export REXX_PATH="$HERE/src:$HERE/dependencies/crime_area_analytics:$MATHROOT/oorexx_maths_v0.8/rexx:${REXX_PATH:-}"
REXX="${REXX:-$OOREXX_BUILD/bin/rexx}"
[ -x "$REXX" ] || { echo "ooRexx executable not found: $REXX" >&2; exit 2; }
"$REXX" "$HERE/tests/test_core.rex"
"$REXX" "$HERE/tests/test_3d_space_app.rex"
"$REXX" "$HERE/tests/test_presentation.rex"
"$REXX" "$HERE/tests/test_generic_presentation.rex"
"$REXX" "$HERE/tests/test_3d_space_composition.rex"
"$REXX" "$HERE/tests/test_mail_spatial_equivalence.rex"
"$REXX" "$HERE/tests/test_maths3d_integration.rex"
if command -v node >/dev/null 2>&1; then
  node --check "$HERE/web/wire3d.js"
  python "$HERE/tests/test_presentation_static.py"
  node "$HERE/tests/test_renderer_math.mjs"
  [ ! -f "$HERE/web/wire3d-live.js" ] || node --check "$HERE/web/wire3d-live.js"
fi
echo 'Wire3D phone Rexx tests: PASS'
