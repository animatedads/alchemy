#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Fake s3270 implements enough of the real -script protocol to exercise the
# continuous-session state machine.  It deliberately echoes LISTCAT command
# input nowhere; authentication must arise from the READY screen only.
cat > "$TMP/fake-s3270" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
# The live defect being locked here was caused by the default blocking AID
# behavior.  Refuse to emulate a session unless the controller explicitly
# disables AidWait.
args=" $* "
[[ "$args" == *" -clear aidWait "* ]] || { echo 'error AidWait was not cleared'; exit 97; }
state=WELCOME
pending=""
status(){ echo 'L F U C(fake) I 2 24 80 22 11 0x0 0.000'; echo ok; }
screen(){
  case "$state" in
    WELCOME) echo 'data: Hercules Version : 4.9.1'; echo 'data: The MVS 3.8j Turnkey System' ;;
    LOGON) echo 'data:                              Logon ===>'; echo 'data: RUNNING TK5' ;;
    PASSWORD) echo 'data:  ENTER CURRENT PASSWORD FOR HERC03-' ;;
    WELCOME_TSO) echo 'data: WELCOME TO TSO' ;;
    FORTUNE) echo 'data: A MAINFRAME IS A TERRIBLE THING TO WASTE.' ;;
    ISPF) echo 'data: ISPF PRIMARY OPTION MENU'; echo 'data: OPTION ===>' ;;
    READY) echo 'data: READY' ;;
    PROFILE) echo 'data: IKJ56688I CHARACTER-PREFIX = HERC03'; echo 'data: READY' ;;
    LISTCAT) echo 'data: NONVSAM ------- HERC03.CLIST'; echo 'data: NONVSAM ------- HERC03.COBOL'; echo 'data: READY' ;;
    LISTALC) echo 'data: DDNAME   DATA SET NAME'; echo 'data: SYSEXEC  SYS2.CMDPROC'; echo 'data: READY' ;;
  esac
}
while IFS= read -r cmd; do
  case "$cmd" in
    'Wait(3270Mode)'|'Wait(1,Output)'|'Wait(2,Output)'|'Wait(3,Output)'|'Reset()'|'Disconnect()') status ;;
    'Ascii()') screen; case "$state" in PROFILE|LISTCAT|LISTALC) state=READY ;; esac; status ;;
    'Clear()') state=LOGON; status ;;
    'String("HERC03")') pending=USER; status ;;
    'String("PASS4U")') pending=PASSWORD; status ;;
    'String("PROFILE")') pending=PROFILE; status ;;
    'String("LISTCAT LEVEL(HERC03)")') pending=LISTCAT; status ;;
    'String("LISTALC STATUS")') pending=LISTALC; status ;;
    'String("LOGOFF")') pending=LOGOFF; status ;;
    'Enter()')
      case "$pending:$state" in
        USER:LOGON) state=PASSWORD; pending="" ;;
        PASSWORD:PASSWORD) state=WELCOME_TSO; pending="" ;;
        :WELCOME_TSO) state=FORTUNE ;;
        :FORTUNE) state=ISPF ;;
        PROFILE:READY) state=PROFILE; pending="" ;;
        LISTCAT:READY) state=LISTCAT; pending="" ;;
        LISTALC:READY) state=LISTALC; pending="" ;;
        LOGOFF:READY) state=LOGON; pending="" ;;
      esac
      status ;;
    'PF(3)') state=READY; status ;;
    'Quit()') echo ok; exit 0 ;;
    *) echo "error unknown action $cmd"; exit 1 ;;
  esac
done
FAKE
chmod +x "$TMP/fake-s3270"

X3270_CLIENT="$TMP/fake-s3270" X3270_TRANSCRIPT="$TMP/transcript.txt" \
  TSO_USER=HERC03 TSO_PASSWORD=PASS4U \
  "$ROOT/tools/x3270_tso_read_discovery.sh" ED209Z 127.0.0.1 3270 00C0 > "$TMP/feed.tsv"

grep -q $'^FACT\tSESSION\tAUTHENTICATED\tTRUE\t' "$TMP/feed.tsv"
grep -q $'^FACT\tSESSION\tTARGET\tED209Z\t' "$TMP/feed.tsv"
grep -q $'^FACT\tSESSION\tHOST\t127.0.0.1\t' "$TMP/feed.tsv"
grep -q $'^FACT\tSESSION\tLU\t00C0\t' "$TMP/feed.tsv"
grep -q $'^FACT\tTSO\tUSER\tHERC03\t' "$TMP/feed.tsv"
grep -q $'^FACT\tDATASET.HERC03.CLIST\tROW\tHERC03.CLIST|UNKNOWN|FALSE\t' "$TMP/feed.tsv"
grep -q $'^FACT\tDATASET.HERC03.COBOL\tROW\tHERC03.COBOL|UNKNOWN|FALSE\t' "$TMP/feed.tsv"
if grep -q 'PASS4U' "$TMP/feed.tsv" "$TMP/transcript.txt"; then echo 'FAIL password leaked into retained evidence'; exit 1; fi
printf 'PASS authenticated x3270 TSO non-blocking-AID continuous-session adapter\n'
