#!/usr/bin/env rexx
root = 'example/demo'
ring = .CryptoMacKeyRing~new
ring~addKey('msqlshim-test', '00112233445566778899aabbccddeeff')
sealer = .AlchemyMacSealer~new(ring)
authority = .AlchemyCapabilityAuthority~new(ring)
server = .MySQLWireServer~new(root, '127.0.0.1', 3333, sealer, authority)
call assertTrue server~isA(.AlchemyObject), 'server AlchemyObject'
call assertTrue server~backendGate~isA(.AlchemyObject), 'backend gate AlchemyObject'
connection = .MySQLWireConnection~new(.nil, sealer, authority)
call assertTrue connection~isA(.AlchemyObject), 'connection AlchemyObject'
call assertTrue server~alchemyObjectId <> '', 'server object identity'
call assertTrue connection~alchemyObjectId <> '', 'connection object identity'
call assertTrue server~checkSurfaceContract~ok, 'server surface contract'
call assertTrue server~backendGate~checkSurfaceContract~ok, 'gate surface contract'
call assertTrue connection~checkSurfaceContract~ok, 'connection surface contract'
serverAdoption = .AlchemyAdoptionVerifier~verify(server, 'STANDARD')
gateAdoption = .AlchemyAdoptionVerifier~verify(server~backendGate, 'STANDARD')
connectionAdoption = .AlchemyAdoptionVerifier~verify(connection, 'STANDARD')
call assertTrue serverAdoption~ok, 'server STANDARD adoption'
call assertTrue gateAdoption~ok, 'backend gate STANDARD adoption'
call assertTrue connectionAdoption~ok, 'connection STANDARD adoption'
call assertEq 'INIT', serverAdoption~evidence['construction_provenance']['entrypoint'], 'server preferred INIT construction'
call assertEq 'INIT', gateAdoption~evidence['construction_provenance']['entrypoint'], 'gate preferred INIT construction'
call assertEq 'INIT', connectionAdoption~evidence['construction_provenance']['entrypoint'], 'connection preferred INIT construction'
checkpoint = .AlchemyAdoptionVerifier~checkpoint(server, 'STANDARD')
call assertTrue .AlchemyAdoptionVerifier~compareCheckpoint(server, checkpoint)~ok, 'server adoption checkpoint round-trip'
cap = server~compatibilitySnapshot
call assertEq '0.21.2', cap['msqlshim_version'], 'component version'
call assertEq '0.8', cap['alchemy_base_version'], 'Alchemy base version'
call assertEq '0.79', cap['backend_release'], 'backend release'
call assertTrue cap['client_compress'], 'compression declared'
call assertTrue cap['client_deprecate_eof'], 'deprecate EOF declared'
call assertTrue cap['client_optional_resultset_metadata'], 'optional metadata declared'
call assertTrue cap['client_query_attributes'], 'query attributes declared'
call assertTrue cap['client_connect_attrs'], 'connect attributes declared'
call assertTrue cap['handshake_database_selection'], 'handshake database selection declared'
call assertTrue cap['prepared_statements'], 'prepared statements declared'
call assertTrue cap['prepared_read_only_cursors'], 'prepared cursor declared'
call assertTrue \cap['tls'], 'TLS honestly absent'
call assertTrue \cap['authentication'], 'authentication honestly absent'
call assertTrue \cap['zstd_compression'], 'zstd honestly absent'
metrics = server~alchemyMetrics
call assertTrue metrics['use_count'] >= 1, 'service telemetry increments'
envelope = server~sealPublicIntrospection
call assertTrue sealer~verify(envelope), 'sealed public introspection verifies'
payload = envelope~payload
call assertEq '0.21.2', payload['metadata']['PACKAGE_VERSION'], 'public package version evidence'
server~recordRelationship('TEST_LINK', connection, 'detached identity test', 'PUBLIC')
rels = server~relationshipEvidence('PUBLIC')
call assertTrue rels~items >= 1, 'public detached relationship evidence'
last = rels[rels~items]
call assertEq connection~alchemyObjectId, last['target_object_id'], 'relationship carries target identity'
connection = .nil
call assertEq 'MYSQL WIRE ALCHEMY BASE SMOKE PASS', 'MYSQL WIRE ALCHEMY BASE SMOKE PASS', 'final marker'
say 'MYSQL WIRE ALCHEMY BASE SMOKE PASS'
exit 0

assertTrue: procedure
  use strict arg condition, label
  if condition then do
    say 'PASS' label
    return
  end
  say 'FAIL' label
  exit 1

assertEq: procedure
  use strict arg expected, actual, label
  if expected == actual then do
    say 'PASS' label || ': ' || actual
    return
  end
  say 'FAIL' label || ': expected='expected 'actual='actual
  exit 1

::requires 'src/MySQLWireServer.cls'
::requires 'AlchemyAdoption.cls'
