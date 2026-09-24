#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$HERE/.." && pwd)
RT=${REXXTRONICS_ROOT:-"$ROOT/rexxtronics_v0.1-dev15"}
UNITS=${OOREXX_UNITS_ROOT:-"$ROOT/oorexx_units_v0.1-dev4"}
MATERIALS=${OOREXX_MATERIALS_ROOT:-"$ROOT/oorexx_materials_v0.1-dev4"}
MATHS=${OOREXX_MATHS_ROOT:-"$ROOT/oorexx_maths_v0.8"}
[ -f "$RT/src/RexxTronicsDC.cls" ] || { echo "missing Rexx-tronics at $RT" >&2; exit 2; }
[ -f "$UNITS/rexx/Units.cls" ] || { echo "missing Units at $UNITS" >&2; exit 2; }
[ -d "$MATHS" ] || { echo "missing Maths at $MATHS" >&2; exit 2; }
[ -f "$MATERIALS/src/MaterialsCatalog.cls" ] || { echo "missing Materials at $MATERIALS" >&2; exit 2; }
export REXX_PATH="$HERE/src:$MATERIALS/src:$RT/src:$UNITS/rexx:$MATHS/src:$MATHS/rexx${REXX_PATH:+:$REXX_PATH}"
cd "$HERE/tests"
rexx test_catalog.rex
rexx test_extension_catalog.rex
rexx test_material_references.rex
rexx test_mechanical_families.rex
rexx test_family_catalog.rex
rexx test_dev5_extension.rex
rexx test_rexxtronics_factory.rex
rexx test_units_sanity.rex
rexx test_manufacturing_boundary.rex
rexx test_dev15_parts.rex
echo "ALL TESTS PASSED"
