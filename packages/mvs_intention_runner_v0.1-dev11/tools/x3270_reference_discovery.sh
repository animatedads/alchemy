#!/usr/bin/env bash
set -euo pipefail

# Read-only x3270-family reference discovery adapter for MVS Intention.
#
# This is a qualification/reference adapter, not the permanent Terminal Machine
# authority.  It deliberately performs only safe session/navigation actions:
# connect, observe, Reset, Clear, observe, disconnect.
#
# Usage:
#   x3270_reference_discovery.sh TARGET [HOST [PORT [LU]]]
#
# Environment:
#   X3270_HOST          optional explicit host override; otherwise target map is authoritative
#   X3270_PORT          default 3270
#   X3270_LU            default 00C0
#   X3270_MODEL         default 3278-2
#   X3270_CLIENT        default auto (prefers s3270)
#   X3270_TIMEOUT       default 12 seconds
#   X3270_TRANSCRIPT    optional path to retain raw transcript
#   X3270_FIXTURE       optional raw transcript file; no network/client required

TARGET=${1:-ED209Z}
ARG_HOST=${2:-}
ARG_PORT=${3:-}
ARG_LU=${4:-}
TARGETS_FILE=${X3270_TARGETS_FILE:-$(cd "$(dirname "$0")/.." && pwd)/config/x3270_targets.tsv}

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
[[ -n "$HOST" ]] || { printf 'x3270 reference discovery: no endpoint mapped for target %s; set X3270_HOST or pass HOST explicitly\n' "$TARGET" >&2; exit 1; }
MODEL=${X3270_MODEL:-3278-2}
TIMEOUT=${X3270_TIMEOUT:-12}
CLIENT=${X3270_CLIENT:-auto}
FIXTURE=${X3270_FIXTURE:-}
TRANSCRIPT=${X3270_TRANSCRIPT:-}

fail(){ printf 'x3270 reference discovery: %s\n' "$*" >&2; exit 1; }

if [[ -n "$FIXTURE" ]]; then
  [[ -f "$FIXTURE" ]] || fail "fixture not found: $FIXTURE"
  raw=$(cat "$FIXTURE")
  client_name=FIXTURE
else
  if [[ "$CLIENT" == auto ]]; then
    if command -v s3270 >/dev/null 2>&1; then CLIENT=s3270
    elif command -v tcl3270 >/dev/null 2>&1; then CLIENT=tcl3270
    else fail 's3270/tcl3270 not found; c3270 may be used as the visible witness, but automated discovery needs a scripting client'
    fi
  fi
  command -v "$CLIENT" >/dev/null 2>&1 || fail "client not found: $CLIENT"
  client_name=$(basename "$CLIENT")

  # Keep the action list intentionally tiny and safe.  Reset only unlocks the
  # local keyboard state.  Clear is the established TK5 transition from the
  # Hercules welcome panel to the MVS Logon panel on ordinary LU 00C0.
  actions=$'Wait(3270Mode)\nSnap(Save)\nSnap(Ascii)\nReset()\nClear()\nWait(1,Output)\nSnap(Save)\nSnap(Ascii)\nDisconnect()\nQuit()\n'

  # timeout prevents a broken emulator/network path from hanging qualification.
  set +e
  raw=$(printf '%s' "$actions" | timeout "${TIMEOUT}s" "$CLIENT" -script -model "$MODEL" "${LU}@${HOST}:${PORT}" 2>&1)
  rc=$?
  set -e
  if [[ $rc -ne 0 && $rc -ne 124 ]]; then
    printf '%s\n' "$raw" >&2
    fail "$CLIENT exited rc=$rc"
  fi
fi

if [[ -n "$TRANSCRIPT" ]]; then
  mkdir -p "$(dirname "$TRANSCRIPT")"
  printf '%s\n' "$raw" > "$TRANSCRIPT"
fi

# Canonical safe-discovery feed.  This adapter intentionally reports only facts
# directly supported by the reference terminal transcript.
printf 'PROBE\tCONNECT_3270\tclient=%s host=%s port=%s lu=%s model=%s target=%s\n' "$client_name" "$HOST" "$PORT" "$LU" "$MODEL" "$TARGET"
printf 'PROBE\tOBSERVE_INITIAL_SCREEN\tSnap(Ascii) before navigation\n'
printf 'PROBE\tRESET_KEYBOARD\tReset() local terminal state only\n'
printf 'PROBE\tCLEAR_TO_MVS\tClear() established TK5 welcome-to-logon transition\n'
printf 'PROBE\tOBSERVE_MVS_SCREEN\tSnap(Ascii) after Clear\n'
printf 'PROBE\tDISCONNECT_3270\tclean reference-session disconnect\n'

connected=FALSE
if grep -Eqi '(connected|[LUFP] [UF] [UP] C\(|@[^ ]+\)|Hercules Version|Logon ===>)' <<<"$raw"; then connected=TRUE; fi
printf 'FACT\tSESSION\tSTATE\t%s\t100\tx3270:%s@%s:%s\n' "$( [[ "$connected" == TRUE ]] && echo CONNECTED || echo UNKNOWN )" "$LU" "$HOST" "$PORT"

screen_class=UNKNOWN
if grep -Fqi 'Logon ===>' <<<"$raw"; then screen_class=TSO_LOGON
elif grep -Fqi 'Hercules Version' <<<"$raw"; then screen_class=HERCULES_WELCOME
fi
printf 'FACT\tSCREEN\tCLASS\t%s\t100\tx3270:screen\n' "$screen_class"

if grep -Fqi 'RUNNING TK5' <<<"$raw"; then
  printf 'FACT\tSCREEN\tMARKER\tRUNNING TK5\t100\tx3270:screen\n'
fi
if grep -Fqi 'Logon ===>' <<<"$raw"; then
  printf 'FACT\tSCREEN\tMARKER\tLogon ===>\t100\tx3270:screen\n'
  printf 'FACT\tTSO\tLOGON_PANEL\tAVAILABLE\t100\tx3270:screen\n'
fi

# Preserve only structural status clues, never credentials or entered text.
# x3270 status lines include rows/columns and keyboard/connect state.  Store the
# last compact status-looking line as native evidence for later comparison.
status=$(grep -E '^[A-Z] [A-Z] [A-Z] ' <<<"$raw" | tail -1 || true)
if [[ -n "$status" ]]; then
  safe_status=${status//$'\t'/ }
  safe_status=${safe_status//$'\r'/ }
  printf 'FACT\tSESSION\tNATIVE_STATUS\t%s\t95\tx3270:status\n' "$safe_status"

  # x3270-family status lines place model, rows, columns, cursor row and cursor
  # column in fields 6..10.  Retain these as structural reference evidence;
  # do not infer application semantics from them.
  model_no=$(awk '{print $6}' <<<"$status")
  rows=$(awk '{print $7}' <<<"$status")
  cols=$(awk '{print $8}' <<<"$status")
  cursor_row=$(awk '{print $9}' <<<"$status")
  cursor_col=$(awk '{print $10}' <<<"$status")
  if [[ "$model_no" =~ ^[0-9]+$ && "$rows" =~ ^[0-9]+$ && "$cols" =~ ^[0-9]+$ ]]; then
    printf 'FACT\tSESSION\tMODEL\t3278-%s\t100\tx3270:status\n' "$model_no"
    printf 'FACT\tSCREEN\tROWS\t%s\t100\tx3270:status\n' "$rows"
    printf 'FACT\tSCREEN\tCOLUMNS\t%s\t100\tx3270:status\n' "$cols"
  fi
  if [[ "$cursor_row" =~ ^[0-9]+$ && "$cursor_col" =~ ^[0-9]+$ ]]; then
    printf 'FACT\tCURSOR\tROW\t%s\t100\tx3270:status\n' "$cursor_row"
    printf 'FACT\tCURSOR\tCOLUMN\t%s\t100\tx3270:status\n' "$cursor_col"
  fi
fi
