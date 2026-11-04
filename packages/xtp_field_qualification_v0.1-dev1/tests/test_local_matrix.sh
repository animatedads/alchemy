#!/usr/bin/env bash
# The field controller, end to end on this machine: a stand-in sshnode.sh makes
# each "node" a directory here, every address 127.0.0.1 (one unroutable).
# Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
T=$(mktemp -d); trap 'rm -rf "$T"; rm -rf "$ROOT"/results-protected-*-localtest 2>/dev/null' EXIT
cat > "$T/sshnode.sh" <<EOS
#!/usr/bin/env bash
H="$T/homes"
if [[ "\$1" == --transfer ]]; then mkdir -p "\$H/\$2"; cp "\$3" "\$4"; exit \$?; fi
n=\$1; shift; mkdir -p "\$H/\$n"; cd "\$H/\$n"
if [[ "\$n" == nodearm && "\$*" == "uname -m" ]]; then echo aarch64; exit 0; fi
HOME="\$H/\$n" bash -c "\$*"
EOS
chmod +x "$T/sshnode.sh"
fail=0
# 1. three reachable nodes
printf 'A\t127.0.0.1\tnodea\t1\nB\t127.0.0.1\tnodeb\t1\nC\t127.0.0.1\tnodec\t1\n' > "$T/inv.tsv"
out=$(XTP_SSHNODE="$T/sshnode.sh" XTP_FIELD_BYTES=262144 bash "$ROOT/run_protected_matrix.sh" "$T/inv.tsv" 2>&1)
res=$(sed -n 's/^FIELD_PROTECTED_COMPLETE results=//p' <<<"$out")
raw=PASS; "$ROOT/bin/xtp-field" probe | grep -q '^FIELD_RAW36 available' || raw=LOCAL_PERMISSION
u=$(grep -c '^pair .* udp PASS clear_refused=YES wrong_key_dropped=YES encrypted_echo=YES' <<<"$out")
if [[ $raw == PASS ]]; then r=$(grep -c '^pair .* raw36 PASS clear_refused=YES wrong_key_dropped=YES encrypted_echo=YES' <<<"$out"); else r=$(grep -c '^pair .* raw36 FAIL .*LOCAL_PERMISSION' <<<"$out"); fi
if [[ $u -eq 6 && $r -eq 6 ]]; then echo "PASS three nodes: 6 directed pairs, udp all PASS, raw36 all $raw"; else echo "FAIL three nodes: udp $u/6, raw36 $r/6"; echo "$out" | tail -20; fail=1; fi
left=$(find "$T/homes" -mindepth 2 2>/dev/null | wc -l)
if [[ $left -eq 0 ]]; then echo 'PASS nothing left on the nodes after the run'; else echo "FAIL $left files left on the nodes"; fail=1; fi
# every 64-hex-digit value in any output must be a data digest (sha256=), never a key secret
other=$(grep -Eoh '[^ =]*=?[0-9a-f]{64}' "$res"/*.txt "$res"/*.log "$res/pairs"/* "$res/hosts"/* 2>/dev/null | grep -Ev '^(binary_)?sha256=' | wc -l)
digests=$(grep -Eoh 'sha256=[0-9a-f]{64}' "$res/pairs"/* 2>/dev/null | wc -l)
if [[ -n "$res" && -f "$res/SUMMARY.txt" && ! -e "$res/keys" && $other -eq 0 && $digests -gt 0 ]]; then
  echo "PASS the receipt exists; the run keys are gone; the only 64-hex values in the logs are $digests data digests"
else echo 'FAIL receipt, key removal or secret check'; fail=1; fi
[[ -n "$res" ]] && mv "$res" "$res-localtest"
# 2. an unreachable node is reported, never passed
printf 'A\t127.0.0.1\tnodea\t1\nB\t192.0.2.1\tnodeb\t1\n' > "$T/inv2.tsv"
out=$(XTP_SSHNODE="$T/sshnode.sh" XTP_FIELD_BYTES=65536 bash "$ROOT/run_protected_matrix.sh" "$T/inv2.tsv" 2>&1)
res=$(sed -n 's/^FIELD_PROTECTED_COMPLETE results=//p' <<<"$out"); [[ -n "$res" ]] && mv "$res" "$res-localtest"
if grep -q '^pair A -> B udp FAIL .*NO_RESPONSE_OR_FILTERED' <<<"$out" && ! grep -q '^pair A -> B .* PASS' <<<"$out"; then echo 'PASS an unreachable destination is reported NO_RESPONSE_OR_FILTERED, never PASS'
else echo 'FAIL unreachable destination'; echo "$out" | grep '^pair'; fail=1; fi
# 3. a node of another architecture is reported, and its pairs are skipped, not failed
printf 'A\t127.0.0.1\tnodea\t1\nR\t127.0.0.1\tnodearm\t1\n' > "$T/inv3.tsv"
out=$(XTP_SSHNODE="$T/sshnode.sh" bash "$ROOT/run_protected_matrix.sh" "$T/inv3.tsv" 2>&1)
res=$(sed -n 's/^FIELD_PROTECTED_COMPLETE results=//p' <<<"$out"); [[ -n "$res" ]] && mv "$res" "$res-localtest"
if grep -q '^host R arch=aarch64 deploy=UNSUPPORTED_ARCH_aarch64' <<<"$out" && [[ $(grep -c '^pair .* SKIP UNSUPPORTED_ARCH' <<<"$out") -eq 4 ]]; then echo 'PASS an aarch64 node is reported UNSUPPORTED_ARCH and its 4 pair tests skipped'
else echo 'FAIL other architecture'; echo "$out" | grep '^host\|^pair'; fail=1; fi
exit $fail
