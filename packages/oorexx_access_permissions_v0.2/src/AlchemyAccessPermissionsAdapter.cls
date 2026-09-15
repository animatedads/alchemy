/* Thin adapter from AlchemySecurityManager policy contract to PermissionAuthority.
 * Security Manager remains the enforcement point.  This adapter only decides.
 */

::class AlchemyPermissionPolicyAdapter public
::attribute decisionEnvelopes get
::method init
  expose principal permissionPolicy permissionAuthority securityEffectResolver fallbackPolicy decisionEnvelopes counter
  use strict arg principalArg, permissionPolicyArg, permissionAuthorityArg, securityEffectResolverArg, fallbackPolicyArg = .nil
  if principalArg == .nil | \principalArg~sealed then raise syntax 88.900 array("Alchemy permission adapter requires sealed attributed principal")
  if permissionPolicyArg == .nil | \permissionPolicyArg~sealed then raise syntax 88.900 array("Alchemy permission adapter requires sealed permission policy")
  if permissionAuthorityArg == .nil then raise syntax 88.900 array("Alchemy permission adapter requires PermissionAuthority")
  if securityEffectResolverArg == .nil then raise syntax 88.900 array("Alchemy permission adapter requires Security Effect resolver")
  principal = principalArg
  permissionPolicy = permissionPolicyArg
  permissionAuthority = permissionAuthorityArg
  securityEffectResolver = securityEffectResolverArg
  fallbackPolicy = fallbackPolicyArg
  decisionEnvelopes = .array~new
  counter = 0

::method evaluate public
  expose principal permissionPolicy permissionAuthority securityEffectResolver fallbackPolicy decisionEnvelopes counter
  use strict arg checkpoint, info, legacyAuthority = .nil
  checkpoint = checkpoint~string~upper
  if checkpoint <> "METHOD" then do
    if fallbackPolicy <> .nil then return fallbackPolicy~evaluate(checkpoint, info, legacyAuthority)
    return .AlchemySecurityDecision~new(.false, "permission adapter governs METHOD only; no fallback policy for " || checkpoint)
  end
  if info == .nil | \info~hasIndex("OBJECT") | \info~hasIndex("NAME") then return .AlchemySecurityDecision~new(.false, "incomplete METHOD checkpoint evidence")
  obj = info["OBJECT"]
  methodName = info["NAME"]~string~upper
  if obj~hasMethod("ALCHEMYOBJECTID") then objectId = obj~alchemyObjectId
  else objectId = obj~identityHash~string
  objectClass = obj~class~id~string~upper
  args = .array~new
  if info~hasIndex("ARGUMENTS") then if info["ARGUMENTS"] <> .nil then args = info["ARGUMENTS"]

  effectResult = securityEffectResolver~assessmentFor(principal~principalId, obj, methodName, args, info)
  if effectResult == .nil then return .AlchemySecurityDecision~new(.false, "Security Effect resolver returned no assessment")
  if effectResult~hasMethod("OK") then do
    if \effectResult~ok then return .AlchemySecurityDecision~new(.false, "Security Effect failed: " || effectResult~code)
    assessment = effectResult~value
  end
  else assessment = effectResult
  if assessment == .nil | \assessment~hasMethod("DISPOSITION") then return .AlchemySecurityDecision~new(.false, "Security Effect assessment invalid")

  counter += 1
  requestId = "ALCHEMY:" || principal~principalId || ":" || objectId || ":" || methodName || ":" || counter
  request = .PermissionRequest~new(requestId, principal~principalId, objectId, objectClass, methodName, .DateTime~new)
  if \request~bindSecurityAssessment(assessment) then return .AlchemySecurityDecision~new(.false, "Security Effect subject mismatch")
  request~seal
  result = permissionAuthority~decide(request, permissionPolicy)
  if \result~ok then return .AlchemySecurityDecision~new(.false, "permission evaluation failed: " || result~code)
  envelope = result~value
  decisionEnvelopes~append(envelope)
  decision = envelope~decision
  return .AlchemySecurityDecision~new(decision~allowed, decision~code || ":" || decision~reason)


/* Executable composition of the two distinct authority layers.
 *
 * AlchemyAccessControlledDomain is the building/domain boundary.  It requires
 * cryptographic attribution for the exact AccessControlRequest and an
 * Access Control ALLOW before it creates a session.  The resulting session's
 * Security Manager still performs a separate PermissionAuthority decision for
 * every protected METHOD checkpoint.  The Access Control receipt is retained
 * as evidence and is never accepted as a method capability.
 */
::class AlchemyAccessControlledSession public
::attribute sessionId get
::attribute principal get
::attribute principalId get
::attribute domainId get
::attribute accessDecisionEnvelope get
::attribute permissionAdapter get
::attribute securityManager get
::attribute enteredAt get
::method init
  expose sessionId principal principalId domainId accessDecisionEnvelope permissionAdapter securityManager enteredAt
  use strict arg sessionIdArg, principalArg, domainIdArg, accessEnvelopeArg, permissionAdapterArg, securityManagerArg, enteredAtArg = .nil
  if principalArg == .nil | \principalArg~sealed then raise syntax 88.900 array("access-controlled session requires sealed principal")
  if accessEnvelopeArg == .nil | accessEnvelopeArg~kind <> "ACCESS_CONTROL" then raise syntax 88.900 array("access-controlled session requires Access Control decision envelope")
  if \accessEnvelopeArg~decision~allowed then raise syntax 88.900 array("denied Access Control decision cannot create session")
  sessionId = sessionIdArg~string
  principal = principalArg
  principalId = principal~principalId
  domainId = domainIdArg~string~upper
  accessDecisionEnvelope = accessEnvelopeArg
  permissionAdapter = permissionAdapterArg
  securityManager = securityManagerArg
  if enteredAtArg == .nil then enteredAt = .DateTime~new
  else enteredAt = enteredAtArg
::method secure
  expose securityManager
  use strict arg executable
  if executable == .nil | \executable~hasMethod("SETSECURITYMANAGER") then raise syntax 88.900 array("secure requires executable with setSecurityManager")
  executable~setSecurityManager(securityManager)
  return executable
::method canonicalText
  expose sessionId principalId domainId accessDecisionEnvelope enteredAt
  text = "ALCHEMY-ACCESS-CONTROLLED-SESSION/1" || '0a'x
  text ||= .AccessPermissionsCanonical~field("SESSION_ID", sessionId)
  text ||= .AccessPermissionsCanonical~field("PRINCIPAL_ID", principalId)
  text ||= .AccessPermissionsCanonical~field("DOMAIN_ID", domainId)
  text ||= .AccessPermissionsCanonical~field("ACCESS_DECISION_IDENTITY", accessDecisionEnvelope~semanticIdentity)
  text ||= .AccessPermissionsCanonical~field("ENTERED_AT", enteredAt)
  return text
::method semanticIdentity
  return self~canonicalText

::class AlchemyAccessControlledDomain public
::attribute domainId get
::attribute accessPolicy get
::attribute permissionPolicy get
::method init
  expose domainId accessPolicy accessAuthority permissionPolicy permissionAuthority securityEffectResolver fallbackPolicy runtimeProfile quotaSet requireAccessProof
  use strict arg domainIdArg, accessPolicyArg, accessAuthorityArg, permissionPolicyArg, permissionAuthorityArg, securityEffectResolverArg, fallbackPolicyArg = .nil, runtimeProfileArg = .nil, quotaSetArg = .nil, requireAccessProofArg = .true
  domainId = domainIdArg~string~upper
  accessPolicy = accessPolicyArg
  accessAuthority = accessAuthorityArg
  permissionPolicy = permissionPolicyArg
  permissionAuthority = permissionAuthorityArg
  securityEffectResolver = securityEffectResolverArg
  fallbackPolicy = fallbackPolicyArg
  runtimeProfile = runtimeProfileArg
  quotaSet = quotaSetArg
  requireAccessProof = requireAccessProofArg
  if domainId = "" then raise syntax 88.900 array("access-controlled domain id required")
  if accessPolicy == .nil | \accessPolicy~sealed then raise syntax 88.900 array("access-controlled domain requires sealed Access Control policy")
  if accessAuthority == .nil then raise syntax 88.900 array("access-controlled domain requires AccessControlAuthority")
  if permissionPolicy == .nil | \permissionPolicy~sealed then raise syntax 88.900 array("access-controlled domain requires sealed Permission policy")
  if permissionAuthority == .nil then raise syntax 88.900 array("access-controlled domain requires PermissionAuthority")
  if securityEffectResolver == .nil then raise syntax 88.900 array("access-controlled domain requires Security Effect resolver")
::method enter
  expose domainId accessPolicy accessAuthority permissionPolicy permissionAuthority securityEffectResolver fallbackPolicy runtimeProfile quotaSet requireAccessProof
  use strict arg accessRequest, principal, assertion
  if accessRequest == .nil | \accessRequest~sealed then return .AccessPermissionsResult~failure("ACCESS_REQUEST_NOT_SEALED")
  if principal == .nil | \principal~sealed then return .AccessPermissionsResult~failure("ACCESS_PRINCIPAL_REQUIRED")
  if assertion == .nil then return .AccessPermissionsResult~failure("ACCESS_ATTRIBUTION_REQUIRED")
  if accessRequest~principalId <> principal~principalId then return .AccessPermissionsResult~failure("ACCESS_PRINCIPAL_MISMATCH")
  if accessRequest~domainId <> domainId then return .AccessPermissionsResult~failure("ACCESS_DOMAIN_MISMATCH")

  accessResult = accessAuthority~decide(accessRequest, accessPolicy, assertion, principal)
  if \accessResult~ok then return accessResult
  envelope = accessResult~value
  if envelope == .nil | envelope~kind <> "ACCESS_CONTROL" then return .AccessPermissionsResult~failure("ACCESS_DECISION_INVALID")
  if \envelope~decision~allowed then return .AccessPermissionsResult~failure("ACCESS_DENIED", envelope~decision~reason, envelope)
  if requireAccessProof & \envelope~proved then return .AccessPermissionsResult~failure("ACCESS_PROOF_REQUIRED", "protected domain requires cryptographically proved Access Control ALLOW", envelope)

  adapter = .AlchemyPermissionPolicyAdapter~new(principal, permissionPolicy, permissionAuthority, securityEffectResolver, fallbackPolicy)
  manager = .AlchemySecurityManager~new(adapter, .nil, runtimeProfile, quotaSet)
  enteredAt = .DateTime~new
  seed = principal~principalId || "|" || domainId || "|" || envelope~semanticIdentity || "|" || enteredAt~string
  sessionId = "ACCESS-SESSION:" || .AccessPermissionsCanonical~hash(seed)
  session = .AlchemyAccessControlledSession~new(sessionId, principal, domainId, envelope, adapter, manager, enteredAt)
  return .AccessPermissionsResult~success(session, "Access Control admitted principal; method authority remains with Security Manager + PermissionAuthority")

::requires 'AccessPermissions.cls'
::requires 'AlchemySecurity.cls'
