#!/usr/bin/env python3
from pathlib import Path
import sys
root=Path(__file__).resolve().parents[1]
a=(root/'HOST/src/MasPlatformRouteAuthority.cls').read_text()
t=(root/'HOST/tests/mas_platform_route_authority.rex').read_text()
h=(root/'scripts/qualify_ed209c_ed209z_services.sh').read_text()
p=(root/'scripts/preflight_ed209c_readonly.sh').read_text()
s=(root/'spec/current-production-bindings.md').read_text()
checks={
 'dev8 policy':'ConnectAuthenticatedRoutePolicy' in t and 'oorexx_connect_selector_v0.1-dev8.zip' in h,
 'ldap session proof':"session~authenticated \\== .true" in a and 'aclDecision' in a and 'oorexx_ldap_identity_v0.1-dev22.zip' in h,
 'no intent identity':'never derive from intention options' in a and 'intention~options' not in a,
 'independent channel':'attestRoute' in a and 'mas.private_ca_verified' in a,
 'https current':'oorexx_https_server_v0.4.8.zip' in h,
 'current pins':'ConnectSelector dev8' in s and 'LDAP Identity dev22' in s and 'HTTPS Server v0.4.8' in s,
 'preflight split':'PRE25_ED209C_READONLY_PREFLIGHT' in p and "'$HASP'" in p,
}
bad=[k for k,v in checks.items() if not v]
if bad:
 print('FAIL PLATFORM_ROUTE_AUTHORITY '+', '.join(bad)); sys.exit(1)
print('PASS PLATFORM_ROUTE_AUTHORITY PRE25')
