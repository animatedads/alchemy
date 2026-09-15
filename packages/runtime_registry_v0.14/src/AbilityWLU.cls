/* Ability WLU Bridge v0.1
 *
 * Optional admission/accounting bridge between Ability HTTP invocation and the
 * separate ooRexx Work Load Units authority.  Only this optional bridge
 * ::requires WorkLoadUnits.cls; AbilityHttpServer itself does not, so the
 * Runtime Registry / Ability stack remains fully usable without WLU installed.
 */

::class AbilityWLUBuild public
::constant PRODUCT "ooRexx Ability WLU Bridge"
::constant RELEASE "0.1"
::constant API_VERSION "ability.wlu/0.1"

::class AbilityMeterFact public
::attribute factType get
::attribute quantity get
::attribute source get
::attribute dimensions get

::method init
  expose factType quantity source dimensions
  use arg factTypeArg, quantityArg = 1, sourceArg = "", dimensionsArg = .nil
  factType = factTypeArg~string~strip~upper
  quantity = quantityArg
  source = sourceArg~string
  if factType = "" then raise syntax 88.900 array("Ability meter fact type must not be empty")
  if \datatype(quantity, "W") then raise syntax 88.900 array("Ability meter fact quantity must be a whole number")
  if quantity < 0 then raise syntax 88.900 array("Ability meter fact quantity must not be negative")
  dimensions = .table~new
  if dimensionsArg \== .nil then do
    supplier = dimensionsArg~supplier
    do while supplier~available
      dimensions[supplier~index~string] = supplier~item~string
      supplier~next
    end
  end

::class AbilityWLUPlan public
::attribute scope get
::attribute ceilingMicroWlu get
::attribute targetSeconds get
::attribute ttlSeconds get
::attribute requestId get

::method init
  expose scope plannedFacts ceilingMicroWlu targetSeconds ttlSeconds requestId
  use arg scopeArg, plannedFactsArg, ceilingMicroWluArg = .nil, targetSecondsArg = 0, ttlSecondsArg = 30, requestIdArg = ""
  scope = scopeArg~string~strip
  if scope = "" then raise syntax 88.900 array("Ability WLU plan scope must not be empty")
  plannedFacts = self~copyFacts(plannedFactsArg)
  if plannedFacts~items = 0 then raise syntax 88.900 array("Ability WLU plan requires at least one planned fact")
  ceilingMicroWlu = ceilingMicroWluArg
  if ceilingMicroWlu \== .nil then do
    if \datatype(ceilingMicroWlu, "W") then raise syntax 88.900 array("Ability WLU ceiling must be a whole micro-WLU value")
    if ceilingMicroWlu <= 0 then raise syntax 88.900 array("Ability WLU ceiling must be positive")
  end
  targetSeconds = targetSecondsArg
  ttlSeconds = ttlSecondsArg
  requestId = requestIdArg~string~strip
  if \datatype(targetSeconds, "W") then raise syntax 88.900 array("Ability WLU target seconds must be whole")
  if targetSeconds < 0 then raise syntax 88.900 array("Ability WLU target seconds must not be negative")
  if \datatype(ttlSeconds, "W") then raise syntax 88.900 array("Ability WLU TTL must be whole")
  if ttlSeconds < 0 then raise syntax 88.900 array("Ability WLU TTL must not be negative")

::method plannedFacts
  expose plannedFacts
  return self~copyFacts(plannedFacts)

::method copyFacts private
  use arg sourceFacts
  copiedFacts = .array~new
  if sourceFacts == .nil then return copiedFacts
  do fact over sourceFacts
    if fact~isa(.AbilityMeterFact) then copiedFacts~append(.AbilityMeterFact~new(fact~factType, fact~quantity, fact~source, fact~dimensions))
    else copiedFacts~append(fact)
  end
  return copiedFacts

::class AbilityWLUExecutionEvidence public
::attribute reservationId get
::attribute identity get
::attribute accountId get
::attribute scope get
::attribute rateCardId get
::attribute rateCardVersion get
::attribute expectedMicroWlu get
::attribute ceilingMicroWlu get
::attribute requestedRateMicroWluPerSecond get
::attribute settlementState get
::attribute actualMicroWlu get
::attribute actualMicroWluKnown get
::attribute actualFactCount get
::attribute proofAlgorithm get
::attribute proofKeyId get
::attribute wluApiVersion get

::method init
  expose reservationId identity accountId scope rateCardId rateCardVersion expectedMicroWlu ceilingMicroWlu requestedRateMicroWluPerSecond settlementState actualMicroWlu actualMicroWluKnown actualFactCount proofAlgorithm proofKeyId wluApiVersion
  use arg reservation, settlementStateArg, actualFactCountArg, actualMicroWluArg = .nil, wluApiVersionArg = ""
  reservationId = reservation~reservationId
  identity = reservation~identity
  accountId = reservation~accountId
  scope = reservation~scope
  rateCardId = reservation~rateCardId
  rateCardVersion = reservation~rateCardVersion
  expectedMicroWlu = reservation~expectedMicroWlu
  ceilingMicroWlu = reservation~reservedMicroWlu
  requestedRateMicroWluPerSecond = reservation~reservedRateMicroWluPerSecond
  settlementState = settlementStateArg~string
  actualFactCount = actualFactCountArg
  actualMicroWlu = actualMicroWluArg
  actualMicroWluKnown = actualMicroWluArg \== .nil
  proofAlgorithm = ""
  proofKeyId = ""
  proof = reservation~proof
  if proof \== .nil then do
    if proof~hasMethod("ALGORITHM") then proofAlgorithm = proof~algorithm
    if proof~hasMethod("KEYID") then proofKeyId = proof~keyId
  end
  wluApiVersion = wluApiVersionArg~string

::method asDirectory
  expose reservationId identity accountId scope rateCardId rateCardVersion expectedMicroWlu ceilingMicroWlu requestedRateMicroWluPerSecond settlementState actualMicroWlu actualMicroWluKnown actualFactCount proofAlgorithm proofKeyId wluApiVersion
  d = .directory~new
  d["reservation_id"] = reservationId
  d["identity"] = identity
  d["account_id"] = accountId
  d["scope"] = scope
  d["rate_card_id"] = rateCardId
  d["rate_card_version"] = rateCardVersion
  d["expected_micro_wlu"] = expectedMicroWlu
  d["ceiling_micro_wlu"] = ceilingMicroWlu
  d["requested_rate_micro_wlu_per_second"] = requestedRateMicroWluPerSecond
  d["settlement_state"] = settlementState
  d["actual_fact_count"] = actualFactCount
  if actualMicroWluKnown then d["actual_micro_wlu"] = actualMicroWlu
  if proofAlgorithm <> "" then d["proof_algorithm"] = proofAlgorithm
  if proofKeyId <> "" then d["proof_key_id"] = proofKeyId
  if wluApiVersion <> "" then d["wlu_api_version"] = wluApiVersion
  return d

::class AbilityWLUInvocation public
::attribute reservation get
::attribute scope get
::attribute finalized get

::method init
  expose authority reservation scope actualFacts finalized evidence apiVersion
  use arg authorityArg, reservationArg, scopeArg, apiVersionArg = ""
  authority = authorityArg
  reservation = reservationArg
  scope = scopeArg~string
  actualFacts = .array~new
  finalized = .false
  evidence = .nil
  apiVersion = apiVersionArg~string

::method meterFact
  expose actualFacts finalized
  use arg factType, quantity = 1, source = "", dimensions = .nil
  if finalized then return .RuntimeResult~failure("ABILITY_WLU_FINALIZED", "metering is closed")
  fact = .AbilityMeterFact~new(factType, quantity, source, dimensions)
  actualFacts~append(fact)
  return .RuntimeResult~success(fact)

::method facts
  expose actualFacts
  copiedFacts = .array~new
  do fact over actualFacts
    copiedFacts~append(fact)
  end
  return copiedFacts

::method finish
  expose authority reservation actualFacts finalized evidence apiVersion
  guard on
  if finalized then return .RuntimeResult~success(evidence)

  actualMicroWlu = .nil
  if actualFacts~items = 0 then do
    closeOutcome = authority~release(reservation)
    if \closeOutcome~ok then return .RuntimeResult~failure("ABILITY_WLU_RELEASE_FAILED", closeOutcome~code || ": " || closeOutcome~detail)
    settlementState = closeOutcome~value
  end
  else do
    wluFacts = self~toWluFacts(actualFacts)
    /* If policy has not rolled during the invocation, expose the actual WLU
     * amount directly. Settlement itself always uses the reservation's pinned
     * rate-card generation inside WLUAuthority. */
    quoteOutcome = authority~quoteFacts(reservation~identity, reservation~scope, wluFacts)
    if quoteOutcome~ok then do
      quote = quoteOutcome~value
      if quote~rateCardId = reservation~rateCardId then do
        if quote~rateCardVersion = reservation~rateCardVersion then actualMicroWlu = quote~microWlu
      end
    end
    closeOutcome = authority~settleFacts(reservation, wluFacts)
    if \closeOutcome~ok then return .RuntimeResult~failure("ABILITY_WLU_SETTLEMENT_FAILED", closeOutcome~code || ": " || closeOutcome~detail)
    settlementState = closeOutcome~value
  end

  evidence = .AbilityWLUExecutionEvidence~new(reservation, settlementState, actualFacts~items, actualMicroWlu, apiVersion)
  finalized = .true
  return .RuntimeResult~success(evidence)

::method toWluFacts private
  use arg abilityFacts
  outputFacts = .array~new
  do fact over abilityFacts
    if fact~isa(.AbilityMeterFact) then outputFacts~append(.WLUFact~new(fact~factType, fact~quantity, fact~source, fact~dimensions))
    else outputFacts~append(fact)
  end
  return outputFacts

::class AbilityWLUBridge public
::attribute authority get

::method init
  expose authority planners
  use arg authorityArg
  if authorityArg == .nil then raise syntax 88.900 array("AbilityWLUBridge requires a WLU authority")
  authority = authorityArg
  planners = .table~new

::method registerPlanner
  expose planners
  use arg abilityId, planner
  key = abilityId~string~strip~lower
  if key = "" then return .RuntimeResult~failure("ABILITY_WLU_ABILITY_REQUIRED", "")
  if planner == .nil then return .RuntimeResult~failure("ABILITY_WLU_PLANNER_REQUIRED", key)
  if \planner~hasMethod("PLAN") then return .RuntimeResult~failure("ABILITY_WLU_PLANNER_INVALID", key)
  planners[key] = planner
  return .RuntimeResult~success(planner)

::method managed
  expose planners
  use arg abilityId
  return planners~at(abilityId~string~strip~lower) \== .nil

::method apiVersion
  expose authority
  if authority~hasMethod("APIVERSION") then return authority~apiVersion
  return ""

::method begin
  expose authority planners
  use arg session, descriptor, body, requestId = ""
  planner = planners~at(descriptor~abilityId)
  if planner == .nil then return .RuntimeResult~success(.nil, "ability has no WLU planner")

  planOutcome = planner~plan(session, descriptor, body)
  if planOutcome~isa(.RuntimeResult) then do
    if \planOutcome~ok then return planOutcome
    plan = planOutcome~value
  end
  else plan = planOutcome
  if plan == .nil then return .RuntimeResult~failure("ABILITY_WLU_PLAN_MISSING", descriptor~abilityId)
  if \plan~isa(.AbilityWLUPlan) then return .RuntimeResult~failure("ABILITY_WLU_PLAN_INVALID", descriptor~abilityId)

  plannedFacts = self~toWluFacts(plan~plannedFacts)
  quoteOutcome = authority~quoteFacts(session~clientId, plan~scope, plannedFacts)
  if \quoteOutcome~ok then return quoteOutcome
  quote = quoteOutcome~value
  ceiling = plan~ceilingMicroWlu
  if ceiling == .nil then ceiling = quote~microWlu
  if ceiling < quote~microWlu then return .RuntimeResult~failure("ABILITY_WLU_CEILING_BELOW_QUOTE", "expected=" || quote~microWlu || " ceiling=" || ceiling)
  demand = .WLUWorkDemand~new(quote~microWlu, ceiling, plan~targetSeconds)
  effectiveRequestId = requestId~string~strip
  if effectiveRequestId = "" then effectiveRequestId = plan~requestId
  reserveOutcome = authority~reserveDemand(session~clientId, plan~scope, demand, plan~ttlSeconds, effectiveRequestId, quote~rateCardId, quote~rateCardVersion)
  if \reserveOutcome~ok then return reserveOutcome
  reservation = reserveOutcome~value
  admitOutcome = authority~admit(reservation)
  if \admitOutcome~ok then do
    ignoredRelease = authority~release(reservation)
    return admitOutcome
  end
  apiVersion = ""
  if authority~hasMethod("APIVERSION") then apiVersion = authority~apiVersion
  return .RuntimeResult~success(.AbilityWLUInvocation~new(authority, reservation, plan~scope, apiVersion))

::method finish
  use arg invocation
  if invocation == .nil then return .RuntimeResult~success(.nil)
  return invocation~finish

::method toWluFacts private
  use arg abilityFacts
  outputFacts = .array~new
  do fact over abilityFacts
    if fact~isa(.AbilityMeterFact) then outputFacts~append(.WLUFact~new(fact~factType, fact~quantity, fact~source, fact~dimensions))
    else outputFacts~append(fact)
  end
  return outputFacts

::requires "RuntimeRegistry.cls"

::requires "WorkLoadUnits.cls"
