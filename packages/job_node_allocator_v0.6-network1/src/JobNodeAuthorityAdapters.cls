/* Job-to-Node Allocator v0.5 authority adapters.
 * These adapters consume the existing authoritative decision objects. They do
 * not recreate Security Effect, Legal Effect or Access Permissions policy.
 */

::class JobNodeAuthorityEvidence public
::attribute securityAssessment get
::attribute legalAssessment get
::attribute accessDecision get
::attribute permissionDecision get
::method init
  expose securityAssessment legalAssessment accessDecision permissionDecision
  use arg securityArg=.nil, legalArg=.nil, accessArg=.nil, permissionArg=.nil
  securityAssessment=securityArg
  legalAssessment=legalArg
  accessDecision=accessArg
  permissionDecision=permissionArg

::class JobNodeDecisionObjectAssessor subclass JobNodeHardConstraintAssessor public
::method init
  expose evidenceResolver
  use arg resolverArg
  evidenceResolver=resolverArg

::method assess
  expose evidenceResolver
  use arg placementRequest, capability, capacity, nowEpochMs
  reasons=.array~new
  if evidenceResolver==.nil then do
    reasons~append("AUTHORITY_EVIDENCE_RESOLVER_MISSING")
    return reasons
  end
  evidence=evidenceResolver~evidenceFor(placementRequest,capability,capacity,nowEpochMs)
  if evidence==.nil then do
    reasons~append("AUTHORITY_EVIDENCE_MISSING")
    return reasons
  end

  s=evidence~securityAssessment
  if s==.nil then reasons~append("SECURITY_ASSESSMENT_MISSING")
  else do
    d=s~disposition~string~upper
    /* ALLOW and CAUTION are executable Security Effect outcomes. Review/Hold/
     * Reject are not eligible for automatic placement. */
    if d<>"ALLOW" & d<>"CAUTION" then reasons~append("SECURITY_" || d)
  end

  l=evidence~legalAssessment
  if l==.nil then reasons~append("LEGAL_ASSESSMENT_MISSING")
  else if l~status~string~upper<>"ADMISSIBLE" then reasons~append("LEGAL_" || l~status~string~upper)

  a=evidence~accessDecision
  if a==.nil then reasons~append("ACCESS_DECISION_MISSING")
  else if \a~allowed then reasons~append("ACCESS_" || a~code~string~upper)

  p=evidence~permissionDecision
  if p==.nil then reasons~append("PERMISSION_DECISION_MISSING")
  else if \p~allowed then reasons~append("PERMISSION_" || p~code~string~upper)

  return reasons

/* Simple deterministic resolver useful where the caller has already obtained
 * authoritative decisions for each candidate node. */
::class JobNodeAuthorityEvidenceMap public
::method init
  expose rows
  rows=.directory~new
::method put
  expose rows
  use arg nodeId, evidence
  rows[nodeId~string~upper]=evidence
  return self
::method evidenceFor
  expose rows
  use arg placementRequest, capability, capacity, nowEpochMs
  return rows[capability~nodeId~string~upper]

::requires "JobNodeAllocator.cls"
