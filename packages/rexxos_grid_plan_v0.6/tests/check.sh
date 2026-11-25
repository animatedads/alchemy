#!/bin/sh
# Checks the plan and the standing rules carry their key terms.  Claude (Opus 5.5).
set -eu
cd "$(dirname "$0")/.."
n=0
for pair in "docs/STANDING_RULES.md:Everything inside cats2 (ed209l), including rebooting and deallocating it, is" \
            "docs/STANDING_RULES.md:Keys and the Auth, the Azure network security group, and every" \
            "docs/STANDING_RULES.md:Azure serial console" "docs/STANDING_RULES.md:Advertise, then decide" \
            "docs/PLAN.md:MU_READY over XTP" "docs/PLAN.md:ChatGPT 1: xtpd at boot" "docs/PLAN.md:Tom Dyer" "docs/STANDING_RULES.md:R6. ed209k may host LDAP and xtpd" "docs/PLAN.md:LDAP.main on ed209k" "docs/STANDING_RULES.md:R7. The witness is a rolling role; cats1 may hold it" "docs/STANDING_RULES.md:R8. XTP through the firewalls" "docs/PLAN.md:DONE 25 Nov 2026, 21:01 UTC" "docs/STANDING_RULES.md:commissioned port **62801**"; do
  f=${pair%%:*}; t=${pair#*:}
  grep -qF "$t" "$f" || { echo "FAIL $f lacks: $t"; exit 1; }
  n=$((n+1)); echo "PASS $f: $t"
done
echo "PASS rexxos_grid_plan v0.6 ($n checks)"
