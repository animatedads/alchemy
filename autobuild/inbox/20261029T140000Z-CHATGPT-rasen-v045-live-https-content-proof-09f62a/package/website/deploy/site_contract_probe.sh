#!/usr/bin/env bash
# Native HTTPS, real endpoint and exact immutable public-site content verification.
# Deliberately no /unknown-path hostile probe: the owned firewall can block testers.
set -euo pipefail
if [[ $# != 1 ]]; then echo 'usage: site_contract_probe.sh https://rasenfalcon.com[:port]' >&2; exit 2; fi
url="${1%/}"
[[ "$url" =~ ^https://(rasenfalcon\.com|www\.rasenfalcon\.com)(:([0-9]{1,5}))?$ ]] || {
  echo 'Only the exact RasenFalcon public HTTPS authority is permitted' >&2; exit 2;
}
host="${BASH_REMATCH[1]}"
port="${BASH_REMATCH[3]:-443}"
[[ "$port" -ge 1 && "$port" -le 65535 ]] || { echo 'Invalid port' >&2; exit 2; }
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
cmd=(python3 "$HERE/public_https_integrity_probe.py" --site-root "$HERE/../site" --host "$host" --port "$port")
if [[ -n "${RF_SITE_CA_FILE:-}" ]]; then cmd+=(--ca-file "$RF_SITE_CA_FILE"); fi
if [[ -n "${RF_SITE_LEAF_SHA256:-}" ]]; then cmd+=(--expect-leaf-sha256 "$RF_SITE_LEAF_SHA256"); fi
"${cmd[@]}"
