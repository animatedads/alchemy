parse arg root
policy = root || '/policy/ourladyair_safety_policy.txt'
session = .ShannonChatSession~new('test-nosql-audit', policy)
service = .ShannonQueueService~new(session)
call assertEqual .QueueFabricBuild~VERSION, service~queueFabricVersion, 'loaded Queue Fabric identity retained'
call assertEqual .NoSQLServerBuild~RELEASE, service~noSQLServerVersion, 'loaded NoSQLServer identity retained'

putOperation = service~submit('What extras can you sell me?')
call assertTrue putOperation~ok, 'queue submit succeeds'
call assertEqual 1, service~auditCatalog~indexedCount, 'one audit indexed'

turnQuery = service~queryAudit("SELECT session_id,turn_number,model_gross_cents,governed_gross_cents,legal_api_version FROM shannon_turns")
call assertEqual .Error~SUCCESS, turnQuery~status, 'turn SQL succeeds'
call assertEqual 1, turnQuery~rows~items, 'one turn row'
call assertEqual 'test-nosql-audit', turnQuery~rows[1]['session_id'], 'session projected'
call assertEqual policy~legalApiVersion, turnQuery~rows[1]['legal_api_version'], 'Legal API projected'
call assertTrue turnQuery~rows[1]['model_gross_cents'] >= turnQuery~rows[1]['governed_gross_cents'], 'governed gross does not exceed model gross'

decisionQuery = service~queryAudit("SELECT product_class,target_passenger_id,price_cents,legal_status,permitted FROM shannon_offer_decisions WHERE product_class='BAR_BUNDLE'")
call assertEqual .Error~SUCCESS, decisionQuery~status, 'decision SQL succeeds'
call assertEqual 1, decisionQuery~rows~items, 'adult bar decision projected'
call assertEqual 'P1', decisionQuery~rows[1]['target_passenger_id'], 'target projected'
call assertEqual 1000, decisionQuery~rows[1]['price_cents'], 'bar price projected'
call assertEqual 1, decisionQuery~rows[1]['permitted'], 'adult bar offer permitted'

/* SQL is only the management projection. The rich object still exists in the
   queue and carries nested source/governance objects. */
auditOperation = service~getAudit
call assertTrue auditOperation~ok, 'rich audit remains queued'
audit = auditOperation~value~payload
call assertTrue audit['commercial']['decisions']~items > 0, 'rich decision objects retained'
call assertEqual 'DERIVED_INDEX_ONLY', audit['queue']['projectionAuthority'], 'projection explicitly non-authoritative'
call assertEqual .QueueFabricBuild~VERSION, audit['queue']['fabricVersion'], 'queue version retained in audit'
call assertEqual 'NoSQLServer/0.74', audit['queue']['auditProjection'], 'NoSQL projection version retained'

say 'PASS test_shannon_nosql_audit'
exit 0

assertTrue: procedure
  use arg conditionValue, label
  if \conditionValue then do; say 'FAIL:' label; exit 1; end
  return
assertEqual: procedure
  use arg expected, actual, label
  if expected \== actual then do; say 'FAIL:' label 'expected=' expected 'actual=' actual; exit 1; end
  return

::requires 'ShannonQueueService.cls'
