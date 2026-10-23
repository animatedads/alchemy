#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"
REPO=/tmp/osc-cli-test
rm -rf "$REPO"

bin/osc baseline tests/fixtures/provider_v1 --repo "$REPO" --component DataStore --level 1 >/tmp/osc-cli-baseline1.txt
TP=$(cut -d'|' -f1 "$REPO/proposals.osc")
bin/osc proposal accept "$TP" --repo "$REPO" --reason production_sql >/tmp/osc-cli-accept.txt
bin/osc intake tests/fixtures/incoming_rollup.zip --repo "$REPO" --against tests/fixtures/work >/tmp/osc-cli-intake.txt

check() {
  needle=$1
  if ! grep -F "$needle" /tmp/osc-cli-intake.txt >/dev/null; then
    echo "FAIL missing intake output: $needle" >&2
    cat /tmp/osc-cli-intake.txt >&2
    exit 1
  fi
}
check "METHOD_CONTRACT_CHANGED"
check "METHOD_REMOVED"
check "SQL_PROJECTION_OR_ORDER_CHANGED"
check "KNOWN_UNSATISFIED_SURFACE"
check "DECLARED_RESULT_ORDINAL"
check "at=src/Consumer.cls:5"
check "changedComponents= 1"


# Accepting a proposal must not require rewriting source level 1.
bin/osc surface DataStore --repo "$REPO" >/tmp/osc-cli-surface.txt
grep -F "EXTERNAL EO-" /tmp/osc-cli-surface.txt >/dev/null

# File blobs are supporting evidence/export material; checkout is byte exact.
rm -rf /tmp/osc-cli-export
bin/osc export DataStore --repo "$REPO" --level 1 --to /tmp/osc-cli-export >/tmp/osc-cli-export.txt
cmp tests/fixtures/provider_v1/src/DataStore.cls /tmp/osc-cli-export/src/DataStore.cls

# A different source body may not be written over an accepted source level.
if bin/osc baseline tests/fixtures/provider_v2 --repo "$REPO" --component DataStore --level 1 >/tmp/osc-cli-immutable.txt 2>&1; then
  echo "FAIL accepted source level was mutable" >&2
  exit 1
fi

# AT_LEAST is evaluated even when no source surface changed.
bin/osc intake tests/fixtures/incoming_low_rollup.zip --repo "$REPO" --against tests/fixtures/work >/tmp/osc-cli-low.txt
grep -F "REQUIREMENT_UNSATISFIED" /tmp/osc-cli-low.txt >/dev/null
grep -F "incoming source level is 0" /tmp/osc-cli-low.txt >/dev/null

# Legacy filename versions are labels only; no authoritative sourceLevel means verification required.
bin/osc intake tests/fixtures/incoming_legacy_rollup.zip --repo "$REPO" --against tests/fixtures/work >/tmp/osc-cli-legacy.txt
grep -F "VERIFICATION_REQUIRED" /tmp/osc-cli-legacy.txt >/dev/null
grep -F "no authoritative sourceLevel" /tmp/osc-cli-legacy.txt >/dev/null


# A component archive may itself be semantic source while also carrying nested
# ZIP dependencies. Its own SSC_MANIFEST must not be ignored just because a
# nested archive exists.
rm -rf /tmp/osc-cli-root-package /tmp/osc-cli-noise
mkdir -p /tmp/osc-cli-root-package/vendor /tmp/osc-cli-noise
cp -a tests/fixtures/provider_v2/. /tmp/osc-cli-root-package/
cat > /tmp/osc-cli-noise/SSC_MANIFEST <<'MANIFEST'
component=Noise
lineage=MAIN
sourceLevel=1
MANIFEST
cat > /tmp/osc-cli-noise/Noise.cls <<'REXX'
::class Noise public
::method ping
  return 1
REXX
(cd /tmp/osc-cli-noise && zip -qr /tmp/osc-cli-root-package/vendor/noise.zip .)
(cd /tmp/osc-cli-root-package && zip -qr /tmp/osc-cli-root-with-nested.zip .)
bin/osc impact /tmp/osc-cli-root-with-nested.zip --repo "$REPO" --against tests/fixtures/work >/tmp/osc-cli-root-with-nested.txt
grep -F "METHOD_CONTRACT_CHANGED" /tmp/osc-cli-root-with-nested.txt >/dev/null
grep -F "DataStore.AccountStore.loadAccounts" /tmp/osc-cli-root-with-nested.txt >/dev/null

# Method side is part of the selector.  Class-side source/consumers are not
# conflated with instance constructors of the same message name.
SREPO=/tmp/osc-cli-scope
rm -rf "$SREPO"
bin/osc baseline tests/fixtures_v02/scope_v1 --repo "$SREPO" --component Dual --level 1 >/tmp/osc-cli-scope-base.txt
bin/osc source 'Dual.Dual.init#CLASS' --repo "$SREPO" >/tmp/osc-cli-scope-source.txt
grep -F 'return "class:" || value' /tmp/osc-cli-scope-source.txt >/dev/null
bin/osc consumers 'Dual.Dual.init#CLASS' --against tests/fixtures_v02/scope_work --repo /tmp/osc-cli-scope-consumers >/tmp/osc-cli-scope-consumers.txt
grep -F 'LITERAL_CLASS_MESSAGE' /tmp/osc-cli-scope-consumers.txt >/dev/null
if grep -F 'CONSTRUCTOR' /tmp/osc-cli-scope-consumers.txt >/dev/null; then
  echo "FAIL class-side consumer query included instance constructor" >&2
  exit 1
fi

echo "PASS test_cli_intake"
