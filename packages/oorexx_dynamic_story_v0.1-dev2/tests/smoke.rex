/* All permissions here are test doubles. Never use this gateway in production. */
call tests
exit 0
::routine assertEq
  use strict arg actual, expected, label
  if actual \== expected then do
    say 'FAIL:' label 'expected='expected 'actual='actual
    exit 1
  end
::routine tests
  ctx = .StoryContext~new('tenant-one', 'DE', 'web', 'de-DE', 'req-1')
  engine = .StoryDecisionEngine~new
  engine~registerIntention(.StoryIntention~new('sales', 10, 'Explain value', '1'))
  engine~registerIntention(.StoryIntention~new('incident', 90, 'Restore service', '2'))
  engine~registerScopedNarrative(.StoryNarrative~new('n-sales-de', 'sales', 'Technical value', 'Benefits', 'Learn', .Array~of('c1'), '5'), 'DE', 'web', 10)
  engine~registerScopedNarrative(.StoryNarrative~new('n-sales-default', 'sales', 'General value', 'Benefits', 'Learn', .Array~of('c1'), '2'), '*', '*', 1)
  engine~registerNarrative(.StoryNarrative~new('n-incident', 'incident', 'Support', 'Recovery', 'Open support', .Array~of('c2'), '3'))
  call assertEq engine~decide(.Array~of('sales'), ctx)['status'], 'BLOCKED_NO_AUTHORITY', 'no-local-approval'
  gate = .TestAuthorityGateway~new
  engine~setAuthorityGateway(gate)
  result = engine~decide(.Array~of('sales'), ctx)
  call assertEq result['narrative_id'], 'n-sales-de', 'scoped-narrative'
  call assertEq result['authority_proof_ref'], 'test-only-authority', 'traceable-review'
  result = engine~decide(.Array~of('sales', 'incident'), ctx)
  call assertEq result['intention_id'], 'incident', 'support-over-sales'
  gate~mode('HOLD')
  result = engine~decide(.Array~of('incident'), ctx)
  call assertEq result['status'], 'BLOCKED_HOLD', 'instant-hold'
  gate~mode('ALLOW')
  gate~stale(.true)
  result = engine~decide(.Array~of('incident'), ctx)
  call assertEq result['status'], 'BLOCKED_AUTHORITY_REVISION_MISMATCH', 'revision-binding'
  gate~stale(.false)
  call assertEq engine~decide(.Array~of('sales','incident'), ctx)['status'], 'APPROVED', 'review-per-request'
  call assertEq engine~decide(.Array~of('nonsense'), ctx)['status'], 'NO_ELIGIBLE_INTENTION', 'unknown-candidate'
  call assertEq engine~decide(.Array~of('sales', 'sales'), ctx)['status'], 'APPROVED', 'deduplicate'
  source = .TestIntentionSource~new
  engine~setIntentionSource(source)
  call assertEq engine~decideLive(ctx)['intention_id'], 'sales', 'dynamic-discovery-1'
  source~incident(.true)
  call assertEq engine~decideLive(ctx)['intention_id'], 'incident', 'dynamic-discovery-2'
  gate~mode('DENY')
  result = engine~decideLive(ctx)
  call assertEq result['status'], 'BLOCKED_DENY', 'withdrawn-next-request'
  say 'PASS: Dynamic Story dev2 runtime authority, scope and live intention tests'
::class 'TestAuthorityGateway' public
::method init
  expose modeValue staleValue
  modeValue = 'ALLOW'
  staleValue = .false
::method mode
  expose modeValue
  use strict arg modeValue
::method stale
  expose staleValue
  use strict arg staleValue
::method review
  expose modeValue staleValue
  use strict arg context, intention, narrative
  revision = narrative~revision
  if staleValue then revision = 'outdated-revision'
  return .StoryAuthorityResult~new(modeValue, 'test-only-authority', 'test-policy-8', intention~identifier, intention~revision, narrative~identifier, revision, 'test-gate')
::class 'TestIntentionSource' public
::method init
  expose includeIncident
  includeIncident = .false
::method incident
  expose includeIncident
  use strict arg includeIncident
::method candidates
  expose includeIncident
  use strict arg context
  if includeIncident then return .Array~of('sales', 'incident')
  return .Array~of('sales')
::requires 'src/DynamicStory.cls'
