/* Demonstrate metadata discovery and one materialized Virtual RYTA relation. */

engine = .AlgorithmRelationEngine~new
provider = .RYTAAlgorithmProvider~new(.nil, '..')
registered = engine~addProvider(provider)

say 'ALGORITHM PROVIDER CATALOG'
do line over engine~catalog~render
  say line
end
say
say 'ALGORITHM SCHEMA CATALOG'
do line over engine~schemaCatalog~render
  say line
end
say 'provider invocations after metadata:' provider~invocationCount

world = .RYTAWorldState~new('WORLD-DEMO-ALGREL')
world~putKnown('HAS_QUERY', .true)
world~putKnown('PRODUCT_RELEVANT', .true)
world~putKnown('PRODUCT_VALUE_HIGH', .true)
world~putKnown('UPSELL_OPPORTUNITY', .true)
world~putKnown('ESSENTIAL_MEDICATION', .true)
world~putKnown('IMMEDIATE_ACCESS', .true)
world~putKnown('GUARANTEED_CUSTODY', .false)
context = .AlgorithmExecutionContext~new('DEMO-INV-1', world~snapshotOid, world~snapshotOid)
algorithmResult = engine~execute('VIRTUAL_RYTA', world, context)

say
say 'MATERIALIZED RESULT'
do line over algorithmResult~render
  say line
end

sameResult = engine~execute('VIRTUAL_RYTA', world, context)
say
sameObject = sameResult == algorithmResult
say 'logical rescan returns same object:' sameObject
say 'provider invocations:' provider~invocationCount
say 'engine cache hits:' engine~cacheHits
exit 0

::requires '../algorithm/AlgorithmRelation.cls'
::requires '../algorithm/RYTAAlgorithmProvider.cls'
::requires '../HardWorld.cls'
