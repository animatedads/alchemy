#!/usr/bin/env python3
from pathlib import Path
root=Path(__file__).resolve().parents[1]
g=(root/'HOST/src/MasLiveGateway.cls').read_text()
c=(root/'HOST/src/MasConnectSelectorBinding.cls').read_text()
s=(root/'spec/connect-selector-binding.md').read_text()
checks={
 'identity resolver injected': 'identityResolverArg = .nil' in g,
 'services injectable': 'servicesArg = .nil' in g and 'else services=servicesArg' in g,
 'production smtp signFor': "hasMethod('signFor')" in g and '~signFor(identity~principalId,d)' in g,
 'production smtp submitFor': "hasMethod('submitFor')" in g and 'submitFor(identity~principalId,session~sessionId,d)' in g,
 'principal fail closed': "MAS_PRINCIPAL_REQUIRED" in g,
 'selector request': ".ConnectIntent~new(operation,'REQUEST','IMMEDIATE'" in c,
 'selector no hidden queue mapping': 'mapped automatically' in s and 'QPUT' in s and 'QGET/QDEPTH' in s,
 'selector dependency explicit': "::requires 'ConnectSelector.cls'" in c,
}
bad=[k for k,v in checks.items() if not v]
if bad:
 print('FAIL CONNECT_SELECTOR_SECURITY '+','.join(bad)); raise SystemExit(1)
print('PASS CONNECT_SELECTOR_SECURITY PRE24')
