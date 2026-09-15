MICRO = 1000000
path = "/tmp/ai_model_router_v01.log"
ignore = RxFuncAdd("SysFileDelete", "rxunixsys", "SysFileDelete")
ignore = SysFileDelete(path)

keys = .WLUFastMacKeyRing~new
keys~addKey("ai-route", "000102030405060708090a0b0c0d0e0f")
journal = .WLUJobRouteFileJournal~new(path, keys)

/* Route A: stronger success evidence; Route B: cheaper but weaker. */
call addHistory journal, keys, "OPENAI-EU-STANDARD", "O", 5, 5, 4 * MICRO, 0
call addHistory journal, keys, "GROK-EU-STANDARD", "G", 5, 4, 3 * MICRO, 0
/* Route C exists in history but is intentionally not CHAT capable. */
call addHistory journal, keys, "LOCAL-EMBED", "L", 5, 5, 1 * MICRO, 0
call addHistory journal, keys, "ANTHROPIC-EU-BATCH", "A", 5, 5, 2 * MICRO, 0
snapshotResult = .WLUJobRouteAnalytics~new(keys)~verifiedSnapshot(journal)
call assertTrue snapshotResult~ok, "verified route analytics snapshot"
snapshot = snapshotResult~value

router = .AIModelRouter~new(keys)
call assertEq "0.1", .AIModelRouterBuild~RELEASE, "router package version"
call assertEq "0.8", .AlchemyObject~VERSION, "Alchemy v0.8 loaded"
call assertEq "0.12", .WLUDBuild~VERSION, "WLU package v0.12 loaded"
standard = .AlchemyAdoptionVerifier~verify(router, "STANDARD")
call assertTrue standard~ok, "router STANDARD adoption"
call assertEq 0, standard~warnings~items, "router has zero adoption warnings"

catalog = .AIModelRouteCatalog~new
openai = .AIModelRouteCandidate~new("OPENAI-EU-STANDARD", "OPENAI-COMPAT", "openai-standard", "eu-direct", "EU", .false, "AI:OPENAI:EU", 4 * MICRO, 6 * MICRO, "prod", "model-openai-eu", "model.complete", .array~of("CHAT", "TOOLS"))
grok = .AIModelRouteCandidate~new("GROK-EU-STANDARD", "GROK", "grok-standard", "eu-direct", "EU", .false, "AI:GROK:EU", 3 * MICRO, 5 * MICRO, "prod", "model-grok-eu", "model.complete", .array~of("CHAT", "TOOLS"))
embed = .AIModelRouteCandidate~new("LOCAL-EMBED", "LOCAL", "embed-test", "local", "ANY", .false, "AI:LOCAL", 1 * MICRO, 2 * MICRO, "prod", "model-local", "model.complete", .array~of("EMBED"))
anthropicBatch = .AIModelRouteCandidate~new("ANTHROPIC-EU-BATCH", "ANTHROPIC", "claude-batch-test", "eu-batch", "EU", .true, "AI:ANTHROPIC:EU:BATCH", 2 * MICRO, 4 * MICRO, "prod", "model-anthropic-eu", "model.complete", .array~of("CHAT", "TOOLS"))
call assertTrue catalog~register(openai)~ok, "register OpenAI route"
call assertTrue catalog~register(grok)~ok, "register Grok route"
call assertTrue catalog~register(embed)~ok, "register local route"
call assertTrue catalog~register(anthropicBatch)~ok, "register Anthropic batch route"
call assertFalse catalog~register(openai)~ok, "duplicate route rejected"

request = .AIModelRouteRequest~new(.array~of("CHAT", "TOOLS"), "EU", .false)
policy = .WLURouteAdvisoryPolicy~new(5, 3000, 7000, 0)
now = .DateTime~new
policyCatalog = .InstitutionalPolicyCatalog~new
rules = .WLURouteDecisionRules~new("RECOMMENDED_ONLY", "EVIDENCE_ELIGIBLE")~seal
release = .InstitutionalPolicyRelease~new("AI-MODEL-ROUTE", "1.0", now - .TimeSpan~new(0,1,0,0,0), .nil, "AI_PLATFORM", "OPERATIONS_BOARD", "", rules)~seal
call assertTrue policyCatalog~publish(release)~ok, "publish route policy"

outcome = router~route(catalog, request, snapshot, policy, policyCatalog, "AI-MODEL-ROUTE", now, "AUTOMATED")
call assertTrue outcome~ok, "model route permitted"
plan = outcome~value
call assertEq "OPENAI-EU-STANDARD", plan~routeId, "stronger conservative success evidence wins"
call assertEq "OPENAI-COMPAT", plan~providerId, "provider retained"
call assertEq "prod", plan~environment, "environment retained for later Runtime acquisition"
call assertEq "model-openai-eu", plan~clientId, "client id retained for later Runtime acquisition"
call assertEq "model.complete", plan~abilityId, "ability id retained"
call assertFalse plan~admitted, "route plan is not WLU admission"
call assertFalse plan~executableAuthority, "route plan is not execution authority"
call assertTrue plan~advisory~verify(keys), "advisory proof verifies"
call assertTrue plan~decision~verify(keys), "policy decision proof verifies"
call assertEq "RECOMMENDED_STAGE_PERMITTED", plan~decision~reasonCode, "automated policy follows recommendation"

/* Batch eligibility is explicit: once allowed, the equally reliable cheaper batch route can win. */
batchRequest = .AIModelRouteRequest~new(.array~of("CHAT", "TOOLS"), "EU", .true)
batchOutcome = router~route(catalog, batchRequest, snapshot, policy, policyCatalog, "AI-MODEL-ROUTE", now, "AUTOMATED")
call assertTrue batchOutcome~ok, "batch-enabled route permitted"
call assertEq "ANTHROPIC-EU-BATCH", batchOutcome~value~routeId, "batch route wins only when batch is allowed"

/* An explicit provider allowlist is a pre-advisory constraint, not a hidden ranking weight. */
grokOnly = .AIModelRouteRequest~new(.array~of("CHAT", "TOOLS"), "EU", .false, .array~of("GROK"))
grokOutcome = router~route(catalog, grokOnly, snapshot, policy, policyCatalog, "AI-MODEL-ROUTE", now, "AUTOMATED")
call assertTrue grokOutcome~ok, "provider allowlist route permitted"
call assertEq "GROK-EU-STANDARD", grokOutcome~value~routeId, "provider allowlist applied before advice"

/* WLU never saw deployment coordinates: its candidate assessment is stage-id economics only. */
a = plan~advisory~assessmentFor("OPENAI-EU-STANDARD")
call assertTrue a \== .nil, "selected WLU assessment present"
call assertFalse a~hasMethod("CLIENTID"), "WLU assessment carries no client id"
call assertFalse a~hasMethod("ABILITYID"), "WLU assessment carries no ability id"
call assertFalse plan~hasMethod("ACQUIRE"), "plan has no Runtime acquire authority"
call assertFalse plan~hasMethod("RESERVE"), "plan has no WLU reserve authority"
call assertFalse plan~hasMethod("SECRETVALUE"), "plan has no Secret Broker authority"
call assertFalse plan~hasMethod("COMPLETE"), "plan has no provider execution surface"

/* No evidence-eligible route is explicit rather than silently defaulting. */
strict = .WLURouteAdvisoryPolicy~new(100, 9000, 1000, 0)
noEvidence = router~route(catalog, request, snapshot, strict, policyCatalog, "AI-MODEL-ROUTE", now, "AUTOMATED")
call assertFalse noEvidence~ok, "insufficient evidence refuses route"
call assertEq "AI_MODEL_ROUTE_NO_EVIDENCE_ELIGIBLE", noEvidence~code, "no evidence code"

/* An operative policy may disable automated route switching even when advice exists. */
denyCatalog = .InstitutionalPolicyCatalog~new
denyRules = .WLURouteDecisionRules~new("DENY", "EVIDENCE_ELIGIBLE")~seal
denyRelease = .InstitutionalPolicyRelease~new("AI-MODEL-ROUTE-DENY", "1.0", now - .TimeSpan~new(0,1,0,0,0), .nil, "AI_PLATFORM", "OPERATIONS_BOARD", "", denyRules)~seal
call assertTrue denyCatalog~publish(denyRelease)~ok, "publish deny policy"
denied = router~route(catalog, request, snapshot, policy, denyCatalog, "AI-MODEL-ROUTE-DENY", now, "AUTOMATED")
call assertFalse denied~ok, "automated policy denial preserved"
call assertEq "AI_MODEL_ROUTE_POLICY_DENIED", denied~code, "policy denial code"
call assertEq "POLICY_ACTOR_MODE_DENIED", denied~decision~reasonCode, "policy denial reason"

/* Provider/tag constraints are applied before WLU advice. */
missing = .AIModelRouteRequest~new(.array~of("VISION"), "EU", .false)
none = router~route(catalog, missing, snapshot, policy, policyCatalog, "AI-MODEL-ROUTE", now, "AUTOMATED")
call assertFalse none~ok, "missing capability refuses route"
call assertEq "AI_MODEL_ROUTE_NO_CANDIDATES", none~code, "no candidates code"

/* Instrumentation is route/policy metadata only. */
events = router~instrumentationEvents
serialized = .JSON~toJSON(events)
call assertEq 0, serialized~pos("model-openai-eu"), "client id absent from instrumentation"
call assertEq 0, serialized~pos("model.complete"), "ability id absent from instrumentation"
call assertEq 0, serialized~pos("openai-standard"), "model id absent from instrumentation"

say "AI MODEL ROUTER V0.1: OK"
say "  recommendation=" || plan~routeId
say "  advisory_sequence=" || plan~advisory~sourceSequence
say "  decision_policy=" || plan~decision~policyId || "@" || plan~decision~policyVersion
call SysFileDelete path
exit 0

addHistory: procedure
  use strict arg journal, keys, stageId, prefix, samples, successes, actual, handoff
  do i = 1 to samples
    if i <= successes then outcome = "SUCCESS"
    else outcome = "PROVIDER_FAILURE"
    expected = actual
    if outcome = "PROVIDER_FAILURE" then expected = actual - 500000
    e = .WLUJobRouteEvidence~new(prefix || "-" || i, 1, i, .WLUJobRouteEventType~STAGE_SETTLED, stageId, "", "r-" || prefix || i, actual, handoff, .true, expected, expected + 2000000, 1, "WITHIN_BUDGET", "", outcome, "outcome:" || prefix || i, "ai-model-router", "2026-08")
    e = e~withProof(keys~sign(e~canonicalText))
    appended = journal~appendEvent(e)
    if \appended~ok then raise syntax 88.900 array("route history append failed: " || appended~code)
  end
  return

assertTrue: procedure
  use strict arg value, label
  if value \== .true then raise syntax 88.900 array("assertTrue failed: " || label)
  return
assertFalse: procedure
  use strict arg value, label
  if value \== .false then raise syntax 88.900 array("assertFalse failed: " || label)
  return
assertEq: procedure
  use strict arg expected, actual, label
  if expected \== actual then raise syntax 88.900 array("assertEq failed: " || label || " expected=" || expected || " actual=" || actual)
  return

::requires "AIModelRouter.cls"
::requires "WLURouteJournal.cls"
::requires "json.cls"

::requires "AlchemyAdoption.cls"
