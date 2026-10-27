from pathlib import Path
import sys
root=Path(__file__).resolve().parents[1]
b=(root/'HOST/src/MasRpcServiceBinding.cls').read_text()
t=(root/'HOST/tests/mas_rpc_service_core.rex').read_text()
h=(root/'scripts/qualify_ed209c_ed209z_services.sh').read_text()
s=(root/'spec/rpc-service-core-binding.md').read_text()
checks={
 'publisher only': 'MasRpcServicePublisher' in b and 'MasRpcCoreConnector' not in b,
 'upstream dispatcher adapter': 'ConnectRpcDispatchAdapter~new' in t,
 'dev6 selector': 'oorexx_connect_selector_v0.1-dev6.zip' in h,
 'rpc portfolio': 'oorexx_rpc_portfolio_v0.1-dev1.zip' in h,
 'rpc core path': 'oorexx_rpc_service_core_v0.1-dev1/src' in h,
 'authority split': 'ConnectSelector owns route admission' in s and 'SerializationSelector owns representation/schema' in s,
}
for k,v in checks.items():
    if not v: print('FAIL',k); sys.exit(1)
print('PASS RPC_CORE_ALIGNMENT PRE23')
