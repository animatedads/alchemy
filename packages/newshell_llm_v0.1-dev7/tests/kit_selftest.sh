#!/bin/bash
# kit_selftest.sh - newshell kit self-test on an MU (cats1). Read-only: it uses a
# temporary state directory and config under /tmp and removes them.
# Architecture: Tom Dyer. Coding: Claude (Opus 5.5). Run as root (the fence needs it).
K=/opt/newshell
T=$(mktemp -d /tmp/newshell-selftest.XXXXXX); trap 'rm -rf "$T"' EXIT
cat > "$T/agent.conf" <<C
principal codex
state $T/state
policy $K/etc/cats1.policy
provide mu Mu /opt/mu-tools/etc/mu_contract_cats.txt
provide net Network
provide svc Services
provide xtpd Xtpd
C
fails=0
step() {  # step NAME EXPECTED-EXIT CODE...
  name="$1"; want="$2"; shift 2
  printf '%s\n' "$@" > "$T/p.rex"
  out=$("$K/bin/nsh-agent" --config "$T/agent.conf" run "$T/p.rex" 2>"$T/err"); got=$?
  echo "== $name (exit $got, want $want)"; echo "$out" | sed 's/^/   /'
  if [ "$got" != "$want" ]; then echo "FAIL $name"; sed 's/^/   err: /' "$T/err" | tail -5; fails=$((fails+1)); fi
}
"$K/bin/nsh-agent" --config "$T/agent.conf" describe 2>/dev/null | grep -q 'mu: a MU object' && echo "== describe: ok" || { echo "FAIL describe"; fails=$((fails+1)); }
step 'mu' 0 'return mu'
step 'listening sockets' 0 'return mu~net~listening'
step 'interfaces' 0 'return mu~net~interfaces'
step 'routes' 0 'return mu~net~routes'
step 'fence chains' 0 'return mu~net~firewall~chains'
step 'fence rules' 0 'return mu~net~firewall~rules'
step 'fence sets' 0 'return mu~net~firewall~sets'
step 'failed units' 0 'return mu~services~failed'
step 'MU audit' 0 'return mu~audit'
step 'MU audit findings' 0 'return mu~audit~findings'
step 'xtpd' 0 'return mu~xtpd'
step 'xtpd bringUp is refused by the policy' 2 "mu~xtpd~bringUp('/etc/xtpd/xtpd.conf')" 'return 1'
step 'a command is rejected before it runs' 2 'address system "touch /tmp/newshell_selftest_hacked"' 'return 1'
[ -e /tmp/newshell_selftest_hacked ] && { echo "FAIL a command ran"; fails=$((fails+1)); }
if [ $fails = 0 ]; then echo "PASS newshell kit self-test"; else echo "FAIL newshell kit self-test: $fails step(s)"; fi
exit $fails
