/*
 * Brand Narrative Directive v0.1-dev4
 *
 * Connector-neutral bridge from the Brand evidence/governance stack to a
 * future runtime narrative authority such as Dynamic Story.
 *
 * This package deliberately stops before activation, publication, channel
 * delivery, prompt mutation, customer treatment, or content generation.
 */

::class BrandNarrativeDirectiveBuild public
::constant VERSION "0.1-dev4"
::constant API_VERSION "brand.narrative.directive/0.1"
::constant PRODUCT "ooRexx Brand Narrative Directive"

::class BrandNarrativeDirectiveConstant public
::constant STATUS_PROPOSED "PROPOSED_NOT_ACTIVE"
::constant AUTHORITY_EXTERNAL "EXTERNAL_NARRATIVE_AUTHORITY_REQUIRED"
::constant CAUSAL_ASSOCIATION_ONLY "ASSOCIATION_ONLY"

::constant EFFECT_NONE "NONE"
::constant EFFECT_ADAPT "ADAPT"
::constant EFFECT_CONTINUE "CONTINUE"
::constant EFFECT_PAUSE "PAUSE"
::constant EFFECT_WITHDRAW "WITHDRAW"

::constant ROLLOUT_NONE "NONE"
::constant ROLLOUT_CONTROLLED_PILOT "CONTROLLED_PILOT"
::constant ROLLOUT_LIMITED_EXPANSION "LIMITED_EXPANSION"
::constant ROLLOUT_CURRENT "CURRENT"

::constant KIND_EVIDENCE_ONLY "EVIDENCE_ONLY"
::constant KIND_PRESERVE_BASELINE "PRESERVE_BASELINE"
::constant KIND_PROPOSE_ADAPTATION "PROPOSE_ADAPTATION"
::constant KIND_CONTINUE_ADAPTATION "CONTINUE_ADAPTATION"
::constant KIND_PAUSE_ADAPTATION "PAUSE_ADAPTATION"
::constant KIND_WITHDRAW_ADAPTATION "WITHDRAW_ADAPTATION"

::constant SOURCE_COMMUNICATIONS "COMMUNICATIONS_DISCOVERY"
::constant SOURCE_LIBRARIAN "LIBRARIAN_V2"
::constant SOURCE_BRAND "BRAND_EVIDENCE"
::constant SOURCE_OTHER "OTHER"
::constant MODE_NO_DISPATCH "NO_DISPATCH"
::constant MODE_EVIDENCE_ONLY "EVIDENCE_ONLY"

::constant REVIEW_COMMUNICATIONS_NARRATIVE "COMMUNICATIONS_NARRATIVE_EVIDENCE"
::constant REVIEW_LIBRARIAN_POSITION "LIBRARIAN_POSITIONING"
::constant REVIEW_LIBRARIAN_CHANGE "LIBRARIAN_CHANGE_LINEAGE"
::constant REVIEW_LIBRARIAN_ORIGIN "LIBRARIAN_DECLARED_ORIGIN"
::constant CLAIM_NOT_VERIFIED "NOT_VERIFIED"
::constant MATURITY_LIBRARIAN_EXPERIMENTAL "LIBRARIAN_EXPERIMENTAL"
::constant MATURITY_EXPERIMENTAL "EXPERIMENTAL"

::constant HANDOFF_EVIDENCE_ONLY "EVIDENCE_ONLY_NO_RUNTIME_CHANGE"
::constant HANDOFF_READY_SELECTION "READY_FOR_NARRATIVE_SELECTION"
::constant HANDOFF_READY_EVIDENCE_REVIEW "READY_FOR_NARRATIVE_EVIDENCE_REVIEW"
::constant HANDOFF_HELD_EXTERNAL_REVIEW "HELD_EXTERNAL_REVIEW"
::constant HANDOFF_READY_EXTERNAL_AUTHORITY "READY_FOR_EXTERNAL_AUTHORITY_REVIEW"
::constant PUBLICATION_AUTHORITY_NONE "NONE"

::class BrandNarrativeDirectiveResult public
::attribute ok get
::attribute value get
::attribute code get
::attribute detail get
::method init
  expose ok value code detail
  use strict arg ok, value = .nil, code = "", detail = ""
::method success class
  use strict arg value = .nil, detail = ""
  return self~new(.true, value, "OK", detail)
::method failure class
  use strict arg code, detail = ""
  return self~new(.false, .nil, code, detail)

::class BrandNarrativeDirectiveCanonical public
::method token class
  use strict arg value
  if value == .nil then return ""
  text = value~string~strip~translate
  return changestr(" ", text, "_")
::method copyArray class
  use strict arg source
  out = .Array~new
  if source == .nil then return out
  do item over source
    out~append(item)
  end
  return out
::method appendUnique class
  use strict arg target, value
  if value == .nil then return .false
  text = value~string~strip
  if text == "" then return .false
  do item over target
    if item~string == text then return .false
  end
  target~append(text)
  return .true
::method field class
  use strict arg name, value
  return name~string || "=" || value~string || '0a'x
::method join class
  use strict arg name, values
  out = ""
  do item over values
    out ||= self~field(name, item)
  end
  return out

::class BrandNarrativeEvidenceReference subclass AlchemyObject public
::attribute evidenceId get
::attribute sourceKind get
::attribute sourceRef get
::attribute evidenceState get
::attribute observedAt get
::attribute authorityMode get
::attribute sealed get
::method init
  expose evidenceId sourceKind sourceRef evidenceState observedAt authorityMode sealed
  use strict arg evidenceId, sourceKind, sourceRef, evidenceState = "UNSPECIFIED", observedAt = "", authorityMode = "EVIDENCE_ONLY"
  sourceKind = .BrandNarrativeDirectiveCanonical~token(sourceKind)
  authorityMode = .BrandNarrativeDirectiveCanonical~token(authorityMode)
  evidenceState = .BrandNarrativeDirectiveCanonical~token(evidenceState)
  if evidenceId~string~strip == "" then raise syntax 93.900 array("BRAND_NARRATIVE_EVIDENCE_ID_REQUIRED")
  if sourceRef~string~strip == "" then raise syntax 93.900 array("BRAND_NARRATIVE_EVIDENCE_SOURCE_REF_REQUIRED")
  validSource = .false
  if sourceKind == .BrandNarrativeDirectiveConstant~SOURCE_COMMUNICATIONS then validSource = .true
  if sourceKind == .BrandNarrativeDirectiveConstant~SOURCE_LIBRARIAN then validSource = .true
  if sourceKind == .BrandNarrativeDirectiveConstant~SOURCE_BRAND then validSource = .true
  if sourceKind == .BrandNarrativeDirectiveConstant~SOURCE_OTHER then validSource = .true
  if \validSource then raise syntax 93.900 array("BRAND_NARRATIVE_EVIDENCE_SOURCE_KIND_INVALID")
  validMode = .false
  if authorityMode == .BrandNarrativeDirectiveConstant~MODE_NO_DISPATCH then validMode = .true
  if authorityMode == .BrandNarrativeDirectiveConstant~MODE_EVIDENCE_ONLY then validMode = .true
  if \validMode then raise syntax 93.900 array("BRAND_NARRATIVE_EVIDENCE_AUTHORITY_ESCALATION")
  sealed = .false
  meta = .Directory~new
  meta["purpose"] = "detached context/evidence reference; never runtime narrative authority"
  meta["package_version"] = .BrandNarrativeDirectiveBuild~VERSION
  meta["api_version"] = .BrandNarrativeDirectiveBuild~API_VERSION
  meta["component"] = "BRAND_NARRATIVE_DIRECTIVE"
  self~initAlchemy(meta)
  self~registerStateVariable("evidenceId", "INTERNAL", "local evidence reference id")
  self~registerStateVariable("sourceKind", "INTERNAL", "external evidence family")
  self~registerStateVariable("sourceRef", "INTERNAL", "opaque upstream evidence reference")
  self~registerStateVariable("evidenceState", "CUSTOMER", "upstream evidence state as supplied")
  self~registerStateVariable("observedAt", "CUSTOMER", "upstream observation time if supplied")
  self~registerStateVariable("authorityMode", "CUSTOMER", "NO_DISPATCH or EVIDENCE_ONLY")
  self~registerStateVariable("sealed", "CUSTOMER", "evidence reference immutability")
::method seal
  expose sealed
  sealed = .true
  return .BrandNarrativeDirectiveResult~success(self)
::method pointId
  expose evidenceId
  return "BRAND_NARRATIVE:EVIDENCE:" || evidenceId
::method toDirectory
  expose evidenceId sourceKind sourceRef evidenceState observedAt authorityMode sealed
  if \sealed then raise syntax 93.900 array("BRAND_NARRATIVE_EVIDENCE_NOT_SEALED")
  out = .Directory~new
  out["evidence_id"] = evidenceId
  out["source_kind"] = sourceKind
  out["source_ref"] = sourceRef
  out["evidence_state"] = evidenceState
  out["observed_at"] = observedAt
  out["authority_mode"] = authorityMode
  return out

