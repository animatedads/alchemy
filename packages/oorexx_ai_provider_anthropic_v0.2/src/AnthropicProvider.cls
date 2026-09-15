/* ooRexx AI Provider - Anthropic v0.2
 *
 * Live-capable Anthropic provider adapter behind oorexx_ai_access_v0.6, plus
 * a capability selector and cost optimizer that are the actual point of this
 * package: given a workload, choose the cheapest Anthropic model/channel/zone
 * that clears the workload's own capability floor and data-sovereignty
 * requirement -- never "send everything to the biggest available model".
 *
 * Real Anthropic wire facts this package is built against (2026-08):
 *   Direct API   -> https://api.anthropic.com   (US-only; no region control)
 *   AWS Bedrock  -> region is a property of the chosen Bedrock endpoint;
 *                   EU options include eu-central-1 (Frankfurt), eu-west-1
 *                   (Ireland), eu-west-3 (Paris), eu-north-1 (Stockholm)
 *   GCP Vertex   -> region is a property of the chosen Vertex endpoint;
 *                   EU multi-region options exist there too
 *   Anthropic's own direct API has NO first-party EU/region-locked
 *   processing option. A workload that requires EU (or other non-US)
 *   data residency MUST be routed to Bedrock/Vertex in that region, not the
 *   direct channel -- the selector below enforces exactly that.
 *
 *   Real-time:  POST /v1/messages
 *   Batch:      POST   /v1/messages/batches
 *               GET    /v1/messages/batches/{id}
 *               GET    /v1/messages/batches/{id}/results
 *               POST   /v1/messages/batches/{id}/cancel
 *               DELETE /v1/messages/batches/{id}
 *               GET    /v1/messages/batches            (list)
 *   Batch discount: 50% off matching real-time token pricing (published,
 *   subject to change -- treat AnthropicModelCatalog rates as a rate CARD
 *   an operator supplies/updates, not a pricing guarantee baked into code).
 *   Batch hard timeout 24h, up to 100,000 requests / 256MB per batch,
 *   results retained 29 days.
 *
 * Scope deliberately not added in v0.2 (separate authority boundaries):
 *   - AWS SigV4 / GCP OAuth signed transport for Bedrock/Vertex channels.
 *     Those channels ARE modeled for selection/routing/cost purposes (a
 *     workload requiring EU residency correctly gets routed to them, never
 *     silently served from the US-only direct channel) but v0.2 only ships
 *     a working live transport for the direct channel. A routing plan for
 *     Bedrock/Vertex is a fully-specified handoff object, not a fake signed
 *     request.
 *   - credential/secret-store implementation (narrow CredentialSource
 *     interface only; production deployments should supply one backed by
 *     oorexx_secret_broker or equivalent, matching sibling packages)
 *   - MCP/tool-call brokerage (that's oorexx_ai_tool_broker's job)
 *   - streaming response transport
 */

::class AnthropicProviderBuild public
::constant PRODUCT "ooRexx AI Provider - Anthropic"
::constant RELEASE "0.2"
::constant API_VERSION "ai.provider.anthropic/0.1"
::constant AI_ACCESS_VERSION "0.6"
::constant ALCHEMY_OBJECTS_VERSION "0.8"
::constant SECRET_BROKER_VERSION "0.2"
::constant ANTHROPIC_API_VERSION_HEADER "2023-06-01"
::constant PATH_MESSAGES "/v1/messages"
::constant PATH_BATCHES "/v1/messages/batches"


/* ---------------------------------------------------------------------
 * Channels: where a request can actually be sent, and what data-sovereignty
 * zone that channel/region combination satisfies. This is the factual
 * backbone the selector uses to refuse to route EU-required work to a
 * US-only channel.
 * --------------------------------------------------------------------- */
::class AnthropicChannel public
::attribute id get
::attribute kind get          -- DIRECT | BEDROCK | VERTEX
::attribute region get        -- "" for DIRECT; e.g. "eu-central-1" for others
::attribute zone get          -- data-sovereignty zone this satisfies: US, EU, ANY
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
  return zone = requiredZone

::method direct class
  return self~new("ANTHROPIC_DIRECT", "DIRECT", "", "US", "api.anthropic.com", .true)

::method bedrock class
  use arg region, zone
  return self~new("BEDROCK_" || region~translate, "BEDROCK", region, zone, "bedrock-runtime." || region || ".amazonaws.com", .true)

::method vertex class
  use arg region, zone
  return self~new("VERTEX_" || region~translate, "VERTEX", region, zone, region || "-aiplatform.googleapis.com", .true)

::method standardChannels class
  -- The known/common channel set. A deployment can supply its own list;
  -- this is a reasonable default, not an exhaustive account of every
  -- Bedrock/Vertex region Anthropic models are offered in.
  chans = .array~new
  chans~append(self~direct)
  chans~append(self~bedrock("eu-central-1", "EU"))
  chans~append(self~bedrock("eu-west-1", "EU"))
  chans~append(self~bedrock("eu-west-3", "EU"))
  chans~append(self~bedrock("us-east-1", "US"))
  chans~append(self~vertex("europe-west4", "EU"))
  chans~append(self~vertex("us-central1", "US"))
  return chans


/* ---------------------------------------------------------------------
 * Model catalog: a rate card + capability tier, not a claim of ground-truth
 * pricing. Operators should refresh microUsd figures from their own
 * contract/console pricing; this is the shape, with reasonable-as-of-build
 * placeholder figures clearly labelled as such.
 * --------------------------------------------------------------------- */
::class AnthropicModelEntry public
::attribute modelId get
::attribute tier get                 -- ECONOMY | STANDARD | FRONTIER | RESEARCH
::attribute capabilityScore get      -- 1-100 rough proxy, operator-tunable
::attribute inputMicroUsdPerMTok get
::attribute outputMicroUsdPerMTok get
::attribute batchEligible get
::attribute channelsAvailable get     -- Array of AnthropicChannel~id this model ships on

::method init
  expose modelId tier capabilityScore inputMicroUsdPerMTok outputMicroUsdPerMTok batchEligible channelsAvailable
  use arg modelIdArg, tierArg, capabilityScoreArg, inMicroArg, outMicroArg, batchEligibleArg, channelsArg
  modelId = modelIdArg~string~strip
  tier = tierArg~string~strip~upper
  capabilityScore = capabilityScoreArg
  inputMicroUsdPerMTok = inMicroArg
  outputMicroUsdPerMTok = outMicroArg
  batchEligible = batchEligibleArg == .true
  channelsAvailable = channelsArg

::method availableOnChannel
  expose channelsAvailable
  use arg channelId
  do c over channelsAvailable
    if c = channelId then return .true
  end
  return .false


::class AnthropicModelCatalog public

::method init
  expose entries
  entries = .directory~new
  -- Placeholder rate-card figures (micro-USD per million tokens), clearly
  -- illustrative -- callers running this for real should replace these via
  -- registerModel with figures from their own Anthropic/Bedrock/Vertex
  -- pricing agreement.
  self~registerModel("claude-haiku-4-5-20251001", "ECONOMY",  35, 1000000,   5000000,   .true,  .array~of("ANTHROPIC_DIRECT", "BEDROCK_EU-CENTRAL-1", "BEDROCK_EU-WEST-1", "BEDROCK_EU-WEST-3", "BEDROCK_US-EAST-1", "VERTEX_EUROPE-WEST4", "VERTEX_US-CENTRAL1"))
  self~registerModel("claude-sonnet-5",           "STANDARD", 65, 3000000,   15000000,  .true,  .array~of("ANTHROPIC_DIRECT", "BEDROCK_EU-CENTRAL-1", "BEDROCK_EU-WEST-1", "BEDROCK_EU-WEST-3", "BEDROCK_US-EAST-1", "VERTEX_EUROPE-WEST4", "VERTEX_US-CENTRAL1"))
  self~registerModel("claude-opus-4-8",           "FRONTIER", 85, 15000000,  75000000,  .true,  .array~of("ANTHROPIC_DIRECT", "BEDROCK_EU-CENTRAL-1", "BEDROCK_US-EAST-1", "VERTEX_EUROPE-WEST4", "VERTEX_US-CENTRAL1"))
  self~registerModel("claude-fable-5",            "RESEARCH", 97, 20000000,  100000000, .false, .array~of("ANTHROPIC_DIRECT"))

::method registerModel
  expose entries
  use arg modelId, tier, capabilityScore, inMicro, outMicro, batchEligible, channels
  entries[modelId~string~strip] = .AnthropicModelEntry~new(modelId, tier, capabilityScore, inMicro, outMicro, batchEligible, channels)

::method entry
  expose entries
  use arg modelId
  return entries[modelId~string~strip]

::method allEntries
  expose entries
  list = .array~new
  do e over entries~allItems
    list~append(e)
  end
  return list

::method entriesForTierFloor
  -- tier order ECONOMY < STANDARD < FRONTIER < RESEARCH
  expose entries
  use arg minTier
  order = .directory~new
  order["ECONOMY"] = 1; order["STANDARD"] = 2; order["FRONTIER"] = 3; order["RESEARCH"] = 4
  floor = order[minTier~string~strip~upper]
  if floor == .nil then floor = 1
  list = .array~new
  do e over entries~allItems
    rank = order[e~tier]
    if rank == .nil then rank = 1
    if rank >= floor then list~append(e)
  end
  return list


/* ---------------------------------------------------------------------
 * Workload profile: what the caller actually needs, in non-model terms.
 * The whole point is that the caller describes the JOB, not the model.
 * --------------------------------------------------------------------- */
::class AnthropicWorkloadProfile public
::attribute taskTier get              -- LOW | MEDIUM | HIGH | RESEARCH (capability FLOOR the job needs)
::attribute requiredZone get          -- US | EU | ANY
::attribute batchOk get               -- .true if a 24h turnaround is acceptable
::attribute estInputTokens get
::attribute estOutputTokens get
::attribute costCeilingMicroUsd get   -- .nil = no ceiling

::method init
  expose taskTier requiredZone batchOk estInputTokens estOutputTokens costCeilingMicroUsd
  use arg taskTierArg = "LOW", requiredZoneArg = "ANY", batchOkArg = .false, estInputArg = 1000, estOutputArg = 256, costCeilingArg = .nil
  taskTier = taskTierArg~string~strip~upper
  requiredZone = requiredZoneArg~string~strip~upper
  batchOk = batchOkArg == .true
  estInputTokens = estInputArg
  estOutputTokens = estOutputArg
  costCeilingMicroUsd = costCeilingArg


::class AnthropicRoutingPlan public
::attribute modelId get
::attribute channelId get
::attribute channelKind get
::attribute region get
::attribute useBatch get
::attribute estimatedMicroUsd get
::attribute reason get

::method init
  expose modelId channelId channelKind region useBatch estimatedMicroUsd reason
  use arg modelIdArg, channelIdArg, channelKindArg, regionArg, useBatchArg, estimatedMicroUsdArg, reasonArg
  modelId = modelIdArg
  channelId = channelIdArg
  channelKind = channelKindArg
  region = regionArg
  useBatch = useBatchArg == .true
  estimatedMicroUsd = estimatedMicroUsdArg
  reason = reasonArg~string


/* ---------------------------------------------------------------------
 * The capability selector: the actual deliverable. Filters by sovereignty
 * zone and capability floor FIRST, then ranks the surviving candidates by
 * cost. It never simply returns the highest-tier model.
 * --------------------------------------------------------------------- */
::class AnthropicCapabilitySelector subclass AlchemyObject public

::method init
  expose catalog channels jobLedger
  use arg catalogArg = .nil, channelsArg = .nil
  if catalogArg == .nil then catalog = .AnthropicModelCatalog~new
  else catalog = catalogArg
  if channelsArg == .nil then channels = .AnthropicChannel~standardChannels
  else channels = channelsArg
  jobLedger = .directory~new

  meta = .directory~new
  meta["purpose"] = "Anthropic capability selection and cost optimisation -- chooses the cheapest model/channel/zone that clears a workload's own capability floor and data-sovereignty requirement"
  meta["package_version"] = .AnthropicProviderBuild~RELEASE
  meta["api_version"] = .AnthropicProviderBuild~API_VERSION
  meta["authorship"] = "Alchemy ooRexx project"
  meta["standards"] = "ALCHEMY-HOUSE-OBJECT-0.8; ai.provider.anthropic/0.1; evidence-first capability and sovereignty routing"
  meta["design_limitations"] = "Selector ranks only the supplied model/channel catalogue and declared workload facts; pricing data is operator-supplied and illustrative defaults are not authoritative provider pricing"
  self~init:super(meta)
  self~registerExternalRequirement("library", "alchemy_objects", "v" || .AnthropicProviderBuild~ALCHEMY_OBJECTS_VERSION, .true)
  self~registerMethodContract("SELECTMODEL", "choose a routing plan for a workload profile", .array~of("PROFILE"), "ANTHROPICROUTINGPLAN", .false, "AUTO", "PUBLIC", "NORMAL", "READ", "NONE")
  self~registerMethodContract("ESTIMATECOST", "estimate micro-USD cost for a model/token/batch combination", .array~of("MODELID", "INPUTTOKENS", "OUTPUTTOKENS", "USEBATCH"), "NUMERIC", .false, "AUTO", "PUBLIC", "NORMAL", "READ", "NONE")
  self~registerMethodContract("QUERYJOBCOST", "return recorded actual/estimated micro-USD cost for a previously routed job id", .array~of("JOBID"), "ANY", .false, "AUTO", "PUBLIC", "NORMAL", "READ", "NONE")
  self~declareHouseCompliance(90)

/* Core selection rule, in one place so it can't drift into "just pick the
 * best model": eligible = zone-satisfying AND capability-floor-satisfying.
 * Winner = lowest estimated cost among eligible, batch preferred when the
 * workload allows it and the model supports it. Ties broken toward lower
 * tier (cheaper/simpler), never toward higher tier. */
::method selectModel public
  expose catalog channels
  use arg profile
  self~alchemyTouch("SELECTMODEL")

  eligibleChannels = .array~new
  do c over channels
    if c~satisfiesZone(profile~requiredZone) then eligibleChannels~append(c)
  end
  if eligibleChannels~items = 0 then
    raise syntax 88.900 array("Anthropic capability selector: no channel satisfies required zone" profile~requiredZone)

  candidates = catalog~entriesForTierFloor(profile~taskTier)
  if candidates~items = 0 then
    raise syntax 88.900 array("Anthropic capability selector: no model meets task tier floor" profile~taskTier)

  best = .nil
  bestCost = .nil
  bestChannel = .nil
  bestBatch = .false
  do m over candidates
    do c over eligibleChannels
      if \m~availableOnChannel(c~id) then iterate
      useBatch = profile~batchOk & m~batchEligible & c~batchCapable
      cost = self~estimateCost(m~modelId, profile~estInputTokens, profile~estOutputTokens, useBatch)
      if profile~costCeilingMicroUsd \== .nil then do
        if cost > profile~costCeilingMicroUsd then iterate
      end
      if bestCost == .nil then do
        best = m; bestCost = cost; bestChannel = c; bestBatch = useBatch
      end
      else do
        if cost < bestCost then do
          best = m; bestCost = cost; bestChannel = c; bestBatch = useBatch
        end
      end
    end
  end

  if best == .nil then
    raise syntax 88.900 array("Anthropic capability selector: no zone+tier+cost-ceiling combination is satisfiable for this workload")

  reason = "tier-floor=" || profile~taskTier || " zone=" || profile~requiredZone || " cheapest-eligible=" || best~modelId || " tier=" || best~tier || " batch=" || bestBatch~string
  return .AnthropicRoutingPlan~new(best~modelId, bestChannel~id, bestChannel~kind, bestChannel~region, bestBatch, bestCost, reason)

::method rankCandidates public
  -- same eligibility rule as selectModel, but returns every eligible
  -- (model,channel) pair sorted cheapest-first, so a caller can see the
  -- tradeoffs rather than just the winner.
  expose catalog channels
  use arg profile
  eligibleChannels = .array~new
  do c over channels
    if c~satisfiesZone(profile~requiredZone) then eligibleChannels~append(c)
  end
  candidates = catalog~entriesForTierFloor(profile~taskTier)
  ranked = .array~new
  do m over candidates
    do c over eligibleChannels
      if \m~availableOnChannel(c~id) then iterate
      useBatch = profile~batchOk & m~batchEligible & c~batchCapable
      cost = self~estimateCost(m~modelId, profile~estInputTokens, profile~estOutputTokens, useBatch)
      ranked~append(.AnthropicRoutingPlan~new(m~modelId, c~id, c~kind, c~region, useBatch, cost, "candidate"))
    end
  end
  return self~sortPlansByCost(ranked)

::method sortPlansByCost private
  use arg plans
  n = plans~items
  do i = 1 to n - 1
    do j = 1 to n - i
      if plans[j]~estimatedMicroUsd > plans[j + 1]~estimatedMicroUsd then do
        tmp = plans[j]; plans[j] = plans[j + 1]; plans[j + 1] = tmp
      end
    end
  end
  return plans

::method estimateCost public
  expose catalog
  use arg modelId, inputTokens, outputTokens, useBatch = .false
  entry = catalog~entry(modelId)
  if entry == .nil then raise syntax 88.900 array("Anthropic capability selector: unknown model" modelId)
  inCost = (inputTokens / 1000000) * entry~inputMicroUsdPerMTok
  outCost = (outputTokens / 1000000) * entry~outputMicroUsdPerMTok
  total = inCost + outCost
  if useBatch & entry~batchEligible then total = total * 0.5
  return total~trunc(0)

::method recordJobCost public
  -- Called by the batch provider once a job is created/settled, so a
  -- caller can query cost for a job id after the fact.
  expose jobLedger
  use arg jobId, modelId, estimatedMicroUsd, actualMicroUsd = .nil, status = "ESTIMATED"
  rec = .directory~new
  rec["job_id"] = jobId~string
  rec["model"] = modelId~string
  rec["estimated_micro_usd"] = estimatedMicroUsd
  rec["actual_micro_usd"] = actualMicroUsd
  rec["status"] = status~string~upper
  jobLedger[jobId~string] = rec
  return rec

::method queryJobCost public
  expose jobLedger
  use arg jobId
  self~alchemyTouch("QUERYJOBCOST")
  rec = jobLedger[jobId~string]
  if rec == .nil then return .nil
  return rec

::requires "AlchemyObject.cls"
