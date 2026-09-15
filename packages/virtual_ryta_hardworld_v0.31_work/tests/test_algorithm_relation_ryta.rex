/* Virtual RYTA through the generic Algorithm Relation engine. */

say 'ALGORITHM RELATION RYTA V0.4 START'

world = .RYTAWorldState~new('WORLD-RYTA-ALGREL-1')
world~putKnown('HAS_QUERY', .true)
world~putKnown('PRODUCT_RELEVANT', .true)
world~putKnown('PRODUCT_VALUE_HIGH', .true)
world~putKnown('UPSELL_OPPORTUNITY', .true)
world~putKnown('ESSENTIAL_MEDICATION', .true)
world~putKnown('IMMEDIATE_ACCESS', .true)
world~putKnown('GUARANTEED_CUSTODY', .false)

provider = .RYTAAlgorithmProvider~new(.nil, '..')
engine = .AlgorithmRelationEngine~new
call assertTrue 'provider registration', engine~addProvider(provider)

catalog = engine~catalog
call assertEqual 'RYTA catalog has two declared relations', 2, catalog~rows~items
call assertEqual 'metadata discovery does not invoke RYTA', 0, provider~invocationCount
call assertEqual 'RYTA source manifest file hashed', 'FILE_HASHED', provider~sourceManifestMode
call assertTrue 'RYTA source manifest hash populated', provider~sourceManifestHash~length == 64
schemaCatalog = engine~schemaCatalog
call assertTrue 'RYTA schema catalog populated', schemaCatalog~rows~items > 10
call assertEqual 'schema discovery does not invoke RYTA', 0, provider~invocationCount

context = .AlgorithmExecutionContext~new('RYTA-INV-1', world~snapshotOid, world~snapshotOid)
algorithmResult = engine~execute('VIRTUAL_RYTA', world, context)
call assertTrue 'result exists', algorithmResult \== .nil
call assertEqual 'provider invoked once', 1, provider~invocationCount
call assertTrue 'provider did not install capability facts into caller world', \world~hasFact('CAN_WARNING')
call assertEqual 'result validation', 0, algorithmResult~validationErrors~items

relation = algorithmResult~relation('RYTA_ACTION_DECISIONS')
call assertTrue 'actions relation exists', relation \== .nil
call assertEqual 'seven action rows', 7, relation~rows~items

bigUpsell = findAction(relation, 'BIG_UPSELL')
warning = findAction(relation, 'WARNING')
answer = findAction(relation, 'ANSWER_QUERY')
call assertTrue 'big upsell row exists', bigUpsell \== .nil
call assertTrue 'warning row exists', warning \== .nil
call assertEqual 'state remediation', 'REMEDIATION_REQUIRED', bigUpsell~value('STATE')
call assertEqual 'big upsell prohibited', 'PROHIBITED', bigUpsell~value('DISPOSITION')
call assertEqual 'big upsell not selected', .false, bigUpsell~value('FINAL_SELECTED')
call assertEqual 'warning required', 'REQUIRED', warning~value('DISPOSITION')
call assertEqual 'warning selected', .true, warning~value('FINAL_SELECTED')
call assertEqual 'warning output', 'do warning', warning~value('OUTPUT_TEXT')
call assertEqual 'answer output', 'blah blah blah answer query', answer~value('OUTPUT_TEXT')

traceRelation = algorithmResult~relation('RYTA_DECISION_TRACE')
call assertTrue 'trace relation exists', traceRelation \== .nil
call assertTrue 'trace relation has rows', traceRelation~rows~items > 0

sameResult = engine~execute('VIRTUAL_RYTA', world, context)
call assertTrue 'logical rescan returns same materialization', sameResult == algorithmResult
call assertEqual 'provider not rerun on rescan', 1, provider~invocationCount

context2 = .AlgorithmExecutionContext~new('RYTA-INV-2', world~snapshotOid, world~snapshotOid)
result2 = engine~execute('VIRTUAL_RYTA', world, context2)
call assertTrue 'second invocation result exists', result2 \== .nil
call assertEqual 'new audit invocation reuses same content materialization', 1, provider~invocationCount
call assertTrue 'new invocation is an audit replay view', result2 \== algorithmResult
call assertEqual 'same content key reused', algorithmResult~materializationKey, result2~materializationKey
call assertEqual 'new invocation id rebound', 'RYTA-INV-2', result2~relation('RYTA_ACTION_DECISIONS')~rows[1]~value('INVOCATION_ID')

say 'ALGORITHM RELATION RYTA V0.4: OK'
exit 0

findAction: procedure
  use arg relation, actionCode
  do row over relation~rows
    if row~value('ACTION_CODE') == actionCode then return row
  end
  return .nil

assertEqual: procedure
  use arg label, expected, actual
  if expected == actual then return .true
  say 'ASSERT FAILED:' label
  say '  expected:' expected
  say '  actual:  ' actual
  exit 1

assertTrue: procedure
  use arg label, actual
  if actual then return .true
  say 'ASSERT FAILED:' label
  say '  actual:' actual
  exit 1

::requires '../algorithm/AlgorithmRelation.cls'
::requires '../algorithm/RYTAAlgorithmProvider.cls'
::requires '../HardWorld.cls'
