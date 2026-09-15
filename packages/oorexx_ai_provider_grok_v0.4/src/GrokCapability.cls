/* ooRexx AI Provider Grok (xAI) Capability Selector v0.4
 *
 * Answers "which model / channel / batch mode should this job use"
 * from a description of the *workload*, not from a caller-forced model name.
 *
 * Selection rule (fail-closed, hard to route around):
 *   1. Filter catalog entries whose capability tier meets the workload floor
 *      (ECONOMY < STANDARD < FRONTIER).
 *   2. Filter to channels that satisfy the workload's data-sovereignty zone.
 *      (xAI today is primarily DIRECT/US; the channel abstraction is kept
 *      honest for future regional options without inventing them.)
 *   3. Prefer batch when the workload allows it AND the model is batchEligible.
 *   4. Of what remains, pick the cheapest estimated micro-USD cost.
 *   5. If nothing survives, raise -- never silently drop tier, zone, or
 *      force real-time when batch was required by policy.
 *
 * This unit does NOT acquire credentials, touch Secret Broker, or perform
 * HTTP.  It only produces a GrokRoutingPlan that downstream adapters and
 * WLU planners consume.
 */

::class GrokCapabilityBuild public
::constant PRODUCT "ooRexx AI Provider - Grok Capability Selector"
::constant RELEASE "0.4"
::constant API_VERSION "ai.provider.grok.capability/0.3"
::constant AI_ACCESS_VERSION "0.6"
::constant ALCHEMY_OBJECTS_VERSION "0.8"

/* ---------------------------------------------------------------------
 * Channel: where a request can be sent and which data-sovereignty zone
 * that satisfies.  xAI public inference is currently DIRECT/US; the
 * abstraction exists so EU/regional options can be added without rewriting
 * the selector.
 * --------------------------------------------------------------------- */
::class GrokChannel public
::attribute id get
::attribute kind get          -- DIRECT
::attribute region get
::attribute zone get          -- US | ANY | (future EU etc.)
::attribute baseHost get
::attribute batchCapable get

::method init
  expose id kind region zone baseHost batchCapable
  use arg idArg, kindArg, regionArg, zoneArg, baseHostArg, batchCapableArg = .true
  id = idArg~string~strip~upper
  kind = kindArg~string~strip~upper
  region = regionArg~string~strip
  zone = zoneArg~string~strip~upper
  baseHost = baseHostArg~string~strip
  batchCapable = batchCapableArg == .true

::method satisfiesZone
  expose zone
  use arg requiredZone
  requiredZone = requiredZone~string~strip~upper
  if requiredZone = "" | requiredZone = "ANY" then return .true
  if zone = "ANY" then return .true
  return zone = requiredZone

::method direct class
  return self~new("XAI_DIRECT", "DIRECT", "", "US", "api.x.ai", .true)


/* ---------------------------------------------------------------------
 * Model catalog entry: tier + published-style pricing + batch eligibility.
 * Prices are illustrative micro-USD per million tokens based on public
 * xAI list prices; deployments may replace the catalog entirely.
 * --------------------------------------------------------------------- */
::class GrokModelEntry public
::attribute modelId get
::attribute tier get                 -- ECONOMY | STANDARD | FRONTIER
::attribute capabilityScore get      -- higher = more capable within tier
::attribute inputMicroUsdPerMTok get
::attribute outputMicroUsdPerMTok get
::attribute batchEligible get
::attribute batchDiscountBps get     -- basis points off (5000 = 50%)
::attribute channelsAvailable get    -- Array of GrokChannel

::method init
  expose modelId tier capabilityScore inputMicroUsdPerMTok outputMicroUsdPerMTok batchEligible batchDiscountBps channelsAvailable
  use arg modelIdArg, tierArg, capabilityScoreArg, inMicroArg, outMicroArg, batchEligibleArg = .true, batchDiscountBpsArg = 5000, channelsArg = .nil
  modelId = modelIdArg~string~strip
  tier = tierArg~string~strip~upper
  capabilityScore = capabilityScoreArg
  inputMicroUsdPerMTok = inMicroArg
  outputMicroUsdPerMTok = outMicroArg
  batchEligible = batchEligibleArg == .true
  batchDiscountBps = batchDiscountBpsArg
  if channelsArg == .nil then channelsAvailable = .array~of(.GrokChannel~direct)
  else channelsAvailable = channelsArg
  if modelId = "" then raise syntax 88.900 array("Grok model id must not be empty")
  if tier \= "ECONOMY" & tier \= "STANDARD" & tier \= "FRONTIER" then ,
    raise syntax 88.900 array("Grok model tier must be ECONOMY, STANDARD or FRONTIER")
  if \datatype(capabilityScore, "W") then raise syntax 88.900 array("Grok capability score must be whole")
  if \datatype(inputMicroUsdPerMTok, "W") then raise syntax 88.900 array("Grok input price must be whole micro-USD")
  if \datatype(outputMicroUsdPerMTok, "W") then raise syntax 88.900 array("Grok output price must be whole micro-USD")
  if \datatype(batchDiscountBps, "W") then raise syntax 88.900 array("Grok batch discount must be whole basis points")
  if batchDiscountBps < 0 | batchDiscountBps > 10000 then raise syntax 88.900 array("Grok batch discount out of range")

::method estimateMicroUsd
  expose inputMicroUsdPerMTok outputMicroUsdPerMTok batchEligible batchDiscountBps
  use arg inputTokens, outputTokens, useBatch
  inCost = (inputTokens * inputMicroUsdPerMTok) % 1000000
  outCost = (outputTokens * outputMicroUsdPerMTok) % 1000000
  total = inCost + outCost
  if useBatch & batchEligible & batchDiscountBps > 0 then do
    total = total * (10000 - batchDiscountBps) % 10000
  end
  if total < 1 & (inputTokens > 0 | outputTokens > 0) then total = 1
  return total


::class GrokModelCatalog public
::attribute entries get

::method init
  expose entries
  entries = .directory~new

::method register
  expose entries
  use arg entry
  if \entry~isa(.GrokModelEntry) then raise syntax 88.900 array("Grok catalog accepts GrokModelEntry only")
  entries[entry~modelId] = entry
  return self

::method get
  expose entries
  use arg modelId
  return entries[modelId~string~strip]

::method allEntries
  expose entries
  list = .array~new
  do id over entries~allIndexes
    list~append(entries[id])
  end
  return list

/* Built-in default catalog reflecting public xAI model lineup (Aug 2026).
 * Prices in micro-USD per million tokens (e.g. $2.00/1M = 2000000 micro-USD).
 * Deployments may replace this catalog via GrokCapabilitySelector~init. */
::method defaultCatalog class
  cat = self~new
  direct = .array~of(.GrokChannel~direct)
  /* ECONOMY / fast */
  cat~register(.GrokModelEntry~new("grok-code-fast-1", "ECONOMY", 40, 200000, 500000, .true, 5000, direct))
  /* STANDARD */
  cat~register(.GrokModelEntry~new("grok-4.3", "STANDARD", 60, 1000000, 3000000, .true, 5000, direct))
  cat~register(.GrokModelEntry~new("grok-4.5", "STANDARD", 70, 1500000, 4500000, .true, 5000, direct))
  cat~register(.GrokModelEntry~new("grok-2-vision", "STANDARD", 55, 2000000, 10000000, .true, 5000, direct))
  cat~register(.GrokModelEntry~new("grok-2-vision-1212", "STANDARD", 55, 2000000, 10000000, .true, 5000, direct))
  /* FRONTIER */
  cat~register(.GrokModelEntry~new("grok-4", "FRONTIER", 85, 2000000, 6000000, .true, 5000, direct))
  cat~register(.GrokModelEntry~new("grok-4.6", "FRONTIER", 95, 2000000, 6000000, .true, 5000, direct))
  return cat

::method tierRank class
  use arg tier
  t = tier~string~strip~upper
  if t = "ECONOMY" then return 1
  if t = "STANDARD" then return 2
  if t = "FRONTIER" then return 3
  return 0


/* ---------------------------------------------------------------------
 * Workload profile: what the job needs, in non-model terms.
 * --------------------------------------------------------------------- */
::class GrokWorkloadProfile public
::attribute taskTier get              -- ECONOMY | STANDARD | FRONTIER
::attribute requiredZone get          -- ANY | US | (future EU)
::attribute batchOk get
::attribute estInputTokens get
::attribute estOutputTokens get
::attribute costCeilingMicroUsd get   -- .nil = no ceiling

::method init
  expose taskTier requiredZone batchOk estInputTokens estOutputTokens costCeilingMicroUsd
  use arg taskTierArg = "STANDARD", requiredZoneArg = "ANY", batchOkArg = .false, ,
      estInputArg = 1000, estOutputArg = 256, costCeilingArg = .nil
  taskTier = taskTierArg~string~strip~upper
  requiredZone = requiredZoneArg~string~strip~upper
  batchOk = batchOkArg == .true
  estInputTokens = estInputArg
  estOutputTokens = estOutputArg
  costCeilingMicroUsd = costCeilingArg
  if taskTier \= "ECONOMY" & taskTier \= "STANDARD" & taskTier \= "FRONTIER" then ,
    raise syntax 88.900 array("Grok workload taskTier must be ECONOMY, STANDARD or FRONTIER")
  if \datatype(estInputTokens, "W") then raise syntax 88.900 array("Grok workload estInputTokens must be whole")
  if \datatype(estOutputTokens, "W") then raise syntax 88.900 array("Grok workload estOutputTokens must be whole")
  if estInputTokens < 0 | estOutputTokens < 0 then raise syntax 88.900 array("Grok workload token estimates must not be negative")
  if costCeilingMicroUsd \== .nil then do
    if \datatype(costCeilingMicroUsd, "W") then raise syntax 88.900 array("Grok workload cost ceiling must be whole micro-USD")
    if costCeilingMicroUsd < 0 then raise syntax 88.900 array("Grok workload cost ceiling must not be negative")
  end


/* ---------------------------------------------------------------------
 * Routing plan: the selector's answer.  Downstream real-time / batch
 * adapters and WLU planners consume this; they do not re-decide tier.
 * --------------------------------------------------------------------- */
::class GrokRoutingPlan public
::attribute modelId get
::attribute channelId get
::attribute channelKind get
::attribute region get
::attribute useBatch get
::attribute estimatedMicroUsd get
::attribute reason get
::attribute tier get

::method init
  expose modelId channelId channelKind region useBatch estimatedMicroUsd reason tier
  use arg modelIdArg, channelIdArg, channelKindArg, regionArg, useBatchArg, estimatedMicroUsdArg, reasonArg, tierArg = ""
  modelId = modelIdArg~string~strip
  channelId = channelIdArg~string~strip
  channelKind = channelKindArg~string~strip
  region = regionArg~string
  useBatch = useBatchArg == .true
  estimatedMicroUsd = estimatedMicroUsdArg
  reason = reasonArg~string
  tier = tierArg~string~strip~upper


/* ---------------------------------------------------------------------
 * Capability selector.
 * --------------------------------------------------------------------- */
::class GrokCapabilitySelector subclass AlchemyObject public

::method init
  expose catalog
  use arg catalogArg = .nil
  if catalogArg == .nil then catalog = .GrokModelCatalog~defaultCatalog
  else do
    if \catalogArg~isa(.GrokModelCatalog) then raise syntax 88.900 array("GrokCapabilitySelector requires GrokModelCatalog")
    catalog = catalogArg
  end
  meta = .directory~new
  meta["purpose"] = "Grok capability selection and cost optimisation -- cheapest model/channel/batch mode that clears the workload floor"
  meta["package"] = "oorexx_ai_provider_grok"
  meta["package_version"] = .GrokCapabilityBuild~RELEASE
  meta["api_version"] = .GrokCapabilityBuild~API_VERSION
  meta["authorship"] = "Alchemy ooRexx project"
  meta["standards"] = "ALCHEMY-HOUSE-OBJECT-0.8; ai.provider.grok.capability/0.3 deterministic workload-to-route selection"
  meta["design_limitations"] = "Selector uses deployment-supplied model/channel/cost facts only; it acquires no credential, performs no provider request and has no WLU admission or Runtime Registry execution authority"
  self~init:super(meta)
  self~registerMethodContract("SELECTMODEL", "select model/channel/batch from workload profile", .array~of("WORKLOAD"), "GROKROUTINGPLAN", .false, "AUTO", "PUBLIC", "NORMAL", "READ", "NONE")
  self~registerMethodContract("ESTIMATECOST", "estimate micro-USD for model/tokens/batch", .array~of("MODELID", "INPUTTOKENS", "OUTPUTTOKENS", "USEBATCH"), "NUMERIC", .false, "AUTO", "PUBLIC", "NORMAL", "READ", "NONE")
  self~registerExternalRequirement("library", "alchemy_objects", "v" || .GrokCapabilityBuild~ALCHEMY_OBJECTS_VERSION, .true)
  self~declareHouseCompliance(95)

::method selectModel
  expose catalog
  use arg workload
  if \workload~isa(.GrokWorkloadProfile) then raise syntax 88.900 array("selectModel requires GrokWorkloadProfile")

  floorRank = .GrokModelCatalog~tierRank(workload~taskTier)
  if floorRank = 0 then raise syntax 88.900 array("Grok workload taskTier is not recognised")

  candidates = .array~new
  do entry over catalog~allEntries
    entryRank = .GrokModelCatalog~tierRank(entry~tier)
    if entryRank < floorRank then iterate   /* does not meet capability floor */

    /* Find a channel on this entry that satisfies the zone. */
    chosenChannel = .nil
    do ch over entry~channelsAvailable
      if ch~satisfiesZone(workload~requiredZone) then do
        chosenChannel = ch
        leave
      end
    end
    if chosenChannel == .nil then iterate   /* no channel meets sovereignty */

    /* Prefer batch when allowed and eligible. */
    useBatch = .false
    if workload~batchOk & entry~batchEligible & chosenChannel~batchCapable then useBatch = .true

    cost = entry~estimateMicroUsd(workload~estInputTokens, workload~estOutputTokens, useBatch)
    if workload~costCeilingMicroUsd \== .nil then do
      if cost > workload~costCeilingMicroUsd then iterate
    end

    cand = .directory~new
    cand["entry"] = entry
    cand["channel"] = chosenChannel
    cand["useBatch"] = useBatch
    cand["cost"] = cost
    candidates~append(cand)
  end

  if candidates~items = 0 then ,
    raise syntax 88.900 array("GrokCapabilitySelector: no model/channel satisfies tier=" || ,
      workload~taskTier || " zone=" || workload~requiredZone || " batchOk=" || workload~batchOk)

  /* Pick cheapest; tie-break by higher capabilityScore then modelId. */
  best = candidates[1]
  do i = 2 to candidates~items
    c = candidates[i]
    if c["cost"] < best["cost"] then best = c
    else if c["cost"] = best["cost"] then do
      if c["entry"]~capabilityScore > best["entry"]~capabilityScore then best = c
      else if c["entry"]~capabilityScore = best["entry"]~capabilityScore then do
        if c["entry"]~modelId < best["entry"]~modelId then best = c
      end
    end
  end

  entry = best["entry"]
  ch = best["channel"]
  useBatch = best["useBatch"]
  cost = best["cost"]
  reason = "tier>=" || workload~taskTier || "; zone=" || workload~requiredZone || ,
    "; batch=" || useBatch || "; cheapest eligible"
  return .GrokRoutingPlan~new(entry~modelId, ch~id, ch~kind, ch~region, useBatch, cost, reason, entry~tier)

::method estimateCost
  expose catalog
  use arg modelId, inputTokens, outputTokens, useBatch = .false
  entry = catalog~get(modelId)
  if entry == .nil then raise syntax 88.900 array("GrokCapabilitySelector: unknown model " || modelId)
  return entry~estimateMicroUsd(inputTokens, outputTokens, useBatch == .true)

::requires "AlchemyObject.cls"
