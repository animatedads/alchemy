/*
 * Reputation Feed v0.12 governed decision evidence.
 *
 * This object records bounded, replayable facts about a Feed policy execution.
 * It deliberately excludes raw claim/customer content.  It is evidence about
 * why the Feed admitted/withheld/contested evidence, not a reputational
 * disposition and not a logging framework.
 */

::class ReputationFeedDecisionTrace subclass ReputationFeedAlchemyObject public
::constant PERSISTENT_TYPE "reputation.feed.decision-trace/1"
::attribute traceId get
::attribute operation get
::attribute actionTime get
::attribute inputIdentity get
::attribute decisionCode get
::attribute outcomeStatus get
::attribute evaluationMode get
::attribute policyId get
::attribute policyVersion get
::attribute policyIdentity get
::attribute policySetIdentity get
::attribute assuranceMode get
::attribute deploymentIdentity get
::attribute deploymentPointIdentity get
::attribute deploymentMode get
::attribute deploymentSource get
::attribute deploymentBindingIdentity get
::attribute deploymentBindingId get
::attribute progressiveRolloutIdentity get
::attribute progressiveRolloutId get
::attribute claimCount get
::attribute eligibleClaimCount get
::attribute discoveryOnlyClaimCount get
::attribute independentFamilyCount get
::attribute eligibleIndependentFamilyCount get
::attribute requiredIndependentFamilies get
::attribute weightedConfidence get
::attribute requiredWeightedConfidence get
::attribute thresholdSatisfied get
::attribute contested get
::attribute sealed get

::method init
  expose traceId operation actionTime inputIdentity decisionCode outcomeStatus evaluationMode policyId policyVersion policyIdentity policySetIdentity assuranceMode deploymentIdentity deploymentPointIdentity deploymentMode deploymentSource deploymentBindingIdentity deploymentBindingId progressiveRolloutIdentity progressiveRolloutId claimCount eligibleClaimCount discoveryOnlyClaimCount independentFamilyCount eligibleIndependentFamilyCount requiredIndependentFamilies weightedConfidence requiredWeightedConfidence thresholdSatisfied contested reasonSummary sealed
  use arg traceIdArg = "", governedOutcomeArg = .nil, inputIdentityArg = "", decisionCodeArg = "", alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationFeedDecisionTrace", alchemyContextArg)
  traceId = traceIdArg~string~upper~strip
  operation = ""
  actionTime = ""
  inputIdentity = inputIdentityArg~string
  decisionCode = decisionCodeArg~string~upper~strip
  outcomeStatus = "UNKNOWN"
  evaluationMode = ""
  policyId = ""
  policyVersion = ""
  policyIdentity = ""
  policySetIdentity = ""
  assuranceMode = ""
  deploymentIdentity = ""
  deploymentPointIdentity = ""
  deploymentMode = ""
  deploymentSource = ""
  deploymentBindingIdentity = ""
  deploymentBindingId = ""
  progressiveRolloutIdentity = ""
  progressiveRolloutId = ""
  claimCount = 0
  eligibleClaimCount = 0
  discoveryOnlyClaimCount = 0
  independentFamilyCount = 0
  eligibleIndependentFamilyCount = 0
  requiredIndependentFamilies = 0
  weightedConfidence = 0
  requiredWeightedConfidence = 0
  thresholdSatisfied = .false
  contested = .false
  reasonSummary = .array~new
  sealed = .false
  if governedOutcomeArg <> .nil then self~populateFromOutcome(governedOutcomeArg)
  self~registerStateVariable("traceId", "PUBLIC", "Decision trace identity")
  self~registerStateVariable("operation", "PUBLIC", "Governed Feed operation")
  self~registerStateVariable("inputIdentity", "INTERNAL", "Bounded identity of evaluated input, never raw content")
  self~registerStateVariable("decisionCode", "PUBLIC", "Deterministic decision/audit reason code")
  self~registerStateVariable("outcomeStatus", "PUBLIC", "Domain outcome status")
  self~registerStateVariable("policyIdentity", "PUBLIC", "Exact institutional policy identity")
  self~registerStateVariable("policySetIdentity", "PUBLIC", "Exact domain policy-set identity")
  self~registerStateVariable("deploymentBindingId", "PUBLIC", "Exact deployment binding used")
  self~registerStateVariable("progressiveRolloutId", "PUBLIC", "Progressive rollout identifier when applicable")
  self~registerStateVariable("claimCount", "INTERNAL", "Bounded evidence count only")
  self~registerStateVariable("eligibleClaimCount", "INTERNAL", "Evidence items eligible for corroboration")
  self~registerStateVariable("discoveryOnlyClaimCount", "INTERNAL", "Evidence retained but excluded from corroboration")
  self~registerStateVariable("weightedConfidence", "INTERNAL", "Family-normalised confidence used by policy")
  self~registerStateVariable("sealed", "PUBLIC", "Decision trace sealing state")
  self~registerMethodContract("REASONSUMMARY", "Return bounded reason-code counts without source/customer content", .array~new, "ARRAY", .false, "AUTO", "INTERNAL", "NORMAL", "READ", "NONE")

::method populateFromOutcome private
  expose operation actionTime decisionCode outcomeStatus evaluationMode policyId policyVersion policyIdentity policySetIdentity assuranceMode deploymentIdentity deploymentPointIdentity deploymentMode deploymentSource deploymentBindingIdentity deploymentBindingId progressiveRolloutIdentity progressiveRolloutId claimCount eligibleClaimCount discoveryOnlyClaimCount independentFamilyCount eligibleIndependentFamilyCount requiredIndependentFamilies weightedConfidence requiredWeightedConfidence thresholdSatisfied contested reasonSummary
  use arg outcome
  if \outcome~hasMethod("OPERATION") | \outcome~hasMethod("DOMAINRESULT") then raise syntax 88.900 array("Decision trace requires ReputationFeedGovernedOutcome")
  operation = outcome~operation
  actionTime = outcome~actionTime~string
  evaluationMode = outcome~evaluationMode
  policyId = outcome~policyId
  policyVersion = outcome~policyVersion
  policyIdentity = outcome~policyIdentity
  policySetIdentity = outcome~policySetIdentity
  assuranceMode = outcome~assuranceMode
  deploymentIdentity = outcome~deploymentIdentity
  deploymentPointIdentity = outcome~deploymentPointIdentity
  deploymentMode = outcome~deploymentMode
  deploymentSource = outcome~deploymentSource
  deploymentBindingIdentity = outcome~deploymentBindingIdentity
  deploymentBindingId = outcome~deploymentBindingId
  progressiveRolloutIdentity = outcome~progressiveRolloutIdentity
  progressiveRolloutId = outcome~progressiveRolloutId
  domain = outcome~domainResult
  if domain <> .nil then do
    if domain~hasMethod("STATUS") then outcomeStatus = domain~status~string~upper
    else if domain~hasMethod("BAND") then outcomeStatus = domain~band~string~upper
    else outcomeStatus = domain~class~id
    if domain~hasMethod("CLAIMCOUNT") then claimCount = domain~claimCount
    if domain~hasMethod("ELIGIBLECLAIMCOUNT") then eligibleClaimCount = domain~eligibleClaimCount
    if domain~hasMethod("DISCOVERYONLYCLAIMCOUNT") then discoveryOnlyClaimCount = domain~discoveryOnlyClaimCount
    if domain~hasMethod("INDEPENDENTFAMILYCOUNT") then independentFamilyCount = domain~independentFamilyCount
    if domain~hasMethod("ELIGIBLEINDEPENDENTFAMILYCOUNT") then eligibleIndependentFamilyCount = domain~eligibleIndependentFamilyCount
    if domain~hasMethod("REQUIREDINDEPENDENTFAMILIES") then requiredIndependentFamilies = domain~requiredIndependentFamilies
    if domain~hasMethod("WEIGHTEDCONFIDENCE") then weightedConfidence = domain~weightedConfidence
    if domain~hasMethod("REQUIREDWEIGHTEDCONFIDENCE") then requiredWeightedConfidence = domain~requiredWeightedConfidence
    if domain~hasMethod("THRESHOLDSATISFIED") then thresholdSatisfied = domain~thresholdSatisfied
    if domain~hasMethod("CONTESTED") then contested = domain~contested
    if domain~hasMethod("EVIDENCESTATUSES") then reasonSummary = self~summarizeReasons(domain~evidenceStatuses)
  end
  if decisionCode = "" then do
    if operation = "" then decisionCode = outcomeStatus
    else decisionCode = operation || "_" || outcomeStatus
  end
  return self

::method summarizeReasons private
  use arg statuses
  counts = .table~new
  if statuses <> .nil then do item over statuses
    reason = item~reasonCode~string~upper~strip
    if reason = "" then reason = "UNSPECIFIED"
    if \counts~hasIndex(reason) then counts[reason] = 0
    counts[reason] = counts[reason] + 1
  end
  keys = counts~allIndexes
  keys~sort
  resultItems = .array~new
  do reason over keys; resultItems~append(reason || "=" || counts[reason]); end
  return resultItems

::method reasonSummary
  expose reasonSummary
  return .ReputationFeedCanonical~copyArray(reasonSummary)

::method seal
  expose sealed traceId
  if traceId = "" then raise syntax 88.900 array("Decision trace requires traceId before seal")
  sealed = .true
  self~alchemyTouch("DECISION_TRACE_SEALED")
  return self

::method canonicalText
  expose traceId operation actionTime inputIdentity decisionCode outcomeStatus evaluationMode policyId policyVersion policyIdentity policySetIdentity assuranceMode deploymentIdentity deploymentPointIdentity deploymentMode deploymentSource deploymentBindingIdentity deploymentBindingId progressiveRolloutIdentity progressiveRolloutId claimCount eligibleClaimCount discoveryOnlyClaimCount independentFamilyCount eligibleIndependentFamilyCount requiredIndependentFamilies weightedConfidence requiredWeightedConfidence thresholdSatisfied contested reasonSummary sealed
  text = "REPUTATION-FEED-DECISION-TRACE/1" || '0a'x
  text ||= .ReputationFeedCanonical~field("TRACE_ID", traceId)
  text ||= .ReputationFeedCanonical~field("OPERATION", operation)
  text ||= .ReputationFeedCanonical~field("ACTION_TIME", actionTime)
  text ||= .ReputationFeedCanonical~field("INPUT_IDENTITY", inputIdentity)
  text ||= .ReputationFeedCanonical~field("DECISION_CODE", decisionCode)
  text ||= .ReputationFeedCanonical~field("OUTCOME_STATUS", outcomeStatus)
  text ||= .ReputationFeedCanonical~field("EVALUATION_MODE", evaluationMode)
  text ||= .ReputationFeedCanonical~field("POLICY", policyId || "@" || policyVersion)
  text ||= .ReputationFeedCanonical~field("POLICY_IDENTITY", policyIdentity)
  text ||= .ReputationFeedCanonical~field("POLICY_SET_IDENTITY", policySetIdentity)
  text ||= .ReputationFeedCanonical~field("ASSURANCE", assuranceMode)
  text ||= .ReputationFeedCanonical~field("DEPLOYMENT_IDENTITY", deploymentIdentity)
  text ||= .ReputationFeedCanonical~field("DEPLOYMENT_POINT", deploymentPointIdentity)
  text ||= .ReputationFeedCanonical~field("DEPLOYMENT_MODE", deploymentMode)
  text ||= .ReputationFeedCanonical~field("DEPLOYMENT_SOURCE", deploymentSource)
  text ||= .ReputationFeedCanonical~field("DEPLOYMENT_BINDING_IDENTITY", deploymentBindingIdentity)
  text ||= .ReputationFeedCanonical~field("DEPLOYMENT_BINDING_ID", deploymentBindingId)
  text ||= .ReputationFeedCanonical~field("ROLLOUT_IDENTITY", progressiveRolloutIdentity)
  text ||= .ReputationFeedCanonical~field("ROLLOUT_ID", progressiveRolloutId)
  text ||= .ReputationFeedCanonical~field("CLAIM_COUNT", claimCount)
  text ||= .ReputationFeedCanonical~field("ELIGIBLE_CLAIMS", eligibleClaimCount)
  text ||= .ReputationFeedCanonical~field("DISCOVERY_ONLY_CLAIMS", discoveryOnlyClaimCount)
  text ||= .ReputationFeedCanonical~field("INDEPENDENT_FAMILIES", independentFamilyCount)
  text ||= .ReputationFeedCanonical~field("ELIGIBLE_FAMILIES", eligibleIndependentFamilyCount)
  text ||= .ReputationFeedCanonical~field("REQUIRED_FAMILIES", requiredIndependentFamilies)
  text ||= .ReputationFeedCanonical~field("WEIGHTED_CONFIDENCE", weightedConfidence)
  text ||= .ReputationFeedCanonical~field("REQUIRED_CONFIDENCE", requiredWeightedConfidence)
  text ||= .ReputationFeedCanonical~field("THRESHOLD_SATISFIED", thresholdSatisfied)
  text ||= .ReputationFeedCanonical~field("CONTESTED", contested)
  text ||= .ReputationFeedCanonical~join("REASON", reasonSummary)
  text ||= .ReputationFeedCanonical~field("SEALED", sealed)
  return text

::method queuePersistentType
  return self~PERSISTENT_TYPE

::method queuePersistentState
  expose traceId operation actionTime inputIdentity decisionCode outcomeStatus evaluationMode policyId policyVersion policyIdentity policySetIdentity assuranceMode deploymentIdentity deploymentPointIdentity deploymentMode deploymentSource deploymentBindingIdentity deploymentBindingId progressiveRolloutIdentity progressiveRolloutId claimCount eligibleClaimCount discoveryOnlyClaimCount independentFamilyCount eligibleIndependentFamilyCount requiredIndependentFamilies weightedConfidence requiredWeightedConfidence thresholdSatisfied contested reasonSummary sealed
  state = .table~new
  state["trace_id"] = traceId
  state["operation"] = operation
  state["action_time"] = actionTime
  state["input_identity"] = inputIdentity
  state["decision_code"] = decisionCode
  state["outcome_status"] = outcomeStatus
  state["evaluation_mode"] = evaluationMode
  state["policy_id"] = policyId
  state["policy_version"] = policyVersion
  state["policy_identity"] = policyIdentity
  state["policy_set_identity"] = policySetIdentity
  state["assurance_mode"] = assuranceMode
  state["deployment_identity"] = deploymentIdentity
  state["deployment_point_identity"] = deploymentPointIdentity
  state["deployment_mode"] = deploymentMode
  state["deployment_source"] = deploymentSource
  state["deployment_binding_identity"] = deploymentBindingIdentity
  state["deployment_binding_id"] = deploymentBindingId
  state["progressive_rollout_identity"] = progressiveRolloutIdentity
  state["progressive_rollout_id"] = progressiveRolloutId
  state["claim_count"] = claimCount~string
  state["eligible_claim_count"] = eligibleClaimCount~string
  state["discovery_only_claim_count"] = discoveryOnlyClaimCount~string
  state["independent_family_count"] = independentFamilyCount~string
  state["eligible_independent_family_count"] = eligibleIndependentFamilyCount~string
  state["required_independent_families"] = requiredIndependentFamilies~string
  state["weighted_confidence"] = weightedConfidence~string
  state["required_weighted_confidence"] = requiredWeightedConfidence~string
  state["threshold_satisfied"] = thresholdSatisfied~string
  state["contested"] = contested~string
  state["reason_summary"] = .ReputationFeedCanonical~copyArray(reasonSummary)
  state["sealed"] = sealed~string
  return state

::method queueRestoreState
  expose traceId operation actionTime inputIdentity decisionCode outcomeStatus evaluationMode policyId policyVersion policyIdentity policySetIdentity assuranceMode deploymentIdentity deploymentPointIdentity deploymentMode deploymentSource deploymentBindingIdentity deploymentBindingId progressiveRolloutIdentity progressiveRolloutId claimCount eligibleClaimCount discoveryOnlyClaimCount independentFamilyCount eligibleIndependentFamilyCount requiredIndependentFamilies weightedConfidence requiredWeightedConfidence thresholdSatisfied contested reasonSummary sealed
  use arg state
  traceId = state["trace_id"]~string
  operation = state["operation"]~string
  actionTime = state["action_time"]~string
  inputIdentity = state["input_identity"]~string
  decisionCode = state["decision_code"]~string
  outcomeStatus = state["outcome_status"]~string
  evaluationMode = state["evaluation_mode"]~string
  policyId = state["policy_id"]~string
  policyVersion = state["policy_version"]~string
  policyIdentity = state["policy_identity"]~string
  policySetIdentity = state["policy_set_identity"]~string
  assuranceMode = state["assurance_mode"]~string
  deploymentIdentity = state["deployment_identity"]~string
  deploymentPointIdentity = state["deployment_point_identity"]~string
  deploymentMode = state["deployment_mode"]~string
  deploymentSource = state["deployment_source"]~string
  deploymentBindingIdentity = state["deployment_binding_identity"]~string
  deploymentBindingId = state["deployment_binding_id"]~string
  progressiveRolloutIdentity = state["progressive_rollout_identity"]~string
  progressiveRolloutId = state["progressive_rollout_id"]~string
  claimCount = state["claim_count"] + 0
  eligibleClaimCount = state["eligible_claim_count"] + 0
  discoveryOnlyClaimCount = state["discovery_only_claim_count"] + 0
  independentFamilyCount = state["independent_family_count"] + 0
  eligibleIndependentFamilyCount = state["eligible_independent_family_count"] + 0
  requiredIndependentFamilies = state["required_independent_families"] + 0
  weightedConfidence = state["weighted_confidence"] + 0
  requiredWeightedConfidence = state["required_weighted_confidence"] + 0
  thresholdSatisfied = self~restoreTruth(state["threshold_satisfied"])
  contested = self~restoreTruth(state["contested"])
  if state~hasIndex("reason_summary") then reasonSummary = .ReputationFeedCanonical~copyArray(state["reason_summary"]); else reasonSummary = .array~new
  sealed = self~restoreTruth(state["sealed"])
  return self

::method restoreTruth private
  use arg value
  if value == .true then return .true
  if value == .false | value == .nil then return .false
  text = value~string~upper
  return text = "1" | text = "TRUE" | text = "YES" | text = "ON"


::requires "ReputationFeed.cls"
