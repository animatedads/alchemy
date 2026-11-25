#!/bin/sh
# Checks the plan and the standing rules carry their key terms.  Claude (Opus 5.5).
set -eu
cd "$(dirname "$0")/.."
n=0
for pair in "docs/STANDING_RULES.md:Everything inside cats2 (ed209l), including rebooting and deallocating it, is" \
            "docs/STANDING_RULES.md:Keys and the Auth, the Azure network security group, and every" \
            "docs/STANDING_RULES.md:Azure serial console" "docs/STANDING_RULES.md:Advertise, then decide" \
            "docs/PLAN.md:MU_READY over XTP" "docs/PLAN.md:ChatGPT 1: xtpd at boot" "docs/PLAN.md:Tom Dyer"; do
  f=${pair%%:*}; t=${pair#*:}
  grep -qF "$t" "$f" || { echo "FAIL $f lacks: $t"; exit 1; }
  n=$((n+1)); echo "PASS $f: $t"
done
echo "PASS rexxos_grid_plan v0.1 ($n checks)"
