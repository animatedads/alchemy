#!/usr/bin/env python3
"""Static source-gate; do not call this an ooRexx runtime regression."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
s=(root/'src/RpcHttpsJsonGateway.cls').read_text()
t=(root/'tests/test_gateway.rex').read_text()
required={
 'no raw-method reflection': "serviceRegistry~resolve(service,operation)",
 'reject callback binding': "entry~mode == 'CALLBACK'",
 'per-call policy': "authority~authorizeOperation(context~principal,service,operation,context~exchange)",
 'request auth': 'authority~authenticate(request,request~context)',
 'transport-bound identity': 'principal~requestId \\== request~context~requestId',
 'TLS required': "when request~tlsProtocol == 'TLSv1.2'",
 'request byte cap': 'request~body~length > maximumBytes',
 'missing context rejected': 'request~context == .nil',
 'notification no response': '.HttpResponse~empty(204)',
 'no caching': "response~header('Cache-Control','no-store')",
 'real protocol engine': '.JsonRpcDispatcher~new(registry,.JsonRpcCodec~new(maximumBytes))',
 'real service dispatch': 'dispatcher~invoke(service,operation,arguments,context)',
 'deny unauthorized': ".JsonRpcFault~new(-32001,'Permission denied')",
 'frozen routes': 'if \\registry~frozen then return self~errorResponse(503',
}
for name, needle in required.items():
 assert needle in s, f'missing {name}'
for forbidden in ['~sendWith(', 'rpc~send(', 'openSSL', 'queue~put(', 'bind(']:
 assert forbidden not in s, f'forbidden architectural leakage: {forbidden}'
for case in ['authentication fail closed','stale session binding rejected','unpublished method rejected','notification response','TLS required','context required','size limit','unsupported encoding']:
 assert case in t, f'missing test case: {case}'
print(f'PASS {len(required)} RPC HTTPS source invariants and 8 fixture cases (STATIC; no ooRexx execution)')
