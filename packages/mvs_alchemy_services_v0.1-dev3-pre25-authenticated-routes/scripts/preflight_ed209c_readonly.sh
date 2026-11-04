#!/usr/bin/env bash
set -euo pipefail
SSHNODE=${SSHNODE:-/home/hc3/alchemy-autobuild/sshnode.sh}
TARGET=${MAS_TEST_HOST:-ed209c}
PREFIX=${MAS_SSH_JOB_ID_PREFIX:-MAS-PRE25-PREFLIGHT}
HERCULES_LOG=${HERCULES_LOG:-/home/azureuser/mvs-tk5/log/ed209c-hercules.log}
run_gate(){
  local name=$1 command=$2 job_id="${PREFIX}-${name}"
  printf 'GATE %s job_id=%s\n' "$name" "$job_id"
  if "$SSHNODE" --job-id "$job_id" "$TARGET" "$command"; then
    printf 'PASS %s job_id=%s\n' "$name" "$job_id"
  else
    rc=$?; printf 'BLOCKED %s job_id=%s rc=%s\n' "$name" "$job_id" "$rc" >&2; exit "$rc"
  fi
}
run_gate HERCULES "systemctl is-active tk5-hercules-ed209c.service"
run_gate LOG_READABLE "test -r '$HERCULES_LOG' && printf '%s\\n' READABLE"
run_gate S3270 "command -v s3270"
run_gate PORTS "ss -ltn | grep -E '10\\.0\\.0\\.4:3270|:3505'"
run_gate LOG_EVIDENCE "python3 - '$HERCULES_LOG' <<'PY'
import sys
lines=open(sys.argv[1],errors='replace').read().splitlines()[-5000:]
hits=[x for x in lines if ('TCAS ACCEPTING LOGONS' in x or '$HASP' in x or 'HERC_TCPIP_PROB_STATE' in x)]
for x in hits[-80:]: print(x)
if not hits: raise SystemExit(1)
PY"
printf 'PASS PRE25_ED209C_READONLY_PREFLIGHT\n'
