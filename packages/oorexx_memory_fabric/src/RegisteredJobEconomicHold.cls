/* RegisteredJobEconomicHold.cls
 * Deterministic economic hold policy for Registered Job.
 *
 * This is intentionally not an LLM loop and not a second queue authority.
 * It evaluates already-observed offers / optional ML forecast evidence and
 * returns a scheduling recommendation for the Registered Job authority.
 */

::class RegisteredJobEconomicBuild public
::constant VERSION "0.1-dev3"
::constant API "registered.job.economic/0.1"

::class RegisteredJobEconomicDecision public
::constant RUN_EXISTING "RUN_EXISTING"
::constant RUN_COMMISSIONED "RUN_COMMISSIONED"
::constant ECONOMIC_HOLD "ECONOMIC_HOLD"
::constant DEADLINE_RUN "DEADLINE_RUN"
::constant NO_ELIGIBLE_OPTION "NO_ELIGIBLE_OPTION"

::class RegisteredJobEconomicPolicy public

::method init
  expose targetCost maximumCost earliestStart latestStart deadline delayAllowed spotAllowed idleAllowed minimumMemoryBytes preferredMemoryBytes minimumSpeedClass
  use strict arg targetCost, maximumCost, earliestStart=0, latestStart=0, deadline=0, delayAllowed=.true, spotAllowed=.true, idleAllowed=.true, minimumMemoryBytes=0, preferredMemoryBytes=0, minimumSpeedClass=0
  numeric digits 20
  targetCost=targetCost+0
  maximumCost=maximumCost+0
  earliestStart=earliestStart+0
  latestStart=latestStart+0
  deadline=deadline+0
  delayAllowed=delayAllowed
  spotAllowed=spotAllowed
  idleAllowed=idleAllowed
  minimumMemoryBytes=minimumMemoryBytes+0
  preferredMemoryBytes=preferredMemoryBytes+0
  minimumSpeedClass=minimumSpeedClass+0
  if maximumCost<targetCost then raise syntax 88.900 array("maximumCost must be >= targetCost")

::attribute targetCost get
::attribute maximumCost get
::attribute earliestStart get
::attribute latestStart get
::attribute deadline get
::attribute delayAllowed get
::attribute spotAllowed get
::attribute idleAllowed get
::attribute minimumMemoryBytes get
::attribute preferredMemoryBytes get
::attribute minimumSpeedClass get


::class RegisteredJobCapacityOffer public

::method init
  expose offerId source incrementalCost memoryBytes speedClass spot localityCost existingCapacity validUntil
  use strict arg offerId, source, incrementalCost, memoryBytes, speedClass=0, spot=.false, localityCost=100, existingCapacity=.false, validUntil=0
  numeric digits 20
  offerId=offerId~string~strip
  source=source~string~strip
  incrementalCost=incrementalCost+0
  memoryBytes=memoryBytes+0
  speedClass=speedClass+0
  spot=spot
  localityCost=localityCost+0
  existingCapacity=existingCapacity
  validUntil=validUntil+0

::attribute offerId get
::attribute source get
::attribute incrementalCost get
::attribute memoryBytes get
::attribute speedClass get
::attribute spot get
::attribute localityCost get
::attribute existingCapacity get
::attribute validUntil get


::class RegisteredJobPriceForecast public

::method init
  expose targetCost predictedAt confidence modelId observedAt
  use strict arg targetCost, predictedAt, confidence, modelId="", observedAt=0
  numeric digits 20
  targetCost=targetCost+0
  predictedAt=predictedAt+0
  confidence=confidence+0
  modelId=modelId~string
  observedAt=observedAt+0

::attribute targetCost get
::attribute predictedAt get
::attribute confidence get
::attribute modelId get
::attribute observedAt get


::class RegisteredJobEconomicResult public

::method init
  expose decision offer reason
  use strict arg decision, offer=.nil, reason=""
  numeric digits 20
  decision=decision~string
  offer=offer
  reason=reason~string

::attribute decision get
::attribute offer get
::attribute reason get


::class RegisteredJobEconomicEvaluator public

::method evaluate
  use strict arg policy, now, offers, forecast=.nil, minimumForecastConfidence=0.70
  numeric digits 20
  now=now+0

  eligible=.array~new
  do offer over offers
    if self~eligible(policy,now,offer) then eligible~append(offer)
  end

  /* Existing idle capacity wins when permitted: it avoids commissioning and
   * can run with less headroom / lower speed so long as hard minima are met. */
  if policy~idleAllowed then do
    bestExisting=self~bestExisting(eligible)
    if bestExisting<>.nil then
      return .RegisteredJobEconomicResult~new(.RegisteredJobEconomicDecision~RUN_EXISTING,bestExisting,"eligible existing idle capacity")
  end

  best=self~bestCost(eligible)

  if best<>.nil then do
    if best~incrementalCost<=policy~targetCost then
      return .RegisteredJobEconomicResult~new(.RegisteredJobEconomicDecision~RUN_COMMISSIONED,best,"target cost satisfied")

    if policy~latestStart>0 & now>=policy~latestStart then
      return .RegisteredJobEconomicResult~new(.RegisteredJobEconomicDecision~DEADLINE_RUN,best,"latest start reached")

    if policy~delayAllowed & forecast<>.nil then do
      if forecast~confidence>=minimumForecastConfidence then do
        if forecast~targetCost<=policy~targetCost then do
          if policy~latestStart=0 | forecast~predictedAt<=policy~latestStart then
            return .RegisteredJobEconomicResult~new(.RegisteredJobEconomicDecision~ECONOMIC_HOLD,.nil,"forecast indicates target before latest start")
        end
      end
    end

    if \policy~delayAllowed then
      return .RegisteredJobEconomicResult~new(.RegisteredJobEconomicDecision~RUN_COMMISSIONED,best,"delay not permitted")

    return .RegisteredJobEconomicResult~new(.RegisteredJobEconomicDecision~ECONOMIC_HOLD,.nil,"waiting for target or better eligible capacity")
  end

  return .RegisteredJobEconomicResult~new(.RegisteredJobEconomicDecision~NO_ELIGIBLE_OPTION,.nil,"no offer satisfies hard constraints")

::method eligible private
  use strict arg policy, now, offer
  numeric digits 20
  if offer~validUntil>0 & now>offer~validUntil then return .false
  if offer~memoryBytes<policy~minimumMemoryBytes then return .false
  if offer~speedClass<policy~minimumSpeedClass then return .false
  if offer~spot & \policy~spotAllowed then return .false
  if offer~incrementalCost>policy~maximumCost then return .false
  return .true

::method bestExisting private
  use strict arg offers
  numeric digits 20
  best=.nil
  do offer over offers
    if offer~existingCapacity then do
      if best=.nil then best=offer
      else if offer~incrementalCost<best~incrementalCost then best=offer
      else if offer~incrementalCost=best~incrementalCost & offer~localityCost<best~localityCost then best=offer
    end
  end
  return best

::method bestCost private
  use strict arg offers
  numeric digits 20
  best=.nil
  do offer over offers
    if \offer~existingCapacity then do
      if best=.nil then best=offer
      else if offer~incrementalCost<best~incrementalCost then best=offer
      else if offer~incrementalCost=best~incrementalCost & offer~localityCost<best~localityCost then best=offer
    end
  end
  return best
