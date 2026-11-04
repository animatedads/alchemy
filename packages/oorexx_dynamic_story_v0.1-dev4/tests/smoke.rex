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
  call assertEq engine~decideLive(ctx)['status'], 'BLOCKED_NO_CATALOGUE_SOURCE', 'catalogue-required'
  catalogue = .TestCatalogueSource~new
  engine~setCatalogueSource(catalogue)
  catalogue~failure('MISSING')
  call assertEq engine~decideLive(ctx)['status'], 'BLOCKED_NO_CATALOGUE_SNAPSHOT', 'catalogue-missing'
  catalogue~failure('INVALID')
  call assertEq engine~decideLive(ctx)['status'], 'BLOCKED_INVALID_CATALOGUE_SNAPSHOT', 'catalogue-invalid'
  catalogue~failure('NONE')
  call assertEq engine~decideLive(ctx)['intention_id'], 'sales', 'dynamic-discovery-1'
  source~incident(.true)
  call assertEq engine~decideLive(ctx)['intention_id'], 'incident', 'dynamic-discovery-2'
  catalogue~hold(.true)
  call assertEq engine~decideLive(ctx)['status'], 'BLOCKED_CATALOGUE_HOLD', 'catalogue-live-hold'
  catalogue~hold(.false)
  catalogue~revision('cat-new')
  call assertEq engine~decideLive(ctx)['catalogue_revision'], 'cat-new', 'catalogue-live-revision'
  gate~mismatch('CATALOGUE')
  call assertEq engine~decideLive(ctx)['status'], 'BLOCKED_AUTHORITY_CATALOGUE_MISMATCH', 'catalogue-replay-blocked'
  gate~mismatch('NONE')
  site = .StorySiteProjection~new
  siteCandidate = site~project(engine~decideLive(ctx), 'rf-public-hero')
  call assertEq siteCandidate['status'], 'CANDIDATE', 'site-candidate'
  call assertEq siteCandidate['publication_authority'], 'NONE', 'site-no-publish'
  call assertEq siteCandidate['authority_proof_ref'], .nil, 'site-proof-hidden'
  agent = .StoryAgentProjection~new
  packet = agent~project(engine~decideLive(ctx))
  call assertEq packet['catalogue_revision'], 'cat-new', 'agent-current-catalogue'
  gate~mismatch('REQUEST')
  call assertEq engine~decide(.Array~of('sales'), ctx)['status'], 'BLOCKED_AUTHORITY_CONTEXT_MISMATCH', 'request-bound'
  gate~mismatch('TENANT')
  call assertEq engine~decide(.Array~of('sales'), ctx)['status'], 'BLOCKED_AUTHORITY_CONTEXT_MISMATCH', 'tenant-bound'
  gate~mismatch('COUNTRY')
  call assertEq engine~decide(.Array~of('sales'), ctx)['status'], 'BLOCKED_AUTHORITY_CONTEXT_MISMATCH', 'country-bound'
  gate~mismatch('CHANNEL')
  call assertEq engine~decide(.Array~of('sales'), ctx)['status'], 'BLOCKED_AUTHORITY_CONTEXT_MISMATCH', 'channel-bound'
  gate~mismatch('LOCALE')
  call assertEq engine~decide(.Array~of('sales'), ctx)['status'], 'BLOCKED_AUTHORITY_CONTEXT_MISMATCH', 'locale-bound'
  gate~mismatch('CLAIMS')
  call assertEq engine~decide(.Array~of('sales'), ctx)['status'], 'BLOCKED_AUTHORITY_CLAIMS_MISMATCH', 'claims-bound'
  gate~mismatch('POLICY')
  call assertEq engine~decide(.Array~of('sales'), ctx)['status'], 'BLOCKED_MISSING_AUTHORITY_PROOF', 'policy-selected'
  gate~mismatch('NONE')
  selected = engine~decide(.Array~of('sales'), ctx)
  call assertEq selected['status'], 'APPROVED', 'valid-request'
  projector = .StoryAgentProjection~new
  projection = projector~project(selected)
  call assertEq projection['status'], 'CANDIDATE', 'agent-candidate'
  call assertEq projection['authority_proof_ref'], .nil, 'agent-proof-omitted'
  call assertEq projection['dispatch_authority'], 'NONE', 'agent-no-dispatch'
  gate~mode('DENY')
  result = engine~decideLive(ctx)
  call assertEq result['status'], 'BLOCKED_DENY', 'withdrawn-next-request'
  call assertEq site~project(result, 'rf-public-hero')['status'], 'BLOCKED', 'site-held-output'
  say 'PASS: Dynamic Story dev4 runtime authority, scope and live intention tests'
::class 'TestAuthorityGateway' public
::method init
  expose modeValue staleValue mismatchValue
  modeValue = 'ALLOW'
  staleValue = .false
  mismatchValue = 'NONE'
::method mode
  expose modeValue
  use strict arg modeValue
::method stale
  expose staleValue
  use strict arg staleValue
::method mismatch
  expose mismatchValue
  use strict arg mismatchValue
::method review
  expose modeValue staleValue mismatchValue
  use strict arg context, intention, narrative, catalogueRevision
  revision = narrative~revision
  if staleValue then revision = 'outdated-revision'
  tenant = context~tenantId
  request = context~requestId
  country = context~country
  channel = context~channel
  locale = context~locale
  policyRef = 'test-selection-8'
  claims = narrative~claimIds
  select
    when mismatchValue == 'REQUEST' then request = 'other-request'
    when mismatchValue == 'TENANT' then tenant = 'other-tenant'
    when mismatchValue == 'COUNTRY' then country = 'GB'
    when mismatchValue == 'CHANNEL' then channel = 'email'
    when mismatchValue == 'LOCALE' then locale = 'en-GB'
    when mismatchValue == 'CLAIMS' then claims = .Array~of('other-claim')
    when mismatchValue == 'POLICY' then policyRef = ''
    otherwise nop
  end
  if mismatchValue == 'CATALOGUE' then catalogueRevision = 'stale-catalogue'
  return .StoryAuthorityResult~new(modeValue, 'test-only-authority', 'test-policy-8', policyRef, intention~identifier, intention~revision, narrative~identifier, revision, 'test-gate', tenant, request, country, channel, locale, claims, catalogueRevision)
::class 'TestCatalogueSource' public
::method init
  expose held rev failureMode
  held = .false
  rev = 'cat-1'
  failureMode = 'NONE'
::method hold
  expose held
  use strict arg held
::method revision
  expose rev
  use strict arg rev
::method failure
  expose failureMode
  use strict arg failureMode
::method snapshot
  expose held rev failureMode
  use strict arg context
  if failureMode == 'MISSING' then return .nil
  if failureMode == 'INVALID' then return 'invalid-catalogue'
  status = 'ACTIVE'
  if held then status = 'HOLD'
  narratives = .Array~new
  narratives~append(.StoryNarrativeBinding~new(.StoryNarrative~new('n-sales-de', 'sales', 'Technical value', 'Benefits', 'Learn', .Array~of('c1'), '5'), 'DE', 'web', 10))
  narratives~append(.StoryNarrativeBinding~new(.StoryNarrative~new('n-sales-default', 'sales', 'General value', 'Benefits', 'Learn', .Array~of('c1'), '2'), '*', '*', 1))
  narratives~append(.StoryNarrativeBinding~new(.StoryNarrative~new('n-incident', 'incident', 'Support', 'Recovery', 'Open support', .Array~of('c2'), '3'), '*', '*', 0))
  return .StoryCatalogueSnapshot~new(rev, status, .Array~of(.StoryIntention~new('sales', 10, 'Explain value', '1'), .StoryIntention~new('incident', 90, 'Restore service', '2')), narratives)
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
