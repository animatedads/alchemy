#!/usr/bin/env python3
import json, re, sys
from pathlib import Path

def fail(msg):
    raise SystemExit("FAIL: " + msg)

def main(path):
    data=json.loads(Path(path).read_text(encoding="utf-8"))
    if data.get("schema")!="flylo.platform-integration/0.1": fail("schema")
    p=data["policy"]
    if p["authenticationAuthority"]!="oorexx-ldap-identity": fail("LDAP authority changed")
    if p["httpsAuthority"]!="oorexx-https-server": fail("HTTPS authority changed")
    if p["browserIsBusinessAuthority"] is not False: fail("browser authority")
    if p["externalIdpMayReplaceLdapAuthority"] is not False: fail("external IdP replacement")
    seen=set()
    for d in data["dependencies"]:
        if d["id"] in seen: fail("duplicate dependency "+d["id"])
        seen.add(d["id"])
        if not re.fullmatch(r"[0-9a-f]{64}", d["sha256"]): fail("bad digest "+d["id"])
        if d["activationStatus"]=="ACTIVE" and d.get("openGates"): fail("active with open gates "+d["id"])
    if seen != {"terminal-machine","ldap-identity","https-server"}: fail("dependency set")
    print("PASS flylo platform integration gates: 3 exact candidates, all fail-closed pending live qualification")

if __name__=="__main__":
    main(sys.argv[1])
