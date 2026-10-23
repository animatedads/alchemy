#!/usr/bin/env python3
"""Source and architecture invariant checker, no ooRexx dependency."""
import hashlib, json, pathlib, sys
ROOT = pathlib.Path(__file__).resolve().parents[1]
p = json.loads((ROOT/'SOURCE_PROVENANCE.json').read_text())
count = 0
for rec in p['source_archives']:
    base = ROOT/'components'/rec['component']
    actual = {str(f.relative_to(base)) for f in base.rglob('*') if f.is_file()}
    expected = {f['path'] for f in rec['files']}
    assert actual == expected, (rec['component'], actual^expected)
    for f in rec['files']:
        data = (base/f['path']).read_bytes()
        assert len(data)==f['size'] and hashlib.sha256(data).hexdigest()==f['sha256'], (rec['component'],f['path'])
        assert not f['path'].endswith(('.so','.a','.o','.pyc'))
        count+=1
core=(ROOT/'components/oorexx_rpc_service_core_v0.1-dev1/src/RpcServiceCore.cls').read_text()
assert '::method registerMethod' in core and '::method registerCallbackMethod' in core
assert '::method invokeCallback' in core and "target~hasMethod(methodName)" in core
jsonrpc=(ROOT/'components/oorexx_json_rpc_fabric_v0.1-dev3/src/JsonRpcFabric.cls').read_text()
soap=(ROOT/'components/oorexx_soap_rpc_binding_v0.1-dev2/src/SoapRpcBinding.cls').read_text()
grpc=(ROOT/'components/oorexx_grpc_rpc_binding_v0.1-dev3/src/GrpcRpcBinding.cls').read_text()
assert 'JsonRpc' in jsonrpc and 'Soap' in soap and 'Grpc' in grpc
assert not list((ROOT/'components/oorexx_soap_rpc_binding_v0.1-dev2/src').glob('RpcServiceCore.cls'))
assert not list((ROOT/'components/oorexx_grpc_rpc_binding_v0.1-dev3/src').glob('Protobuf.cls'))
assert (ROOT/'integration.json').is_file()
manifest=json.loads((ROOT/'integration.json').read_text())
assert manifest['schema']=='alchemy.autobuild.integration/0.2'
assert manifest['publish']['tree']['path']=='packages/oorexx_rpc_portfolio_v0.1-dev1'
print(f'PASS {count} source hashes, 4 component manifests, shared registered dispatcher, protocol and publication boundaries')
