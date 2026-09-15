/*
 * WLURouteDecisionPolicy v0.1
 *
 * Deterministic institutional-policy gate for use of WLU route-advisory
 * evidence by an external scheduler.  This layer is deliberately
 * non-entitling: it can permit or reject a proposed route decision, but it
 * cannot reserve WLU, mutate a logical job, acquire hierarchy capacity,
 * reserve throughput, promote standby work, or invoke a provider.
 *
 * Publication/effective-time/supersession/replay mechanics are delegated to
 * institutional_policy_v0.1 rather than reimplemented here.
 */

::options digits 30

::class WLURouteDecisionPolicyBuild public
::constant VERSION "0.1"
::constant API_VERSION "work.load.units.route-decision-policy/0.1"

::class WLURouteDecisionActor public
::constant AUTOMATED "AUTOMATED"
::constant OPERATOR "OPERATOR"

::class WLURouteDecisionRule public
::constant DENY "DENY"
::constant RECOMMENDED_ONLY "RECOMMENDED_ONLY"
::constant EVIDENCE_ELIGIBLE "EVIDENCE_ELIGIBLE"
::constant DECLARED_CANDIDATE "DECLARED_CANDIDATE"

::class WLURouteDecisionStatus public
::constant PERMITTED "PERMITTED"
::constant REJECTED "REJECTED"

/* Domain-owned fixed rule payload.  InstitutionalPolicyRelease owns policy
 * id/version/authorship/approval/effective time and supersession. */
::class WLURouteDecisionRules public
::attribute automatedRule get
::attribute operatorRule get
::attribute sealed get

::method init
  expose automatedRule operatorRule sealed
  use strict arg automatedRule = "RECOMMENDED_ONLY", operatorRule = "EVIDENCE_ELIGIBLE"
  automatedRule = self~normalizeRule(automatedRule)
  operatorRule = self~normalizeRule(operatorRule)
  sealed = .false

::method seal
  expose sealed
  sealed = .true
  return self

::method publicationEligible
  expose sealed
  return sealed

::method ruleForActor
  expose automatedRule operatorRule
  use strict arg actorMode
  actorMode = actorMode~string~strip~translate
  if actorMode = .WLURouteDecisionActor~AUTOMATED then return automatedRule
  if actorMode = .WLURouteDecisionActor~OPERATOR then return operatorRule
  raise syntax 88.900 array("unknown WLU route-decision actor mode: " || actorMode)

::method canonicalText
  expose automatedRule operatorRule sealed
  if \sealed then raise syntax 88.900 array("WLU route decision rules must be sealed before canonical identity")
  text = "WLU-ROUTE-DECISION-RULES/1" || '0a'x
  text ||= "AUTOMATED_RULE=" || automatedRule || '0a'x
  text ||= "OPERATOR_RULE=" || operatorRule || '0a'x
  return text

::method semanticIdentity
  return self~canonicalText

::method normalizeRule private
  use strict arg value
  value = value~string~strip~translate
  if value = .WLURouteDecisionRule~DENY then return value
  if value = .WLURouteDecisionRule~RECOMMENDED_ONLY then return value
  if value = .WLURouteDecisionRule~EVIDENCE_ELIGIBLE then return value
  if value = .WLURouteDecisionRule~DECLARED_CANDIDATE then return value
  raise syntax 88.900 array("unknown WLU route-decision rule: " || value)

/* Authenticated decision evidence.  The rich policy release/execution context
 * and publication record are retained separately from the canonical scalar
 * trace so callers can inspect the exact operative institutional artefact. */
::class WLURouteDecisionEvidence public
::attribute allowed get
::attribute status get
::attribute reasonCode get
::attribute actorMode get
::attribute proposedStageId get
::attribute candidateEligible get
::attribute candidateStatus get
::attribute recommendedStageId get
::attribute advisoryStatus get
::attribute advisorySourceSequence get
::attribute advisorySourceTag get
::attribute advisoryProofKeyId get
::attribute advisoryProofTag get
::attribute policyId get
::attribute policyVersion get
::attribute policyIdentity get
::attribute policyRule get
::attribute actionTime get
::attribute evaluationMode get
::attribute policyRelease get
::attribute publicationRecord get
::attribute executionContext get
::attribute proof get

::method init
  expose allowed status reasonCode actorMode proposedStageId candidateEligible candidateStatus recommendedStageId advisoryStatus advisorySourceSequence advisorySourceTag advisoryProofKeyId advisoryProofTag policyId policyVersion policyIdentity policyRule actionTime evaluationMode policyRelease publicationRecord executionContext proof
  use strict arg allowed, status, reasonCode, actorMode, proposedStageId, candidateEligible, candidateStatus, recommendedStageId, advisoryStatus, advisorySourceSequence, advisorySourceTag, advisoryProofKeyId, advisoryProofTag, policyId, policyVersion, policyIdentity, policyRule, actionTime, evaluationMode, policyRelease, publicationRecord = .nil, executionContext = .nil, proof = .nil

::method canonicalText
  expose allowed status reasonCode actorMode proposedStageId candidateEligible candidateStatus recommendedStageId advisoryStatus advisorySourceSequence advisorySourceTag advisoryProofKeyId advisoryProofTag policyId policyVersion policyIdentity policyRule actionTime evaluationMode publicationRecord
  text = "WLU-ROUTE-DECISION-EVIDENCE/1" || '0a'x
  text ||= self~field("ALLOWED", allowed)
  text ||= self~field("STATUS", status)
  text ||= self~field("REASON_CODE", reasonCode)
  text ||= self~field("ACTOR_MODE", actorMode)
  text ||= self~field("PROPOSED_STAGE", proposedStageId)
  text ||= self~field("CANDIDATE_ELIGIBLE", candidateEligible)
  text ||= self~field("CANDIDATE_STATUS", candidateStatus)
  text ||= self~field("RECOMMENDED_STAGE", recommendedStageId)
  text ||= self~field("ADVISORY_STATUS", advisoryStatus)
  text ||= self~field("ADVISORY_SOURCE_SEQUENCE", advisorySourceSequence)
  text ||= self~field("ADVISORY_SOURCE_TAG", advisorySourceTag)
  text ||= self~field("ADVISORY_PROOF_KEY_ID", advisoryProofKeyId)
  text ||= self~field("ADVISORY_PROOF_TAG", advisoryProofTag)
  text ||= self~field("POLICY_ID", policyId)
  text ||= self~field("POLICY_VERSION", policyVersion)
  text ||= self~field("POLICY_IDENTITY", policyIdentity)
  text ||= self~field("POLICY_RULE", policyRule)
  text ||= self~field("ACTION_TIME", actionTime)
  text ||= self~field("EVALUATION_MODE", evaluationMode)
  if publicationRecord == .nil then text ||= self~field("PUBLICATION_RECORD", "")
  else text ||= self~field("PUBLICATION_RECORD", publicationRecord~canonicalText)
  return text

::method withProof
  expose allowed status reasonCode actorMode proposedStageId candidateEligible candidateStatus recommendedStageId advisoryStatus advisorySourceSequence advisorySourceTag advisoryProofKeyId advisoryProofTag policyId policyVersion policyIdentity policyRule actionTime evaluationMode policyRelease publicationRecord executionContext
  use strict arg proofArg
  return .WLURouteDecisionEvidence~new(allowed, status, reasonCode, actorMode, proposedStageId, candidateEligible, candidateStatus, recommendedStageId, advisoryStatus, advisorySourceSequence, advisorySourceTag, advisoryProofKeyId, advisoryProofTag, policyId, policyVersion, policyIdentity, policyRule, actionTime, evaluationMode, policyRelease, publicationRecord, executionContext, proofArg)

::method verify
  expose proof
  use strict arg keyRing
  if proof == .nil then return .false
  return keyRing~verify(self~canonicalText, proof)

::method outcomeIdentity
  expose allowed proposedStageId actorMode
  return "ALLOWED=" || allowed || ";STAGE=" || proposedStageId || ";ACTOR=" || actorMode

::method traceIdentity
  return self~canonicalText

::method evidenceRef
  expose policyId policyVersion proposedStageId advisorySourceSequence advisorySourceTag evaluationMode
  return "WLU_ROUTE_DECISION:" || policyId || "@" || policyVersion || ":" || evaluationMode || ":" || proposedStageId || ":" || advisorySourceSequence || ":" || advisoryProofTag

::method field private
  use strict arg name, value
  if value == .nil then value = ""
  value = value~string
  return name || ":" || value~length || ":" || value || '0a'x

/* Long-lived institutional-policy evaluation boundary.  It consumes an
 * authenticated advisory result and a shared Institutional Policy release.
 * It returns evidence only and accepts no WLUAuthority or job-manager object. */
::class WLUJobRouteDecisionGate subclass AlchemyObject public
::attribute keyRing get

::method init
  expose keyRing
  use strict arg keyRing
  if keyRing == .nil | \keyRing~isA(.WLUFastMacKeyRing) then raise syntax 88.900 array("WLU route decision gate requires WLUFastMacKeyRing")
  alchemyConstruction = .WLUAlchemySupport~construction(keyRing, "WLUJobRouteDecisionGate", "Deterministic institutional-policy gate over authenticated WLU route advisory evidence")
  alchemyConstruction[1]["standards"] ||= "; institutional.policy/0.1; work.load.units.route-decision-policy/0.1"
  self~init:super(alchemyConstruction[1], alchemyConstruction[2], alchemyConstruction[3])
  ignore = .WLUAlchemySupport~finishConstruction(self)
  self~registerExternalRequirement("library", "institutional_policy", "v0.1", .true)
  self~registerMethodContract("DECIDE", "Resolve the operative institutional policy and evaluate one proposed scheduler route without granting WLU authority", .array~of("CATALOG", "POLICYID", "ADVISORY", "PROPOSEDSTAGEID", "ACTIONTIME", "ACTORMODE"), "WLURESULT", .false, "AUTO", "CUSTOMER", "SENSITIVE", "READ", "NONE")
  self~registerMethodContract("COUNTERFACTUAL", "Evaluate one proposed route under an explicitly selected sealed alternative policy without changing operative authority", .array~of("POLICYRELEASE", "ADVISORY", "PROPOSEDSTAGEID", "ACTIONTIME", "ACTORMODE"), "WLURESULT", .false, "AUTO", "CUSTOMER", "SENSITIVE", "READ", "NONE")
  self~registerMethodContract("COMPARE", "Compare policy-governed route decision outcome and trace identities", .array~of("FROMDECISION", "TODECISION"), "INSTITUTIONALPOLICYCOMPARISON", .false, "AUTO", "CUSTOMER", "NORMAL", "READ", "NONE")
  self~registerInstrumentationPoint("WLU.JOB.ROUTE.DECISION_POLICY", "non-entitling institutional route-decision policy boundary", .true, "ALL", "INTERNAL")

::method decide
  expose keyRing
  use strict arg catalog, policyId, advisory, proposedStageId, actionTime = .nil, actorMode = "AUTOMATED"
  guard on
  advisoryValidation = self~validateAdvisory(advisory)
  if \advisoryValidation~ok then return advisoryValidation
  if catalog == .nil | \catalog~isA(.InstitutionalPolicyCatalog) then return .WLUResult~failure("WLU_ROUTE_DECISION_CATALOG_REQUIRED", "InstitutionalPolicyCatalog required")
  if actionTime == .nil then actionTime = .DateTime~new
  resolved = catalog~resolve(policyId, actionTime)
  if \resolved~ok then return .WLUResult~failure("WLU_ROUTE_DECISION_POLICY_RESOLUTION_FAILED", resolved~code || ":" || resolved~detail)
  release = resolved~value
  guarded = .InstitutionalPolicyReplayGuard~operative(release, actionTime)
  if \guarded~ok then return .WLUResult~failure("WLU_ROUTE_DECISION_POLICY_NOT_OPERATIVE", guarded~code || ":" || guarded~detail)
  publication = catalog~publicationRecord(release~policyId, release~version)
  if \publication~ok then return .WLUResult~failure("WLU_ROUTE_DECISION_PUBLICATION_RECORD_MISSING", publication~code)
  return self~evaluate(release, guarded~value, publication~value, advisory, proposedStageId, actorMode)

::method counterfactual
  use strict arg policyRelease, advisory, proposedStageId, actionTime = .nil, actorMode = "AUTOMATED"
  guard on
  advisoryValidation = self~validateAdvisory(advisory)
  if \advisoryValidation~ok then return advisoryValidation
  if actionTime == .nil then actionTime = .DateTime~new
  guarded = .InstitutionalPolicyReplayGuard~counterfactual(policyRelease, actionTime)
  if \guarded~ok then return .WLUResult~failure("WLU_ROUTE_DECISION_COUNTERFACTUAL_POLICY_INVALID", guarded~code || ":" || guarded~detail)
  return self~evaluate(policyRelease, guarded~value, .nil, advisory, proposedStageId, actorMode)

::method compare
  use strict arg fromDecision, toDecision
  if fromDecision == .nil | \fromDecision~isA(.WLURouteDecisionEvidence) then raise syntax 88.900 array("fromDecision must be WLURouteDecisionEvidence")
  if toDecision == .nil | \toDecision~isA(.WLURouteDecisionEvidence) then raise syntax 88.900 array("toDecision must be WLURouteDecisionEvidence")
  return .InstitutionalPolicyComparison~new(fromDecision~policyRelease, toDecision~policyRelease, fromDecision~outcomeIdentity, toDecision~outcomeIdentity, fromDecision~traceIdentity, toDecision~traceIdentity)

::method evaluate private
  expose keyRing
  use strict arg release, executionContext, publicationRecord, advisory, proposedStageId, actorMode
  payload = release~payload
  if payload == .nil | \payload~isA(.WLURouteDecisionRules) then return .WLUResult~failure("WLU_ROUTE_DECISION_POLICY_PAYLOAD_INVALID", "WLURouteDecisionRules payload required")
  if \payload~sealed then return .WLUResult~failure("WLU_ROUTE_DECISION_POLICY_PAYLOAD_NOT_SEALED")
  actorMode = actorMode~string~strip~translate
  if actorMode \= .WLURouteDecisionActor~AUTOMATED & actorMode \= .WLURouteDecisionActor~OPERATOR then return .WLUResult~failure("WLU_ROUTE_DECISION_ACTOR_INVALID", actorMode)
  proposedStageId = proposedStageId~string~strip~translate
  if proposedStageId = "" then return .WLUResult~failure("WLU_ROUTE_DECISION_STAGE_REQUIRED")
  assessment = advisory~assessmentFor(proposedStageId)
  if assessment == .nil then do
    candidateEligible = .false
    candidateStatus = "NOT_DECLARED_CANDIDATE"
  end
  else do
    candidateEligible = assessment~decisionEligible
    candidateStatus = assessment~status
  end
  rule = payload~ruleForActor(actorMode)
  allowed = .false
  reason = ""
  select
    when rule = .WLURouteDecisionRule~DENY then reason = "POLICY_ACTOR_MODE_DENIED"
    when assessment == .nil then reason = "PROPOSED_STAGE_NOT_DECLARED"
    when rule = .WLURouteDecisionRule~DECLARED_CANDIDATE then do
      allowed = .true
      reason = "DECLARED_CANDIDATE_PERMITTED"
    end
    when rule = .WLURouteDecisionRule~EVIDENCE_ELIGIBLE then do
      if assessment~decisionEligible then do
        allowed = .true
        reason = "EVIDENCE_ELIGIBLE_PERMITTED"
      end
      else reason = "PROPOSED_STAGE_NOT_EVIDENCE_ELIGIBLE"
    end
    when rule = .WLURouteDecisionRule~RECOMMENDED_ONLY then do
      if \advisory~hasRecommendation then reason = "ADVISORY_RECOMMENDATION_REQUIRED"
      else if advisory~recommendedStageId~translate \= proposedStageId then reason = "PROPOSED_STAGE_NOT_RECOMMENDED"
      else if \assessment~decisionEligible then reason = "PROPOSED_STAGE_NOT_EVIDENCE_ELIGIBLE"
      else do
        allowed = .true
        reason = "RECOMMENDED_STAGE_PERMITTED"
      end
    end
    otherwise reason = "POLICY_RULE_INVALID"
  end
  if allowed then status = .WLURouteDecisionStatus~PERMITTED
  else status = .WLURouteDecisionStatus~REJECTED
  evidence = .WLURouteDecisionEvidence~new(allowed, status, reason, actorMode, proposedStageId, candidateEligible, candidateStatus, advisory~recommendedStageId, advisory~status, advisory~sourceSequence, advisory~sourceTag, advisory~proof~keyId, advisory~proof~tag, release~policyId, release~version, release~semanticIdentity, rule, executionContext~actionTime, executionContext~evaluationMode, release, publicationRecord, executionContext)
  evidence = evidence~withProof(keyRing~sign(evidence~canonicalText))
  meta = .directory~new
  meta["allowed"] = allowed
  meta["status"] = status
  meta["reason_code"] = reason
  meta["actor_mode"] = actorMode
  meta["proposed_stage_id"] = proposedStageId
  meta["policy_id"] = release~policyId
  meta["policy_version"] = release~version
  meta["evaluation_mode"] = executionContext~evaluationMode
  meta["advisory_source_sequence"] = advisory~sourceSequence
  self~alchemyInstrument("WLU.JOB.ROUTE.DECISION_POLICY", meta)
  return .WLUResult~success(evidence)

::method validateAdvisory private
  expose keyRing
  use strict arg advisory
  if advisory == .nil | \advisory~isA(.WLURouteAdvisoryResult) then return .WLUResult~failure("WLU_ROUTE_DECISION_ADVISORY_REQUIRED", "authenticated WLURouteAdvisoryResult required")
  if \advisory~verify(keyRing) then return .WLUResult~failure("WLU_ROUTE_DECISION_ADVISORY_PROOF_INVALID", "route advisory proof invalid")
  return .WLUResult~success(advisory)

::requires "WLURouteAdvisory.cls"
::requires "InstitutionalPolicy.cls"
