/* Reputation Feed v0.12 optional Institutional Policy v0.6 bridge.
 *
 * Institutional Policy governs publication, authority, deployment lifecycle,
 * scoped topology and bounded progressive rollout evidence. Reputation Feed
 * continues to own lineage, corroboration, provenance-eligibility and
 * geographic-salience semantics.
 */

::class ReputationFeedPolicyDeploymentEvidence subclass ReputationFeedAlchemyObject public
::attribute executionContext get
::attribute deploymentPoint get
::attribute topologyState get
::attribute progressiveBinding get
::attribute deploymentIdentity get
::attribute deploymentPointIdentity get
::attribute deploymentMode get
::attribute deploymentSource get
::attribute deploymentBindingIdentity get
::attribute deploymentBindingId get
::attribute progressiveRolloutIdentity get
::attribute progressiveRolloutId get
::attribute operative get

::method init
  expose executionContext deploymentPoint topologyState progressiveBinding deploymentIdentity deploymentPointIdentity deploymentMode deploymentSource deploymentBindingIdentity deploymentBindingId progressiveRolloutIdentity progressiveRolloutId operative
  use arg executionContextArg, deploymentPointArg = .nil, topologyStateArg = .nil, progressiveBindingArg = .nil, alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationFeedPolicyDeploymentEvidence", alchemyContextArg)
  if executionContextArg == .nil then raise syntax 88.900 array("Policy deployment evidence requires InstitutionalPolicyExecutionContext")
  executionContext = executionContextArg
  deploymentPoint = deploymentPointArg
  topologyState = topologyStateArg
  progressiveBinding = progressiveBindingArg
  deploymentIdentity = executionContextArg~deploymentIdentity
  deploymentPointIdentity = ""
  if deploymentPoint <> .nil then deploymentPointIdentity = deploymentPoint~semanticIdentity
  deploymentMode = "COUNTERFACTUAL"
  deploymentSource = "COUNTERFACTUAL"
  deploymentBindingIdentity = ""
  deploymentBindingId = ""
  progressiveRolloutIdentity = ""
  progressiveRolloutId = ""
  operative = .false
  if topologyState <> .nil then do
    deploymentMode = topologyState~mode
    deploymentSource = topologyState~source
    operative = topologyState~operative
    if topologyState~binding <> .nil then do
      deploymentBindingIdentity = topologyState~binding~semanticIdentity
      deploymentBindingId = topologyState~binding~deploymentId
    end
    self~recordRelationship("DEPLOYMENT_TOPOLOGY", topologyState, "exact institutional policy topology state used for Feed execution", "INTERNAL")
  end
  if progressiveBinding <> .nil then do
    progressiveRolloutIdentity = progressiveBinding~semanticIdentity
    progressiveRolloutId = progressiveBinding~rolloutId
    self~recordRelationship("PROGRESSIVE_ROLLOUT", progressiveBinding, "bounded exact-version overlap authority evidence", "INTERNAL")
  end
  self~registerStateVariable("deploymentIdentity", "PUBLIC", "Institutional execution deployment identity")
  self~registerStateVariable("deploymentPointIdentity", "PUBLIC", "Exact service/region/channel/tenant/cohort point")
  self~registerStateVariable("deploymentMode", "PUBLIC", "ACTIVE, CANARY, STAGED or other deployment mode")
  self~registerStateVariable("deploymentSource", "PUBLIC", "Topology resolution source")
  self~registerStateVariable("deploymentBindingId", "PUBLIC", "Selected immutable deployment binding identifier")
  self~registerStateVariable("progressiveRolloutId", "PUBLIC", "Bounded progressive rollout identifier when applicable")
  self~registerStateVariable("operative", "PUBLIC", "Whether topology state was operative")

::method canonicalText
  expose executionContext deploymentIdentity deploymentPointIdentity deploymentMode deploymentSource deploymentBindingIdentity deploymentBindingId progressiveRolloutIdentity progressiveRolloutId operative
  text = "REPUTATION-FEED-POLICY-DEPLOYMENT-EVIDENCE/1" || '0a'x
  text ||= .ReputationFeedCanonical~field("POLICY", executionContext~policy~policyId || "@" || executionContext~policy~version)
  text ||= .ReputationFeedCanonical~field("MODE", executionContext~evaluationMode)
  text ||= .ReputationFeedCanonical~field("DEPLOYMENT_IDENTITY", deploymentIdentity)
  text ||= .ReputationFeedCanonical~field("POINT", deploymentPointIdentity)
  text ||= .ReputationFeedCanonical~field("TOPOLOGY_MODE", deploymentMode)
  text ||= .ReputationFeedCanonical~field("TOPOLOGY_SOURCE", deploymentSource)
  text ||= .ReputationFeedCanonical~field("OPERATIVE", operative)
  text ||= .ReputationFeedCanonical~field("BINDING_ID", deploymentBindingId)
  text ||= .ReputationFeedCanonical~field("BINDING_IDENTITY", deploymentBindingIdentity)
  text ||= .ReputationFeedCanonical~field("ROLLOUT_ID", progressiveRolloutId)
  text ||= .ReputationFeedCanonical~field("ROLLOUT_IDENTITY", progressiveRolloutIdentity)
  return text


::class ReputationFeedGovernedOutcome subclass ReputationFeedAlchemyObject public
::attribute operation get
::attribute evaluationMode get
::attribute actionTime get
::attribute policyId get
::attribute policyVersion get
::attribute policyIdentity get
::attribute policySetIdentity get
::attribute assuranceMode get
::attribute publicationRecord get
::attribute domainResult get
::attribute deploymentEvidence get
::attribute deploymentIdentity get
::attribute deploymentPointIdentity get
::attribute deploymentMode get
::attribute deploymentSource get
::attribute deploymentBindingIdentity get
::attribute deploymentBindingId get
::attribute progressiveRolloutIdentity get
::attribute progressiveRolloutId get

::method init
  expose operation evaluationMode actionTime policyId policyVersion policyIdentity policySetIdentity assuranceMode publicationRecord domainResult deploymentEvidence deploymentIdentity deploymentPointIdentity deploymentMode deploymentSource deploymentBindingIdentity deploymentBindingId progressiveRolloutIdentity progressiveRolloutId
  use arg operationArg, executionContextArg, publicationRecordArg, domainResultArg, alchemyContextArg = .nil, deploymentEvidenceArg = .nil
  self~initDomainAlchemy("ReputationFeedGovernedOutcome", alchemyContextArg)
  operation = operationArg~string~upper~strip
  evaluationMode = executionContextArg~evaluationMode
  actionTime = executionContextArg~actionTime
  policyId = executionContextArg~policy~policyId
  policyVersion = executionContextArg~policy~version
  policyIdentity = executionContextArg~policyIdentity
  policySetIdentity = executionContextArg~policy~payload~semanticIdentity
  publicationRecord = publicationRecordArg
  domainResult = domainResultArg
  deploymentEvidence = deploymentEvidenceArg
  if publicationRecord == .nil then assuranceMode = "UNRECORDED"
  else assuranceMode = publicationRecord~assuranceMode
  deploymentIdentity = executionContextArg~deploymentIdentity
  deploymentPointIdentity = ""
  deploymentMode = "COUNTERFACTUAL"
  deploymentSource = "COUNTERFACTUAL"
  deploymentBindingIdentity = ""
  deploymentBindingId = ""
  progressiveRolloutIdentity = ""
  progressiveRolloutId = ""
  if deploymentEvidence <> .nil then do
    deploymentIdentity = deploymentEvidence~deploymentIdentity
    deploymentPointIdentity = deploymentEvidence~deploymentPointIdentity
    deploymentMode = deploymentEvidence~deploymentMode
    deploymentSource = deploymentEvidence~deploymentSource
    deploymentBindingIdentity = deploymentEvidence~deploymentBindingIdentity
    deploymentBindingId = deploymentEvidence~deploymentBindingId
    progressiveRolloutIdentity = deploymentEvidence~progressiveRolloutIdentity
    progressiveRolloutId = deploymentEvidence~progressiveRolloutId
    self~recordRelationship("DEPLOYMENT_EVIDENCE", deploymentEvidence, "exact institutional deployment route used by Feed", "INTERNAL")
  end
  self~registerStateVariable("operation", "PUBLIC", "Governed Reputation Feed operation")
  self~registerStateVariable("evaluationMode", "PUBLIC", "OPERATIVE or COUNTERFACTUAL")
  self~registerStateVariable("policyId", "PUBLIC", "Institutional policy family")
  self~registerStateVariable("policyVersion", "PUBLIC", "Institutional policy version")
  self~registerStateVariable("policyIdentity", "PUBLIC", "Exact institutional policy semantic identity")
  self~registerStateVariable("assuranceMode", "PUBLIC", "Institutional publication assurance mode")
  self~registerStateVariable("deploymentMode", "PUBLIC", "Exact policy deployment mode")
  self~registerStateVariable("deploymentBindingId", "PUBLIC", "Exact deployment binding identifier")
  self~registerStateVariable("progressiveRolloutId", "PUBLIC", "Progressive rollout authorization identifier")
  self~recordRelationship("EVALUATED_UNDER_POLICY", executionContextArg~policy, "exact effective-dated institutional policy release", "INTERNAL")

::method outcomeIdentity
  expose domainResult
  if domainResult == .nil then return ""
  if domainResult~hasMethod("CANONICALTEXT") then return domainResult~canonicalText
  if domainResult~hasMethod("SEMANTICIDENTITY") then return domainResult~semanticIdentity
  return domainResult~string

::method canonicalText
  expose operation evaluationMode actionTime policyId policyVersion policyIdentity policySetIdentity assuranceMode publicationRecord deploymentIdentity deploymentPointIdentity deploymentMode deploymentSource deploymentBindingIdentity deploymentBindingId progressiveRolloutIdentity progressiveRolloutId
  text = "REPUTATION-FEED-GOVERNED-OUTCOME/2" || '0a'x
  text ||= .ReputationFeedCanonical~field("OPERATION", operation)
  text ||= .ReputationFeedCanonical~field("MODE", evaluationMode)
  text ||= .ReputationFeedCanonical~field("ACTION_TIME", actionTime)
  text ||= .ReputationFeedCanonical~field("POLICY", policyId || "@" || policyVersion)
  text ||= .ReputationFeedCanonical~field("POLICY_IDENTITY", policyIdentity)
  text ||= .ReputationFeedCanonical~field("POLICY_SET_IDENTITY", policySetIdentity)
  text ||= .ReputationFeedCanonical~field("ASSURANCE", assuranceMode)
  text ||= .ReputationFeedCanonical~field("DEPLOYMENT_IDENTITY", deploymentIdentity)
  text ||= .ReputationFeedCanonical~field("DEPLOYMENT_POINT", deploymentPointIdentity)
  text ||= .ReputationFeedCanonical~field("DEPLOYMENT_MODE", deploymentMode)
  text ||= .ReputationFeedCanonical~field("DEPLOYMENT_SOURCE", deploymentSource)
  text ||= .ReputationFeedCanonical~field("DEPLOYMENT_BINDING_ID", deploymentBindingId)
  text ||= .ReputationFeedCanonical~field("DEPLOYMENT_BINDING", deploymentBindingIdentity)
  text ||= .ReputationFeedCanonical~field("PROGRESSIVE_ROLLOUT_ID", progressiveRolloutId)
  text ||= .ReputationFeedCanonical~field("PROGRESSIVE_ROLLOUT", progressiveRolloutIdentity)
  if publicationRecord <> .nil then text ||= .ReputationFeedCanonical~field("PUBLICATION_RECORD", publicationRecord~canonicalText)
  text ||= .ReputationFeedCanonical~field("OUTCOME", self~outcomeIdentity)
  return text


::class ReputationFeedPolicyExecution subclass ReputationFeedAlchemyObject public
::attribute executionContext get
::attribute publicationRecord get
::attribute policySet get
::attribute deploymentEvidence get

::method init
  expose executionContext publicationRecord policySet deploymentEvidence
  use arg executionContextArg, publicationRecordArg = .nil, alchemyContextArg = .nil, deploymentEvidenceArg = .nil
  self~initDomainAlchemy("ReputationFeedPolicyExecution", alchemyContextArg)
  if executionContextArg == .nil then raise syntax 88.900 array("ReputationFeedPolicyExecution requires InstitutionalPolicyExecutionContext")
  if \executionContextArg~hasMethod("POLICY") then raise syntax 88.900 array("Institutional policy execution context missing policy")
  release = executionContextArg~policy
  if release~payload == .nil then raise syntax 88.900 array("Reputation Feed institutional release has no policy payload")
  if \release~payload~hasMethod("POLICYSETID") | \release~payload~hasMethod("CORROBORATIONPOLICY") | \release~payload~hasMethod("EVIDENCEPOLICY") | \release~payload~hasMethod("GEOGRAPHICSALIENCEPOLICY") | \release~payload~hasMethod("LINEAGEPOLICY") then raise syntax 88.900 array("Institutional policy payload is not a ReputationFeedPolicySet")
  if \release~payload~sealed then raise syntax 88.900 array("Reputation Feed policy set must be sealed")
  executionContext = executionContextArg
  publicationRecord = publicationRecordArg
  policySet = release~payload
  deploymentEvidence = deploymentEvidenceArg
  self~recordRelationship("USES_POLICY_SET", policySet, "domain-owned deterministic Reputation Feed rules", "INTERNAL")
  if deploymentEvidence <> .nil then self~recordRelationship("USES_DEPLOYMENT_ROUTE", deploymentEvidence, "exact scoped/progressive institutional deployment evidence", "INTERNAL")

::method corroborate
  expose executionContext publicationRecord policySet deploymentEvidence
  use arg hypothesis
  if hypothesis == .nil then raise syntax 88.900 array("Governed corroboration requires hypothesis")
  domain = hypothesis~corroboration(policySet~corroborationPolicy, policySet~evidencePolicy)
  return .ReputationFeedGovernedOutcome~new("CORROBORATION", executionContext, publicationRecord, domain, self~domainAlchemyContext, deploymentEvidence)

::method cluster
  expose executionContext publicationRecord policySet deploymentEvidence
  use arg claims
  engine = .ReputationEventClusterEngine~new(self~domainAlchemyContext)
  domain = engine~cluster(claims, policySet~corroborationPolicy)
  return .ReputationFeedGovernedOutcome~new("EVENT_CLUSTER", executionContext, publicationRecord, domain, self~domainAlchemyContext, deploymentEvidence)

::method lineage
  expose executionContext publicationRecord policySet deploymentEvidence
  use arg articles, comparisons
  engine = .ReputationLineageEngine~new(self~domainAlchemyContext)
  domain = engine~group(articles, comparisons, policySet~lineagePolicy)
  return .ReputationFeedGovernedOutcome~new("LINEAGE", executionContext, publicationRecord, domain, self~domainAlchemyContext, deploymentEvidence)

::method assessGeographicSalience
  expose executionContext publicationRecord policySet deploymentEvidence
  use arg evidence
  if evidence == .nil then raise syntax 88.900 array("Governed geographic salience requires evidence")
  domain = policySet~geographicSaliencePolicy~assess(evidence)
  return .ReputationFeedGovernedOutcome~new("GEOGRAPHIC_SALIENCE", executionContext, publicationRecord, domain, self~domainAlchemyContext, deploymentEvidence)


::class ReputationFeedInstitutionalPolicyBridge subclass ReputationFeedAlchemyObject public
::attribute policyId get

::method init
  expose policyId
  use arg policyIdArg = "REPUTATION-FEED-POLICY", alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationFeedInstitutionalPolicyBridge", alchemyContextArg)
  policyId = policyIdArg~string~upper~strip
  if policyId = "" then policyId = "REPUTATION-FEED-POLICY"
  self~registerExternalRequirement("library", "institutional_policy", "0.6", .true)

::method newRelease
  expose policyId
  use arg versionArg, policySetArg, effectiveFromArg = .nil, effectiveUntilArg = .nil, authoredByArg = "", approvedByArg = "", supersedesArg = ""
  if policySetArg == .nil then raise syntax 88.900 array("Reputation Feed institutional release requires policy set")
  if \policySetArg~hasMethod("POLICYSETID") | \policySetArg~hasMethod("SEALED") then raise syntax 88.900 array("Reputation Feed institutional release requires ReputationFeedPolicySet")
  if \policySetArg~sealed then raise syntax 88.900 array("Reputation Feed policy set must be sealed before institutional release")
  release = .InstitutionalPolicyRelease~new(policyId, versionArg, effectiveFromArg, effectiveUntilArg, authoredByArg, approvedByArg, supersedesArg, policySetArg)
  return release~seal

::method activeProgressiveBinding private
  use arg catalog, selectedPolicy, actionTime
  if catalog == .nil | selectedPolicy == .nil then return .nil
  found = .nil
  do candidate over catalog~versions(selectedPolicy~policyId)
    result = catalog~progressiveBinding(selectedPolicy~policyId, candidate~version)
    if result~ok then do
      binding = result~value
      if binding~activeAt(actionTime) then do
        selected = (selectedPolicy~version = binding~priorVersion & selectedPolicy~semanticIdentity = binding~priorIdentity) | (selectedPolicy~version = binding~nextVersion & selectedPolicy~semanticIdentity = binding~nextIdentity)
        if selected then do
          if found <> .nil then if found~semanticIdentity <> binding~semanticIdentity then return .nil
          found = binding
        end
      end
    end
  end
  return found

::method executionFromContext private
  expose policyId
  use arg catalog, executionContext, deploymentPoint = .nil, actionTime = .nil
  if actionTime == .nil then actionTime = executionContext~actionTime
  policy = executionContext~policy
  recordResult = catalog~publicationRecord(policyId, policy~version)
  if recordResult~ok then record = recordResult~value; else record = .nil
  topologyResult = catalog~topologyState(policyId, policy~version, deploymentPoint, actionTime)
  if \topologyResult~ok then return topologyResult
  progressive = self~activeProgressiveBinding(catalog, policy, actionTime)
  deploymentEvidence = .ReputationFeedPolicyDeploymentEvidence~new(executionContext, deploymentPoint, topologyResult~value, progressive, self~domainAlchemyContext)
  return .InstitutionalPolicyResult~success(.ReputationFeedPolicyExecution~new(executionContext, record, self~domainAlchemyContext, deploymentEvidence))

::method operative
  use arg catalog, actionTime = .nil
  return self~operativeForContext(catalog, .nil, actionTime)

::method operativeForContext
  expose policyId
  use arg catalog, deploymentPoint, actionTime = .nil
  if actionTime == .nil then actionTime = .DateTime~new
  if catalog == .nil then return .InstitutionalPolicyResult~failure("POLICY_CATALOG_REQUIRED")
  contextResult = catalog~executionContextForContext(policyId, deploymentPoint, actionTime)
  if \contextResult~ok then return contextResult
  return self~executionFromContext(catalog, contextResult~value, deploymentPoint, actionTime)

::method counterfactual
  expose policyId
  use arg catalog, versionArg, actionTime = .nil
  if actionTime == .nil then actionTime = .DateTime~new
  if catalog == .nil then return .InstitutionalPolicyResult~failure("POLICY_CATALOG_REQUIRED")
  versionResult = catalog~policyVersion(policyId, versionArg)
  if \versionResult~ok then return versionResult
  guard = .InstitutionalPolicyReplayGuard~counterfactual(versionResult~value, actionTime)
  if \guard~ok then return guard
  recordResult = catalog~publicationRecord(policyId, versionResult~value~version)
  if recordResult~ok then record = recordResult~value; else record = .nil
  deploymentEvidence = .ReputationFeedPolicyDeploymentEvidence~new(guard~value, .nil, .nil, .nil, self~domainAlchemyContext)
  return .InstitutionalPolicyResult~success(.ReputationFeedPolicyExecution~new(guard~value, record, self~domainAlchemyContext, deploymentEvidence))

::requires 'InstitutionalPolicy.cls'
::requires 'ReputationFeed.cls'
