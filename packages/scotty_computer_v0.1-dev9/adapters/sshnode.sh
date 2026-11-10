#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  ./sshnode.sh NODE
  ./sshnode.sh NODE COMMAND [ARG...]
  ./sshnode.sh --job-id JOB_ID NODE COMMAND [ARG...]
  ./sshnode.sh --transfer NODE LOCAL_FILE [REMOTE_FILE]
  ./sshnode.sh NODE --transfer LOCAL_FILE [REMOTE_FILE]
  ./sshnode.sh --pull NODE REMOTE_FILE [LOCAL_FILE]
  ./sshnode.sh NODE --pull REMOTE_FILE [LOCAL_FILE]

Examples:
  ./sshnode.sh ed209c
  SSHNODE_JOB_ID=audio-campaign-01 ./sshnode.sh ed209c queue status --json
  ./sshnode.sh --transfer ed209h ./job.zip ~/job.zip
  ./sshnode.sh --pull ed209h /tmp/results.tar.gz ./results.tar.gz
EOF
  exit 2
}

[[ $# -ge 1 ]] || usage

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
log_file=${SSHNODE_LOG:-$script_dir/sshnode.log}
job_id=${SSHNODE_JOB_ID:-}

if [[ ${1:-} == --job-id ]]; then
  [[ $# -ge 3 ]] || usage
  job_id=$2
  shift 2
elif [[ ${1:-} == --job-id=* ]]; then
  job_id=${1#--job-id=}
  [[ -n $job_id ]] || usage
  shift
fi

if [[ -z $job_id ]]; then
  job_id="sshnode-$(date -u +%Y%m%dT%H%M%SZ)-$$"
fi

log_event() {
  local event=$1
  shift
  local line
  printf -v line '%s job_id=%q event=%q %s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$job_id" "$event" "$*"
  mkdir -p -- "$(dirname -- "$log_file")" 2>/dev/null || true
  if command -v flock >/dev/null 2>&1; then
    { flock -x 9; printf '%s' "$line" >> "$log_file"; } 9>>"$log_file"
  else
    printf '%s' "$line" >> "$log_file"
  fi
}

started_epoch=$(date +%s)
completed=0
on_exit() {
  local rc=$?
  [[ $completed -eq 1 ]] && return
  completed=1
  local finished_epoch duration
  finished_epoch=$(date +%s)
  duration=$((finished_epoch - started_epoch))
  log_event completed "node=$node mode=$mode rc=$rc duration_seconds=$duration"
}
trap on_exit EXIT

mode=ssh
node=''
local_file=''
remote_file=''

if [[ $1 == --transfer ]]; then
  mode=transfer
  [[ $# -ge 3 ]] || usage
  node=$2
  local_file=$3
  remote_file=${4:-$(basename -- "$local_file")}
  shift $#
elif [[ $1 == --pull || $1 == --download ]]; then
  mode=pull
  [[ $# -ge 3 ]] || usage
  node=$2
  remote_file=$3
  local_file=${4:-$(basename -- "$remote_file")}
  shift $#
else
  node=$1
  shift
  if [[ ${1:-} == --transfer ]]; then
    mode=transfer
    [[ $# -ge 2 ]] || usage
    local_file=$2
    remote_file=${3:-$(basename -- "$local_file")}
    shift $#
  elif [[ ${1:-} == --pull || ${1:-} == --download ]]; then
    mode=pull
    [[ $# -ge 2 ]] || usage
    remote_file=$2
    local_file=${3:-$(basename -- "$remote_file")}
    shift $#
  fi
fi

if [[ $mode == transfer || $mode == pull ]]; then
  [[ $# -eq 0 ]] || usage
fi

case "$node" in
  ed209a) user=opc; host=193.123.184.140; key='';;
  ed209b) user=opc; host=193.123.190.35; key='';;
  ed209c) user=azureuser; host=52.146.17.8; key='';;
  ed209d) user=ec2-user; host=16.170.244.216; key="$HOME/.ssh/AMAZON.pem";;
  # ED209E is a normal OpenSSH target.  Let ssh use this system's
  # ssh_config, agent and default identities; GCP_KEY remains an optional
  # explicit override for callers that genuinely need one.
  ed209e) user=${ED209E_USER:-animated.ads.cy}; host=${ED209E_HOST:-34.16.115.198}; key="${GCP_KEY:-}";;
  ed209h) user=linuxuser; host=155.138.214.182; key='';;
  ed209i) user=azureuser; host=${ED209I_HOST:-20.114.63.150}; key="${ED209I_KEY:-$HOME/.ssh/id_ed25519}";;
  ed209k) user=${ED209K_USER:-root}; host=${ED209K_HOST:-80.240.21.156}; key="${ED209K_KEY:-$script_dir/gcloud-ssh/ed209k}";;
  ed209j) user=bashqueue; host=${ED209J_HOST:-34.44.126.133}; key="$script_dir/gcloud-ssh/ed209j";;
  ed209x) user=u0_a329; host=192.168.188.25; key="$HOME/.ssh/id_ed25519a";;
  *) echo "Unknown node: $node" >&2; usage;;
esac

batch_mode=${SSHNODE_BATCH_MODE:-yes}
[[ $batch_mode == yes || $batch_mode == no ]] || { echo 'SSHNODE_BATCH_MODE must be yes or no' >&2; exit 2; }
ssh_args=(-F "$HOME/.ssh/config" -o "BatchMode=$batch_mode" -o ConnectTimeout="${SSHNODE_CONNECT_TIMEOUT:-12}" -o ServerAliveInterval=15 -o ServerAliveCountMax=3)
[[ -n "$key" ]] && ssh_args+=(-i "$key")
scp_args=("${ssh_args[@]}")

# ed209i has no stable host-key entry in the local managed workspace.
if [[ $node == ed209e || $node == ed209i || $node == ed209x ]]; then
  ssh_args+=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR)
  scp_args+=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR)
fi

if [[ $node == ed209j ]]; then
  ssh_args+=(-o StrictHostKeyChecking=yes -o UserKnownHostsFile="$script_dir/gcloud-ssh/known_hosts")
  scp_args+=(-o StrictHostKeyChecking=yes -o UserKnownHostsFile="$script_dir/gcloud-ssh/known_hosts")
fi

if [[ $node == ed209k ]]; then
  ssh_args+=(-o StrictHostKeyChecking=accept-new -o UserKnownHostsFile="$script_dir/ed209k_known_hosts")
  scp_args+=(-o StrictHostKeyChecking=accept-new -o UserKnownHostsFile="$script_dir/ed209k_known_hosts")
fi

if [[ $node == ed209x ]]; then
  ssh_args+=(-p 8022)
  scp_args+=(-P 8022)
fi

if [[ $mode == transfer ]]; then
  operation="scp transfer local=$(printf '%q' "$local_file") remote=$(printf '%q' "$remote_file")"
elif [[ $mode == pull ]]; then
  operation="scp pull remote=$(printf '%q' "$remote_file") local=$(printf '%q' "$local_file")"
else
  operation="ssh command="
  for arg in "$@"; do
    printf -v quoted '%q' "$arg"
    operation+=" $quoted"
  done
fi
log_event started "node=$node mode=$mode target=$(printf '%q' "$user@$host") $operation"

if [[ $mode == transfer ]]; then
  [[ -f "$local_file" ]] || { echo "Local file not found: $local_file" >&2; exit 1; }
  scp "${scp_args[@]}" "$local_file" "$user@$host:$remote_file"
  exit $?
elif [[ $mode == pull ]]; then
  scp "${scp_args[@]}" "$user@$host:$remote_file" "$local_file"
  exit $?
else
  ssh "${ssh_args[@]}" "$user@$host" "$@"
  exit $?
fi
