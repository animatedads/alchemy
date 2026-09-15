say 'RYTA ALCHEMY V0.7 ADOPTION V0.28 START'

ring = .CryptoMacKeyRing~new
ring~addKey('ryta-v028', '00112233445566778899aabbccddeeff')
sealer = .AlchemyMacSealer~new(ring)
authority = .AlchemyCapabilityAuthority~new(ring)
options = .directory~new
options['SEALER'] = sealer
options['CAPABILITY_AUTHORITY'] = authority

ryta = .VirtualRYTA~new(options)

adoption = .AlchemyAdoptionVerifier~verify(ryta, 'STANDARD')
call AssertTrue adoption~ok, 'VirtualRYTA STANDARD Alchemy adoption'
call AssertEqual 0, adoption~warnings~items, 'preferred construction has no migration warning'

construction = ryta~alchemyConstructionProvenance
call AssertEqual 'INIT', construction['entrypoint'], 'preferred Alchemy construction entrypoint'
call AssertEqual '0.7', construction['base_version'], 'Alchemy base version'
call AssertTrue construction['initial_integrity_ok'], 'reserved Alchemy surface clean at construction'

base = ryta~alchemyBaseState
metadata = base['metadata']
call AssertEqual 'virtual_ryta_hardworld', metadata['PACKAGE'], 'standard package metadata'
call AssertEqual '0.28-work', metadata['PACKAGE_VERSION'], 'standard package version metadata'
call AssertTrue metadata['DESIGN_LIMITATIONS']~pos('does not confer') > 0, 'authority limitation explicit'

/* The public RYTA decision surface is contract-described and can be explicitly
   instrumented by the host. The execution record must describe execution, not
   copy raw world/context values or become decision authority. */
instrumented = ryta~instrumentMethod('EVALUATE', .false)
call AssertTrue instrumented~ok, 'EVALUATE instrumentation installed'

world = .RYTAWorldState~new('V028-WORLD')
call AssertTrue .AlchemyAdoptionVerifier~verify(world, 'STANDARD')~ok, 'RYTAWorldState STANDARD adoption'
call AssertEqual 'INIT', world~alchemyConstructionProvenance['entrypoint'], 'world uses preferred construction entrypoint'

run = ryta~evaluate(world)
call AssertTrue run~isA(.RYTADecisionRun), 'instrumented evaluate returns ordinary decision run'

cap = authority~issue('ryta-v028-auditor', ryta~alchemyObjectId, 'SEALEDINTROSPECTION', 'INTROSPECT:CUSTOMER')
customer = ryta~sealedIntrospection('CUSTOMER', cap)
call AssertTrue sealer~verify(customer), 'customer introspection seal verifies'
exec = customer~payload['execution_provenance']
call AssertEqual 'alchemy.objects.execution-provenance/0.1', exec['schema'], 'execution provenance schema'
call AssertTrue exec['visible_total'] >= 1, 'at least one execution record visible'
record = .nil
do candidate over exec['records']
  if candidate['method'] = 'EVALUATE' then do
    record = candidate
    leave
  end
end
call AssertTrue record \== .nil, 'EVALUATE execution record present'
call AssertEqual 'SUCCESS', record['outcome'], 'EVALUATE execution outcome'
call AssertEqual 'METHOD:EVALUATE', record['contract_id'], 'stable method contract id'
call AssertTrue record['contract_revision'] >= 1, 'method contract revision recorded'
call AssertEqual 'USE', record['authority_effect'], 'execution record labels authority use'
call AssertEqual 1, record['argument_count'], 'only argument count retained'
call AssertTrue \record~hasIndex('arguments'), 'raw world argument not retained'

/* Alchemy execution identity/provenance stays orthogonal to RYTA semantic state. */
world2 = .RYTAWorldState~new('V028-WORLD')
run2 = .VirtualRYTA~new~evaluate(world2)
call AssertEqual run~state, run2~state, 'instrumentation does not alter deterministic state'
call AssertEqual run~winningRule, run2~winningRule, 'instrumentation does not alter winning rule'

say '  adoption=' || adoption~level
say '  construction=' || construction['entrypoint'] || '/base-' || construction['base_version']
say '  execution_contract=' || record['contract_id'] || '/r' || record['contract_revision']
say 'RYTA ALCHEMY V0.7 ADOPTION V0.28: OK'
exit 0

::routine AssertTrue
  use strict arg value, label
  if \value then raise syntax 88.900 array('ASSERT TRUE FAILED: ' || label)
  return 0

::routine AssertEqual
  use strict arg expected, actual, label
  if expected \== actual then raise syntax 88.900 array('ASSERT EQUAL FAILED: ' || label || ' expected=' || expected || ' actual=' || actual)
  return 0

::requires '../VirtualRYTA.cls'
::requires 'AlchemyEvidence.cls'
::requires 'AlchemySecurity.cls'
::requires 'AlchemyAdoption.cls'
