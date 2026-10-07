/* RegisteredJobExecutionContext.cls
 * ooRexx Memory Fabric v0.1-dev3
 *
 * The job is placed INTO an execution context formed around memory and storage
 * topology.  This is intentionally advisory to Job-to-Node: hard execution
 * eligibility and authoritative leases remain outside this planner.
 */

::class RegisteredJobContextBuild public
::constant VERSION "0.1-dev3"
::constant API "registered.job.execution-context/0.1"

::class RegisteredJobPlacementAction public
::constant RUN_EXISTING "RUN_EXISTING"
::constant COMMISSION "COMMISSION"
::constant ECONOMIC_HOLD "ECONOMIC_HOLD"
::constant NO_CONTEXT "NO_CONTEXT"

::class RegisteredJobExecutionProfile public

::method init
  expose profileId minimumMemoryBytes preferredMemoryBytes maximumMemoryProviders maximumMemoryLocality minimumSpeedClass workspaceBytes durableOutputRequired
  use strict arg profileId, minimumMemoryBytes, preferredMemoryBytes, maximumMemoryProviders=8, maximumMemoryLocality=100, minimumSpeedClass=0, workspaceBytes=0, durableOutputRequired=.false
  numeric digits 20
  profileId=profileId~string~strip
  minimumMemoryBytes=minimumMemoryBytes+0
  preferredMemoryBytes=preferredMemoryBytes+0
  maximumMemoryProviders=maximumMemoryProviders+0
  maximumMemoryLocality=maximumMemoryLocality+0
  minimumSpeedClass=minimumSpeedClass+0
  workspaceBytes=workspaceBytes+0
  durableOutputRequired=durableOutputRequired
  if profileId="" then raise syntax 88.900 array("profileId must not be empty")
  if minimumMemoryBytes<0 | preferredMemoryBytes<minimumMemoryBytes then raise syntax 88.900 array("invalid memory profile")
  if maximumMemoryProviders<1 then raise syntax 88.900 array("maximumMemoryProviders must be positive")

::attribute profileId get
::attribute minimumMemoryBytes get
::attribute preferredMemoryBytes get
::attribute maximumMemoryProviders get
::attribute maximumMemoryLocality get
::attribute minimumSpeedClass get
::attribute workspaceBytes get
::attribute durableOutputRequired get


::class RegisteredJobStorageEvidence public

::method init
  expose nodeId workspaceFits localInputBytes materialiseBytes durableOutputAdmissible movementCost evidenceRef
  use strict arg nodeId, workspaceFits=.true, localInputBytes=0, materialiseBytes=0, durableOutputAdmissible=.true, movementCost=0, evidenceRef=""
  numeric digits 20
  nodeId=nodeId~string~strip
  workspaceFits=workspaceFits
  localInputBytes=localInputBytes+0
  materialiseBytes=materialiseBytes+0
  durableOutputAdmissible=durableOutputAdmissible
  movementCost=movementCost+0
  evidenceRef=evidenceRef~string

::attribute nodeId get
::attribute workspaceFits get
::attribute localInputBytes get
::attribute materialiseBytes get
::attribute durableOutputAdmissible get
::attribute movementCost get
::attribute evidenceRef get


::class RegisteredJobNodeCandidate public

::method init
  expose nodeId muId miId machineId siteId hardEligible idle speedClass incrementalCost commissioningOfferId storageEvidence
  use strict arg nodeId, muId, miId="", machineId="", siteId="", hardEligible=.true, idle=.false, speedClass=0, incrementalCost=0, commissioningOfferId="", storageEvidence=.nil
  numeric digits 20
  nodeId=nodeId~string~strip
  muId=muId~string~strip
  miId=miId~string~strip
  machineId=machineId~string~strip
  siteId=siteId~string~strip
  hardEligible=hardEligible
  idle=idle
  speedClass=speedClass+0
  incrementalCost=incrementalCost+0
  commissioningOfferId=commissioningOfferId~string~strip
  storageEvidence=storageEvidence
  if nodeId="" | muId="" then raise syntax 88.900 array("nodeId/muId are mandatory")

::attribute nodeId get
::attribute muId get
::attribute miId get
::attribute machineId get
::attribute siteId get
::attribute hardEligible get
::attribute idle get
::attribute speedClass get
::attribute incrementalCost get
::attribute commissioningOfferId get
::attribute storageEvidence get

::method isCommissionedCandidate
  expose commissioningOfferId
  return commissioningOfferId<>""


::class RegisteredJobExecutionContextPlan public

::method init
  expose action candidate profile memoryPlan reason score
  use strict arg action, candidate=.nil, profile=.nil, memoryPlan=.nil, reason="", score=0
  numeric digits 20
  action=action~string
  candidate=candidate
  profile=profile
  memoryPlan=memoryPlan
  reason=reason~string
  score=score+0

::attribute action get
::attribute candidate get
::attribute profile get
::attribute memoryPlan get
::attribute reason get
::attribute score get


::class RegisteredJobExecutionContextPlanner public

::method init
  expose memoryPlanner economicEvaluator
  use strict arg memoryPlanner, economicEvaluator=.nil
  numeric digits 20
  if economicEvaluator=.nil then economicEvaluator=.RegisteredJobEconomicEvaluator~new

/* candidates are already projected from Job-to-Node / commissioning.
 * hardEligible=false is absolute: this class never softens it.
 *
 * profiles are ordered by caller preference.  A slower / lower-headroom profile
 * can therefore be used on idle existing capacity before commissioning.
 */
::method choose
  expose memoryPlanner economicEvaluator
  use strict arg profiles, candidates, economicPolicy=.nil, now=0, forecast=.nil
  numeric digits 20

  bestExisting=.nil
  bestCommission=.nil

  do profile over profiles
    do candidate over candidates
      if candidate~hardEligible then do
        if candidate~speedClass>=profile~minimumSpeedClass then do
          se=candidate~storageEvidence
          storageOK=.true
          movement=0
          if se<>.nil then do
            if \se~workspaceFits & profile~workspaceBytes>0 then storageOK=.false
            if profile~durableOutputRequired & \se~durableOutputAdmissible then storageOK=.false
            movement=se~movementCost
          end

          if storageOK then do
            mp=memoryPlanner~plan(candidate~muId,candidate~machineId,candidate~siteId,profile~minimumMemoryBytes,.false,profile~maximumMemoryProviders,profile~maximumMemoryLocality)

            if mp~complete then do
              /* Lower is better.  Locality and storage movement are penalties.
               * Incremental cost is deliberately not converted to fake latency;
               * economic policy gets its own decision phase below. */
              score=mp~worstLocality+movement
              ctx=.RegisteredJobExecutionContextPlan~new("",candidate,profile,mp,"",score)

              if candidate~idle & \candidate~isCommissionedCandidate then do
                if bestExisting=.nil then bestExisting=ctx
                else if score<bestExisting~score then bestExisting=ctx
              end
              else if candidate~isCommissionedCandidate then do
                if bestCommission=.nil then bestCommission=ctx
                else if candidate~incrementalCost<bestCommission~candidate~incrementalCost then bestCommission=ctx
                else if candidate~incrementalCost=bestCommission~candidate~incrementalCost then
                  if score<bestCommission~score then bestCommission=ctx
              end
            end
          end
        end
      end
    end
    /* Caller profile order is semantic preference.  Once an existing idle
     * context satisfies this profile, do not descend to more degraded profiles. */
    if bestExisting<>.nil then leave
  end

  if bestExisting<>.nil then
    return .RegisteredJobExecutionContextPlan~new(.RegisteredJobPlacementAction~RUN_EXISTING,bestExisting~candidate,bestExisting~profile,bestExisting~memoryPlan,"existing idle execution context satisfies a declared profile",bestExisting~score)

  if bestCommission<>.nil then do
    if economicPolicy=.nil then
      return .RegisteredJobExecutionContextPlan~new(.RegisteredJobPlacementAction~COMMISSION,bestCommission~candidate,bestCommission~profile,bestCommission~memoryPlan,"commissioning context required",bestCommission~score)

    offers=.array~new
    /* Economic evaluator sees only the chosen commissioning topology here.
     * A higher layer may pass multiple cloud offers as candidates and call this
     * planner after its own deterministic offer normalization. */
    c=bestCommission~candidate
    offers~append(.RegisteredJobCapacityOffer~new(c~commissioningOfferId,"execution-context",c~incrementalCost,bestCommission~memoryPlan~totalBytes,c~speedClass,.false,bestCommission~memoryPlan~worstLocality,.false,0))
    er=economicEvaluator~evaluate(economicPolicy,now,offers,forecast)
    if er~decision=.RegisteredJobEconomicDecision~ECONOMIC_HOLD then
      return .RegisteredJobExecutionContextPlan~new(.RegisteredJobPlacementAction~ECONOMIC_HOLD,.nil,bestCommission~profile,.nil,er~reason,0)
    if er~decision=.RegisteredJobEconomicDecision~NO_ELIGIBLE_OPTION then
      return .RegisteredJobExecutionContextPlan~new(.RegisteredJobPlacementAction~NO_CONTEXT,.nil,bestCommission~profile,.nil,er~reason,0)

    return .RegisteredJobExecutionContextPlan~new(.RegisteredJobPlacementAction~COMMISSION,bestCommission~candidate,bestCommission~profile,bestCommission~memoryPlan,er~reason,bestCommission~score)
  end

  return .RegisteredJobExecutionContextPlan~new(.RegisteredJobPlacementAction~NO_CONTEXT,.nil,.nil,.nil,"no hard-eligible node has an acceptable memory/storage execution context",0)

::requires "MemoryFabric.cls"
::requires "RegisteredJobEconomicHold.cls"
