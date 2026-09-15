say 'RYTA ALCHEMY BASE V0.24 START'

ring = .CryptoMacKeyRing~new
ring~addKey('ryta-test', '00112233445566778899aabbccddeeff')
sealer = .AlchemyMacSealer~new(ring)
options = .directory~new
options['SEALER'] = sealer

ryta = .VirtualRYTA~new(options)
call AssertTrue ryta~isA(.AlchemyObject), 'VirtualRYTA derives from AlchemyObject'
envelope = ryta~sealPublicIntrospection
call AssertTrue sealer~verify(envelope), 'VirtualRYTA public introspection MAC verifies'
payload = envelope~payload
metadata = payload['metadata']
call AssertEqual 'virtual_ryta_hardworld', metadata['COMPONENT'], 'component metadata'
call AssertEqual '0.28-work', metadata['COMPONENT_VERSION'], 'component version metadata'
call AssertEqual 'DECISION_ORCHESTRATOR', metadata['AUTHORITY_ROLE'], 'authority role metadata'
call AssertEqual 'Alchemy object identity/introspection/execution provenance is evidence, not decision authority', metadata['AUTHORITY_NOTE'], 'authority boundary metadata'

world = .RYTAWorldState~new('ALCHEMY-WORLD')
context = .RYTADecisionContext~new('M', '1', 'HASH', world~snapshotOid)
run = .RYTADecisionRun~new(world, context)
call AssertTrue world~isA(.AlchemyObject), 'RYTAWorldState derives from AlchemyObject'
call AssertTrue run~isA(.AlchemyObject), 'RYTADecisionRun derives from AlchemyObject'

p1 = .EvidencePromotion~new('P-A', 'TEST', 'SRC-A', 'THING_ALLOWED', 'KNOWN', .true, 'AUTH-A', 'POLICY-A', 'RULE-A', 'PERMITTED', 'AUTHORIZED')
p2 = .EvidencePromotion~new('P-A', 'TEST', 'SRC-A', 'THING_ALLOWED', 'KNOWN', .true, 'AUTH-A', 'POLICY-A', 'RULE-A', 'PERMITTED', 'AUTHORIZED')
call AssertTrue p1~isA(.AlchemyObject), 'EvidencePromotion derives from AlchemyObject'
call AssertTrue p1~alchemyObjectId \== p2~alchemyObjectId, 'Alchemy object identity is per object'
call AssertEqual p1~algorithmCanonicalText, p2~algorithmCanonicalText, 'Alchemy identity excluded from promotion canonical identity'

q1 = .QueueAuthorityWorkIdentity~new('NODE-A/AUTHORITY', 'AUTH', 'PKG-1', 'LOCAL', '', '', '', 'AUTH', '2026-08-23T10:00:00Z', 0, .true, 'TEST', '', '', '', '')
q2 = .QueueAuthorityWorkIdentity~new('NODE-A/AUTHORITY', 'AUTH', 'PKG-1', 'LOCAL', '', '', '', 'AUTH', '2026-08-23T10:00:00Z', 0, .true, 'TEST', '', '', '', '')
call AssertTrue q1~isA(.AlchemyObject), 'QueueAuthorityWorkIdentity derives from AlchemyObject'
call AssertTrue q1~alchemyObjectId \== q2~alchemyObjectId, 'queue Alchemy identity is per object'
call AssertEqual q1~stableKeyText, q2~stableKeyText, 'Alchemy identity excluded from queue stable key'
call AssertEqual q1~executionKey, q2~executionKey, 'Alchemy identity excluded from queue execution key'

fact = .RYTAFact~new('HOT_FACT', .true)
clause = .HardWorldClause~new('HOT_FACT', 'KNOWN_TRUE')
call AssertTrue \fact~isA(.AlchemyObject), 'hot RYTAFact deliberately exempt from heavyweight base'
call AssertTrue \clause~isA(.AlchemyObject), 'hot HardWorldClause deliberately exempt from heavyweight base'

say 'RYTA ALCHEMY BASE V0.24: OK'
exit 0

::routine AssertTrue
  use arg condition, label
  if \condition then raise syntax 88.900 array('ASSERT TRUE FAILED: ' || label)
  return 0

::routine AssertEqual
  use arg expected, actual, label
  if expected \== actual then raise syntax 88.900 array('ASSERT EQUAL FAILED: ' || label || ' expected=' || expected || ' actual=' || actual)
  return 0

::requires '../VirtualRYTA.cls'
::requires '../algorithm/EvidencePromotion.cls'
::requires '../integration/QueueFabricAuthorityExecution.cls'
::requires 'AlchemyEvidence.cls'
