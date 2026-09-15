/* Optional bridge to current Institutional Policy.
 * RID policy remains the domain payload; Institutional Policy owns publication,
 * effective dating, governance and deployment lifecycle.
 */
::class RIDInstitutionalPolicyBridge public
::method release class
  use arg policy, effectiveFrom = .nil, effectiveUntil = .nil, authoredBy = "Federation Distribution Design", approvedBy = "Federation Distribution Governance", supersedes = ""
  if policy == .nil then raise syntax 88.986 array("RID policy required")
  if \policy~isA(.RIDDistributionPolicy) then raise syntax 88.986 array("RIDDistributionPolicy required")
  if \policy~sealed then raise syntax 88.986 array("RID policy must be sealed")
  if effectiveFrom == .nil then effectiveFrom = .DateTime~new
  return .InstitutionalPolicyRelease~new(policy~policyId, policy~version, effectiveFrom, effectiveUntil, authoredBy, approvedBy, supersedes, policy, policy~semanticIdentity)~seal
::method resolvePayload class
  use arg catalog, policyId, atTime = .nil
  if atTime == .nil then atTime = .DateTime~new
  r = catalog~resolve(policyId, atTime)
  if \r~ok then return .RIDResult~failure(r~code, r~detail)
  release = r~value
  payload = release~payload
  if payload == .nil then return .RIDResult~failure("POLICY_PAYLOAD_MISSING")
  if \payload~isA(.RIDDistributionPolicy) then return .RIDResult~failure("POLICY_PAYLOAD_WRONG_TYPE")
  if release~semanticIdentity = "" then return .RIDResult~failure("POLICY_RELEASE_IDENTITY_MISSING")
  return .RIDResult~success(payload, release~semanticIdentity)

::requires "RegulatedIntermediaryDistribution.cls"
::requires "InstitutionalPolicy.cls"
