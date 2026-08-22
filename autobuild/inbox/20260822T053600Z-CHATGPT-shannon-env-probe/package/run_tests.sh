#!/bin/sh
set -eu
ROOT="${SHANNON_ROOT:-/home/hc3/alchemy/ourladyair_shannon_v0.5}"

echo '== Shannon run_tests.sh =='
cat "$ROOT/run_tests.sh"

echo '== top-level alchemy directories =='
find /home/hc3/alchemy -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort

echo '== likely dependency roots =='
for d in /home/hc3/alchemy/runtime_registry /home/hc3/alchemy/reputation_effect /home/hc3/alchemy/reputation_feed /home/hc3/alchemy/oorexx_queue_fabric /home/hc3/alchemy/nosqlserver /home/hc3/alchemy/oorexx_db_skeleton; do
  if [ -d "$d" ]; then
    echo "FOUND $d"
    find "$d" -maxdepth 2 -type f \( -name 'VERSION.txt' -o -name '*Registry.cls' -o -name 'ReputationEffect.cls' -o -name 'ReputationFeed.cls' \) -print | sort
  else
    echo "MISSING $d"
  fi
done

echo '== Shannon source directories =='
find "$ROOT" -maxdepth 2 -type d -print | sort

echo 'PASS SHANNON_ENVIRONMENT_CAPTURED'
