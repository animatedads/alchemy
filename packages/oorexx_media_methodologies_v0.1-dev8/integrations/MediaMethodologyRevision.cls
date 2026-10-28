/* Consume EvidenceRevisionAudit classifications without duplicating Reasoned
 * Thought's evidence-combination authority.
 *
 * API: media.methodologies.revision/0.1
 */

::class MediaCandidateRevision public
::method init
  expose candidateRef classification lifecycle claimedMatchesDerived details
  use strict arg candidateRefArg,classificationArg,lifecycleArg,claimedMatchesDerivedArg=.nil,detailsArg=.nil
  candidateRef=candidateRefArg
  classification=translate(strip(classificationArg))
  lifecycle=translate(strip(lifecycleArg))
  claimedMatchesDerived=claimedMatchesDerivedArg
  if detailsArg=.nil then detailsArg=.Directory~new
  details=detailsArg
::attribute candidateRef get
::attribute classification get
::attribute lifecycle get
::attribute claimedMatchesDerived get
::method details
  expose details
  return details
::method allowsAutomaticCandidatePromotion
  return .false

::class MediaMethodologyRevisionBridge public
::method consume
  use strict arg candidateRef,auditResult
  if auditResult=.nil then raise syntax 93.900 array("Evidence revision result is required")
  classification=translate(strip(auditResult["classification"]))
  select
    when classification="NO_REVISION" then lifecycle="UNCHANGED"
    when classification="ADMITTED_DELTA_BACKED" then lifecycle="REVISED"
    when classification="MUTATED_GROUND_ID" | classification="UNVERIFIED_REMOVAL" then lifecycle="QUARANTINED"
    when classification="POLICY_CHANGE_REQUIRES_REVIEW" then lifecycle="REVIEW_REQUIRED"
    otherwise lifecycle="UNRESOLVED"
  end
  details=.Directory~new
  details["AUTHORITY_OWNER"]="EVIDENCE_REVISION_AUDIT"
  details["FACTUAL_TRUTH_CLAIM"]="FALSE"
  details["OBSERVATION_MUTATION"]="FALSE"
  details["AUDIT_RESULT"]=auditResult
  claimed=auditResult["claimedMatchesDerived"]
  return .MediaCandidateRevision~new(candidateRef,classification,lifecycle,claimed,details)
