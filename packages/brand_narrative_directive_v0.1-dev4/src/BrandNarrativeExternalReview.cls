::class BrandNarrativeExternalReview subclass AlchemyObject public
::attribute reviewId get
::attribute reviewKind get
::attribute sourceRef get
::attribute status get
::attribute reason get
::attribute authorityMode get
::attribute claimAuthority get
::attribute evidenceMaturity get
::attribute snapshot get
::attribute sealed get
::method init
  expose reviewId reviewKind sourceRef status reason authorityMode claimAuthority evidenceMaturity snapshot sealed
  use strict arg reviewId, reviewKind, sourceRef, status, reason, authorityMode, claimAuthority, evidenceMaturity, snapshot
  reviewKind = .BrandNarrativeDirectiveCanonical~token(reviewKind)
  authorityMode = .BrandNarrativeDirectiveCanonical~token(authorityMode)
  claimAuthority = .BrandNarrativeDirectiveCanonical~token(claimAuthority)
  evidenceMaturity = .BrandNarrativeDirectiveCanonical~token(evidenceMaturity)
  status = .BrandNarrativeDirectiveCanonical~token(status)
  if reviewId~string~strip == "" then raise syntax 93.900 array("BRAND_NARRATIVE_EXTERNAL_REVIEW_ID_REQUIRED")
  if sourceRef~string~strip == "" then raise syntax 93.900 array("BRAND_NARRATIVE_EXTERNAL_REVIEW_SOURCE_REF_REQUIRED")
  validKind = .false
  if reviewKind == .BrandNarrativeDirectiveConstant~REVIEW_COMMUNICATIONS_NARRATIVE then validKind = .true
  if reviewKind == .BrandNarrativeDirectiveConstant~REVIEW_LIBRARIAN_POSITION then validKind = .true
  if reviewKind == .BrandNarrativeDirectiveConstant~REVIEW_LIBRARIAN_CHANGE then validKind = .true
  if reviewKind == .BrandNarrativeDirectiveConstant~REVIEW_LIBRARIAN_ORIGIN then validKind = .true
  if \validKind then raise syntax 93.900 array("BRAND_NARRATIVE_EXTERNAL_REVIEW_KIND_INVALID")
  validMode = .false
  if authorityMode == .BrandNarrativeDirectiveConstant~MODE_NO_DISPATCH then validMode = .true
  if authorityMode == .BrandNarrativeDirectiveConstant~MODE_EVIDENCE_ONLY then validMode = .true
  if \validMode then raise syntax 93.900 array("BRAND_NARRATIVE_EXTERNAL_REVIEW_AUTHORITY_ESCALATION")
  if claimAuthority \== .BrandNarrativeDirectiveConstant~CLAIM_NOT_VERIFIED then raise syntax 93.900 array("BRAND_NARRATIVE_EXTERNAL_REVIEW_CLAIM_AUTHORITY_INVALID")
  sealed = .false
  meta = .Directory~new
  meta["purpose"] = "detached snapshot of adjacent narrative/evidence review; no dispatch, truth, bias or publication authority"
  meta["package_version"] = .BrandNarrativeDirectiveBuild~VERSION
  meta["api_version"] = .BrandNarrativeDirectiveBuild~API_VERSION
  meta["component"] = "BRAND_NARRATIVE_DIRECTIVE_EXTERNAL_REVIEW"
  self~initAlchemy(meta)
  self~registerStateVariable("reviewKind", "INTERNAL", "adjacent review contract family")
  self~registerStateVariable("sourceRef", "INTERNAL", "opaque upstream review reference")
  self~registerStateVariable("status", "CUSTOMER", "upstream review status preserved without promotion")
  self~registerStateVariable("reason", "CUSTOMER", "upstream review reason")
  self~registerStateVariable("authorityMode", "CUSTOMER", "NO_DISPATCH or EVIDENCE_ONLY only")
  self~registerStateVariable("claimAuthority", "CUSTOMER", "always NOT_VERIFIED")
  self~registerStateVariable("evidenceMaturity", "CUSTOMER", "upstream maturity preserved")
  self~registerStateVariable("snapshot", "INTERNAL", "detached upstream review snapshot")
  self~registerStateVariable("sealed", "CUSTOMER", "review snapshot immutability")
::method seal
  expose sealed
  sealed = .true
  self~alchemyTouch("BRAND_NARRATIVE_EXTERNAL_REVIEW_SEAL")
  return .BrandNarrativeDirectiveResult~success(self)
::method pointId
  expose reviewId
  return "BRAND_NARRATIVE:EXTERNAL_REVIEW:" || reviewId
::method toDirectory
  expose reviewId reviewKind sourceRef status reason authorityMode claimAuthority evidenceMaturity snapshot sealed
  if \sealed then raise syntax 93.900 array("BRAND_NARRATIVE_EXTERNAL_REVIEW_NOT_SEALED")
  out = .Directory~new
  out["review_id"] = reviewId
  out["review_kind"] = reviewKind
  out["source_ref"] = sourceRef
  out["status"] = status
  out["reason"] = reason
  out["authority_mode"] = authorityMode
  out["claim_authority"] = claimAuthority
  out["evidence_maturity"] = evidenceMaturity
  out["snapshot"] = snapshot
  return out

::class BrandNarrativeExternalReviewAdapter public
::method fromCommunicationsAssessment class
  use strict arg assessment, reviewId, sourceRef
  if assessment == .nil then return .BrandNarrativeDirectiveResult~failure("COMMUNICATIONS_REVIEW_REQUIRED")
  if translate(assessment~class~id) \== "CMSNARRATIVEEVIDENCEASSESSMENT" then return .BrandNarrativeDirectiveResult~failure("COMMUNICATIONS_REVIEW_TYPE_INVALID")
  snapshot = assessment~toJson
  review = .BrandNarrativeExternalReview~new(reviewId, .BrandNarrativeDirectiveConstant~REVIEW_COMMUNICATIONS_NARRATIVE, sourceRef, assessment~status, assessment~reason, .BrandNarrativeDirectiveConstant~MODE_NO_DISPATCH, .BrandNarrativeDirectiveConstant~CLAIM_NOT_VERIFIED, .BrandNarrativeDirectiveConstant~MATURITY_LIBRARIAN_EXPERIMENTAL, snapshot)
  return review~seal
::method fromLibrarianPosition class
  use strict arg comparison, reviewId, sourceRef
  if comparison == .nil then return .BrandNarrativeDirectiveResult~failure("LIBRARIAN_POSITION_REQUIRED")
  if translate(comparison~class~id) \== "LIBRARIANPOSITIONCOMPARISON" then return .BrandNarrativeDirectiveResult~failure("LIBRARIAN_POSITION_TYPE_INVALID")
  if comparison~omissionAssessment \== "NOT_ESTABLISHED" then return .BrandNarrativeDirectiveResult~failure("LIBRARIAN_POSITION_OMISSION_AUTHORITY_ESCALATION")
  if comparison~biasVerdict \== "NOT_DETERMINED" then return .BrandNarrativeDirectiveResult~failure("LIBRARIAN_POSITION_BIAS_AUTHORITY_ESCALATION")
  snapshot = .BrandNarrativeDirectiveCanonical~field("EVENT_ID", comparison~eventId)
  snapshot ||= .BrandNarrativeDirectiveCanonical~field("PROPOSITION_ID", comparison~propositionId)
  snapshot ||= .BrandNarrativeDirectiveCanonical~field("COVERAGE", comparison~coverage)
  snapshot ||= .BrandNarrativeDirectiveCanonical~field("ARTICLES", comparison~articles)
  snapshot ||= .BrandNarrativeDirectiveCanonical~field("SOURCES", comparison~sources)
  snapshot ||= .BrandNarrativeDirectiveCanonical~field("ORIGINS", comparison~origins)
  snapshot ||= .BrandNarrativeDirectiveCanonical~field("SUPPORT", comparison~support)
  snapshot ||= .BrandNarrativeDirectiveCanonical~field("DISPUTE", comparison~dispute)
  snapshot ||= .BrandNarrativeDirectiveCanonical~field("NEUTRAL", comparison~neutral)
  snapshot ||= .BrandNarrativeDirectiveCanonical~field("UNCLASSIFIED", comparison~unclassified)
  snapshot ||= .BrandNarrativeDirectiveCanonical~field("OMISSION_ASSESSMENT", comparison~omissionAssessment)
  snapshot ||= .BrandNarrativeDirectiveCanonical~field("BIAS_VERDICT", comparison~biasVerdict)
  review = .BrandNarrativeExternalReview~new(reviewId, .BrandNarrativeDirectiveConstant~REVIEW_LIBRARIAN_POSITION, sourceRef, "POSITION_EVIDENCE_ONLY", "comparative positioning only; omission and bias remain unestablished", .BrandNarrativeDirectiveConstant~MODE_EVIDENCE_ONLY, .BrandNarrativeDirectiveConstant~CLAIM_NOT_VERIFIED, .BrandNarrativeDirectiveConstant~MATURITY_EXPERIMENTAL, snapshot)
  return review~seal
::method fromLibrarianOrigin class
  use strict arg originEvidence, reviewId, sourceRef, firstSource, secondSource
  if originEvidence == .nil then return .BrandNarrativeDirectiveResult~failure("LIBRARIAN_ORIGIN_REQUIRED")
  if translate(originEvidence~class~id) \== "LIBRARIANORIGINEVIDENCE" then return .BrandNarrativeDirectiveResult~failure("LIBRARIAN_ORIGIN_TYPE_INVALID")
  firstKey = firstSource~string~strip
  secondKey = secondSource~string~strip
  if firstKey == "" then return .BrandNarrativeDirectiveResult~failure("LIBRARIAN_ORIGIN_FIRST_SOURCE_REQUIRED")
  if secondKey == "" then return .BrandNarrativeDirectiveResult~failure("LIBRARIAN_ORIGIN_SECOND_SOURCE_REQUIRED")
  independence = originEvidence~independenceVerdict
  if independence \== "NOT_ESTABLISHED" then return .BrandNarrativeDirectiveResult~failure("LIBRARIAN_ORIGIN_INDEPENDENCE_AUTHORITY_ESCALATION")
  relationship = originEvidence~relationship(firstKey, secondKey)
  firstRoot = originEvidence~trace(firstKey)
  secondRoot = originEvidence~trace(secondKey)
  snapshot = .BrandNarrativeDirectiveCanonical~field("FIRST_SOURCE_ID", firstKey)
  snapshot ||= .BrandNarrativeDirectiveCanonical~field("SECOND_SOURCE_ID", secondKey)
  snapshot ||= .BrandNarrativeDirectiveCanonical~field("FIRST_DECLARED_ROOT", firstRoot)
  snapshot ||= .BrandNarrativeDirectiveCanonical~field("SECOND_DECLARED_ROOT", secondRoot)
  snapshot ||= .BrandNarrativeDirectiveCanonical~field("RELATIONSHIP", relationship)
  snapshot ||= .BrandNarrativeDirectiveCanonical~field("INDEPENDENCE_VERDICT", independence)
  snapshot ||= .BrandNarrativeDirectiveCanonical~field("ORIGIN_AUTHORITY", "DECLARED_NOT_VERIFIED")
  snapshot ||= .BrandNarrativeDirectiveCanonical~field("EDITORIAL_INDEPENDENCE", "NOT_ESTABLISHED")
  snapshot ||= .BrandNarrativeDirectiveCanonical~field("BIAS_VERDICT", "NOT_DETERMINED")
  snapshot ||= .BrandNarrativeDirectiveCanonical~field("CAUSAL_VERDICT", "NOT_DETERMINED")
  review = .BrandNarrativeExternalReview~new(reviewId, .BrandNarrativeDirectiveConstant~REVIEW_LIBRARIAN_ORIGIN, sourceRef, "DECLARED_ORIGIN_EVIDENCE_ONLY", "declared source lineage only; common roots are not verified provenance and different roots do not establish independence", .BrandNarrativeDirectiveConstant~MODE_EVIDENCE_ONLY, .BrandNarrativeDirectiveConstant~CLAIM_NOT_VERIFIED, .BrandNarrativeDirectiveConstant~MATURITY_EXPERIMENTAL, snapshot)
  return review~seal
::method fromLibrarianChange class
  use strict arg comparison, reviewId, sourceRef, eventId, propositionId
  if comparison == .nil then return .BrandNarrativeDirectiveResult~failure("LIBRARIAN_CHANGE_REQUIRED")
  if translate(comparison~class~id) \== "LIBRARIANCHANGECOMPARISON" then return .BrandNarrativeDirectiveResult~failure("LIBRARIAN_CHANGE_TYPE_INVALID")
  if comparison~biasVerdict \== "NOT_DETERMINED" then return .BrandNarrativeDirectiveResult~failure("LIBRARIAN_CHANGE_BIAS_AUTHORITY_ESCALATION")
  eventKey = eventId~string~strip
  propositionKey = propositionId~string~strip
  if eventKey == "" then return .BrandNarrativeDirectiveResult~failure("LIBRARIAN_CHANGE_EVENT_SCOPE_REQUIRED")
  if propositionKey == "" then return .BrandNarrativeDirectiveResult~failure("LIBRARIAN_CHANGE_PROPOSITION_SCOPE_REQUIRED")
  snapshot = .BrandNarrativeDirectiveCanonical~field("EVENT_ID", eventKey)
  snapshot ||= .BrandNarrativeDirectiveCanonical~field("PROPOSITION_ID", propositionKey)
  snapshot ||= .BrandNarrativeDirectiveCanonical~field("SCOPE_BINDING", "CALLER_SUPPLIED_NOT_VERIFIED_BY_COMPARISON")
  snapshot ||= .BrandNarrativeDirectiveCanonical~field("COVERAGE", comparison~coverage)
  snapshot ||= .BrandNarrativeDirectiveCanonical~field("ARTICLES", comparison~articles)
  snapshot ||= .BrandNarrativeDirectiveCanonical~field("SOURCES", comparison~sources)
  snapshot ||= .BrandNarrativeDirectiveCanonical~field("ORIGINS", comparison~origins)
  snapshot ||= .BrandNarrativeDirectiveCanonical~field("SUPPORT", comparison~support)
  snapshot ||= .BrandNarrativeDirectiveCanonical~field("DISPUTE", comparison~dispute)
  snapshot ||= .BrandNarrativeDirectiveCanonical~field("NEUTRAL", comparison~neutral)
  snapshot ||= .BrandNarrativeDirectiveCanonical~field("UNCLASSIFIED", comparison~unclassified)
  snapshot ||= .BrandNarrativeDirectiveCanonical~field("RETRACTED", comparison~retracted)
  snapshot ||= .BrandNarrativeDirectiveCanonical~field("CONFLICTED", comparison~conflicted)
  snapshot ||= .BrandNarrativeDirectiveCanonical~field("RETRACTION_MEANING", "RETRACTED_NOT_FALSE")
  snapshot ||= .BrandNarrativeDirectiveCanonical~field("OMISSION_ASSESSMENT", "NOT_ESTABLISHED")
  snapshot ||= .BrandNarrativeDirectiveCanonical~field("BIAS_VERDICT", comparison~biasVerdict)
  snapshot ||= .BrandNarrativeDirectiveCanonical~field("TRUTH_VERDICT", "NOT_DETERMINED")
  review = .BrandNarrativeExternalReview~new(reviewId, .BrandNarrativeDirectiveConstant~REVIEW_LIBRARIAN_CHANGE, sourceRef, "CHANGE_LINEAGE_EVIDENCE_ONLY", "revision/retraction/conflict evidence only; not truth, omission, bias, dispatch or publication authority", .BrandNarrativeDirectiveConstant~MODE_EVIDENCE_ONLY, .BrandNarrativeDirectiveConstant~CLAIM_NOT_VERIFIED, .BrandNarrativeDirectiveConstant~MATURITY_EXPERIMENTAL, snapshot)
  return review~seal

