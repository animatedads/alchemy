#!/bin/bash
# Logging v0.7 suite with the v0.8 overlay file installed alongside the core.
P=/tmp/pkgs; SRC=/tmp/lg7/src
EXTRA="$P/alchemy_objects_v0.8/src:$P/oorexx_crypto_v0.1/src:$P/institutional_policy_v0.8/src:$P/nosqlserver_v0.79/src:$P/oorexx_queue_fabric_v0.9-dev5/src"
cd /tmp/lg7/tests
pass=0; failed=""
for t in $(grep -o 'run_test [a-z_0-9]*\.rex' run_all.sh | awk '{print $2}'); do
  out=$(PATH="$SRC:$EXTRA:$PATH" REXX_PATH="$SRC:$EXTRA" timeout 120 rexx "$t" 2>&1); rc=$?
  if [ $rc -eq 0 ]; then pass=$((pass+1)); else failed="$failed $t(rc=$rc:$(printf '%s' "$out" | grep -m1 -iE 'error|fail' | cut -c1-90))"; fi
done
echo "v0.7 tests passed: $pass"; echo "failed:$failed" | tr '(' '\n(' 
