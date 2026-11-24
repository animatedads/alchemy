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
P="$WORK/pkg"
# ooRexx 5.2 resolves ::requires '../src/x' from the current directory, 5.3 from the
# requiring file's directory: each script is started from its own directory, so both agree
au() { (cd "$P/bin" && "$REXX_BIN" mu_audit.rex "$@"); }

echo "== interpreter: $("$REXX_BIN" -v 2>&1 | head -1)"
# dev3: the audit and the survey use no CATCH or THROW, so any ooRexx 5 runs them
if grep -nE '^[[:space:]]*(catch|throw)\b|[[:space:]](throw)[[:space:]]' src/NewShellMuAudit.cls src/NewShellMuTree.cls bin/*.rex; then
  echo "FAIL CATCH or THROW above: the audit path must run on interpreters without them"; exit 3
fi

# pitfall P7 and P9, as in the other packages
if grep -nE '^[[:space:]]*call[[:space:]]+\.?[A-Za-z_][A-Za-z0-9_.]*~' src/*.cls bin/*.rex tests/*.rex; then echo "FAIL pitfall P7"; exit 3; fi
if grep -niE '^[^-#]*(^|[^~.[:alnum:]_])result[[:space:]]*=[^=]' src/NewShellMuAudit.cls bin/*.rex tests/*.rex | grep -v 'P9-ok'; then echo "FAIL pitfall P9"; exit 3; fi

echo "== test_mu_audit"
(cd "$P/tests" && "$REXX_BIN" test_mu_audit.rex "$WORK/fx") > "$WORK/t.out" 2>&1 || { cat "$WORK/t.out"; echo "FAIL test_mu_audit"; exit 1; }
echo "PASS test_mu_audit ($(grep -c '^PASS' "$WORK/t.out") checks)"

echo "== mu_audit.rex replays the fixture recording (want exit 1 and 10 findings)"
set +e
au "$WORK/fx/contract.txt" replay "$WORK/fx/fixture.rec" > "$WORK/a.out" 2>/dev/null
rc=$?
set -e
cat "$WORK/a.out"
n=$(grep -cE '^(FORBIDDEN|EXTRA|UNOWNED) ' "$WORK/a.out" || true)
[ "$rc" = 1 ] && [ "$n" = 10 ] || { echo "FAIL mu_audit.rex replay: exit $rc, $n findings"; exit 1; }
echo "PASS mu_audit.rex replay"

echo "== mu_audit.rex reads both contracts"
for c in etc/mu_contract.txt etc/mu_contract_cats.txt; do
  set +e; au "$P/$c" replay "$WORK/fx/fixture.rec" > /dev/null 2>&1; rc=$?; set -e
  [ "$rc" = 0 ] || [ "$rc" = 1 ] || { echo "FAIL $c: exit $rc (2 means the contract did not read)"; exit 1; }
  echo "PASS $c reads (exit $rc)"
done
echo "== a bad contract line stops the audit with exit 2 and names the line"
printf 'allow nonsense here\n' > "$WORK/bad.txt"
set +e; au "$WORK/bad.txt" replay "$WORK/fx/fixture.rec" > "$WORK/b.out" 2>&1; rc=$?; set -e
grep -q 'failed: 98.900 cannot read contract line: allow nonsense here' "$WORK/b.out" && [ "$rc" = 2 ] || { cat "$WORK/b.out"; echo "FAIL bad contract: exit $rc"; exit 1; }
echo "PASS bad contract: exit 2, line named"
echo "== HostCommand: a missing command gives rc 127, not an error"
cat > "$WORK/hc.rex" <<'REX'
o = .HostCommand~run('no_such_command_mu_tools')
say 'RC' o~rc
::requires 'NewShellIdentity.cls'
REX
cp "$WORK/hc.rex" src/hc_probe.rex
[ "$(cd "$P/src" && "$REXX_BIN" hc_probe.rex 2>/dev/null | tail -1)" = "RC 127" ] || { (cd "$P/src" && "$REXX_BIN" hc_probe.rex); echo "FAIL HostCommand on a missing command"; exit 1; }
echo "PASS HostCommand: missing command is rc 127"
echo "PASS mu-tools v0.1-dev3"
