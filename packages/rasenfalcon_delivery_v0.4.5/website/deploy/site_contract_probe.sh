#!/usr/bin/env bash
# Read-only external HTTPS site probe; does not install, configure, or activate.
set -euo pipefail
if [[ $# != 1 ]]; then echo 'usage: site_contract_probe.sh https://qualified-host' >&2; exit 2; fi
url="${1%/}"
[[ "$url" =~ ^https://[A-Za-z0-9.-]+(:[0-9]+)?$ ]] || { echo 'HTTPS authority required' >&2; exit 2; }
for path in / /alchemy/ /visualisation/ /audio-analysis/ /video-analysis/ /secure-protocols/ /intelligent-software/ /contact/ /privacy/ /assets/site.css /assets/site.js /assets/favicon.svg /robots.txt; do
  code="$(curl --proto '=https' --tlsv1.2 --connect-timeout 6 --max-time 12 -sS -o /dev/null -w '%{http_code}' "$url$path")"
  [[ "$code" == 200 ]] || { printf 'FAIL %s code=%s\n' "$path" "$code" >&2; exit 1; }
  printf 'PASS %s\n' "$path"
done
# Nonexistent app routes must not be remapped to a public marketing page.
code="$(curl --proto '=https' --tlsv1.2 --connect-timeout 6 --max-time 12 -sS -o /dev/null -w '%{http_code}' "$url/__rf_must_not_exist__")"
[[ "$code" == 404 || "$code" == 303 ]] || { printf 'FAIL unknown-path=%s\n' "$code" >&2;exit 1; }
printf 'PASS unknown path not served as marketing page (%s)\n' "$code"
