#!/usr/bin/env bash
set -euo pipefail
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
NODES='ed209a,ed209b,ed209c,ed209d,ed209e,ed209i'; MODE=qualification; NO_PREP=0; NO_STAGE=0; RESET_STATE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --nodes) NODES=${2:?}; shift 2;;
    --full) MODE=full; shift;;
    --qualification) MODE=qualification; shift;;
    --no-prepare) NO_PREP=1; shift;;
    --no-stage) NO_STAGE=1; shift;;
    --reset-state) RESET_STATE=1; shift;;
    *) echo "unknown option $1" >&2; exit 2;;
  esac
done
IFS=',' read -r -a requested <<<"$NODES"
for n in "${requested[@]}"; do
  case "$n" in ed209a|ed209b|ed209c|ed209d|ed209e|ed209i) :;; *) echo "unknown node $n" >&2; exit 2;; esac
done
[[ $NO_PREP == 1 ]] || "$ROOT/prepare_samples.sh"
"$ROOT/verify_prepared_samples.sh"

remote_base=audio-rexx-search-v0.12-dev12
host_ip(){ case "$1" in ed209a) echo 193.123.184.140;; ed209b) echo 193.123.190.35;; ed209c) echo 52.146.17.8;; ed209d) echo 16.170.244.216;; ed209e) echo "${ED209E_HOST:-34.28.240.217}";; ed209i) echo "${ED209I_HOST:-20.114.63.150}";; esac; }
user_for(){ case "$1" in ed209a|ed209b) echo opc;; ed209c) echo azureuser;; ed209d) echo ec2-user;; ed209e) echo "${ED209E_USER:-animated.ads.cy}";; ed209i) echo "${ED209I_USER:-azureuser}";; esac; }
qual_limit(){ case "$1" in ed209a) echo 90;; ed209b) echo 90;; ed209c) echo 180;; ed209d) echo 60;; ed209e) echo 60;; ed209i) echo 60;; esac; }
ssh_opts(){
  local n=$1
  if [[ $n == ed209d ]]; then
    printf '%s\n' '-i' "$HOME/.ssh/AMAZON.pem"
  elif [[ $n == ed209e && -n ${GCP_KEY:-} ]]; then
    printf '%s\n' '-i' "$GCP_KEY"
  elif [[ $n == ed209i ]]; then
    printf '%s\n' '-i' "${ED209I_KEY:-$HOME/.ssh/id_ed25519}"
  fi
  printf '%s\n' '-o' 'BatchMode=yes' '-o' 'ConnectTimeout=12' '-o' 'ServerAliveInterval=15' '-o' 'ServerAliveCountMax=3'
}
resolve(){
  local n=$1 u ip h attempt
  u=$(user_for "$n"); ip=$(host_ip "$n")
  local -a opts=(); mapfile -t opts < <(ssh_opts "$n")
  for attempt in 1 2 3; do
    for h in "$n" "$ip"; do
      if ssh "${opts[@]}" "$u@$h" 'true' </dev/null >/dev/null 2>&1; then echo "$u@$h"; return 0; fi
    done
    sleep 2
  done
  return 1
}
remote_running(){
  local n=$1 target=$2
  local -a opts=(); mapfile -t opts < <(ssh_opts "$n")
  ssh "${opts[@]}" "$target" "cd ~/$remote_base 2>/dev/null && ./node_status.sh $n 2>/dev/null | grep -q '^RUNNING '" </dev/null >/dev/null 2>&1
}
stage_one(){
  local n=$1 target=$2 attempt preserve
  local -a opts=(); mapfile -t opts < <(ssh_opts "$n")
  if remote_running "$n" "$target"; then
    echo "REFUSE STAGE $n: v0.12-dev12 is already running; use --no-stage to attach/relaunch safely" >&2
    return 6
  fi
  preserve=1; [[ $RESET_STATE == 1 ]] && preserve=0
  for attempt in 1 2 3; do
    ssh "${opts[@]}" "$target" "rm -rf ~/$remote_base.new && mkdir -p ~/$remote_base.new; if [[ $preserve == 1 && -d ~/$remote_base/state/$n ]]; then mkdir -p ~/$remote_base.new/state; cp -a ~/$remote_base/state/$n ~/$remote_base.new/state/; fi" || { sleep 2; continue; }
    if tar -C "$ROOT" -cf - --exclude='./collected_results' --exclude='./tests/work*' --exclude='./foreign/lib*.so' --exclude='./foreign/audio_checkpoint_fsync' --exclude='./run/controller' --exclude='./state' . \
      | ssh "${opts[@]}" "$target" "tar -C ~/$remote_base.new -xf - && rm -rf ~/$remote_base && mv ~/$remote_base.new ~/$remote_base"; then
      return 0
    fi
    sleep 2
  done
  return 1
}
launch_one(){
  local n=$1 target=$2 lim='' reset=''
  local -a opts=(); mapfile -t opts < <(ssh_opts "$n")
  [[ $MODE == qualification ]] && lim="SEARCH_LIMIT=$(qual_limit "$n") "
  [[ $RESET_STATE == 1 && $n == ed209e ]] && reset='SEARCH_RESET_STATE=1 '
  ssh "${opts[@]}" "$target" "cd ~/$remote_base && ${lim}${reset}./launch_node.sh $n"
}

CTRL="$ROOT/run/controller"
rm -rf "$CTRL"; mkdir -p "$CTRL"
deploy_one(){
  local n=$1 target
  target=$(resolve "$n") || { echo "UNREACHABLE $n" >&2; return 4; }
  printf '%s\n' "$target" > "$CTRL/$n.target"
  echo "TARGET $n -> $target"
  if [[ $NO_STAGE == 0 ]]; then
    echo "STAGE $n"
    stage_one "$n" "$target" || { echo "STAGE FAILED $n" >&2; return 4; }
  fi
  launch_one "$n" "$target"
}

declare -A deploy_pid=()
for n in "${requested[@]}"; do
  deploy_one "$n" >"$CTRL/$n.deploy.log" 2>&1 &
  deploy_pid[$n]=$!
done

active=(); failed=(); paused=()
for n in "${requested[@]}"; do
  if wait "${deploy_pid[$n]}"; then
    cat "$CTRL/$n.deploy.log"
    active+=("$n")
  else
    cat "$CTRL/$n.deploy.log" >&2 || true
    failed+=("$n")
  fi
done

((${#active[@]})) || { echo 'FAIL: no nodes launched' >&2; exit 4; }
mkdir -p "$ROOT/collected_results"
pending=("${active[@]}")
declare -A unreachable_polls=()
MAX_UNREACHABLE_POLLS=${MAX_UNREACHABLE_POLLS:-6}
while ((${#pending[@]})); do
  next=()
  for n in "${pending[@]}"; do
    target=$(cat "$CTRL/$n.target" 2>/dev/null || true)
    if [[ -z "$target" ]]; then target=$(resolve "$n" || true); fi
    if [[ -z "$target" ]]; then
      unreachable_polls[$n]=$(( ${unreachable_polls[$n]:-0} + 1 ))
      if (( unreachable_polls[$n] >= MAX_UNREACHABLE_POLLS )); then
        echo "DEFERRED $n unreachable for ${unreachable_polls[$n]} monitor polls; checkpoint/state left intact" >&2
        paused+=("$n")
      else
        next+=("$n")
      fi
      continue
    fi
    mapfile -t opts < <(ssh_opts "$n")
    status=$(ssh "${opts[@]}" "$target" "cd ~/$remote_base && ./node_status.sh $n" 2>/dev/null || true)
    if [[ -z "$status" ]]; then
      target=$(resolve "$n" || true)
      if [[ -n "$target" ]]; then
        printf '%s\n' "$target" > "$CTRL/$n.target"
        status=$(ssh "${opts[@]}" "$target" "cd ~/$remote_base && ./node_status.sh $n" 2>/dev/null || true)
      fi
    fi
    if [[ -z "$status" ]]; then
      unreachable_polls[$n]=$(( ${unreachable_polls[$n]:-0} + 1 ))
      echo "UNREACHABLE $n poll=${unreachable_polls[$n]}/$MAX_UNREACHABLE_POLLS"
      if (( unreachable_polls[$n] >= MAX_UNREACHABLE_POLLS )); then
        echo "DEFERRED $n; restart/resume with --nodes $n --no-prepare --no-stage" >&2
        paused+=("$n")
      else
        next+=("$n")
      fi
      continue
    fi
    unreachable_polls[$n]=0
    echo "$status"
    if [[ "$status" == COMPLETE* ]]; then
      rm -rf "$ROOT/collected_results/$n"; mkdir -p "$ROOT/collected_results/$n"
      scp "${opts[@]}" -r "$target:~/$remote_base/results/$n/." "$ROOT/collected_results/$n/" >/dev/null
      ssh "${opts[@]}" "$target" "cat ~/$remote_base/run/$n.log" >"$ROOT/collected_results/$n/run.log" || true
      if [[ ${AUDIO_POOL_AUTO_OBSERVE:-0} == 1 ]]; then
        "$ROOT/publish_collected_observation.sh" "$n" "$ROOT/collected_results/$n" >"$CTRL/$n.observe.log" 2>&1 || {
          echo "WARN observation publish failed for $n; result collection remains authoritative" >&2
          cat "$CTRL/$n.observe.log" >&2 || true
        }
      fi
    elif [[ "$status" == FAILED* ]]; then
      ssh "${opts[@]}" "$target" "cat ~/$remote_base/run/$n.log" >&2 || true
      failed+=("$n")
    elif [[ "$status" == UNKNOWN* ]]; then
      if [[ $n == ed209e ]]; then
        echo "PAUSED $n: process absent; checkpoint/state preserved for explicit resume" >&2
        paused+=("$n")
      else
        echo "FAILED $n: process absent without completion rc" >&2
        failed+=("$n")
      fi
    else
      next+=("$n")
    fi
  done
  pending=("${next[@]}")
  ((${#pending[@]})) && sleep 10
done

if ((${#failed[@]} || ${#paused[@]})); then
  ((${#failed[@]})) && printf 'PARTIAL failed/unlaunched nodes: %s\n' "${failed[*]}" >&2
  ((${#paused[@]})) && printf 'PARTIAL paused/deferred nodes (state preserved): %s\n' "${paused[*]}" >&2
  exit 5
fi
"$ROOT/prepare_review.sh" "$ROOT/collected_results" "$ROOT/collected_results/review"
echo "PASS collected Rexx-native results: $ROOT/collected_results"
