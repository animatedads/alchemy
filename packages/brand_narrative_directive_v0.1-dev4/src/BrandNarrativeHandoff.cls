::class BrandNarrativeAuthorityVerification subclass AlchemyObject public
::attribute verified get
::attribute proofRef get
::attribute checkedAt get
::attribute governanceDecisionRef get
::attribute policySelectionRef get
::attribute verifierKind get
::attribute sealed get
::method init
  expose verified proofRef checkedAt governanceDecisionRef policySelectionRef verifierKind sealed
  use strict arg verified, proofRef, checkedAt, governanceDecisionRef, policySelectionRef = "", verifierKind = "HOST_VERIFIER"
  if verified \== .true then do
    if verified \== .false then raise syntax 93.900 array("BRAND_NARRATIVE_AUTHORITY_VERIFIED_BOOLEAN_REQUIRED")
  end
  if governanceDecisionRef~string~strip == "" then raise syntax 93.900 array("BRAND_NARRATIVE_AUTHORITY_GOVERNANCE_REF_REQUIRED")
  if verified then do
    if proofRef~string~strip == "" then raise syntax 93.900 array("BRAND_NARRATIVE_AUTHORITY_PROOF_REQUIRED")
    if checkedAt~string~strip == "" then raise syntax 93.900 array("BRAND_NARRATIVE_AUTHORITY_CHECK_TIME_REQUIRED")
    if verifierKind~string~strip == "" then raise syntax 93.900 array("BRAND_NARRATIVE_AUTHORITY_VERIFIER_KIND_REQUIRED")
  end
  sealed = .false
  meta = .Directory~new
  meta["purpose"] = "bounded host-supplied fresh authority verification result; not credentials"
  meta["package_version"] = .BrandNarrativeDirectiveBuild~VERSION
  meta["api_version"] = .BrandNarrativeDirectiveBuild~API_VERSION
  meta["component"] = "BRAND_NARRATIVE_DIRECTIVE_AUTHORITY_VERIFICATION"
  self~initAlchemy(meta)
  self~registerStateVariable("verified", "CUSTOMER", "fresh host verification outcome")
  self~registerStateVariable("proofRef", "INTERNAL", "opaque proof reference only")
  self~registerStateVariable("checkedAt", "CUSTOMER", "host supplied verification time")
  self~registerStateVariable("governanceDecisionRef", "INTERNAL", "exact governance decision reference verified")
  self~registerStateVariable("policySelectionRef", "INTERNAL", "exact operative policy selection reference verified")
  self~registerStateVariable("verifierKind", "INTERNAL", "host verifier kind claim; not identity proof")
  self~registerStateVariable("sealed", "CUSTOMER", "verification immutability")
::method seal
  expose sealed
  sealed = .true
  self~alchemyTouch("BRAND_NARRATIVE_AUTHORITY_VERIFICATION_SEAL")
  return .BrandNarrativeDirectiveResult~success(self)
::method pointId
  expose proofRef
  if proofRef~string~strip == "" then return "BRAND_NARRATIVE:AUTHORITY_VERIFICATION:UNVERIFIED"
  return "BRAND_NARRATIVE:AUTHORITY_VERIFICATION:" || proofRef

::class BrandNarrativeHandoff subclass AlchemyObject public
::attribute handoffId get
::attribute directiveRef get
::attribute governanceDecisionRef get
::attribute candidateRef get
::attribute stage get
::attribute authorityMode get
::attribute publicationAuthority get
::attribute verificationRef get
::attribute sealed get
::method init
  expose handoffId directiveRef governanceDecisionRef candidateRef stage authorityMode publicationAuthority verificationRef reviews sealed
  use strict arg handoffId, directiveRef, governanceDecisionRef, candidateRef, stage, verificationRef = ""
  if handoffId~string~strip == "" then raise syntax 93.900 array("BRAND_NARRATIVE_HANDOFF_ID_REQUIRED")
  if directiveRef~string~strip == "" then raise syntax 93.900 array("BRAND_NARRATIVE_HANDOFF_DIRECTIVE_REF_REQUIRED")
  if governanceDecisionRef~string~strip == "" then raise syntax 93.900 array("BRAND_NARRATIVE_HANDOFF_GOVERNANCE_REF_REQUIRED")
  stage = .BrandNarrativeDirectiveCanonical~token(stage)
  authorityMode = .BrandNarrativeDirectiveConstant~MODE_NO_DISPATCH
  publicationAuthority = .BrandNarrativeDirectiveConstant~PUBLICATION_AUTHORITY_NONE
  reviews = .Array~new
  sealed = .false
  meta = .Directory~new
  meta["purpose"] = "freshly verified non-dispatch handoff from Brand evidence to external narrative/publication authorities"
  meta["package_version"] = .BrandNarrativeDirectiveBuild~VERSION
  meta["api_version"] = .BrandNarrativeDirectiveBuild~API_VERSION
  meta["component"] = "BRAND_NARRATIVE_DIRECTIVE_HANDOFF"
  self~initAlchemy(meta)
  self~registerStateVariable("stage", "CUSTOMER", "bounded handoff stage; never activation")
  self~registerStateVariable("candidateRef", "INTERNAL", "opaque external narrative candidate reference")
  self~registerStateVariable("verificationRef", "INTERNAL", "fresh host authority verification reference")
  self~registerStateVariable("reviews", "INTERNAL", "detached external review snapshots")
  self~registerStateVariable("authorityMode", "CUSTOMER", "always NO_DISPATCH")
  self~registerStateVariable("publicationAuthority", "CUSTOMER", "always NONE")
  self~registerStateVariable("sealed", "CUSTOMER", "handoff immutability")
::method addReview
  expose reviews sealed
  use strict arg review
  if sealed then return .BrandNarrativeDirectiveResult~failure("HANDOFF_ALREADY_SEALED")
  if review == .nil then return .BrandNarrativeDirectiveResult~failure("EXTERNAL_REVIEW_REQUIRED")
  if \review~isA(.BrandNarrativeExternalReview) then return .BrandNarrativeDirectiveResult~failure("EXTERNAL_REVIEW_TYPE_INVALID")
  if \review~sealed then return .BrandNarrativeDirectiveResult~failure("EXTERNAL_REVIEW_NOT_SEALED")
  reviews~append(review)
  self~recordRelationship("USES_REVIEW", review, "non-authoritative external review snapshot", "INTERNAL")
  return .BrandNarrativeDirectiveResult~success(review)
::method reviews
  expose reviews
  return .BrandNarrativeDirectiveCanonical~copyArray(reviews)
::method seal
  expose sealed
  sealed = .true
  self~alchemyTouch("BRAND_NARRATIVE_HANDOFF_SEAL")
  return .BrandNarrativeDirectiveResult~success(self)
::method pointId
  expose handoffId
  return "BRAND_NARRATIVE:HANDOFF:" || handoffId
::method toDirectory
  expose handoffId directiveRef governanceDecisionRef candidateRef stage authorityMode publicationAuthority verificationRef reviews sealed
  if \sealed then raise syntax 93.900 array("BRAND_NARRATIVE_HANDOFF_NOT_SEALED")
  out = .Directory~new
  out["schema"] = .BrandNarrativeDirectiveBuild~API_VERSION
  out["handoff_id"] = handoffId
  out["directive_ref"] = directiveRef
  out["governance_decision_ref"] = governanceDecisionRef
  out["candidate_ref"] = candidateRef
  out["stage"] = stage
  out["authority_mode"] = authorityMode
  out["publication_authority"] = publicationAuthority
  out["verification_ref"] = verificationRef
  reviewCopies = .Array~new
  do review over reviews
    reviewCopies~append(review~toDirectory)
  end
  out["external_reviews"] = reviewCopies
  return out

::class BrandNarrativeHandoffEngine public
::method prepare
  use strict arg directive, governanceDecision, handoffId = "", candidateRef = "", reviews = .nil, verifier = .nil
  if directive == .nil then return .BrandNarrativeDirectiveResult~failure("DIRECTIVE_REQUIRED")
  if \directive~isA(.BrandNarrativeDirective) then return .BrandNarrativeDirectiveResult~failure("DIRECTIVE_TYPE_INVALID")
  if \directive~sealed then return .BrandNarrativeDirectiveResult~failure("DIRECTIVE_NOT_SEALED")
  if governanceDecision == .nil then return .BrandNarrativeDirectiveResult~failure("GOVERNANCE_DECISION_REQUIRED")
  if \governanceDecision~isA(.BrandInterventionGovernanceDecision) then return .BrandNarrativeDirectiveResult~failure("GOVERNANCE_DECISION_TYPE_INVALID")
  if \governanceDecision~sealed then return .BrandNarrativeDirectiveResult~failure("GOVERNANCE_DECISION_NOT_SEALED")
  if directive~sourceGovernanceDecisionId \== governanceDecision~decisionId then return .BrandNarrativeDirectiveResult~failure("GOVERNANCE_DECISION_STALE")
  if directive~sourceGovernanceDecisionRef \== governanceDecision~decisionRef then return .BrandNarrativeDirectiveResult~failure("GOVERNANCE_DECISION_REF_STALE")

  needsVerification = directive~runtimeEffect \== .BrandNarrativeDirectiveConstant~EFFECT_NONE
  verification = .nil
  if needsVerification then do
    if verifier == .nil then return .BrandNarrativeDirectiveResult~failure("FRESH_AUTHORITY_VERIFICATION_REQUIRED")
    if \verifier~hasMethod("VERIFY") then return .BrandNarrativeDirectiveResult~failure("AUTHORITY_VERIFIER_CONTRACT_INVALID")
    verification = verifier~verify(directive, governanceDecision)
    if verification == .nil then return .BrandNarrativeDirectiveResult~failure("AUTHORITY_VERIFICATION_RESULT_REQUIRED")
    if \verification~isA(.BrandNarrativeAuthorityVerification) then return .BrandNarrativeDirectiveResult~failure("AUTHORITY_VERIFICATION_RESULT_TYPE_INVALID")
    if \verification~sealed then return .BrandNarrativeDirectiveResult~failure("AUTHORITY_VERIFICATION_NOT_SEALED")
    if \verification~verified then return .BrandNarrativeDirectiveResult~failure("AUTHORITY_VERIFICATION_DENIED")
    if verification~governanceDecisionRef \== governanceDecision~decisionRef then return .BrandNarrativeDirectiveResult~failure("AUTHORITY_VERIFICATION_GOVERNANCE_REF_MISMATCH")
    if directive~policySelectionRef \== "" then do
      if verification~policySelectionRef \== directive~policySelectionRef then return .BrandNarrativeDirectiveResult~failure("AUTHORITY_VERIFICATION_POLICY_REF_MISMATCH")
    end
  end

  id = handoffId~string~strip
  if id == "" then id = "HANDOFF-" || directive~directiveId
  candidate = candidateRef~string~strip
  external = .Array~new
  if reviews \== .nil then do review over reviews
    if review == .nil then return .BrandNarrativeDirectiveResult~failure("EXTERNAL_REVIEW_REQUIRED")
    if \review~isA(.BrandNarrativeExternalReview) then return .BrandNarrativeDirectiveResult~failure("EXTERNAL_REVIEW_TYPE_INVALID")
    if \review~sealed then return .BrandNarrativeDirectiveResult~failure("EXTERNAL_REVIEW_NOT_SEALED")
    external~append(review)
  end

  stage = .BrandNarrativeDirectiveConstant~HANDOFF_EVIDENCE_ONLY
  if needsVerification then stage = .BrandNarrativeDirectiveConstant~HANDOFF_READY_SELECTION
  communicationsReady = .false
  communicationsHeld = .false
  do review over external
    if review~reviewKind \== .BrandNarrativeDirectiveConstant~REVIEW_COMMUNICATIONS_NARRATIVE then iterate
    if candidate == "" then return .BrandNarrativeDirectiveResult~failure("COMMUNICATIONS_REVIEW_REQUIRES_CANDIDATE")
    if left(review~status, 5) == "HOLD_" then communicationsHeld = .true
    if review~status == "EDITORIAL_REVIEW_EVIDENCE_ONLY" then communicationsReady = .true
  end
  if candidate \== "" then do
    stage = .BrandNarrativeDirectiveConstant~HANDOFF_READY_EVIDENCE_REVIEW
    if communicationsHeld then stage = .BrandNarrativeDirectiveConstant~HANDOFF_HELD_EXTERNAL_REVIEW
    if communicationsReady then stage = .BrandNarrativeDirectiveConstant~HANDOFF_READY_EXTERNAL_AUTHORITY
  end

  verificationRef = ""
  if verification \== .nil then verificationRef = verification~pointId
  handoff = .BrandNarrativeHandoff~new(id, directive~pointId, governanceDecision~decisionRef, candidate, stage, verificationRef)
  handoff~recordRelationship("PROJECTS", directive, "fresh handoff from immutable directive", "INTERNAL")
  handoff~recordRelationship("REVALIDATES", governanceDecision, "current governance decision rechecked at handoff", "INTERNAL")
  if verification \== .nil then handoff~recordRelationship("VERIFIED_BY", verification, "host-supplied fresh authority proof reference", "INTERNAL")
  do review over external
    added = handoff~addReview(review)
    if \added~ok then return added
  end
  sealed = handoff~seal
  if \sealed~ok then return sealed
  return .BrandNarrativeDirectiveResult~success(handoff)

