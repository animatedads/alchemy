#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
A="$ROOT/tools/x3270_reference_discovery.sh"

# ED209Z must resolve to its explicit ED209C endpoint.  This regression prevents
# a shared/default DNS name from silently steering the target to ED209ZZ.
out=$(X3270_FIXTURE="$ROOT/tests/fixtures/x3270_tk5_logon.txt" "$A" ED209Z)
grep -q $'^PROBE\tCONNECT_3270\t.*host=52.146.17.8 .*target=ED209Z' <<<"$out"
grep -q $'^FACT\tSESSION\tSTATE\tCONNECTED\t' <<<"$out"
grep -q $'^FACT\tSCREEN\tCLASS\tTSO_LOGON\t' <<<"$out"
grep -q $'^FACT\tSCREEN\tMARKER\tRUNNING TK5\t' <<<"$out"
grep -q $'^FACT\tTSO\tLOGON_PANEL\tAVAILABLE\t' <<<"$out"
grep -q $'^FACT\tSESSION\tMODEL\t3278-2\t' <<<"$out"
grep -q $'^FACT\tSCREEN\tROWS\t24\t' <<<"$out"
grep -q $'^FACT\tSCREEN\tCOLUMNS\t80\t' <<<"$out"
grep -q $'^FACT\tCURSOR\tROW\t0\t' <<<"$out"
grep -q $'^FACT\tCURSOR\tCOLUMN\t0\t' <<<"$out"

out=$(X3270_FIXTURE="$ROOT/tests/fixtures/x3270_welcome_only.txt" "$A" ED209Z)
grep -q $'^FACT\tSCREEN\tCLASS\tHERCULES_WELCOME\t' <<<"$out"
if grep -q $'^FACT\tTSO\tLOGON_PANEL\tAVAILABLE\t' <<<"$out"; then
  echo 'FAIL welcome panel was misclassified as TSO logon' >&2
  exit 1
fi

# The real workstation qualification proved Wait(Connect) is not accepted by
# s3270.  Lock the correct wait mode into the shipped harness.
grep -q 'Wait(3270Mode)' "$A"
if grep -q 'Wait(Connect)' "$A"; then
  echo 'FAIL obsolete Wait(Connect) returned to x3270 harness' >&2
  exit 1
fi

# Unknown targets must fail closed unless the caller gives an explicit host.
if X3270_FIXTURE="$ROOT/tests/fixtures/x3270_tk5_logon.txt" "$A" NOT_A_MACHINE >/dev/null 2>&1; then
  echo 'FAIL unmapped target silently acquired an endpoint' >&2
  exit 1
fi
out=$(X3270_FIXTURE="$ROOT/tests/fixtures/x3270_tk5_logon.txt" X3270_HOST=192.0.2.10 "$A" NOT_A_MACHINE)
grep -q $'^PROBE\tCONNECT_3270\t.*host=192.0.2.10 .*target=NOT_A_MACHINE' <<<"$out"

echo 'PASS x3270 reference discovery adapter'
