::class TestNarrativeReport public
::method reasoningMaterial
  return "TEST_REPORT=1" || '0a'x

::class TestGovernanceBinding public
::method reasoningMaterial
  return "TEST_GOVERNANCE_BINDING=1" || '0a'x

::class TestPolicyRelease public
::attribute policyId get
::attribute version get
::attribute semanticIdentity get
::attribute payload get
::method init
  expose policyId version semanticIdentity payload
  use strict arg payload
  policyId = "BRAND-INTERVENTION-GOVERNANCE"
  version = "TEST-1"
  semanticIdentity = "TEST-POLICY-IDENTITY"
::method payloadIdentity
  return "TEST-PAYLOAD-IDENTITY"

::class TestPolicyContext public
::attribute actionTime get
::attribute deploymentIdentity get
::method init
  expose actionTime deploymentIdentity
  actionTime = "2026-10-09T18:00:00Z"
  deploymentIdentity = "TEST-DEPLOYMENT"

::class TestNarrativeFixture public
::method intervention class
  context = .BrandInterventionContext~new("CTX-1", "BRAND_JOURNEY:J1", "2026-10-09T17:00:00Z", "SUPPORT", "OPEN", .true, "UNASSESSED", 20, .false)
  context~addObligation("PRESERVE_RESOLUTION_FOCUS")
  context~seal
  policy = .BrandInterventionPolicy~new
  policy~addObligation("PRESERVE_TRUTHFULNESS")
  policy~addProhibition("INFER_SALES_AUTHORITY_FROM_BRAND_CONTEXT")
  policy~seal
  binding = .BrandInterventionEvidenceBinding~new("BIND-1", .TestNarrativeReport~new, "2026-10-09T17:00:00Z", 0, "TEST_TIME")
  binding~seal
  proposal = .BrandInterventionProposal~new("PROP-1", .BrandInterventionConstant~KIND_TONE, "SASS", 50)
  proposal~addObjective("REDUCE_DISMISSIVE_REGISTER")
  proposal~addObjective("MAINTAIN_SERVICE_ENGAGEMENT")
  proposal~addAvoidance("UNILATERAL_RELATIONAL_CLOSURE")
  proposal~addObligation("PRESERVE_TRUTHFULNESS")
  proposal~addEvidencePoint("BRAND_JOURNEY:J1")
  proposal~seal
  decision = .BrandInterventionDecision~new("INT-DEC-1", .BrandInterventionConstant~MODE_REASONING_GUIDANCE, "SUPPORTED", context, binding, policy, proposal)
  decision~addRationale("TEST_SUPPORTED_EVIDENCE")
  return decision

::method governance class
  use strict arg decisionCode = "APPROVE_CONTROLLED_PILOT", managed = .true
  rules = .BrandInterventionGovernanceRuleSet~new("TEST-RULES", 45, 25, .true, .true)
  rules~seal
  selection = .nil
  if managed then do
    release = .TestPolicyRelease~new(rules)
    context = .TestPolicyContext~new
    selection = .BrandInterventionGovernancePolicySelection~new("SEL-TEST", release, context, rules, .nil, "TEST_ASSURANCE", "GLOBAL")
    selected = selection~seal
    if \selected~ok then raise syntax 93.900 array(selected~code)
  end
  disposition = .BrandInterventionGovernanceConstant~DISPOSITION_CONTROLLED_PILOT
  if decisionCode == .BrandInterventionGovernanceConstant~DECISION_APPROVE_EXPANSION then disposition = .BrandInterventionGovernanceConstant~DISPOSITION_CONTROLLED_EXPANSION
  if decisionCode == .BrandInterventionGovernanceConstant~DECISION_CONTINUE then disposition = .BrandInterventionGovernanceConstant~DISPOSITION_CONTINUE
  if decisionCode == .BrandInterventionGovernanceConstant~DECISION_PAUSE then disposition = .BrandInterventionGovernanceConstant~DISPOSITION_WITHDRAWAL
  if decisionCode == .BrandInterventionGovernanceConstant~DECISION_WITHDRAW then disposition = .BrandInterventionGovernanceConstant~DISPOSITION_WITHDRAWAL
  recommendation = .BrandInterventionGovernanceRecommendation~new("REC-TEST", disposition, .BrandInterventionConstant~KIND_TONE, "PROMISING_ASSOCIATION", 5, 25, .TestGovernanceBinding~new, rules, .nil, .nil, selection)
  recommendation~addRationale("CURRENT_EFFECTIVENESS_STATUS_PROMISING_ASSOCIATION")
  recommendation~addCondition("NAMED_EXTERNAL_AUTHORITY_REQUIRED")
  recommendation~addCondition("PRESERVE_FULL_REASONING_PACKET")
  recommendation~addProhibition("AUTOMATIC_EXECUTION")
  recommendation~addEvidencePoint("BRAND_INTERVENTION:EFFECTIVENESS_STUDY:TEST")
  sealedRecommendation = recommendation~seal
  if \sealedRecommendation~ok then raise syntax 93.900 array(sealedRecommendation~code)
  authority = .BrandInterventionGovernanceAuthority~new("AUTH-TEST", "HUMAN_REVIEW_BOARD", .BrandInterventionConstant~KIND_TONE)
  governance = .BrandInterventionGovernanceDecision~new("GOV-DEC-1", recommendation, authority, decisionCode, "GOVERNANCE_DECISION:TEST-1", "2026-10-09T18:00:00Z")
  sealedDecision = governance~seal
  if \sealedDecision~ok then raise syntax 93.900 array(sealedDecision~code)
  return governance


::class TestNarrativeAuthorityVerifier public
::method init
  expose mode
  use strict arg mode = "OK"
::method verify
  expose mode
  use strict arg directive, governanceDecision
  verified = .true
  proofRef = "TEST-PROOF-1"
  checkedAt = "2026-10-11T20:45:00Z"
  governanceRef = governanceDecision~decisionRef
  policyRef = directive~policySelectionRef
  select
    when mode == "DENY" then do
      verified = .false
      proofRef = ""
      checkedAt = ""
    end
    when mode == "WRONG_POLICY" then policyRef = "BRAND_NARRATIVE:WRONG_POLICY_SELECTION"
    when mode == "WRONG_GOVERNANCE" then governanceRef = "GOVERNANCE_DECISION:STALE"
    otherwise nop
  end
  verification = .BrandNarrativeAuthorityVerification~new(verified, proofRef, checkedAt, governanceRef, policyRef, "TEST_HOST_VERIFIER")
  sealed = verification~seal
  if \sealed~ok then raise syntax 93.900 array(sealed~code)
  return verification

::requires "BrandNarrativeDirective.cls"
