#!/bin/bash
# Rehearses the item 1 order on loopback before Codex runs it on the nodes.
# Claude (Opus 5.5), 25 Nov 2026.  Runs the same tool and kit; only the loopback
# differences are patched in (one IP, two socket and log paths).
set -u
V=0.1-dev3; KIT=/opt/rexxos/xtpd-$V; TAR=$1; H=/tmp/reh
[[ $(id -u) -eq 0 ]] || { echo "needs root"; exit 2; }
mkdir -p /opt/rexxos /run/xtpd
[[ -e $KIT ]] && { echo "refusing: $KIT exists"; exit 2; }
tar -C /opt/rexxos -xzf "$TAR"
(cd $KIT && sha256sum -c --quiet SHA256SUMS) && echo "PASS kit checksums"
$KIT/bin/selftest | tail -1
mkdir -p $H
$KIT/bin/kit-rexx $KIT/bin/item1_files.rex ed209k 127.0.0.1 $H/ed209k
$KIT/bin/kit-rexx $KIT/bin/item1_files.rex ed209k 127.0.0.1 $H/ed209k | tail -1     # second run refuses
mkdir -p $H/cats2; for f in service.keys role.keys role-for-cats2; do install -m 600 $H/ed209k/$f $H/cats2/$f; done
$KIT/bin/kit-rexx $KIT/bin/item1_files.rex cats2 127.0.0.1 $H/cats2
stat -c '%a %n' $H/ed209k/service.keys $H/ed209k/role.keys $H/cats2/role
grep -c 'chacha20poly1305' $H/ed209k/service.keys
# loopback only: ed209k's peer cats2 is 127.0.0.1; separate sockets and logs
sed -i 's|cats2 4 udp 20.118.224.14:47036|cats2 4 udp 127.0.0.1:47037|' $H/ed209k/peers.txt
sed -i "s|/run/xtpd/xtpd.sock|$H/ed209k/xtpd.sock|; s|/run/xtpd/routes.tsv|$H/ed209k/routes.tsv|; s|/var/log/xtpd.log|$H/ed209k/xtpd.log|" $H/ed209k/xtpd.conf
sed -i "s|/run/xtpd/xtpd.sock|$H/cats2/xtpd.sock|; s|/run/xtpd/routes.tsv|$H/cats2/routes.tsv|; s|/var/log/xtpd.log|$H/cats2/xtpd.log|" $H/cats2/xtpd.conf
( cd $KIT/pkg/oorexx_ldap_identity_v0.1-dev9 && exec $KIT/bin/kit-rexx $KIT/pkg/oorexx_xtpd_v$V/tests/ldap_fixture.rex 1389 $H/ldap.ready ) >$H/ldap.out 2>&1 & L=$!
for _ in $(seq 1 100); do [[ -s $H/ldap.ready ]] && break; sleep 0.1; done
$KIT/bin/kit-rexx $KIT/pkg/oorexx_xtpd_v$V/bin/xtpd.rex $H/ed209k/xtpd.conf 2>$H/ed209k.err & A=$!
sleep 2
$KIT/bin/kit-rexx $KIT/pkg/oorexx_xtpd_v$V/bin/xtpd.rex $H/cats2/xtpd.conf 2>$H/cats2.err & B=$!
for _ in $(seq 1 150); do grep -q 'role: source' $H/cats2/xtpd.log 2>/dev/null && break; sleep 0.1; done
$KIT/bin/kit-rexx $KIT/pkg/oorexx_xtpd_v$V/bin/xtp_request.rex --socket $H/cats2/xtpd.sock STATUS
grep -c "$(cut -c1-20 $H/ed209k/service.keys | head -1)" $H/cats2/xtpd.log $H/ed209k/xtpd.log
grep -ho '[0-9a-f]\{64\}' $H/ed209k/xtpd.log $H/cats2/xtpd.log | head -1 | sed 's/^/LEAK? /'
kill $A $B; wait $A $B 2>/dev/null; echo "stopped (udp pass): rc $?"
# second pass: XTP's own carrier, raw IP protocol 36 (layer 3)
$KIT/bin/kit-rexx $KIT/bin/item1_carrier.rex raw36 $H/ed209k
$KIT/bin/kit-rexx $KIT/bin/item1_carrier.rex raw36 $H/cats2
$KIT/bin/kit-rexx $KIT/bin/item1_carrier.rex raw36 $H/cats2 | tail -1      # second run changes nothing
: > $H/cats2/xtpd.log
$KIT/bin/kit-rexx $KIT/pkg/oorexx_xtpd_v$V/bin/xtpd.rex $H/ed209k/xtpd.conf 2>>$H/ed209k.err & A=$!
sleep 2
$KIT/bin/kit-rexx $KIT/pkg/oorexx_xtpd_v$V/bin/xtpd.rex $H/cats2/xtpd.conf 2>>$H/cats2.err & B=$!
for _ in $(seq 1 150); do grep -q 'role: source' $H/cats2/xtpd.log 2>/dev/null && break; sleep 0.1; done
$KIT/bin/kit-rexx $KIT/pkg/oorexx_xtpd_v$V/bin/xtp_request.rex --socket $H/cats2/xtpd.sock STATUS
grep -P '^ed209k\t' $H/cats2/routes.tsv | cut -f1-4
kill $A $B $L; wait $A $B 2>/dev/null; echo "stopped (raw36 pass): rc $?"
