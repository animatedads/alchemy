#!/usr/bin/env bash
set -euo pipefail
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SRC="$ROOT/campaign_audio/campaign0945_source_094030_094930.wav"
CMP="$ROOT/campaign_audio/campaign0945_companion_094015_094945.wav"
[[ -s "$SRC" && -s "$CMP" ]] || { echo 'FAIL: campaign masters missing; run prepare_samples.sh first' >&2; exit 4; }
HOST=${ED209H_HOST:-155.138.214.182}; USER=${ED209H_USER:-linuxuser}
SSH_CONFIG=${ED209H_SSH_CONFIG:-${SSH_CONFIG:-$HOME/.ssh/config}}
H_KEY=${ED209H_KEY:-${VULTR_KEY:-}}
ssh_opts=(-o BatchMode=yes -o ConnectTimeout=12 -o ServerAliveInterval=15 -o ServerAliveCountMax=3)
[[ -r "$SSH_CONFIG" ]] && ssh_opts=(-F "$SSH_CONFIG" "${ssh_opts[@]}")
[[ -n "$H_KEY" ]] && ssh_opts=(-i "$H_KEY" "${ssh_opts[@]}")
TARGET=''; for h in ed209h "$HOST"; do if ssh "${ssh_opts[@]}" "$USER@$h" true </dev/null >/dev/null 2>&1; then TARGET="$USER@$h"; break; fi; done
[[ -n "$TARGET" ]] || { echo 'FAIL: ed209h unreachable by alias and current IP fallback' >&2; exit 4; }
AUDIO_ROOT=${H_AUDIO_ROOT_REMOTE:-}; if [[ -z "$AUDIO_ROOT" ]]; then health=$("$ROOT/h_api.sh" health - 2>/dev/null || true); AUDIO_ROOT=$(printf '%s\n' "$health" | sed -n 's/.*"audio_root":"\([^"]*\)".*/\1/p' | head -1); fi
[[ -n "$AUDIO_ROOT" && "$AUDIO_ROOT" == /* && "$AUDIO_ROOT" != *..* && "$AUDIO_ROOT" =~ ^[A-Za-z0-9_./-]+$ ]] || { echo 'FAIL: cannot safely determine H audio root; set H_AUDIO_ROOT_REMOTE' >&2; exit 4; }
ssh "${ssh_opts[@]}" "$TARGET" "mkdir -p -- '$AUDIO_ROOT'"
scp "${ssh_opts[@]}" "$SRC" "$CMP" "$TARGET:$AUDIO_ROOT/" >/dev/null
remote_check=$(ssh "${ssh_opts[@]}" "$TARGET" "cd '$AUDIO_ROOT' && sha256sum '$(basename "$SRC")' '$(basename "$CMP")'")
local_check=$(cd "$(dirname "$SRC")" && sha256sum "$(basename "$SRC")" "$(basename "$CMP")")
[[ "$remote_check" == "$local_check" ]] || { echo 'FAIL: H campaign master SHA-256 verification mismatch' >&2; exit 5; }
echo "PASS staged 09:45 campaign masters to ed209h audio_root=$AUDIO_ROOT"
