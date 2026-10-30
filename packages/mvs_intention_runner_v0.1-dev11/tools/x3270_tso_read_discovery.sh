#!/usr/bin/env bash
set -euo pipefail

# Authenticated, read-only TK5/TSO reference discovery.
#
# This is a qualification oracle, not Terminal Machine or MVS Alchemy authority.
# One s3270 process owns one TN3270 session for the complete state machine:
#   connect -> establish TSO logon panel -> userid -> password -> post-logon
#   panels -> TSO READY -> fixed read-only queries -> LOGOFF -> disconnect.
#
# No arbitrary TSO command is accepted from the caller.  Authentication is
# proven only by observing a current screen containing an exact TSO READY line;
# command echo text is never authentication evidence.

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TARGET=${1:-ED209Z}
ARG_HOST=${2:-}
ARG_PORT=${3:-}
ARG_LU=${4:-}
TARGETS_FILE=${X3270_TARGETS_FILE:-$ROOT/config/x3270_targets.tsv}

lookup_target(){
  local target=$1
  [[ -f "$TARGETS_FILE" ]] || return 1
  awk -F '\t' -v t="$target" '$1 == t { print $2 "\t" $3 "\t" $4; exit }' "$TARGETS_FILE"
}

mapped=$(lookup_target "$TARGET" || true)
if [[ -n "$mapped" ]]; then
  IFS=$'\t' read -r MAP_HOST MAP_PORT MAP_LU <<<"$mapped"
else
  MAP_HOST=""; MAP_PORT=""; MAP_LU=""
fi
HOST=${ARG_HOST:-${X3270_HOST:-$MAP_HOST}}
PORT=${ARG_PORT:-${X3270_PORT:-${MAP_PORT:-3270}}}
LU=${ARG_LU:-${X3270_LU:-${MAP_LU:-00C0}}}
[[ -n "$HOST" ]] || { printf 'x3270 TSO discovery: no endpoint mapped for target %s\n' "$TARGET" >&2; exit 1; }

MODEL=${X3270_MODEL:-3278-2}
CLIENT=${X3270_CLIENT:-s3270}
TIMEOUT=${X3270_TIMEOUT:-30}
TRANSCRIPT=${X3270_TRANSCRIPT:-}
READBUFFER_RESPONSE=${X3270_READBUFFER_RESPONSE:-}
FIXTURE=${X3270_FIXTURE:-}
TSO_USER=${TSO_USER:-HERC03}
TSO_PASSWORD=${TSO_PASSWORD:-}

TRANSCRIPT_BUF=""
TRANSCRIPT_WRITTEN=FALSE

persist_transcript(){
  [[ -n "$TRANSCRIPT" ]] || return 0
  [[ "$TRANSCRIPT_WRITTEN" == FALSE ]] || return 0
  mkdir -p "$(dirname "$TRANSCRIPT")"
  # Credential material must never survive in retained evidence, including
  # failure paths.  The normal action transcript already uses [REDACTED], but
  # scrub the configured password as a final defence.
  local safe_raw=${TRANSCRIPT_BUF//$TSO_PASSWORD/[REDACTED]}
  printf '%s' "$safe_raw" > "$TRANSCRIPT"
  TRANSCRIPT_WRITTEN=TRUE
}

fail(){
  persist_transcript || true
  printf 'x3270 TSO discovery: %s\n' "$*" >&2
  exit 1
}
[[ "$TSO_USER" =~ ^[A-Za-z0-9$#@]+$ ]] || fail 'TSO_USER contains unsupported characters'
[[ -n "$TSO_PASSWORD" ]] || fail 'TSO_PASSWORD is required at runtime; no packaged default exists'
[[ "$TSO_PASSWORD" =~ ^[A-Za-z0-9$#@]+$ ]] || fail 'TSO_PASSWORD contains unsupported characters'

LAST_STATUS=""
LAST_SCREEN=""
DATASET_SCREEN=""
ACTION_OUT=""
ACTION_COMPLETION=""
client_name=""

append_transcript(){
  local text=$1
  TRANSCRIPT_BUF+="$text"$'\n'
}

screen_text(){
  sed -E 's/^data: ?//' <<<"$1"
}

screen_has(){
  local screen=$1 pattern=$2
  grep -Eqi "$pattern" <<<"$(screen_text "$screen")"
}

screen_has_ready(){
  local screen=$1
  screen_text "$screen" | awk '{gsub(/^[[:space:]]+|[[:space:]]+$/, ""); if ($0 == "READY") found=1} END{exit found ? 0 : 1}'
}

if [[ -n "$FIXTURE" ]]; then
  # Legacy fixture mode is retained for corpus-level parser qualification only.
  # It must contain a positive READY screen; unlike dev5, command names or
  # generic IKJ text are not sufficient to assert authentication.
  [[ -f "$FIXTURE" ]] || fail "fixture not found: $FIXTURE"
  LAST_SCREEN=$(cat "$FIXTURE")
  TRANSCRIPT_BUF="$LAST_SCREEN"$'\n'
  client_name=FIXTURE
  if ! screen_has_ready "$LAST_SCREEN"; then
    fail 'fixture does not contain positive TSO READY state'
  fi
  DATASET_SCREEN="$LAST_SCREEN"
else
  command -v "$CLIENT" >/dev/null 2>&1 || fail "client not found: $CLIENT"
  client_name=$(basename "$CLIENT")

  # AID actions (Enter/Clear/PF/PA) normally block until the host unlocks the
  # keyboard.  TK5 can legitimately start the TSO address space while keeping
  # the terminal locked across a presentation transition.  In that case a
  # blocking Enter() makes the controller kill an otherwise healthy session.
  # Clear AidWait so AID transmission and host-state completion are separate:
  # the action returns once the AID is sent, and the state machine below owns
  # completion by observing Output/current screens.
  coproc X3270_PROC { "$CLIENT" -clear aidWait -script -model "$MODEL" "${LU}@${HOST}:${PORT}"; }
  XIN=${X3270_PROC[1]}
  XOUT=${X3270_PROC[0]}
  XPID=$X3270_PROC_PID

  cleanup(){
    persist_transcript || true
    if kill -0 "$XPID" 2>/dev/null; then
      printf 'Quit()\n' >&"$XIN" 2>/dev/null || true
      kill "$XPID" 2>/dev/null || true
    fi
    wait "$XPID" 2>/dev/null || true
  }
  trap cleanup EXIT

  action(){
    local cmd=$1 display=${2:-$1} line out=""
    ACTION_OUT=""
    ACTION_COMPLETION=""
    append_transcript "> $display"
    printf '%s\n' "$cmd" >&"$XIN" || fail "failed to send action: $display"
    while true; do
      if ! IFS= read -r -t "$TIMEOUT" line <&"$XOUT"; then
        fail "timeout waiting for action: $display"
      fi
      append_transcript "$line"
      if [[ "$line" == "ok" ]]; then
        ACTION_OUT="$out"
        ACTION_COMPLETION="$line"
        return 0
      fi
      if [[ "$line" == error* ]]; then
        ACTION_OUT="$out"
        ACTION_COMPLETION="$line"
        return 1
      fi
      if [[ -n "$out" ]]; then out+=$'\n'; fi
      out+="$line"
    done
  }

  capture_screen(){
    action 'Ascii()' 'Ascii()' || fail 'could not capture current 3270 screen'
    local out="$ACTION_OUT"
    LAST_STATUS=$(grep -E '^[LU] [FU] [UP] [CNU]\(' <<<"$out" | tail -1 || true)
    LAST_SCREEN=$(grep '^data:' <<<"$out" || true)
    [[ -n "$LAST_SCREEN" ]] || LAST_SCREEN="$out"
    printf '%s' "$LAST_SCREEN"
  }

  action 'Wait(3270Mode)' 'Wait(3270Mode)' >/dev/null || fail '3270 mode was not reached'
  capture_screen >/dev/null
  current="$LAST_SCREEN"

  # A fresh TK5 LU may show the Hercules/TK5 welcome presentation.  Establish
  # the real MVS logon panel before typing any credential.  Reset/Clear are the
  # documented safe transition; if the current screen is already the logon
  # panel, do not disturb it.
  if ! screen_has "$current" 'Logon[[:space:]]+===>'; then
    action 'Reset()' 'Reset()' >/dev/null || true
    action 'Clear()' 'Clear()' >/dev/null || fail 'Clear failed while seeking TSO logon panel'
    action 'Wait(1,Output)' 'Wait(1,Output)' >/dev/null || true
    capture_screen >/dev/null
  current="$LAST_SCREEN"
  fi
  screen_has "$current" 'Logon[[:space:]]+===>' || fail 'current session is not at the TSO Logon panel; no credentials sent'

  # Userid entry is allowed only from the positively identified logon screen.
  action "String(\"$TSO_USER\")" "String(\"${TSO_USER^^}\")" >/dev/null || fail 'userid entry failed'
  action 'Enter()' 'Enter()' >/dev/null || fail 'userid submit failed'
  action 'Wait(2,Output)' 'Wait(2,Output)' >/dev/null || true
  capture_screen >/dev/null
  current="$LAST_SCREEN"

  # TK5's normal users require a password.  Do not type it unless the current
  # screen positively requests a password.  This is the guard that dev5 lacked.
  # TK5 Update 5 normally presents `ENTER CURRENT PASSWORD FOR USER-`.
  # Keep the recognizer deliberately positive and bounded rather than treating
  # any occurrence of the word PASSWORD as authority to disclose a credential.
  password_prompt_re='(^|[[:space:]])ENTER[[:space:]]+(CURRENT[[:space:]]+)?PASSWORD([[:space:]]+FOR[[:space:]]+[A-Z0-9$#@]+)?[-:>]?[[:space:]]*$|PASSWORD[[:space:]]*===>'
  screen_has "$current" "$password_prompt_re" || fail 'password prompt was not observed; password not sent'
  action "String(\"$TSO_PASSWORD\")" 'String("[REDACTED]")' >/dev/null || fail 'password entry failed'
  action 'Enter()' 'Enter()' >/dev/null || fail 'password submit failed'
  action 'Wait(3,Output)' 'Wait(3,Output)' >/dev/null || true

  # Drive only the documented TK5 post-logon path, observing after every step.
  # Authentication is not declared until an exact READY line is visible.
  ready=FALSE
  post_enters=0
  do_pf3=0
  for step in 1 2 3 4 5 6 7 8; do
    capture_screen >/dev/null
  current="$LAST_SCREEN"
    if screen_has_ready "$current"; then ready=TRUE; break; fi
    if screen_has "$current" 'ENTER[[:space:]]+(CURRENT[[:space:]]+)?PASSWORD|PASSWORD[[:space:]]*===>|Logon[[:space:]]+===>|INVALID[[:space:]]+PASSWORD|LOGON[[:space:]]+REJECTED|NOT[[:space:]]+AUTHORIZED'; then
      fail 'logon did not enter an authenticated TSO session'
    fi
    if screen_has "$current" 'ISPF.*PRIMARY|PRIMARY OPTION MENU|OPTION[[:space:]]+===>'; then
      action 'PF(3)' 'PF(3)' >/dev/null || fail 'PF3 failed while leaving ISPF'
      action 'Wait(1,Output)' 'Wait(1,Output)' >/dev/null || true
      do_pf3=1
      continue
    fi
    # TK5 documents two ENTER acknowledgements after logon: Welcome to TSO,
    # then the fortune-cookie presentation. Keep this bounded to exactly two.
    if (( post_enters < 2 )); then
      action 'Enter()' 'Enter()' >/dev/null || fail 'post-logon Enter failed'
      action 'Wait(1,Output)' 'Wait(1,Output)' >/dev/null || true
      post_enters=$((post_enters + 1))
      continue
    fi
    fail 'post-logon screen was not recognised as READY or the documented TK5 path'
  done
  [[ "$ready" == TRUE ]] || fail 'TSO READY state was not positively observed'

  # Candidate16 differential evidence: retain one complete s3270
  # ReadBuffer(Ascii) action response from the positively authenticated READY
  # state.  This is detached reference evidence only.  It is never relabelled
  # Terminal Machine authority and it contains no caller-supplied credential.
  if [[ -n "$READBUFFER_RESPONSE" ]]; then
    action 'ReadBuffer(Ascii)' 'ReadBuffer(Ascii)' || fail 'ReadBuffer(Ascii) reference capture failed'
    mkdir -p "$(dirname "$READBUFFER_RESPONSE")"
    {
      printf '%s\n' "$ACTION_OUT"
      printf '%s\n' "$ACTION_COMPLETION"
    } > "$READBUFFER_RESPONSE"
  fi

  # Fixed read-only catalogue.  Each command starts from an observed READY
  # state and its result screen is captured separately.
  action 'String("PROFILE")' 'String("PROFILE")' >/dev/null || fail 'PROFILE entry failed'
  action 'Enter()' 'Enter()' >/dev/null || fail 'PROFILE submit failed'
  action 'Wait(1,Output)' 'Wait(1,Output)' >/dev/null || true
  capture_screen >/dev/null
  profile_screen="$LAST_SCREEN"
  screen_has_ready "$profile_screen" || fail 'PROFILE did not return to READY'

  action "String(\"LISTCAT LEVEL($TSO_USER)\")" "String(\"LISTCAT LEVEL(${TSO_USER^^})\")" >/dev/null || fail 'LISTCAT entry failed'
  action 'Enter()' 'Enter()' >/dev/null || fail 'LISTCAT submit failed'
  action 'Wait(2,Output)' 'Wait(2,Output)' >/dev/null || true
  capture_screen >/dev/null
  DATASET_SCREEN="$LAST_SCREEN"
  screen_has_ready "$DATASET_SCREEN" || fail 'LISTCAT did not return to READY'

  action 'String("LISTALC STATUS")' 'String("LISTALC STATUS")' >/dev/null || fail 'LISTALC entry failed'
  action 'Enter()' 'Enter()' >/dev/null || fail 'LISTALC submit failed'
  action 'Wait(2,Output)' 'Wait(2,Output)' >/dev/null || true
  capture_screen >/dev/null
  listalc_screen="$LAST_SCREEN"
  screen_has_ready "$listalc_screen" || fail 'LISTALC did not return to READY'

  action 'String("LOGOFF")' 'String("LOGOFF")' >/dev/null || fail 'LOGOFF entry failed'
  action 'Enter()' 'Enter()' >/dev/null || fail 'LOGOFF submit failed'
  action 'Wait(2,Output)' 'Wait(2,Output)' >/dev/null || true
  capture_screen >/dev/null
  logoff_screen="$LAST_SCREEN"
  screen_has "$logoff_screen" 'Logon[[:space:]]+===>' || fail 'LOGOFF did not return to TSO logon panel'
  action 'Disconnect()' 'Disconnect()' >/dev/null || true
  action 'Quit()' 'Quit()' >/dev/null || true
  wait "$XPID" 2>/dev/null || true
  trap - EXIT
fi

persist_transcript

SESSION_REF="x3270:${TARGET}:${LU}@${HOST}:${PORT}"
printf 'PROBE\tCONNECT_TSO_3270\tclient=%s host=%s port=%s lu=%s target=%s\n' "$client_name" "$HOST" "$PORT" "$LU" "$TARGET"
printf 'PROBE\tESTABLISH_LOGON_PANEL\tobserve current screen before credential entry\n'
printf 'PROBE\tLOGON_TEST_IDENTITY\tfixed TK5 test login; credential omitted\n'
printf 'PROBE\tREACH_READY\tcurrent-screen state machine; READY required\n'
if [[ -n "$READBUFFER_RESPONSE" ]]; then
  printf 'PROBE\tREADBUFFER_REFERENCE\tcomplete s3270 ReadBuffer(Ascii) action response retained separately\n'
fi
printf 'PROBE\tPROFILE_READ\tTSO PROFILE with no operands\n'
printf 'PROBE\tLISTCAT_READ\tLISTCAT LEVEL(userid)\n'
printf 'PROBE\tLISTALC_READ\tLISTALC STATUS\n'
printf 'PROBE\tLOGOFF_TSO\tclean TSO session teardown\n'
printf 'PROBE\tDISCONNECT_3270\tclean reference-session disconnect\n'

printf 'FACT\tSESSION\tAUTHENTICATED\tTRUE\t100\t%s\n' "$SESSION_REF"
printf 'FACT\tSESSION\tTARGET\t%s\t100\t%s\n' "$TARGET" "$SESSION_REF"
printf 'FACT\tSESSION\tHOST\t%s\t100\t%s\n' "$HOST" "$SESSION_REF"
printf 'FACT\tSESSION\tLU\t%s\t100\t%s\n' "$LU" "$SESSION_REF"
printf 'FACT\tTSO\tUSER\t%s\t100\t%s\n' "${TSO_USER^^}" "$SESSION_REF"
printf 'FACT\tTSO\tREADY\tAVAILABLE\t100\t%s\n' "$SESSION_REF"

# Parse dataset names only from the LISTCAT result screen captured after the
# command completed.  The command-entry transcript and other screens are not
# considered, preventing echoed input from becoming discovery evidence.
screen_text "$DATASET_SCREEN" | tr '[:lower:]' '[:upper:]' \
  | grep -Eo "${TSO_USER^^}(\.[A-Z0-9$#@-]+)+" | sort -u | while IFS= read -r ds; do
      [[ -n "$ds" ]] || continue
      printf 'FACT\tDATASET.%s\tROW\t%s|UNKNOWN|FALSE\t95\t%s:listcat\n' "$ds" "$ds" "$SESSION_REF"
    done
