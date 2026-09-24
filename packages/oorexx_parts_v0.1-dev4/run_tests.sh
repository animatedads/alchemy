#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
RT=${REXXTRONICS_ROOT:-"$HERE/deps/rexxtronics_v0.1-dev15"}
UNITS=${OOREXX_UNITS_ROOT:-"$HERE/deps/oorexx_units_v0.1-dev4"}
MATERIALS=${OOREXX_MATERIALS_ROOT:-"$HERE/../oorexx_materials_v0.1-dev3"}
MATHS=${OOREXX_MATHS_ROOT:-"$RT/deps/oorexx_maths_v0.8"}
[ -f "$RT/src/RexxTronicsDC.cls" ] || { echo "missing Rexx-tronics" >&2; exit 2; }
[ -f "$UNITS/rexx/Units.cls" ] || { echo "missing Units" >&2; exit 2; }
[ -d "$MATHS" ] || { echo "missing Maths v0.8" >&2; exit 2; }
[ -f "$MATERIALS/src/MaterialsCatalog.cls" ] || { echo "missing Materials library" >&2; exit 2; }
export REXX_PATH="$HERE/src:$MATERIALS/src:$RT/src:$UNITS/rexx:$MATHS/src:$MATHS/rexx${REXX_PATH:+:$REXX_PATH}"
cd "$HERE/tests"
rexx test_catalog.rex
rexx test_extension_catalog.rex
rexx test_material_references.rex
rexx test_mechanical_families.rex
rexx test_family_catalog.rex
rexx test_rexxtronics_factory.rex
rexx test_units_sanity.rex
rexx test_manufacturing_boundary.rex

rexx test_dev15_parts.rex
