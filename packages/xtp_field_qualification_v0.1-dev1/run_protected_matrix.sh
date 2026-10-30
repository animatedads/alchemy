#!/usr/bin/env bash
# dev36 field run: protected named-service XTP sessions between ED209 hosts.
# Architecture: Tom Dyer (D-07).  Coding: Claude (Opus 5.5).
#
# For every directed pair of enabled inventory hosts, over native XTP (IPv4
# protocol 36, level 3) and XTP over UDP (level 4), three opens to the named
# service svc.field, whose key exists only for this run:
#   1. clear, with no key        must be refused by the listener: AUTH_REQUIRED
#   2. a wrong secret, same id   must be dropped by the listener: open tag did not verify
#   3. the right key             1 MiB each way, encrypted, byte-exact, with the
#                                dev36 protection evidence printed at both ends
# A pair passes only if all three do.  Results go under
# results-protected-YYYYMMDD-HHMMSS/ in this package; SUMMARY.txt is the receipt.
#
# All node access goes through sshnode.sh (never ssh/scp directly).  On each node
# everything goes in one directory, $HOME/xtp-field-dev36, which is removed at the
# end.  Nothing is installed.  If passwordless sudo exists, it is used only to
# give the copied binary cap_net_raw (setcap) for protocol 36, or, if setcap is
# missing, to run that binary for the protocol-36 tests.
#
# Environment (all optional):
#   XTP_SSHNODE      sshnode helper  (default /home/hc3/alchemy-autobuild/sshnode.sh)
#   XTP_FIELD_NODES  inventory names to use, e.g. "ED209A ED209C" (default: all enabled)
#   XTP_FIELD_BYTES  bytes each way in test 3 (default 1048576)
#   XTP_UDP_BASE_PORT                (default 43600)
set -uo pipefail
ROOT=$(cd "$(dirname "$0")" && pwd)
FIELD="$ROOT"
BIN="$FIELD/bin/xtp-field"
INV=${1:-"$FIELD/inventory.tsv"}
SSHNODE=${XTP_SSHNODE:-/home/hc3/alchemy-autobuild/sshnode.sh}
ONLY=${XTP_FIELD_NODES:-}
BYTES=${XTP_FIELD_BYTES:-1048576}
UDP_BASE=${XTP_UDP_BASE_PORT:-43600}
STAMP=$(date +%Y%m%d-%H%M%S)
OUT="$FIELD/results-protected-$STAMP"
RDIRNAME=xtp-field-dev36
KEYID=00000000000f1e1d
SERVICE=svc.field

say() { echo "$*" | tee -a "$OUT/run.log"; }
mkdir -p "$OUT/hosts" "$OUT/pairs" "$OUT/keys" || exit 2
chmod 700 "$OUT/keys"
say "FIELD_PROTECTED_START $STAMP"

# The binary must be the committed one.
( cd "$FIELD/bin" && sha256sum -c xtp-field.sha256 ) >>"$OUT/run.log" 2>&1 || { say "FIELD_PROTECTED_ABORT the xtp-field binary does not match bin/xtp-field.sha256"; exit 2; }
[[ -x "$SSHNODE" ]] || { say "FIELD_PROTECTED_ABORT sshnode helper not executable: $SSHNODE"; exit 2; }
[[ -f "$INV" ]] || { say "FIELD_PROTECTED_ABORT inventory not found: $INV"; exit 2; }
say "binary_sha256=$(cut -c1-64 "$FIELD/bin/xtp-field.sha256") commit=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"

# Keys for this run only: one right secret, one wrong secret under the same id.
umask 077
rnd() { head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n'; }
printf '%s %s encrypt aes256gcm %s\n' "$SERVICE" "$KEYID" "$(rnd)" > "$OUT/keys/good.keys"
printf '%s %s encrypt aes256gcm %s\n' "$SERVICE" "$KEYID" "$(rnd)" > "$OUT/keys/wrong.keys"
umask 022

node() { "$SSHNODE" "$@"; }

declare -a NAMES ADDRS NODES RHOME PFX KEYS RAW DEPLOY
while IFS=$'\t' read -r name addr sh enabled rest; do
  [[ -z "${name:-}" || "$name" == \#* ]] && continue
  [[ "${enabled:-0}" != 1 ]] && continue
  if [[ -n "$ONLY" ]] && [[ " $ONLY " != *" $name "* ]]; then continue; fi
  NAMES+=("$name"); ADDRS+=("$addr"); NODES+=("$sh")
done < "$INV"
((${#NAMES[@]} >= 2)) || { say "FIELD_PROTECTED_ABORT need at least two hosts"; exit 2; }

# 1. Deploy and probe every host.
printf 'name\taddress\tnode\tarch\tdeploy\traw36\trun_as\tclock_skew_ms\thost\n' > "$OUT/host-capabilities.tsv"
for i in "${!NAMES[@]}"; do
  n=${NAMES[$i]}; sh=${NODES[$i]}; log="$OUT/hosts/$n.log"
  PFX[$i]=""; RAW[$i]=UNAVAILABLE; deploy=FAIL; skew=-; hostline=-
  home=$(node "$sh" 'echo $HOME' 2>>"$log" | tail -1)
  arch=$(node "$sh" 'uname -m' 2>>"$log" | tail -1); [[ -z "$arch" ]] && arch=unknown
  RHOME[$i]=$home; d="$home/$RDIRNAME"; KEYS[$i]="$d/good.keys"
  # bin/xtp-field is x86-64 only: another architecture is reported, not failed
  if [[ "$arch" != x86_64 ]]; then deploy="UNSUPPORTED_ARCH_$arch"; home=""; fi
  if [[ "$home" == /* ]] && node "$sh" "mkdir -p '$d' && chmod 700 '$d'" >>"$log" 2>&1 \
     && node --transfer "$sh" "$BIN" "$d/xtp-field" >>"$log" 2>&1 \
     && node --transfer "$sh" "$OUT/keys/good.keys" "$d/good.keys" >>"$log" 2>&1 \
     && node --transfer "$sh" "$OUT/keys/wrong.keys" "$d/wrong.keys" >>"$log" 2>&1 \
     && node "$sh" "chmod 755 '$d/xtp-field' && chmod 600 '$d/good.keys' '$d/wrong.keys'" >>"$log" 2>&1; then
    deploy=OK
    t0=$(date +%s%3N); p=$(node "$sh" "'$d/xtp-field' probe" 2>>"$log"); t1=$(date +%s%3N)
    echo "$p" >>"$log"
    clk=$(sed -n 's/^FIELD_CLOCK_MS //p' <<<"$p" | tail -1)
    [[ -n "$clk" ]] && skew=$(( clk - (t0 + t1) / 2 ))
    hostline=$(sed -n 's/^FIELD_HOST //p' <<<"$p" | tail -1 | tr ' ' '_')
    if grep -q '^FIELD_RAW36 available' <<<"$p"; then RAW[$i]=AVAILABLE
    elif node "$sh" "sudo -n true" >/dev/null 2>&1; then
      node "$sh" "sudo -n sh -c 'command -v setcap >/dev/null 2>&1 && setcap cap_net_raw+ep \"$d/xtp-field\"'" >>"$log" 2>&1
      if node "$sh" "'$d/xtp-field' probe" 2>>"$log" | grep -q '^FIELD_RAW36 available'; then RAW[$i]=AVAILABLE_SETCAP
      else
        # no setcap: run this binary under sudo for protocol 36, with root-owned key copies
        if node "$sh" "sudo -n sh -c 'cp \"$d/good.keys\" \"$d/good.root.keys\" && cp \"$d/wrong.keys\" \"$d/wrong.root.keys\" && chown 0:0 \"$d\"/*.root.keys && chmod 600 \"$d\"/*.root.keys'" >>"$log" 2>&1 \
           && node "$sh" "sudo -n '$d/xtp-field' probe" 2>>"$log" | grep -q '^FIELD_RAW36 available'; then
          RAW[$i]=AVAILABLE_SUDO; PFX[$i]="sudo -n"
        fi
      fi
    fi
  fi
  DEPLOY[$i]=$deploy
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$n" "${ADDRS[$i]}" "$sh" "$arch" "$deploy" "${RAW[$i]}" "${PFX[$i]:-user}" "$skew" "$hostline" >> "$OUT/host-capabilities.tsv"
  say "host $n arch=$arch deploy=$deploy raw36=${RAW[$i]} clock_skew_ms=$skew"
  [[ "$deploy" == OK ]] || RHOME[$i]=""
done

# 2. Every directed pair, both carriers.
printf 'source\tdestination\tlevel\tcarrier\tresult\tclear_refused\twrong_key_dropped\tencrypted_echo\topen_ms\techo_ms\tmbit_s\tsrtt_ms\tretransmitted\tdetail\n' > "$OUT/pair-matrix.tsv"
run_pair() {
  local si=$1 di=$2 carrier=$3 port=$4 level=$5
  local sn=${NAMES[$si]} dn=${NAMES[$di]} ssh_s=${NODES[$si]} ssh_d=${NODES[$di]}
  local base="$OUT/pairs/${sn}__${dn}__${carrier}"
  local ds="${RHOME[$di]}/$RDIRNAME" ss="${RHOME[$si]}/$RDIRNAME"
  local dpfx="" spfx="" dkeys="$ds/good.keys" sgood="$ss/good.keys" swrong="$ss/wrong.keys"
  if [[ "$carrier" == raw36 ]]; then
    dpfx=${PFX[$di]}; spfx=${PFX[$si]}
    [[ -n "$dpfx" ]] && dkeys="$ds/good.root.keys"
    [[ -n "$spfx" ]] && { sgood="$ss/good.root.keys"; swrong="$ss/wrong.root.keys"; }
  fi
  local bind to
  if [[ "$carrier" == udp ]]; then bind="0.0.0.0:$port"; to="${ADDRS[$di]}:$port"; else bind="0.0.0.0"; to="${ADDRS[$di]}"; fi
  if [[ -z "${RHOME[$si]}" || -z "${RHOME[$di]}" ]]; then
    local why=DEPLOY_FAILED; [[ "${DEPLOY[$si]}${DEPLOY[$di]}" == *UNSUPPORTED_ARCH* ]] && why=UNSUPPORTED_ARCH
    printf '%s\t%s\t%s\t%s\tSKIP\t-\t-\t-\t-\t-\t-\t-\t-\t%s\n' "$sn" "$dn" "$level" "$carrier" "$why" >> "$OUT/pair-matrix.tsv"
    say "pair $sn -> $dn $carrier SKIP $why"; return
  fi
  # the listener: one encrypted session, then it exits (20 s idle limit)
  node "$ssh_d" "rm -f '$ds/server.out' '$ds/server.err'; nohup $dpfx '$ds/xtp-field' serve --carrier $carrier --bind '$bind' --services $SERVICE --keys '$dkeys' --max 1 --idle-s 20 >'$ds/server.out' 2>'$ds/server.err' </dev/null & echo \$! >'$ds/server.pid'" >"$base.start.log" 2>&1
  sleep 0.7
  # the opener: tests 1, 2 and 3 in one call (1.2 s apart, so the listener logs each)
  node "$ssh_s" "cd '$ss'; echo '== 1 clear, no key'; $spfx ./xtp-field open --carrier $carrier --to '$to' --service $SERVICE --keys none --protection none --expect refused --timeout-ms 3000; echo rc1=\$?; sleep 1.2;
    echo '== 2 wrong secret'; $spfx ./xtp-field open --carrier $carrier --to '$to' --service $SERVICE --keys '$swrong' --expect refused --timeout-ms 3000; echo rc2=\$?; sleep 1.2;
    echo '== 3 right key'; $spfx ./xtp-field open --carrier $carrier --to '$to' --service $SERVICE --keys '$sgood' --bytes $BYTES --timeout-ms 4000; echo rc3=\$?" >"$base.client.log" 2>&1
  sleep 0.5
  node "$ssh_d" "cat '$ds/server.out'" >"$base.server.out" 2>/dev/null
  node "$ssh_d" "cat '$ds/server.err'" >"$base.server.err" 2>/dev/null
  node "$ssh_d" "test -s '$ds/server.pid' && $dpfx kill \$(cat '$ds/server.pid') 2>/dev/null; rm -f '$ds/server.pid'; true" >/dev/null 2>&1
  local c=$base.client.log so=$base.server.out se=$base.server.err
  local clear=NO wrong=NO echo=NO detail=- result=FAIL
  grep -q 'FIELD_REFUSED_OK .*AUTH_REQUIRED' "$c" && grep -q 'XTP_DIAG_SENT .*value=17' "$se" && clear=YES
  grep -q '^rc2=0' "$c" && grep -q 'open tag did not verify' "$se" && wrong=YES
  local ok=$(grep '^FIELD_OK ' "$c" | tail -1) sess=$(grep '^FIELD_SESSION ' "$c" | tail -1)
  local acc=$(grep '^FIELD_ACCEPT ' "$so" | tail -1) srv=$(grep '^FIELD_SERVED ' "$so" | tail -1)
  local csha=$(sed -n 's/.* sha256=\([0-9a-f]*\).*/\1/p' <<<"$ok") ssha=$(sed -n 's/.* sha256=\([0-9a-f]*\).*/\1/p' <<<"$srv")
  if [[ -n "$ok" && "$ok" == *"protection=encrypt keyId=$KEYID"* && "$acc" == *"protection=encrypt"*"keyId=$KEYID"* && -n "$csha" && "$csha" == "$ssha" ]]; then echo=YES; fi
  local open_ms=$(sed -n 's/.*open_ms=\([0-9]*\).*/\1/p' <<<"$sess") echo_ms=$(sed -n 's/.* echo_ms=\([0-9]*\).*/\1/p' <<<"$ok")
  local mbit=$(sed -n 's/.*mbit_s_both_ways=\([0-9.]*\).*/\1/p' <<<"$ok") srtt=$(sed -n 's/.*srtt_ms=\([-0-9]*\).*/\1/p' <<<"$ok") rtx=$(sed -n 's/.*retransmitted=\([0-9]*\).*/\1/p' <<<"$ok")
  if [[ $clear == YES && $wrong == YES && $echo == YES ]]; then result=PASS
  elif grep -qi 'Operation not permitted\|Permission denied' "$c" "$se" 2>/dev/null; then detail=LOCAL_PERMISSION
  elif grep -q 'clock window' "$se" 2>/dev/null; then detail=CLOCK_SKEW
  elif ! grep -q 'FIELD_LISTENING' "$so" 2>/dev/null; then detail=LISTENER_NOT_STARTED
  elif [[ -z "$acc" ]] && ! grep -q 'XTP_DIAG_SENT\|OPEN_DROPPED' "$se" 2>/dev/null; then detail=NO_RESPONSE_OR_FILTERED
  else detail=$(grep -m1 '^FIELD_FAIL' "$c" | tr '\t' ' ' | cut -c1-120); [[ -z "$detail" ]] && detail=CHECK_LOGS
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$sn" "$dn" "$level" "$carrier" "$result" "$clear" "$wrong" "$echo" "${open_ms:--}" "${echo_ms:--}" "${mbit:--}" "${srtt:--}" "${rtx:--}" "$detail" >> "$OUT/pair-matrix.tsv"
  say "pair $sn -> $dn $carrier $result clear_refused=$clear wrong_key_dropped=$wrong encrypted_echo=$echo $detail"
  if [[ $result == PASS ]]; then
    { echo "== $sn -> $dn $carrier"; echo "opener   $sess"; echo "acceptor $acc"; echo "transfer $ok"; } >> "$OUT/evidence.txt"
  fi
}
pairno=0
for si in "${!NAMES[@]}"; do
  for di in "${!NAMES[@]}"; do
    ((si == di)) && continue
    pairno=$((pairno + 1))
    run_pair "$si" "$di" raw36 0 3
    run_pair "$si" "$di" udp $((UDP_BASE + pairno % 1000)) 4
  done
done

# 3. Remove everything from the nodes, and this run's keys from here.
for i in "${!NAMES[@]}"; do
  [[ -n "${RHOME[$i]}" ]] || continue
  d="${RHOME[$i]}/$RDIRNAME"
  if [[ -n "${PFX[$i]}" ]]; then node "${NODES[$i]}" "sudo -n rm -f '$d/good.root.keys' '$d/wrong.root.keys'" >/dev/null 2>&1; fi
  node "${NODES[$i]}" "rm -rf '$d'" >/dev/null 2>&1 && say "cleaned ${NAMES[$i]}" || say "CLEANUP_FAILED ${NAMES[$i]} $d"
done
rm -f "$OUT/keys/good.keys" "$OUT/keys/wrong.keys"; rmdir "$OUT/keys" 2>/dev/null

# 4. The receipt.
{
  echo "== XTP dev36 protected field run $STAMP =="
  echo "Architecture: Tom Dyer (D-07). Coding: Claude (Opus 5.5). Run on the ED209 hosts by the operator's machine."
  grep '^binary_sha256=' "$OUT/run.log"
  echo "service=$SERVICE keyId=$KEYID (key made for this run, removed after it) bytes_each_way=$BYTES"
  echo
  echo '== hosts =='; column -t -s $'\t' "$OUT/host-capabilities.tsv" 2>/dev/null || cat "$OUT/host-capabilities.tsv"
  echo
  echo '== directed pairs =='; column -t -s $'\t' "$OUT/pair-matrix.tsv" 2>/dev/null || cat "$OUT/pair-matrix.tsv"
  echo
  echo '== counts (level/carrier/result) =='
  awk -F '\t' 'NR>1 {c[$3"/"$4"/"$5]++} END {for (k in c) print k, c[k]}' "$OUT/pair-matrix.tsv" | sort
} > "$OUT/SUMMARY.txt"
cat "$OUT/SUMMARY.txt" >> "$OUT/run.log"
say "FIELD_PROTECTED_COMPLETE results=$OUT"
