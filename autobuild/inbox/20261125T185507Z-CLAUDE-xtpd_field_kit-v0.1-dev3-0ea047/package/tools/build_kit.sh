#!/bin/bash
# build_kit.sh -- the xtpd field kit for grid item 1, built in the Ubuntu 22.04
# build container (R3), so nothing is built on cats2 or ed209k.
# Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 25 November 2026.
# Output: /tmp/xd/out/xtpd-field-kit-0.1-dev2.tar.gz and its .sha256
# Layout once unpacked at /opt/rexxos/xtpd-0.1-dev2:
#   oorexx/        ooRexx 5.3.0 runtime (bin, lib, rexx.img), from this container
#   native/        libraries built from source here: libxtp native, foreign runtime, process, atomic file
#   pkg/<name>/    the ooRexx sources of each estate package (unchanged copies)
#   bin/kit-rexx   runs rexx with this kit's paths and nothing else
#   bin/selftest   the xtpd and role unit tests, with this kit's rexx
#   systemd/       xtpd.service, ldap-fixture.service
set -euo pipefail
R=/tmp/xd/packages; W=/tmp/xd/w; V=0.1-dev2; KV=0.1-dev3   # V: the xtpd inside; KV: this kit
K=/tmp/xd/kit/xtpd-$V
[[ -f $W/ok ]] || { echo "build the kit first: run_roles_only.sh"; exit 2; }
if [[ -e $K ]]; then echo "refusing: $K exists (remove it first)"; exit 2; fi
mkdir -p $K/oorexx/bin $K/oorexx/lib $K/native $K/pkg $K/bin $K/systemd
cp -a /usr/local/bin/rexx /usr/local/bin/rxapi /usr/local/bin/rexxc /usr/local/bin/rxqueue /usr/local/bin/*.cls $K/oorexx/bin/
cp -a /usr/local/lib/lib*.so* /usr/local/lib/rexx.img $K/oorexx/lib/
# libffi: the foreign runtime loads libffi.so.8 at run time; without it, it falls back to a
# dispatcher limited to three arguments, and xtpd's calls fail (found on Ubuntu 26.04 minimal).
cp -a /usr/lib/x86_64-linux-gnu/libffi.so.8 /usr/lib/x86_64-linux-gnu/libffi.so.8.* $K/native/
cp -a $W/xtp/lib/liboorexx_xtp_native.so $W/fr/build/libforeign_runtime.so $W/process/native/librxprocessnative.so $W/atomic/native/librxatomicnative.so $K/native/
# sources: whole packages, without shipped binaries, examples or their own test suites
for p in oorexx_xtpd_v0.1-dev2 oorexx_xtp_v0.1-dev38 oorexx_foreign_runtime_v0.22.6 oorexx_unix_socket_v0.6 oorexx_process_v0.1-dev2 \
         oorexx_logging_v0.7 oorexx_crypto_v0.8.3 xtpd_bootstrap_v0.1-dev1 oorexx_atomic_file_v0.1-dev1 \
         oorexx_ldap_identity_v0.1-dev9 oorexx_secret_broker_v0.2 alchemy_objects_v0.8; do
  mkdir -p $K/pkg/$p
  tar -C $R/$p --exclude='*.so' --exclude='*.o' --exclude='*.a' --exclude=examples --exclude=native --exclude=build -cf - . | tar -C $K/pkg/$p -xf -
done
cat > $K/bin/kit-rexx <<'EOF'
#!/bin/sh
# Runs rexx with only this kit's paths.  Usage: kit-rexx PROGRAM [ARGS...]
K="$(cd "$(dirname "$0")/.." && pwd)"
P="$K/pkg"
export REXX_PATH="$P/oorexx_xtpd_v0.1-dev2/src:$P/oorexx_xtp_v0.1-dev38/rexx:$P/oorexx_foreign_runtime_v0.22.6/rexx:$P/oorexx_unix_socket_v0.6:$P/oorexx_process_v0.1-dev2/src:$P/oorexx_process_v0.1-dev2/src/providers:$P/oorexx_logging_v0.7/src:$P/oorexx_crypto_v0.8.3/src:$P/xtpd_bootstrap_v0.1-dev1/src:$P/oorexx_atomic_file_v0.1-dev1/src:$P/oorexx_atomic_file_v0.1-dev1/src/providers:$P/oorexx_ldap_identity_v0.1-dev9:$P/oorexx_secret_broker_v0.2/src:$P/alchemy_objects_v0.8/src:$K/oorexx/bin"
export LD_LIBRARY_PATH="$K/native:$K/oorexx/lib"
export FOREIGN_RUNTIME_HOME="$P/oorexx_foreign_runtime_v0.22.6"
export PATH="$K/oorexx/bin:/usr/bin:/bin:/usr/sbin:/sbin"
exec "$K/oorexx/bin/rexx" "$@"
EOF
cat > $K/bin/selftest <<'EOF'
#!/bin/sh
# Runs xtpd's unit tests and role unit tests with this kit.  Prints PASS or FAIL lines;
# the last line is "PASS selftest" only if every check passed.
K="$(cd "$(dirname "$0")/.." && pwd)"
X="$K/pkg/oorexx_xtpd_v0.1-dev2"
T=$(mktemp -d)
"$K/bin/kit-rexx" "$X/tests/test_units.rex" || { echo "FAIL selftest (xtpd units)"; rm -rf "$T"; exit 1; }
"$K/bin/kit-rexx" "$K/bin/selftest_ffi.rex" || { echo "FAIL selftest (foreign calls)"; rm -rf "$T"; exit 1; }
"$K/bin/kit-rexx" "$X/tests/test_roles_units.rex" "$T" "$K/bin/kit-rexx" "$X" || { echo "FAIL selftest (role units)"; rm -rf "$T"; exit 1; }
rm -rf "$T"
echo "PASS selftest"
EOF
cp /tmp/xd/item1_files.rex /tmp/xd/selftest_ffi.rex $K/bin/
chmod 755 $K/bin/kit-rexx $K/bin/selftest
cat > $K/systemd/xtpd.service <<'EOF'
[Unit]
Description=xtpd 0.1-dev2, the XTP network service daemon (one per node)
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/opt/rexxos/xtpd-0.1-dev2/bin/kit-rexx /opt/rexxos/xtpd-0.1-dev2/pkg/oorexx_xtpd_v0.1-dev2/bin/xtpd.rex /etc/xtpd/xtpd.conf
RuntimeDirectory=xtpd
KillSignal=SIGTERM
TimeoutStopSec=15
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
cat > $K/systemd/ldap-fixture.service <<'EOF'
[Unit]
Description=Test LDAP server for grid item 1 (oorexx_ldap_identity dev9 fixture, 127.0.0.1 only; not a production directory)
After=network-online.target

[Service]
WorkingDirectory=/opt/rexxos/xtpd-0.1-dev2/pkg/oorexx_ldap_identity_v0.1-dev9
ExecStart=/opt/rexxos/xtpd-0.1-dev2/bin/kit-rexx /opt/rexxos/xtpd-0.1-dev2/pkg/oorexx_xtpd_v0.1-dev2/tests/ldap_fixture.rex 1389 /run/ldap-fixture.ready
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
(cd $K && find . -type f ! -name SHA256SUMS | sort | xargs sha256sum > SHA256SUMS)
mkdir -p /tmp/xd/out
tar -C /tmp/xd/kit --numeric-owner --owner=0 --group=0 -czf /tmp/xd/out/xtpd-field-kit-$KV.tar.gz xtpd-$V
(cd /tmp/xd/out && sha256sum xtpd-field-kit-$KV.tar.gz > xtpd-field-kit-$KV.tar.gz.sha256)
ls -l /tmp/xd/out; cat /tmp/xd/out/*.sha256
