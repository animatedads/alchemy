#!/usr/bin/env bash
set -euo pipefail

SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PKG_ROOT=$(cd "$SELF_DIR/.." && pwd)
SSHNODE=${SSHNODE:-./sshnode.sh}
TARGET=${MAS_TEST_HOST:-ed209c}
PKG_ZIP=${MAS_PACKAGE_ZIP:-}
REMOTE_BASE=${MAS_REMOTE_BASE:-/home/azureuser/mvs_alchemy_pre25_live}
PORT=${MAS_GATEWAY_PORT:-37075}
RUN_ID=${MAS_RUN_ID:-ED209C-ED209Z-$(date -u +%Y%m%dT%H%M%SZ)}
MAS_SSH_JOB_ID_PREFIX=${MAS_SSH_JOB_ID_PREFIX:-MAS-PRE25-$RUN_ID}
SSH_JOB_SEQ=0
EVIDENCE_DIR=${MAS_EVIDENCE_DIR:-$PWD/mas-live-evidence/$RUN_ID}
HERCULES_LOG=${HERCULES_LOG:-/home/azureuser/mvs-tk5/log/ed209c-hercules.log}
READER_PORT=${MAS_READER_PORT:-3505}
PRINTER_DIR=${MAS_PRINTER_DIR:-/home/azureuser/mvs-tk5/prt}
READER_WAIT=${MAS_READER_WAIT:-30}
JOB_START_WAIT=${MAS_JOB_START_WAIT:-60}
JOB_END_WAIT=${MAS_JOB_END_WAIT:-240}
FACILITY_WAIT=${MAS_FACILITY_WAIT:-120}
JOB_CARD=${MAS_JOB_CARD:-"//MASLIVE JOB (ACCT),'MAS LIVE',CLASS=A,MSGCLASS=A,MSGLEVEL=(1,1)"}
mkdir -p "$EVIDENCE_DIR"

STAGE=INITIAL
finish_state(){ printf '%s\n' "$1" | tee -a "$EVIDENCE_DIR/summary.txt"; }
fail(){ finish_state "FAIL stage=$STAGE $*" >&2; exit 1; }
blocked(){ finish_state "BLOCKED stage=$STAGE $*" >&2; exit 2; }
inconclusive(){ finish_state "INCONCLUSIVE stage=$STAGE $*" >&2; exit 3; }
pass(){ finish_state "PASS stage=$STAGE $*"; }
run_ssh(){
  SSH_JOB_SEQ=$((SSH_JOB_SEQ+1))
  local stage_id=${STAGE//[^A-Za-z0-9_.-]/-}
  local job_id="${MAS_SSH_JOB_ID_PREFIX}-${stage_id}-${BASHPID}-${SSH_JOB_SEQ}"
  "$SSHNODE" --job-id "$job_id" "$TARGET" "$@"
}

cleanup(){
  run_ssh "test -f '$REMOTE_BASE/evidence/gateway.pid' && kill \$(cat '$REMOTE_BASE/evidence/gateway.pid') 2>/dev/null || true" >/dev/null 2>&1 || true
}
interrupted(){
  finish_state "INCONCLUSIVE stage=$STAGE interrupted"
  cleanup
  exit 130
}
trap interrupted INT TERM HUP
trap cleanup EXIT

wait_remote_log(){
  local pattern=$1 seconds=$2 i pattern_q
  printf -v pattern_q '%q' "$pattern"
  for i in $(seq 1 "$seconds"); do
    if run_ssh "grep -Eq $pattern_q '$HERCULES_LOG'" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

capture_live_window(){
  local name=$1
  local start
  start=$(tr -dc '0-9' < "$EVIDENCE_DIR/hercules-log-start-byte.txt" 2>/dev/null || echo 0)
  run_ssh "python3 - <<'PY2'
p='$HERCULES_LOG'; start=int('${start:-0}')
with open(p,'rb') as f:
 f.seek(start); d=f.read()
import sys; sys.stdout.buffer.write(d)
PY2" > "$EVIDENCE_DIR/$name" 2>&1 || true
}

capture_printers(){
  local suffix=$1
  run_ssh "for f in '$PRINTER_DIR'/prt*.txt; do test -f \"\$f\" || continue; echo ===== \"\$f\" =====; cat \"\$f\"; done" > "$EVIDENCE_DIR/printers-$suffix.txt" 2>&1 || true
}

submit_reader_file(){
  local remote_file=$1 local_evidence=$2
  run_ssh "python3 - <<'PY2'
import socket
p='$remote_file'
data=open(p,'rb').read()
s=socket.create_connection(('127.0.0.1',$READER_PORT),timeout=5)
s.sendall(data)
s.shutdown(socket.SHUT_WR)
try:
 while s.recv(4096): pass
except Exception:
 pass
s.close()
print('SUBMITTED',len(data),p)
PY2" | tee "$local_evidence"
}

[[ -x "$SSHNODE" ]] || command -v "$SSHNODE" >/dev/null 2>&1 || fail "sshnode unavailable"
if [[ -z "$PKG_ZIP" ]]; then
  candidate="$PKG_ROOT/../$(basename "$PKG_ROOT").zip"
  [[ -f "$candidate" ]] && PKG_ZIP="$candidate"
fi
[[ -f "$PKG_ZIP" ]] || fail "set MAS_PACKAGE_ZIP to pre25 archive"
sha256sum "$PKG_ZIP" | tee "$EVIDENCE_DIR/package.sha256"

STAGE=STAGE
"$SSHNODE" --transfer "$TARGET" "$PKG_ZIP" /tmp/mvs_alchemy_pre25_live.zip
run_ssh "set -e; rm -rf '$REMOTE_BASE'; mkdir -p '$REMOTE_BASE/package' '$REMOTE_BASE/logging' '$REMOTE_BASE/instrumentation' '$REMOTE_BASE/connect-selector' '$REMOTE_BASE/rpc-portfolio' '$REMOTE_BASE/ldap' '$REMOTE_BASE/https' '$REMOTE_BASE/evidence'; unzip -oq /tmp/mvs_alchemy_pre25_live.zip -d '$REMOTE_BASE/package'; root=\$(find '$REMOTE_BASE/package' -mindepth 1 -maxdepth 1 -type d | head -1); unzip -oq \"\$root/reference/oorexx_logging_v0.7.zip\" -d '$REMOTE_BASE/logging'; unzip -oq \"\$root/reference/oorexx_instrumentation_mesh_v0.1-dev8.zip\" -d '$REMOTE_BASE/instrumentation'; unzip -oq \"\$root/reference/oorexx_connect_selector_v0.1-dev8.zip\" -d '$REMOTE_BASE/connect-selector'; unzip -oq \"\$root/reference/oorexx_rpc_portfolio_v0.1-dev1.zip\" -d '$REMOTE_BASE/rpc-portfolio'; /usr/local/bin/rexx -v 2>&1 | head -3; systemctl is-active tk5-hercules-ed209c.service"
pass "stage and prerequisites"

STAGE=HOST_COMPILE
run_ssh "set -e; root=\$(find '$REMOTE_BASE/package' -mindepth 1 -maxdepth 1 -type d | head -1); logsrc=\$(find '$REMOTE_BASE/logging' -type d -path '*/src' | head -1); instsrc=\$(find '$REMOTE_BASE/instrumentation' -type d -path '*/src' | head -1); connectsrc=\$(find '$REMOTE_BASE/connect-selector' -type d -path '*/src' | head -1); rpccoresrc=\$(find '$REMOTE_BASE/rpc-portfolio' -type d -path '*/components/oorexx_rpc_service_core_v0.1-dev1/src' | head -1); export REXX_PATH=\"\$root/HOST/src:\$logsrc:\$instsrc:\$connectsrc:\$rpccoresrc:/usr/local/bin\"; /usr/local/bin/rexxc \"\$root/HOST/src/MasWire.cls\" >/dev/null; /usr/local/bin/rexxc \"\$root/HOST/src/MasLiveGateway.cls\" >/dev/null; /usr/local/bin/rexxc \"\$root/HOST/src/MasInstrumentationAdapter.cls\" >/dev/null; /usr/local/bin/rexxc \"\$root/HOST/src/MasRpcServiceBinding.cls\" >/dev/null; /usr/local/bin/rexxc \"\$root/HOST/bin/mas-live-gateway-instrumented.rex\" >/dev/null; cd \"\$root/HOST/tests\"; /usr/local/bin/rexx mas_instrumentation_mesh.rex; /usr/local/bin/rexx mas_instrumentation_publication.rex; /usr/local/bin/rexx mas_connect_selector.rex; /usr/local/bin/rexx mas_rpc_service_core.rex; /usr/local/bin/rexx mas_platform_route_authority.rex"
pass "ED209C host gateway compile"

STAGE=X75_PREFLIGHT
run_ssh "python3 - '$HERCULES_LOG' <<'PY2'
import re,sys
p=sys.argv[1]
lines=open(p,errors='replace').read().splitlines()
starts=[i for i,x in enumerate(lines) if 'HHC01413I Hercules version' in x]
if not starts:
 print('BLOCKED no Hercules startup marker'); raise SystemExit(2)
start=starts[-1]
seg=lines[start:]
ipls=[i for i,x in enumerate(seg) if re.search(r'HHC01603I[[:space:]]+ipl[[:space:]]+0390', x)]
# Python re does not understand POSIX classes; accept ordinary whitespace too.
ipls=[i for i,x in enumerate(seg) if re.search(r'HHC01603I\s+ipl\s+0390', x, re.I)]
if not ipls:
 print('BLOCKED no IPL 0390 in current Hercules lifetime'); raise SystemExit(2)
ipl=ipls[-1]
pre=seg[:ipl+1]
enabled=[i for i,x in enumerate(pre) if 'HERC_TCPIP_PROB_STATE' in x and 'Enabled for S/370' in x]
disabled=[i for i,x in enumerate(pre) if re.search(r'facility\s+disable\s+HERC_TCPIP_PROB_STATE',x,re.I)]
if not enabled or (disabled and disabled[-1] > enabled[-1]):
 print('BLOCKED problem-state X75 not proven enabled before current IPL')
 for x in pre[-80:]:
  if 'HERC_TCPIP' in x or 'facility' in x.lower() or re.search(r'HHC01603I\s+ipl',x,re.I): print(x)
 raise SystemExit(2)
print('PASS current Hercules lifetime/current IPL X75 preflight')
for x in pre[max(0,enabled[-1]-2):ipl+1]:
 if 'HERC_TCPIP' in x or re.search(r'HHC01603I\s+ipl',x,re.I): print(x)
PY2" | tee "$EVIDENCE_DIR/x75-preflight.txt" || blocked "HERC_TCPIP_PROB_STATE is not proven enabled before current IPL"
pass "current IPL has Hercules problem-state X75 enabled"

run_ssh "wc -c < '$HERCULES_LOG'" > "$EVIDENCE_DIR/hercules-log-start-byte.txt"
capture_printers before

# First prove that the socket reader is attached to JES, independently of MAS code.
STAGE=READER_SMOKE_BUILD
cat > "$EVIDENCE_DIR/MASRDR.jcl" <<'EOFJ'
//MASRDR JOB (ACCT),'MAS RDR',CLASS=A,MSGCLASS=A,MSGLEVEL=(1,1)
//SMOKE EXEC PGM=IEFBR14
//
EOFJ
"$SSHNODE" --transfer "$TARGET" "$EVIDENCE_DIR/MASRDR.jcl" "$REMOTE_BASE/MASRDR.jcl"
STAGE=READER_SMOKE_SUBMIT
submit_reader_file "$REMOTE_BASE/MASRDR.jcl" "$EVIDENCE_DIR/reader-smoke-submit.txt"

STAGE=READER_JES_ACCEPT
if ! wait_remote_log '\$HASP100[[:space:]]+MASRDR[[:space:]]+ON[[:space:]]+READER' "$READER_WAIT"; then
  capture_live_window hercules-reader-smoke.txt
  capture_printers reader-smoke
  inconclusive "3505 accepted TCP deck but no JES2 HASP100 MASRDR observed"
fi
pass 'reader -> JES2 acceptance (HASP100 MASRDR)'

STAGE=READER_JES_START
if ! wait_remote_log '\$HASP373[[:space:]]+MASRDR[[:space:]]+STARTED' "$JOB_START_WAIT"; then
  capture_live_window hercules-reader-smoke.txt
  capture_printers reader-smoke
  blocked "MASRDR accepted by JES2 but did not start"
fi
pass "JES2 started MASRDR"

STAGE=READER_JES_END
if ! wait_remote_log '\$HASP395[[:space:]]+MASRDR[[:space:]]+ENDED' "$JOB_END_WAIT"; then
  capture_live_window hercules-reader-smoke.txt
  capture_printers reader-smoke
  inconclusive "MASRDR started but did not reach HASP395 before timeout"
fi
pass "reader/JES smoke job completed"

# Start the one-connection gateway only after the reader/JES path is proven.
STAGE=GATEWAY_START
run_ssh "set -e; root=\$(find '$REMOTE_BASE/package' -mindepth 1 -maxdepth 1 -type d | head -1); logsrc=\$(find '$REMOTE_BASE/logging' -type d -path '*/src' | head -1); instsrc=\$(find '$REMOTE_BASE/instrumentation' -type d -path '*/src' | head -1); export REXX_PATH=\"\$root/HOST/src:\$logsrc:\$instsrc:/usr/local/bin\" MAS_RUN_ID='$RUN_ID' MAS_INSTRUMENTATION_ESTATE_ID='alchemy' MAS_INSTRUMENTATION_SERVICE_ID='mvs-alchemy' MAS_INSTRUMENTATION_INSTANCE_ID='ed209z-gateway' MAS_INSTRUMENTATION_NODE_ID='ED209C' MAS_INSTRUMENTATION_GUEST_ID='ED209Z'; nohup /usr/local/bin/rexx \"\$root/HOST/bin/mas-live-gateway-instrumented.rex\" '$PORT' '$REMOTE_BASE/state' '$REMOTE_BASE/evidence/gateway-log.txt' '$REMOTE_BASE/evidence/instrumentation.tsv' > '$REMOTE_BASE/evidence/gateway.stdout' 2>&1 & echo \$! > '$REMOTE_BASE/evidence/gateway.pid'"
ready=0
for _ in $(seq 1 40); do
  if run_ssh "ss -ltn | grep -Eq '127\\.0\\.0\\.1:$PORT[[:space:]]'"; then ready=1; break; fi
  sleep .25
done
if [[ $ready -ne 1 ]]; then
  run_ssh "cat '$REMOTE_BASE/evidence/gateway.stdout' 2>/dev/null || true" > "$EVIDENCE_DIR/gateway-start-failure.txt"
  fail "gateway did not listen"
fi
pass "ED209C live gateway listening"

STAGE=MASLIVE_BUILD
run_ssh "set -e; root=\$(find '$REMOTE_BASE/package' -mindepth 1 -maxdepth 1 -type d | head -1); python3 \"\$root/scripts/build_maslive_jcl.py\" --package-root \"\$root\" --output '$REMOTE_BASE/MASLIVE.jcl' --job-card \"$JOB_CARD\"; wc -lc '$REMOTE_BASE/MASLIVE.jcl'; head -3 '$REMOTE_BASE/MASLIVE.jcl'"
run_ssh "cat '$REMOTE_BASE/MASLIVE.jcl'" > "$EVIDENCE_DIR/MASLIVE.jcl"

STAGE=MASLIVE_SUBMIT
submit_reader_file "$REMOTE_BASE/MASLIVE.jcl" "$EVIDENCE_DIR/submit.txt"

STAGE=MASLIVE_JES_ACCEPT
if ! wait_remote_log '\$HASP100[[:space:]]+MASLIVE[[:space:]]+ON[[:space:]]+READER' "$READER_WAIT"; then
  capture_live_window hercules-maslive.txt
  capture_printers maslive-noaccept
  inconclusive "MASLIVE deck reached 3505 but JES2 did not emit HASP100"
fi
pass "JES2 accepted MASLIVE"

STAGE=MASLIVE_JES_START
if ! wait_remote_log '\$HASP373[[:space:]]+MASLIVE[[:space:]]+STARTED' "$JOB_START_WAIT"; then
  capture_live_window hercules-maslive.txt
  capture_printers maslive-nostart
  blocked "MASLIVE accepted by JES2 but did not start"
fi
pass "JES2 started MASLIVE"

STAGE=MASLIVE_EXECUTION
# Wait independently for facility completion or job end. A compile/link error can
# therefore be diagnosed from JES/printer evidence instead of looking like a transport timeout.
facility=0
jobended=0
for _ in $(seq 1 "$JOB_END_WAIT"); do
  if run_ssh "grep -q 'MASLIVE PASS ALL' '$HERCULES_LOG'" >/dev/null 2>&1; then facility=1; break; fi
  if wait_remote_log '\$HASP395[[:space:]]+MASLIVE[[:space:]]+ENDED' 1; then jobended=1; break; fi
  sleep 1
done
sleep 2
capture_live_window hercules-live-window.txt
capture_printers maslive
run_ssh "cat '$REMOTE_BASE/evidence/gateway.stdout' 2>/dev/null || true" > "$EVIDENCE_DIR/gateway.stdout"
run_ssh "cat '$REMOTE_BASE/evidence/gateway-log.txt' 2>/dev/null || true" > "$EVIDENCE_DIR/gateway-log.txt"
run_ssh "cat '$REMOTE_BASE/evidence/instrumentation.tsv' 2>/dev/null || true" > "$EVIDENCE_DIR/instrumentation.tsv"

if [[ $facility -ne 1 ]]; then
  if [[ $jobended -eq 1 ]]; then
    if grep -Eq 'IFO[0-9]{3}|IEW[0-9]{4}|\*FLUSH\*|COND CODE 000[48]|RC=8|RC=4' "$EVIDENCE_DIR/printers-maslive.txt"; then
      fail "MASLIVE guest build/runtime failed; inspect printers-maslive.txt"
    fi
    fail "MASLIVE ended without PASS ALL; inspect guest spool"
  fi
  inconclusive "MASLIVE did not end and did not reach PASS ALL before timeout"
fi

# A guest PASS marker is not JES completion.  Require the job-end boundary and
# retain final spool after HASP395 before any live PASS can be published.
STAGE=MASLIVE_JES_END
if [[ $jobended -ne 1 ]]; then
  if ! wait_remote_log '\$HASP395[[:space:]]+MASLIVE[[:space:]]+ENDED' "$JOB_END_WAIT"; then
    capture_live_window hercules-maslive-pass-no-end.txt
    capture_printers maslive-pass-no-end
    inconclusive "MASLIVE PASS ALL observed but JES2 did not reach HASP395 before timeout"
  fi
  jobended=1
fi
pass "JES2 ended MASLIVE after facility completion"
capture_printers maslive-final
if ! grep -q 'MASLIVE' "$EVIDENCE_DIR/printers-maslive-final.txt"; then
  inconclusive "HASP395 observed but retained MASLIVE spool was not found in printer evidence"
fi
pass "MASLIVE final spool retained"

STAGE=FACILITY_EVIDENCE
for marker in HELLO 'PING BINARY' QUEUE DATABASE IMAP SMTP PATH ALL; do
  grep -q "MASLIVE PASS $marker" "$EVIDENCE_DIR/hercules-live-window.txt" || fail "missing guest marker: $marker"
done
for op in 1 3 4096 4097 4098 4099 4352 4353 4354 5120 5122 5123 5126 5152 5153 5154 5155 5156 5157 5376 5377 5378 5380 19; do
  grep -q "operation=$op" "$EVIDENCE_DIR/gateway-log.txt" || fail "missing Logging v0.7 gateway operation $op"
done
grep -q $'^request.inflight\tGAUGE\tcount\t0$' "$EVIDENCE_DIR/instrumentation.tsv" || fail "Instrumentation Mesh request.inflight did not settle to zero"
grep -q $'^mas.sessions.active\tGAUGE\tcount\t0$' "$EVIDENCE_DIR/instrumentation.tsv" || fail "Instrumentation Mesh active session did not settle to zero"
grep -q $'^io.bytes.in.total\tCOUNTER\tbytes\t' "$EVIDENCE_DIR/instrumentation.tsv" || fail "missing Instrumentation Mesh input byte counter"
grep -q $'^io.bytes.out.total\tCOUNTER\tbytes\t' "$EVIDENCE_DIR/instrumentation.tsv" || fail "missing Instrumentation Mesh output byte counter"
grep -q $'^semantic_ref\tinstrumentation://alchemy/mvs-alchemy/ed209z-gateway@ED209C$' "$EVIDENCE_DIR/instrumentation.tsv" || fail "Instrumentation Mesh semantic_ref mismatch"
grep -q 'guest_id=ED209Z' "$EVIDENCE_DIR/instrumentation.tsv" || fail "Instrumentation Mesh guest dimension missing"
grep -q 'protocol=mvs.alchemy/1' "$EVIDENCE_DIR/instrumentation.tsv" || fail "Instrumentation Mesh protocol dimension missing"
pass "ED209Z -> X75 -> ED209C MAS live facilities + Instrumentation Mesh"
echo "RUN_ID=$RUN_ID" | tee -a "$EVIDENCE_DIR/summary.txt"
echo "EVIDENCE_DIR=$EVIDENCE_DIR" | tee -a "$EVIDENCE_DIR/summary.txt"
echo "PASS ED209C_ED209Z_MAS_PRE25_LIVE" | tee -a "$EVIDENCE_DIR/summary.txt"
