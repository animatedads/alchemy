#!/usr/bin/env bash
set -euo pipefail
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
COLLECTED=${1:-$ROOT/collected_results}
RANK_SPEC=${2:-rank_01.wav}
REMOTE_BASE=audio-rexx-search-v0.12-dev12
HOST=${ED209H_HOST:-155.138.214.182}
USER=${ED209H_USER:-linuxuser}
ROLL_DIR=${H_ROLL_DIR:-$ROOT/run/controller/h-roll-windows}
TARGET=''
ssh_opts=(-o BatchMode=yes -o ConnectTimeout=12 -o ServerAliveInterval=15 -o ServerAliveCountMax=3)
[[ -n ${VULTR_KEY:-} ]] && ssh_opts=(-i "$VULTR_KEY" "${ssh_opts[@]}")
for h in ed209h "$HOST"; do
  if ssh "${ssh_opts[@]}" "$USER@$h" true </dev/null >/dev/null 2>&1; then TARGET="$USER@$h"; break; fi
done
[[ -n "$TARGET" ]] || { echo 'FAIL: ed209h unreachable by alias and current IP fallback' >&2; exit 4; }

if [[ ${H_NO_PREPARE:-0} != 1 ]]; then
  "$ROOT/prepare_h_roll_windows.sh" "$ROLL_DIR"
else
  [[ -s "$ROLL_DIR/windows.tsv" && -s "$ROLL_DIR/WINDOWS.sha256" ]] || { echo "FAIL: H_NO_PREPARE=1 but rolling fixture missing under $ROLL_DIR" >&2; exit 4; }
  (cd "$ROLL_DIR" && sha256sum -c WINDOWS.sha256 >/dev/null) || { echo 'FAIL: H rolling fixture integrity mismatch' >&2; exit 4; }
fi

TMP="$ROOT/run/controller/ed209h-input"
rm -rf "$TMP"; mkdir -p "$TMP/candidates" "$TMP/windows"
cp "$ROLL_DIR"/windows.tsv "$ROLL_DIR"/WINDOWS.sha256 "$TMP/windows/"
while IFS= read -r f; do cp "$ROLL_DIR/$f" "$TMP/windows/"; done < <(awk -F '\t' 'NR>1{print $7; print $8}' "$ROLL_DIR/windows.tsv" | sort -u)
printf 'parent_node\tparent_rank\tparent_candidate_id\tconfig_file\n' > "$TMP/inputs.tsv"

extract_json_value(){
  local line=$1 key=$2
  printf '%s\n' "$line" | sed -n 's/.*"'"$key"'": \("[^"]*"\|[^,}]*\).*/\1/p' | sed 's/^"//; s/"$//'
}

count=0
IFS=',' read -r -a ranks <<<"$RANK_SPEC"
for node in ed209a ed209b ed209c ed209d ed209e ed209i; do
  for rankfile in "${ranks[@]}"; do
    rankfile=${rankfile// /}
    [[ "$rankfile" =~ ^rank_([0-9]+)\.wav$ ]] || { echo "FAIL: H rank selector must look like rank_01.wav: $rankfile" >&2; exit 2; }
    rank=$((10#${BASH_REMATCH[1]}))
    cfgcat="$COLLECTED/$node/candidate_configs.tsv"
    review="$COLLECTED/$node/review_candidates.tsv"
    results="$COLLECTED/$node/results.json"
    [[ -s "$COLLECTED/$node/$rankfile" ]] || continue
    parent=''; chain=''; score=''; gain=''; hp=''; lp=''; nf=''; ed=''; eg=''; cs=''; ct=''; co=''; cr=''; th=''; rb=''
    if [[ -s "$cfgcat" ]]; then
      row=$(awk -F '\t' -v r="$rank" 'NR>1 && ($3+0)==r {print; exit}' "$cfgcat")
      [[ -n "$row" ]] || { echo "FAIL: no rank $rank in $cfgcat" >&2; exit 4; }
      parent=$(printf '%s\n' "$row" | awk -F '\t' '{print $1}')
      score=$(printf '%s\n' "$row" | awk -F '\t' '{print $4}')
      gain=$(printf '%s\n' "$row" | awk -F '\t' '{print $5}')
      hp=$(printf '%s\n' "$row" | awk -F '\t' '{print $6}')
      lp=$(printf '%s\n' "$row" | awk -F '\t' '{print $7}')
      nf=$(printf '%s\n' "$row" | awk -F '\t' '{print $8}')
      ed=$(printf '%s\n' "$row" | awk -F '\t' '{print $9}')
      eg=$(printf '%s\n' "$row" | awk -F '\t' '{print $10}')
      cs=$(printf '%s\n' "$row" | awk -F '\t' '{print $11}')
      ct=$(printf '%s\n' "$row" | awk -F '\t' '{print $12}')
      co=$(printf '%s\n' "$row" | awk -F '\t' '{print $13}')
      cr=$(printf '%s\n' "$row" | awk -F '\t' '{print $14}')
      th=$(printf '%s\n' "$row" | awk -F '\t' '{print $15}')
      rb=$(printf '%s\n' "$row" | awk -F '\t' '{print $16}')
      chain=$(printf '%s\n' "$row" | awk -F '\t' '{print $17}')
    else
      [[ -s "$results" ]] || { echo "FAIL: $node has promoted WAV but no candidate_configs.tsv or results.json" >&2; exit 4; }
      line=$(grep -m1 -E '^[[:space:]]*\{"rank":[[:space:]]*'"$rank"',' "$results" || true)
      [[ -n "$line" ]] || { echo "FAIL: cannot recover rank $rank config from $results" >&2; exit 4; }
      score=$(extract_json_value "$line" score); pcm=$(extract_json_value "$line" pcm_hash64)
      strategy=$(sed -n 's/.*"strategy": "\([^"]*\)".*/\1/p' "$results" | head -1)
      parent="$node:${strategy:-UNKNOWN}:$pcm"
      gain=$(extract_json_value "$line" gain_db); hp=$(extract_json_value "$line" highpass_hz); lp=$(extract_json_value "$line" lowpass_hz)
      nf=$(extract_json_value "$line" denoise_floor_db); [[ "$nf" == null || -z "$nf" ]] && nf=NONE
      ed=$(extract_json_value "$line" echo_delay_ms); eg=$(extract_json_value "$line" echo_gain); cs=$(extract_json_value "$line" cancel_strength); ct=$(extract_json_value "$line" cancel_tweak_ms)
      co=$(extract_json_value "$line" compress); [[ "$co" == true ]] && co=1; [[ "$co" == false ]] && co=0
      cr=$(extract_json_value "$line" compress_ratio); th=$(extract_json_value "$line" compress_threshold_db); rb=$(extract_json_value "$line" reject_bands)
      if [[ -s "$review" ]]; then chain=$(awk -F '\t' -v r="$rank" 'NR>1 && ($3+0)==r {print $8; exit}' "$review"); fi
      echo "LEGACY H CONFIG EXTRACTION node=$node rank=$rank source=results.json" >&2
    fi
    safe="${node}_rank_$(printf '%02d' "$rank")"
    conf="$TMP/candidates/$safe.conf"
    cat > "$conf" <<EOF
parent_node=$node
parent_rank=$rank
parent_candidate_id=$parent
parent_score=$score
parent_chain=$chain
gain_db=$gain
highpass_hz=$hp
lowpass_hz=$lp
denoise_floor_db=$nf
echo_delay_ms=$ed
echo_gain=$eg
cancel_strength=$cs
cancel_tweak_ms=$ct
compress=$co
compress_ratio=$cr
compress_threshold_db=$th
reject_bands=$rb
EOF
    printf '%s\t%s\t%s\t%s\n' "$node" "$rank" "$parent" "candidates/$safe.conf" >> "$TMP/inputs.tsv"
    count=$((count+1))
  done
done
(( count > 0 )) || { echo "FAIL: no promoted inputs found for $RANK_SPEC under $COLLECTED" >&2; exit 3; }
(cd "$TMP" && find . -type f ! -name INPUTS.sha256 -print0 | sort -z | xargs -0 sha256sum > INPUTS.sha256)

echo "TARGET ed209h -> $TARGET strong_candidates=$count rolling_windows=$(( $(wc -l < "$TMP/windows/windows.tsv") - 1 ))"
if ssh "${ssh_opts[@]}" "$TARGET" "cd ~/$REMOTE_BASE 2>/dev/null && ./node_status.sh ed209h 2>/dev/null | grep -q '^RUNNING '" </dev/null >/dev/null 2>&1; then
  echo 'FAIL: ed209h refinement is already running' >&2; exit 6
fi
ssh "${ssh_opts[@]}" "$TARGET" "rm -rf ~/$REMOTE_BASE.new && mkdir -p ~/$REMOTE_BASE.new"
tar -C "$ROOT" -cf - --exclude='./collected_results' --exclude='./tests/work*' --exclude='./foreign/lib*.so' --exclude='./foreign/audio_checkpoint_fsync' --exclude='./run' --exclude='./results' --exclude='./state' --exclude='./input' . \
  | ssh "${ssh_opts[@]}" "$TARGET" "tar -C ~/$REMOTE_BASE.new -xf -"
ssh "${ssh_opts[@]}" "$TARGET" "rm -rf ~/$REMOTE_BASE && mv ~/$REMOTE_BASE.new ~/$REMOTE_BASE && mkdir -p ~/$REMOTE_BASE/input/ed209h"
tar -C "$TMP" -cf - . | ssh "${ssh_opts[@]}" "$TARGET" "tar -C ~/$REMOTE_BASE/input/ed209h -xf -"
ssh "${ssh_opts[@]}" "$TARGET" "cd ~/$REMOTE_BASE && ./launch_h_refinement.sh"

while :; do
  status=$(ssh "${ssh_opts[@]}" "$TARGET" "cd ~/$REMOTE_BASE && ./node_status.sh ed209h" 2>/dev/null || true)
  echo "${status:-UNREACHABLE ed209h}"
  case "$status" in
    COMPLETE*) break;;
    FAILED*) ssh "${ssh_opts[@]}" "$TARGET" "cat ~/$REMOTE_BASE/run/ed209h.log" >&2 || true; exit 5;;
    UNKNOWN*) echo 'FAIL: ed209h process absent without completion status' >&2; exit 5;;
  esac
  sleep 10
done
rm -rf "$COLLECTED/ed209h"; mkdir -p "$COLLECTED/ed209h"
scp "${ssh_opts[@]}" -r "$TARGET:~/$REMOTE_BASE/results/ed209h/." "$COLLECTED/ed209h/" >/dev/null
ssh "${ssh_opts[@]}" "$TARGET" "cat ~/$REMOTE_BASE/run/ed209h.log" > "$COLLECTED/ed209h/run.log" || true
echo "PASS collected Strategy H rolling refinement: $COLLECTED/ed209h"
