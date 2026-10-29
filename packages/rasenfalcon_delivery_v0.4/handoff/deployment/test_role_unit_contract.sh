#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
python3 - "$ROOT/HOSTS.json" "$ROOT/deploy.sh" <<'PY'
import json,re,sys
hosts=json.load(open(sys.argv[1])); src=open(sys.argv[2]).read()
expected=hosts["separate_private_https_services"]
assert expected["noc.rasenfalcon.com"]=="rasenfalcon-noc-https.service"
assert expected["office.rasenfalcon.com"]=="rasenfalcon-office-https.service"
body=re.search(r'required_units\(\)\{(.*?)\n\}',src,re.S).group(1)
office=re.search(r'office\)(.*?);;',body,re.S).group(1)
noc=re.search(r'\bnoc\)(.*?);;',body,re.S).group(1)
allrow=re.search(r'\ball\)(.*?);;',body,re.S).group(1)
assert "rasenfalcon-office-https.service" in office and "rasenfalcon-https.service" not in office
assert "rasenfalcon-noc-https.service" in noc and "rasenfalcon-https.service" not in noc
assert "rasenfalcon-office-https.service" in allrow and "rasenfalcon-noc-https.service" in allrow
assert re.search(r'identity\).*rasenfalcon-ldap\.service',body)
print("PASS Rasen Falcon role-specific HTTPS/LDAP unit contract")
PY
