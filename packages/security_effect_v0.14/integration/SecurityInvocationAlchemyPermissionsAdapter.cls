/* Invocation-aware Access Permissions adapter for Alchemy Security Manager.
 *
 * The adapter derives a fresh SecurityInvocationEvidence object at the actual
 * METHOD checkpoint. A domain resolver supplies deterministic identities for
 * the live argument vector and live invocation context; the adapter supplies
 * the unique invocation id and observation time itself. The Security assessment
 * must bind that exact evidence before PermissionAuthority is consulted.
 *
 * Security evidence remains non-authoritative. Access Permissions still decides
 * execution, and the Security Manager remains the physical enforcement point.
 */

::class SecurityInvocationAlchemyPermissionPolicyAdapter public
::attribute decisionEnvelopes get
::attribute invocationValidations get
::method init
  expose principal permissionPolicy permissionAuthority securityEffectResolver invocationIdentityResolver invocationPolicy invocationGuard fallbackPolicy decisionEnvelopes invocationValidations counter
  use strict arg principalArg, permissionPolicyArg, permissionAuthorityArg, securityEffectResolverArg, invocationIdentityResolverArg, invocationPolicyArg, invocationGuardArg = .nil, fallbackPolicyArg = .nil
  if principalArg == .nil | \principalArg~sealed then raise syntax 88.900 array("invocation-aware permission adapter requires sealed principal")
  if permissionPolicyArg == .nil | \permissionPolicyArg~sealed then raise syntax 88.900 array("invocation-aware permission adapter requires sealed Permission policy")
  if permissionAuthorityArg == .nil then raise syntax 88.900 array("invocation-aware permission adapter requires PermissionAuthority")
  if securityEffectResolverArg == .nil | \securityEffectResolverArg~hasMethod("ASSESSMENTFORINVOCATION") then raise syntax 88.900 array("Security Effect resolver must implement assessmentForInvocation")
  if invocationIdentityResolverArg == .nil | \invocationIdentityResolverArg~hasMethod("ARGUMENTIDENTITYFOR") | \invocationIdentityResolverArg~hasMethod("CONTEXTIDENTITYFOR") then raise syntax 88.900 array("invocation identity resolver must implement argumentIdentityFor and contextIdentityFor")
  if invocationPolicyArg == .nil | \invocationPolicyArg~sealed then raise syntax 88.900 array("sealed Security invocation policy required")
  principal = principalArg
  permissionPolicy = permissionPolicyArg
  permissionAuthority = permissionAuthorityArg
  securityEffectResolver = securityEffectResolverArg
  invocationIdentityResolver = invocationIdentityResolverArg
  invocationPolicy = invocationPolicyArg
  if invocationGuardArg == .nil then invocationGuard = .SecurityInvocationGuard~new
  else invocationGuard = invocationGuardArg
  fallbackPolicy = fallbackPolicyArg
  decisionEnvelopes = .array~new
  invocationValidations = .array~new
  counter = 0

::method evaluate public
  expose principal permissionPolicy permissionAuthority securityEffectResolver invocationIdentityResolver invocationPolicy invocationGuard fallbackPolicy decisionEnvelopes invocationValidations counter
  use strict arg checkpoint, info, legacyAuthority = .nil
  checkpoint = checkpoint~string~upper
  if checkpoint <> "METHOD" then do
    if fallbackPolicy <> .nil then return fallbackPolicy~evaluate(checkpoint, info, legacyAuthority)
    return .AlchemySecurityDecision~new(.false, "invocation-aware Permission adapter governs METHOD only")
  end
  if info == .nil | \info~hasIndex("OBJECT") | \info~hasIndex("NAME") then return .AlchemySecurityDecision~new(.false, "incomplete METHOD checkpoint evidence")
  obj = info["OBJECT"]
  methodName = info["NAME"]~string~upper
  args = .array~new
  if info~hasIndex("ARGUMENTS") then if info["ARGUMENTS"] <> .nil then args = info["ARGUMENTS"]

  argIdentity = invocationIdentityResolver~argumentIdentityFor(principal~principalId, obj, methodName, args, info)
  contextIdentity = invocationIdentityResolver~contextIdentityFor(principal~principalId, obj, methodName, args, info)
  if argIdentity == .nil then argIdentity = ""
  if contextIdentity == .nil then contextIdentity = ""
  counter += 1
  invocationId = "ALCHEMY-INV:" || principal~principalId || ":" || methodName || ":" || counter
  evidence = .SecurityInvocationEvidence~new(invocationId, argIdentity~string, contextIdentity~string, .DateTime~new)~seal

  effectResult = securityEffectResolver~assessmentForInvocation(principal~principalId, obj, methodName, args, info, evidence)
  if effectResult == .nil then return .AlchemySecurityDecision~new(.false, "Security Effect resolver returned no assessment")
  if effectResult~hasMethod("OK") then do
    if \effectResult~ok then return .AlchemySecurityDecision~new(.false, "Security Effect failed: " || effectResult~code)
    assessment = effectResult~value
  end
  else assessment = effectResult
  if assessment == .nil | \assessment~hasMethod("DISPOSITION") then return .AlchemySecurityDecision~new(.false, "Security Effect assessment invalid")

  requestId = "ALCHEMY-INV-PERM:" || principal~principalId || ":" || methodName || ":" || counter
  bridge = .SecurityAccessPermissionsBridge~new
  prepared = bridge~permissionRequestForInvocation(requestId, assessment, evidence, invocationPolicy, invocationGuard, .DateTime~new)
  if \prepared~ok then return .AlchemySecurityDecision~new(.false, "Security invocation binding failed: " || prepared~code)
  prep = prepared~value
  permissionResult = permissionAuthority~decide(prep~request, permissionPolicy)
  if \permissionResult~ok then return .AlchemySecurityDecision~new(.false, "Permission evaluation failed: " || permissionResult~code)
  envelope = permissionResult~value
  ignore = decisionEnvelopes~append(envelope)
  decision = envelope~decision
  if \decision~allowed then return .AlchemySecurityDecision~new(.false, decision~code || ":" || decision~reason)
  committed = prep~commitIfAllowed(permissionResult)
  if \committed~ok then return .AlchemySecurityDecision~new(.false, "Security invocation consume failed: " || committed~code)
  ignore = invocationValidations~append(prep~validation)
  return .AlchemySecurityDecision~new(.true, decision~code || ":" || decision~reason)

::requires "SecurityAccessPermissionsBridge.cls"
::requires "AlchemySecurity.cls"
