#!/usr/bin/env bash
# ed209_readonly_snapshot.sh -- Increment A, READ-ONLY estate snapshot of the ten ED209 MUs.
# Author: Claude (Opus 5.5), 2026-10-23. Architecture: Tom Dyer.
#
# What it does: for each MU it runs ONE block of read-only commands through the operator's
# existing sshnode.sh and saves the output to a file. Nothing is started, stopped, written,
# installed or restarted on any host. No key material is collected:
#   - node.env: only GRID_NODE_ID / GRID_MU_ID / GRID_NODE_MAC / GRID_ROUTE_ID / GRID_GRID_ID lines
#   - peers.manifest: column 4 (KEY_HEX) is cut out
#   - every other run of 32+ hex characters is replaced by <REDACTED-HEX> on THIS machine before
#     saving, except lines produced by sha256sum (64 hex + two spaces + absolute path).
# sudo is used only if it works non-interactively (sudo -n); otherwise root-only reads show as missing.
#
# Usage (run from the directory that holds sshnode.sh):
#   bash ed209_readonly_snapshot.sh
# Optional: HOSTS="ed209f ed209h" bash ed209_readonly_snapshot.sh
# Output: ./ed209-snapshot-<UTC timestamp>/<host>.txt and ./ed209-snapshot-<UTC timestamp>.tar.gz
set -uo pipefail

SSHNODE=${SSHNODE:-./sshnode.sh}
HOSTS=${HOSTS:-"ed209a ed209b ed209c ed209d ed209e ed209i ed209j ed209k ed209f ed209h"}
PER_HOST_TIMEOUT=${PER_HOST_TIMEOUT:-180}

if [[ ! -f $SSHNODE ]]; then
  echo "sshnode.sh not found at $SSHNODE -- run this from the directory that contains it" >&2
  exit 2
fi

read -r -d '' BLOCK <<'REMOTE'
set +e
S=""; if sudo -n true 2>/dev/null; then S="sudo -n"; fi
echo "=== HOST"; hostname; date -u +%Y-%m-%dT%H:%M:%SZ; uname -srm; head -2 /etc/os-release 2>/dev/null; echo "nproc=$(nproc)"; free -m | head -2; echo "user=$(id -un) sudo_noninteractive=${S:-NO}"; systemd-detect-virt 2>/dev/null
echo "=== QEMU"
command -v qemu-system-x86_64 || echo "qemu-system-x86_64: ABSENT"
ls -l /usr/libexec/qemu-kvm 2>/dev/null || echo "/usr/libexec/qemu-kvm: ABSENT"
qemu-system-x86_64 --version 2>/dev/null | head -1
/usr/libexec/qemu-kvm --version 2>/dev/null | head -1
ls -l /dev/kvm 2>/dev/null || echo "/dev/kvm: ABSENT"
echo "=== OOREXX"; command -v rexx || echo "rexx: ABSENT"; rexx -v 2>&1 | head -1
echo "=== UNITS"; systemctl list-units --all --no-pager --plain 2>/dev/null | grep -i -E 'grid|rexxos|xtp|qemu|alchemy|queue'
echo "=== UNIT_FILES"; systemctl list-unit-files --no-pager 2>/dev/null | grep -i -E 'grid|rexxos|xtp|qemu|alchemy'
echo "=== GUEST_PROCS"; ps -eo pid,etimes,args | grep -E '[q]emu' | cut -c1-700
echo "=== XTP_AND_REXX_PROCS"; ps -eo pid,etimes,args | grep -E '[x]tp|[q]f-xtp|[r]exx' | cut -c1-300
echo "=== LINKS"; ip -br link 2>/dev/null; ip -br addr 2>/dev/null; bridge link 2>/dev/null
echo "=== IFFLAGS (0x100 = promiscuous)"; for i in /sys/class/net/*; do echo "$(basename "$i") flags=$(cat "$i/flags") mtu=$(cat "$i/mtu")"; done
echo "=== UDP_62801"; ss -uanp 2>/dev/null | grep -E ':62801([^0-9]|$)'
echo "=== RAW_SOCKETS"; cat /proc/net/raw 2>/dev/null
echo "=== PACKET_SOCKETS"; cat /proc/net/packet 2>/dev/null
echo "=== CAPS"; grep -E '^Cap(Prm|Eff|Bnd)' /proc/self/status; capsh --print 2>/dev/null | grep -i '^current'
echo "=== GRID_FILES"
$S find /opt/rexxos /etc/grid /etc/rexxos-grid /var/lib/rexxos-grid -maxdepth 5 \( -name 'qf-xtp-rpc' -o -name '*.cpio*' -o -name '*.qcow2' -o -name '*.img' -o -name 'bzImage*' -o -name 'vmlinuz*' -o -name 'node.env' -o -name 'mu.env' -o -name 'peers.manifest*' -o -name 'xtp.routes.tsv' -o -name '*.service' -o -name 'rto2-test.env' \) -printf '%p %s %TY-%Tm-%Td %TH:%TM\n' 2>/dev/null
echo "=== HASHES (binaries and images only, never key files)"
$S find /opt/rexxos /var/lib/rexxos-grid -maxdepth 5 -type f \( -name 'qf-xtp-rpc' -o -name '*.cpio*' -o -name 'bzImage*' -o -name 'vmlinuz*' -o -name '*.so' -o -name 'xtp-*' \) -size -2G -exec $S sha256sum {} + 2>/dev/null
echo "=== IDENTITY (non-secret fields only)"
for f in $($S find /etc/grid -name node.env 2>/dev/null); do echo "-- $f"; $S grep -E '^(GRID_NODE_ID|GRID_MU_ID|GRID_NODE_MAC|GRID_ROUTE_ID|GRID_GRID_ID)=' "$f"; done
echo "=== PEERS (KEY_HEX column removed)"
for f in $($S find /etc/grid -name 'peers.manifest*' 2>/dev/null); do echo "-- $f"; $S cut -d'|' -f1-3,5-9 "$f"; done
echo "=== ROUTES"
for f in $($S find /etc/grid -name 'xtp.routes.tsv' 2>/dev/null); do echo "-- $f"; $S cat "$f"; done
echo "=== RTO2_STATE"
$S ls -la /opt/rexxos/rto2-smoke /opt/rexxos/rto2-smoke/bin /opt/rexxos/rto2-smoke/rexx /opt/rexxos/rto2-smoke/ops 2>/dev/null
$S sha256sum /opt/rexxos/rto2-smoke/bin/* /opt/rexxos/rto2-smoke/rexx/* /opt/rexxos/rto2-smoke/ops/* 2>/dev/null
echo "-- rto2-test.env (documented as non-secret)"; $S cat /etc/rexxos-grid/rto2-test.env 2>/dev/null
echo "-- result stores"; $S find /var/lib/rexxos-grid -maxdepth 4 -path '*rto2-job-results*' -printf '%p %s %TY-%Tm-%Td %TH:%TM\n' 2>/dev/null
echo "-- private stage directory names only"; $S ls -la /root/rexxos-private-stage 2>/dev/null
echo "-- ed209-rto2 unit definitions"; for u in $(systemctl list-units --all --no-pager --plain 'ed209-rto2-*' 2>/dev/null | awk '{print $1}' | grep -E '\.service$'); do echo "---- $u"; $S systemctl cat "$u" 2>/dev/null; $S systemctl show "$u" -p ActiveState -p SubState -p ExecMainStatus -p ExecMainExitTimestamp 2>/dev/null; done
echo "-- ed209-rto2 unit journals since 2026-10-22 (guest console output)"; $S journalctl -u 'ed209-rto2-*' --since '2026-10-22' --no-pager 2>/dev/null | tail -300
echo "=== JOURNAL (since 2026-10-14, last 80 lines per unit)"
for u in $(systemctl list-units --all --no-pager --plain 2>/dev/null | grep -i -E 'grid|rexxos|xtp|qemu' | awk '{print $1}'); do echo "-- $u"; $S journalctl -u "$u" --since '2026-10-14' --no-pager 2>/dev/null | tail -80; done
echo "=== END"
REMOTE

B64=$(printf '%s\n' "$BLOCK" | base64 -w0)
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
OUT="ed209-snapshot-$STAMP"
mkdir -p "$OUT"

for h in $HOSTS; do
  echo "snapshot $h ..."
  timeout "$PER_HOST_TIMEOUT" "$SSHNODE" --job-id "incA-snapshot-$h" "$h" "echo $B64 | base64 -d | bash" 2>&1 \
    | sed -E '/^[0-9a-f]{64}  \//!s/[0-9a-fA-F]{32,}/<REDACTED-HEX>/g' \
    > "$OUT/$h.txt"
  rc=${PIPESTATUS[0]}
  echo "exit_code=$rc" >> "$OUT/$h.txt"
  echo "  $h exit_code=$rc lines=$(wc -l < "$OUT/$h.txt")"
done

tar -czf "$OUT.tar.gz" "$OUT"
echo "DONE: $OUT.tar.gz"
