#!/usr/bin/env bash
# mu-tools v0.1-dev3 tests. Architecture: Tom Dyer. Coding: Claude (Opus 5.5).
# Runs in a temporary copy; the source tree is never written.
#   REXX_BIN   ooRexx 5.3 with CATCH (default: rexx on PATH)
# KEEP=1 keeps the temporary copy.
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"
REXX_BIN="${REXX_BIN:-$(command -v rexx || true)}"
[ -x "$REXX_BIN" ] || { echo "FAIL no ooRexx interpreter (set REXX_BIN)"; exit 2; }
WORK="$(mktemp -d "${TMPDIR:-/tmp}/mu_tools.XXXXXX")"
if [ "${KEEP:-0}" = "1" ]; then echo "KEEP: $WORK"; else trap 'rm -rf "$WORK"' EXIT; fi
cp -r "$SRC" "$WORK/pkg"; cd "$WORK/pkg"

echo "== interpreter: $("$REXX_BIN" -v 2>&1 | head -1)"
cat > "$WORK/catch.rex" <<'REX'
do
  x = 1 + 'a'
catch c = syntax
  say 'CATCH_OK'
end
REX
if [ "$("$REXX_BIN" "$WORK/catch.rex" 2>/dev/null | tail -1)" != "CATCH_OK" ]; then
  echo "FAIL this ooRexx has no CATCH; mu-tools needs 5.3 with CATCH (oorexx-5.3.0-0.ubuntu2204 deb)"; exit 2
fi

# pitfall P7 and P9, as in the other packages
if grep -nE '^[[:space:]]*call[[:space:]]+\.?[A-Za-z_][A-Za-z0-9_.]*~' src/*.cls bin/*.rex tests/*.rex; then echo "FAIL pitfall P7"; exit 3; fi
if grep -niE '^[^-#]*(^|[^~.[:alnum:]_])result[[:space:]]*=[^=]' src/NewShellMuAudit.cls bin/*.rex tests/*.rex | grep -v 'P9-ok'; then echo "FAIL pitfall P9"; exit 3; fi

echo "== test_mu_audit"
"$REXX_BIN" tests/test_mu_audit.rex "$WORK/fx" > "$WORK/t.out" 2>&1 || { cat "$WORK/t.out"; echo "FAIL test_mu_audit"; exit 1; }
echo "PASS test_mu_audit ($(grep -c '^PASS' "$WORK/t.out") checks)"

echo "== mu_audit.rex replays the fixture recording (want exit 1 and 10 findings)"
set +e
"$REXX_BIN" bin/mu_audit.rex "$WORK/fx/contract.txt" replay "$WORK/fx/fixture.rec" > "$WORK/a.out" 2>/dev/null
rc=$?
set -e
cat "$WORK/a.out"
n=$(grep -cE '^(FORBIDDEN|EXTRA|UNOWNED) ' "$WORK/a.out" || true)
[ "$rc" = 1 ] && [ "$n" = 10 ] || { echo "FAIL mu_audit.rex replay: exit $rc, $n findings"; exit 1; }
echo "PASS mu_audit.rex replay"

echo "== mu_audit.rex reads both contracts"
for c in etc/mu_contract.txt etc/mu_contract_cats.txt; do
  set +e; "$REXX_BIN" bin/mu_audit.rex "$c" replay "$WORK/fx/fixture.rec" > /dev/null 2>&1; rc=$?; set -e
  [ "$rc" = 0 ] || [ "$rc" = 1 ] || { echo "FAIL $c: exit $rc (2 means the contract did not read)"; exit 1; }
  echo "PASS $c reads (exit $rc)"
done
echo "PASS mu-tools v0.1-dev3"
