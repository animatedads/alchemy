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
      elif [[ "$state" == PASSWORD ]]; then echo 'data:  ENTER CURRENT PASSWORD FOR HERC03-'
      else echo 'data: LOGON REJECTED'; echo 'data: LISTCAT LEVEL(HERC03)'
      fi
      status ;;
    'String("HERC03")') state=USER_TYPED; status ;;
    'Enter()')
      if [[ "$state" == USER_TYPED ]]; then state=PASSWORD
      elif [[ "$state" == PASSWORD_TYPED ]]; then state=REJECTED
      fi
      status ;;
    'String("TESTPASS")') state=PASSWORD_TYPED; status ;;
    'Quit()'|'Disconnect()') echo ok ;;
    *) status ;;
  esac
done
FAKE
chmod +x "$TMP/fake-s3270"
set +e
X3270_CLIENT="$TMP/fake-s3270" TSO_USER=HERC03 TSO_PASSWORD=TESTPASS \
  "$ROOT/tools/x3270_tso_read_discovery.sh" ED209Z 127.0.0.1 3270 00C0 > "$TMP/feed.tsv" 2> "$TMP/err.txt"
rc=$?
set -e
[[ $rc -ne 0 ]] || { echo 'FAIL rejected login became successful discovery'; exit 1; }
! grep -q $'^FACT\tSESSION\tAUTHENTICATED\tTRUE' "$TMP/feed.tsv"
! grep -q $'^FACT\tDATASET\.' "$TMP/feed.tsv"
grep -q 'logon did not enter an authenticated TSO session' "$TMP/err.txt"
printf 'PASS echoed command text cannot fake TSO authentication\n'
