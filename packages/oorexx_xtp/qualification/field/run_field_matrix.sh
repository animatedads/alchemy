#!/usr/bin/env bash
# Pairwise ED209 XTP field qualification.
# All managed-node access goes through sshnode.sh; direct ssh/scp is forbidden here.
# Tests:
#   host capability: AF_PACKET / EtherType 0x817D and raw IPv4 protocol 36
#   directed inter-host L3: native XTP/IP protocol 36
#   directed inter-host L4: XTP over UDP
#   directed inter-host L2: only pairs explicitly placed in the same l2_domain
#
# This script intentionally does NOT infer L2 adjacency from IP subnets.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
BIN="$ROOT/bin/xtp-local"
INV=${1:-${XTP_INVENTORY:-}}
OUT=${XTP_FIELD_OUT:-"$ROOT/qualification/field/results-$(date +%Y%m%d-%H%M%S)"}
SSHNODE=${XTP_SSHNODE:-$(command -v sshnode.sh || true)}
REMOTE_DIR=${XTP_REMOTE_DIR:-/tmp/xtp-field-qualification}
UDP_BASE=${XTP_UDP_BASE_PORT:-43600}
TIMEOUT_MS=${XTP_TIMEOUT_MS:-750}
RETRIES=${XTP_RETRIES:-6}
REMOTE_PRIV=${XTP_REMOTE_PRIV:-auto} # auto|sudo|none
mkdir -p "$OUT/hosts" "$OUT/pairs"

if [[ ! -x "$BIN" ]]; then make -C "$ROOT" clean all; fi
if [[ -z "$INV" || ! -f "$INV" ]]; then echo "set XTP_INVENTORY or pass a local inventory file" >&2; exit 2; fi

if [[ ! -x "$SSHNODE" ]]; then echo "sshnode helper not executable: $SSHNODE" >&2; exit 2; fi
ssh_cmd() { local node=$1; shift; "$SSHNODE" "$node" "$@"; }
transfer_to() { local src=$1 node=$2 dst=$3; "$SSHNODE" --transfer "$node" "$src" "$dst" >/dev/null; }

remote_exec_prefix() {
  local h=$1
  case "$REMOTE_PRIV" in
    none) echo "" ;;
    sudo) echo "sudo -n" ;;
    auto)
      if ssh_cmd "$h" "sudo -n true" >/dev/null 2>&1; then echo "sudo -n"; else echo ""; fi
      ;;
    *) echo "invalid XTP_REMOTE_PRIV=$REMOTE_PRIV" >&2; exit 2 ;;
  esac
}

# Parsed inventory arrays.
declare -a NAMES ADDRS SSHHOSTS DOMAINS L2IFS L2MACS
declare -A IDX
while IFS=$'\t' read -r name addr sh enabled dom l2if l2mac rest; do
  [[ -z "${name:-}" || "$name" == \#* ]] && continue
  [[ "${enabled:-0}" != 1 ]] && continue
  IDX[$name]=${#NAMES[@]}
  NAMES+=("$name"); ADDRS+=("$addr"); SSHHOSTS+=("$sh"); DOMAINS+=("${dom:-}"); L2IFS+=("${l2if:-}"); L2MACS+=("${l2mac:-}")
done < "$INV"

if ((${#NAMES[@]} < 2)); then echo 'need at least two enabled inventory rows' >&2; exit 2; fi

printf 'name\taddress\tssh\traw36\tl2_raw\tl2_selftest\tdefault_iface\tdefault_mac\tstatus\n' > "$OUT/host-capabilities.tsv"

# Deploy once and collect local capability from every host.
for i in "${!NAMES[@]}"; do
  name=${NAMES[$i]}; addr=${ADDRS[$i]}; sh=${SSHHOSTS[$i]}
  log="$OUT/hosts/$name.log"
  status=PASS; raw=UNKNOWN; l2=UNKNOWN; l2self=NOT_RUN; dif=; dmac=
  {
    echo "== $name $addr via $sh =="
    ssh_cmd "$sh" "mkdir -p '$REMOTE_DIR'" || { echo 'SSH_DEPLOY_FAIL'; exit 20; }
    transfer_to "$BIN" "$sh" "$REMOTE_DIR/xtp-local" || { echo 'TRANSFER_FAIL'; exit 21; }
    transfer_to "$ROOT/qualification/field/remote_host_probe.sh" "$sh" "$REMOTE_DIR/remote_host_probe.sh" || { echo 'TRANSFER_FAIL'; exit 21; }
    transfer_to "$ROOT/qualification/field/remote_l2_selftest.sh" "$sh" "$REMOTE_DIR/remote_l2_selftest.sh" || { echo 'TRANSFER_FAIL'; exit 21; }
    ssh_cmd "$sh" "chmod 755 '$REMOTE_DIR/xtp-local' '$REMOTE_DIR/remote_host_probe.sh' '$REMOTE_DIR/remote_l2_selftest.sh'"
    pref=$(remote_exec_prefix "$sh")
    if [[ -n "$pref" ]]; then
      # Give only raw socket capability to the test binary where setcap is available.
      ssh_cmd "$sh" "$pref sh -c 'command -v setcap >/dev/null 2>&1 && setcap cap_net_raw+ep \"$REMOTE_DIR/xtp-local\" || true'"
    fi
    ssh_cmd "$sh" "'$REMOTE_DIR/remote_host_probe.sh' '$REMOTE_DIR/xtp-local'"
    if [[ -n "$pref" ]]; then
      ssh_cmd "$sh" "$pref '$REMOTE_DIR/remote_l2_selftest.sh' '$REMOTE_DIR/xtp-local'" || true
    else
      echo 'L2_SELFTEST=SKIP_NO_PRIVILEGE'
    fi
  } >"$log" 2>&1 || status=FAIL
  grep -q '^RAW36 available' "$log" && raw=AVAILABLE || raw=UNAVAILABLE
  grep -q '^L2_RAW available' "$log" && l2=AVAILABLE || l2=UNAVAILABLE
  l2self=$(sed -n 's/^L2_SELFTEST=//p' "$log" | tail -1); [[ -z "$l2self" ]] && l2self=NOT_RUN
  dif=$(sed -n 's/^DEFAULT_IFACE=//p' "$log" | tail -1)
  dmac=$(sed -n 's/^DEFAULT_MAC=//p' "$log" | tail -1)
  # If L2 inventory fields were empty, use discovered default interface/MAC only as metadata,
  # never as proof that another host is L2 adjacent.
  [[ -z "${L2IFS[$i]}" ]] && L2IFS[$i]=$dif
  [[ -z "${L2MACS[$i]}" ]] && L2MACS[$i]=$dmac
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$addr" "$sh" "$raw" "$l2" "$l2self" "$dif" "$dmac" "$status" >> "$OUT/host-capabilities.tsv"
done

printf 'source\tdestination\tlevel\tcarrier\tresult\tdetail\n' > "$OUT/pair-matrix.tsv"

start_server() {
  local host=$1 carrier=$2 bind=$3 port=$4 logfile=$5
  local cmd
  case "$carrier" in
    raw36) cmd="'$REMOTE_DIR/xtp-local' server --carrier raw36 --bind '0.0.0.0' --max 1" ;;
    udp)   cmd="'$REMOTE_DIR/xtp-local' server --carrier udp --bind '0.0.0.0:$port' --max 1" ;;
    *) return 2 ;;
  esac
  ssh_cmd "$host" "rm -f '$REMOTE_DIR/server.out' '$REMOTE_DIR/server.err' '$REMOTE_DIR/server.pid'; nohup $cmd >'$REMOTE_DIR/server.out' 2>'$REMOTE_DIR/server.err' < /dev/null & echo \$! >'$REMOTE_DIR/server.pid'; cat '$REMOTE_DIR/server.pid'" >"$logfile.pid" 2>"$logfile.start.err"
}

stop_server() {
  local host=$1
  ssh_cmd "$host" "if test -s '$REMOTE_DIR/server.pid'; then kill \$(cat '$REMOTE_DIR/server.pid') 2>/dev/null || true; fi" >/dev/null 2>&1 || true
}

fetch_server_logs() {
  local host=$1 base=$2
  ssh_cmd "$host" "cat '$REMOTE_DIR/server.out' 2>/dev/null || true" >"$base.server.out" 2>/dev/null || true
  ssh_cmd "$host" "cat '$REMOTE_DIR/server.err' 2>/dev/null || true" >"$base.server.err" 2>/dev/null || true
}

run_ip_pair() {
  local si=$1 di=$2 carrier=$3 port=$4 level=$5
  local sname=${NAMES[$si]} dname=${NAMES[$di]} saddr=${ADDRS[$si]} daddr=${ADDRS[$di]} shs=${SSHHOSTS[$si]} shd=${SSHHOSTS[$di]}
  local base="$OUT/pairs/${sname}__${dname}__${carrier}"
  local key=$((100000 + si*1000 + di*10 + level))
  local msg="field-${sname}-to-${dname}-${carrier}"
  local result=FAIL detail=
  stop_server "$shd"
  if ! start_server "$shd" "$carrier" "$daddr" "$port" "$base"; then
    detail=SERVER_START_FAIL
  else
    sleep 0.25
    set +e
    if [[ "$carrier" == raw36 ]]; then
      ssh_cmd "$shs" "'$REMOTE_DIR/xtp-local' client --carrier raw36 --to '$daddr' --message '$msg' --key '$key' --timeout-ms '$TIMEOUT_MS' --retries '$RETRIES'" >"$base.client.out" 2>"$base.client.err"
    else
      ssh_cmd "$shs" "'$REMOTE_DIR/xtp-local' client --carrier udp --to '$daddr:$port' --message '$msg' --key '$key' --timeout-ms '$TIMEOUT_MS' --retries '$RETRIES'" >"$base.client.out" 2>"$base.client.err"
    fi
    rc=$?
    set -e
    sleep 0.15
    fetch_server_logs "$shd" "$base"
    stop_server "$shd"
    if [[ $rc -eq 0 ]] && grep -q "XTP_OK carrier=$carrier key=$key" "$base.client.out" && grep -q "DELIVER carrier=$carrier .*key=$key" "$base.server.out"; then
      result=PASS; detail="attempts=$(sed -n 's/.* attempts=\([0-9][0-9]*\).*/\1/p' "$base.client.out" | tail -1)"
    else
      if grep -qi 'Operation not permitted\|Permission denied' "$base.client.err" "$base.server.err" 2>/dev/null; then detail=LOCAL_PERMISSION
      elif grep -q 'XTP_FAILED retries_exhausted' "$base.client.err" 2>/dev/null; then detail=NO_RESPONSE_OR_FILTERED
      else detail="CLIENT_RC=$rc"
      fi
    fi
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$sname" "$dname" "$level" "$carrier" "$result" "$detail" >> "$OUT/pair-matrix.tsv"
}

# Every directed pair: native protocol 36 and UDP fallback/interconnect.
pairno=0
for si in "${!NAMES[@]}"; do
  for di in "${!NAMES[@]}"; do
    ((si==di)) && continue
    pairno=$((pairno+1))
    run_ip_pair "$si" "$di" raw36 0 3
    port=$((UDP_BASE + (pairno % 1000)))
    run_ip_pair "$si" "$di" udp "$port" 4
  done
done

# Optional pairwise L2. Only explicit same-domain pairs are tested. This protects us from
# mislabelling routed cloud hosts as a Layer-2 failure.
for si in "${!NAMES[@]}"; do
  for di in "${!NAMES[@]}"; do
    ((si==di)) && continue
    doms=${DOMAINS[$si]}; domd=${DOMAINS[$di]}
    [[ -z "$doms" || "$doms" != "$domd" ]] && continue
    sname=${NAMES[$si]}; dname=${NAMES[$di]}; shs=${SSHHOSTS[$si]}; shd=${SSHHOSTS[$di]}
    sif=${L2IFS[$si]}; dif=${L2IFS[$di]}; dmac=${L2MACS[$di]}
    base="$OUT/pairs/${sname}__${dname}__l2"
    if [[ -z "$sif" || -z "$dif" || -z "$dmac" ]]; then
      printf '%s\t%s\t2\tl2\tSKIP\tL2_METADATA_MISSING\n' "$sname" "$dname" >> "$OUT/pair-matrix.tsv"; continue
    fi
    stop_server "$shd"
    ssh_cmd "$shd" "rm -f '$REMOTE_DIR/server.out' '$REMOTE_DIR/server.err' '$REMOTE_DIR/server.pid'; nohup '$REMOTE_DIR/xtp-local' server --carrier l2 --interface '$dif' --max 1 >'$REMOTE_DIR/server.out' 2>'$REMOTE_DIR/server.err' < /dev/null & echo \$! >'$REMOTE_DIR/server.pid'" >/dev/null
    sleep .25
    key=$((220000 + si*1000 + di))
    msg="field-${sname}-to-${dname}-l2"
    set +e
    ssh_cmd "$shs" "'$REMOTE_DIR/xtp-local' client --carrier l2 --interface '$sif' --to-mac '$dmac' --message '$msg' --key '$key' --timeout-ms '$TIMEOUT_MS' --retries '$RETRIES'" >"$base.client.out" 2>"$base.client.err"
    rc=$?
    set -e
    fetch_server_logs "$shd" "$base"; stop_server "$shd"
    if [[ $rc -eq 0 ]] && grep -q "XTP_OK carrier=l2 key=$key" "$base.client.out" && grep -q "DELIVER carrier=l2 .*key=$key" "$base.server.out"; then
      printf '%s\t%s\t2\tl2\tPASS\tETHERTYPE_0x817D\n' "$sname" "$dname" >> "$OUT/pair-matrix.tsv"
    else
      printf '%s\t%s\t2\tl2\tFAIL\tNO_RESPONSE_OR_FILTERED\n' "$sname" "$dname" >> "$OUT/pair-matrix.tsv"
    fi
  done
done

# Summary tables are plain TSV so no jq/python dependency is required.
{
  echo '== XTP field qualification =='
  echo "inventory=$INV"
  echo "results=$OUT"
  echo
  echo '== host capabilities =='
  column -t -s $'\t' "$OUT/host-capabilities.tsv" 2>/dev/null || cat "$OUT/host-capabilities.tsv"
  echo
  echo '== directed pair matrix =='
  column -t -s $'\t' "$OUT/pair-matrix.tsv" 2>/dev/null || cat "$OUT/pair-matrix.tsv"
  echo
  awk -F '\t' 'NR>1 {k=$3"/"$4"/"$5; c[k]++} END {for(k in c) print k,c[k]}' "$OUT/pair-matrix.tsv" | sort
} | tee "$OUT/SUMMARY.txt"

echo "FIELD_MATRIX_COMPLETE results=$OUT"
