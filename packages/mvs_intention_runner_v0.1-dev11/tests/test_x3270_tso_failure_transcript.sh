#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/fake-s3270" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
state=LOGON
status(){ echo 'L F U C(fake) I 2 24 80 22 11 0x0 0.000'; echo ok; }
while IFS= read -r cmd; do
  case "$cmd" in
    'Wait(3270Mode)'|'Wait(1,Output)'|'Wait(2,Output)'|'Reset()') status ;;
    'Ascii()')
      if [[ "$state" == LOGON ]]; then echo 'data: Logon ===>'
      elif [[ "$state" == USER_TYPED ]]; then echo 'data: THIS IS NOT A PASSWORD PROMPT'
      fi
      status ;;
    'String("HERC03")') state=USER_TYPED; status ;;
    'Enter()') status ;;
    'Quit()'|'Disconnect()') echo ok ;;
    *) status ;;
  esac
done
FAKE
chmod +x "$TMP/fake-s3270"
set +e
X3270_CLIENT="$TMP/fake-s3270" X3270_TRANSCRIPT="$TMP/failure-transcript.txt" \
  TSO_USER=HERC03 TSO_PASSWORD=TESTPASS \
  "$ROOT/tools/x3270_tso_read_discovery.sh" ED209Z 127.0.0.1 3270 00C0 > "$TMP/feed.tsv" 2> "$TMP/err.txt"
rc=$?
set -e
[[ $rc -ne 0 ]] || { echo 'FAIL unrecognised password screen became success'; exit 1; }
[[ -s "$TMP/failure-transcript.txt" ]] || { echo 'FAIL failure transcript was not retained'; exit 1; }
grep -q 'THIS IS NOT A PASSWORD PROMPT' "$TMP/failure-transcript.txt"
! grep -q 'TESTPASS' "$TMP/failure-transcript.txt" "$TMP/feed.tsv"
grep -q 'password prompt was not observed; password not sent' "$TMP/err.txt"
printf 'PASS authenticated x3270 failure transcript retained and redacted\n'
