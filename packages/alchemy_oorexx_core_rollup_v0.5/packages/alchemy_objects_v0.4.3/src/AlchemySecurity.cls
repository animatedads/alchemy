/* AlchemySecurity.cls - Alchemy Objects v0.4.3
 * ooRexx Security Manager policy + delegated cryptographic capabilities.
 */

::class AlchemyCapability public
::attribute schema get
::attribute capabilityId get
::attribute subject get
::attribute objectId get
::attribute operation get
::attribute purpose get
::attribute issuedAt get
::attribute validUntil get
::attribute nonce get
::attribute algorithm get
::attribute keyId get
::attribute tag get

::method init
  expose schema capabilityId subject objectId operation purpose issuedAt validUntil nonce algorithm keyId tag claims
  use strict arg capabilityId, subject, objectId, operation, purpose, issuedAt, validUntil, nonce, algorithm, keyId, tag, claims = .nil
  schema = "alchemy.objects.capability/0.2"
  capabilityId = capabilityId~string
  subject = subject~string
  objectId = objectId~string
  operation = operation~string~translate
  purpose = purpose~string~translate
  issuedAt = issuedAt~string
  validUntil = validUntil~string
  nonce = nonce~string
  algorithm = algorithm~string
  keyId = keyId~string
  tag = tag~string~lower
  if claims == .nil then claims = .directory~new
  else do
    if \claims~isA(.Directory) & \claims~isA(.Table) then raise syntax 88.900 array("Alchemy capability claims must be a Directory or Table")
    copiedClaims = .directory~new
    do claimName over claims~allIndexes
      copiedClaims[claimName~string] = claims~at(claimName)
    end
    claims = copiedClaims
  end

::method claim public
  expose claims
  use strict arg name, defaultValue = ""
  name = name~string
  if claims~hasIndex(name) then return claims~at(name)
  return defaultValue

::method claimsDirectory public
  expose claims
  out = .directory~new
  do claimName over claims~allIndexes
    out[claimName~string] = claims~at(claimName)
  end
  return out

::method unsignedDirectory public
  expose schema capabilityId subject objectId operation purpose issuedAt validUntil nonce claims
  d = .directory~new
  d["schema"] = schema
  d["capability_id"] = capabilityId
  d["subject"] = subject
  d["object_id"] = objectId
  d["operation"] = operation
  d["purpose"] = purpose
  d["issued_at"] = issuedAt
  d["valid_until"] = validUntil
  d["nonce"] = nonce
  d["claims"] = self~claimsDirectory
  return d


::class AlchemyCapabilityAuthority public
::method init
  expose keyRing used revoked counter
  use strict arg keyRing
  if keyRing == .nil then raise syntax 88.900 array("AlchemyCapabilityAuthority requires CryptoMacKeyRing")
  used = .table~new
  revoked = .table~new
  counter = 0

::method issue public
  expose keyRing counter
  use strict arg subject, objectId, operation, purpose, validUntil = "", nonce = "", claims = .nil
  guard on
  if validUntil \= "" then if \self~validExpiryStamp(validUntil) then raise syntax 88.900 array("Alchemy capability validUntil must be DAY:SECOND-OF-DAY")
  counter = counter + 1
  issuedAt = date("S") || "T" || time("L")
  if nonce = "" then nonce = objectId~string || ":" || counter || ":" || random(100000,999999)
  capabilityId = keyRing~activeKeyId || ":" || counter || ":" || nonce
  temp = .AlchemyCapability~new(capabilityId, subject, objectId, operation, purpose, issuedAt, validUntil, nonce, "", "", "", claims)
  canonical = .AlchemyCanonical~encode(temp~unsignedDirectory)
  proof = keyRing~sign(canonical)
  return .AlchemyCapability~new(capabilityId, subject, objectId, operation, purpose, issuedAt, validUntil, nonce, proof~algorithm, proof~keyId, proof~tag, claims)

::method issueForSeconds public
  use strict arg subject, objectId, operation, purpose, lifetimeSeconds, nonce = "", claims = .nil
  if \datatype(lifetimeSeconds~string, "W") then raise syntax 88.900 array("Alchemy capability lifetime must be whole seconds")
  lifetimeSeconds = lifetimeSeconds + 0
  if lifetimeSeconds <= 0 then raise syntax 88.900 array("Alchemy capability lifetime must be greater than zero")
  day = date("B") + 0
  secondOfDay = (time("S") + 0) + lifetimeSeconds
  day = day + (secondOfDay % 86400)
  secondOfDay = secondOfDay // 86400
  validUntil = day || ":" || secondOfDay
  return self~issue(subject, objectId, operation, purpose, validUntil, nonce, claims)

::method verify public
  expose keyRing used revoked
  use strict arg capability, expectedObjectId, expectedOperation, expectedPurpose, consume = .false
  guard on
  if capability == .nil then return .false
  if \capability~isA(.AlchemyCapability) then return .false
  if revoked~hasIndex(capability~capabilityId) then return .false
  if capability~objectId \= expectedObjectId~string then return .false
  if capability~operation \= expectedOperation~string~translate then return .false
  if capability~purpose \= expectedPurpose~string~translate then return .false
  if capability~validUntil \= "" then do
    if \self~validExpiryStamp(capability~validUntil) then return .false
    if self~expiryExpired(capability~validUntil) then return .false
  end
  if consume & used~hasIndex(capability~capabilityId) then return .false
  canonical = .AlchemyCanonical~encode(capability~unsignedDirectory)
  proof = .CryptoMacProof~new(capability~algorithm, capability~keyId, capability~tag)
  if \keyRing~verify(canonical, proof) then return .false
  if consume then used[capability~capabilityId] = .true
  return .true

::method revoke public
  expose revoked
  use strict arg capabilityId
  guard on
  revoked[capabilityId~string] = .true
  return .true

::method validExpiryStamp private
  use strict arg stamp
  parse var stamp day ":" secondOfDay ":" extra
  if day = "" | secondOfDay = "" | extra \= "" then return .false
  if \datatype(day, "W") | \datatype(secondOfDay, "W") then return .false
  if day < 0 | secondOfDay < 0 | secondOfDay >= 86400 then return .false
  return .true

::method expiryExpired private
  use strict arg stamp
  parse var stamp expiryDay ":" expirySecond
  nowDay = date("B") + 0
  nowSecond = time("S") + 0
  if nowDay > expiryDay then return .true
  if nowDay < expiryDay then return .false
  return nowSecond > expirySecond


::class AlchemySecurityRuntimeProfile public
::attribute name get
::attribute versionText get
::attribute continueProcessingReturn get
::attribute handledReturn get
::attribute observed get

::method init
  expose name versionText continueProcessingReturn handledReturn observed
  use strict arg name, versionText, continueProcessingReturn, handledReturn, observed = .true
  name = name
  versionText = versionText
  continueProcessingReturn = continueProcessingReturn
  handledReturn = handledReturn
  observed = observed

/* Compatibility accessor retained for v0.1/v0.2 callers.  "Continue normal
 * processing" is the precise meaning; "allow" was too easy to confuse with
 * the policy decision itself. */
::method allowReturn public
  expose continueProcessingReturn
  return continueProcessingReturn

::method evidence public
  expose name versionText continueProcessingReturn handledReturn observed
  d = .directory~new
  d["schema"] = "alchemy.objects.security-runtime-profile/0.1"
  d["name"] = name
  d["version_text"] = versionText
  d["continue_processing_return"] = continueProcessingReturn
  d["handled_return"] = handledReturn
  d["observed"] = observed
  d["reference_source"] = "Open Object Rexx Reference Chapter 13.1"
  d["reference_continue_processing_return"] = .false
  d["reference_handled_return"] = .true
  d["matches_reference"] = continueProcessingReturn == .false & handledReturn == .true
  return d

::method observedR13196 class public
  parse version v
  return self~new("oorexx-5.3.0-r13196-observed", v, .false, .true, .true)

/* Select the executable profile from observed interpreter behaviour, not from
 * a version-string whitelist.  The first successful probe is cached on the
 * class object for the lifetime of the process. */
::method current class public
  expose cachedCurrent
  if symbol("cachedCurrent") = "VAR" then return cachedCurrent
  parse version v
  cachedCurrent = self~probeCurrent(v)
  return cachedCurrent

::method probeCurrent class private
  use strict arg versionText
  falseProbe = self~probeReturn(.false)
  trueProbe = self~probeReturn(.true)

  falseContinues = falseProbe["ok"] & falseProbe["result"] == "ALCHEMY-PROBE-BODY"
  falseHandles = falseProbe["ok"] & falseProbe["result"] == "ALCHEMY-PROBE-HANDLED-FALSE"
  trueContinues = trueProbe["ok"] & trueProbe["result"] == "ALCHEMY-PROBE-BODY"
  trueHandles = trueProbe["ok"] & trueProbe["result"] == "ALCHEMY-PROBE-HANDLED-TRUE"

  if falseContinues & trueHandles then
    return self~new("runtime-probed-reference-semantics", versionText, .false, .true, .true)
  if trueContinues & falseHandles then
    return self~new("runtime-probed-nonreference-semantics", versionText, .true, .false, .false)

  /* A METHOD checkpoint that is reversed, ambiguous, missing, or internally
   * inconsistent is not enough evidence to generalize across CALL, COMMAND,
   * STREAM, LOCAL, ENVIRONMENT, and other checkpoints.  Fail closed. */
  return self~new("runtime-probe-unverified", versionText, .false, .true, .false)

::method probeReturn class private
  use strict arg returnValue
  lines = .array~of("use strict arg target", "return target~alchemySecuritySemanticsProbe")
  routine = .Routine~new("AlchemySecuritySemanticsProbe", lines)
  if returnValue == .false then marker = "ALCHEMY-PROBE-HANDLED-FALSE"
  else marker = "ALCHEMY-PROBE-HANDLED-TRUE"
  manager = .AlchemySecurityProbeManager~new(returnValue, marker)
  routine~setSecurityManager(manager)
  resultRecord = .directory~new
  resultRecord["ok"] = .false
  signal on syntax name probeFailed
  probeValue = routine~call(.AlchemySecurityProbeTarget~new)
  signal off syntax
  resultRecord["ok"] = manager~hits == 1
  resultRecord["result"] = probeValue
  resultRecord["hits"] = manager~hits
  return resultRecord
probeFailed:
  signal off syntax
  resultRecord["result"] = ""
  resultRecord["hits"] = manager~hits
  return resultRecord

::method documented class public
  parse version v
  /* ooRexx Reference chapter 13: .false authorizes/continues normal
   * processing; .true means the Security Manager performed the action. */
  return self~new("oorexx-reference-documented", v, .false, .true, .false)




::class AlchemySecurityProbeTarget
::method alchemySecuritySemanticsProbe protected
  return "ALCHEMY-PROBE-BODY"


::class AlchemySecurityProbeManager
::attribute hits get

::method init
  expose returnValue handledMarker hits
  use strict arg returnValue, handledMarker
  hits = 0

::method method
  expose returnValue handledMarker hits
  use strict arg info
  hits = hits + 1
  info["RESULT"] = handledMarker
  return returnValue


::class AlchemySecurityDecision public
::attribute allowed get
::attribute reason get
::attribute purpose get
::attribute capabilityArg get

::method init
  expose allowed reason purpose capabilityArg
  use strict arg allowed, reason = "", purpose = "", capabilityArg = 0
  allowed = allowed
  reason = reason~string
  purpose = purpose~string~translate
  capabilityArg = capabilityArg


::class AlchemySecurityRule public
::attribute checkpoint get
::attribute namePattern get
::attribute classPattern get
::attribute action get
::attribute purpose get
::attribute capabilityArg get
::attribute consumeCapability get

::method init
  expose checkpoint namePattern classPattern action purpose capabilityArg consumeCapability
  use strict arg checkpoint, namePattern = "*", classPattern = "*", action = "ALLOW", purpose = "", capabilityArg = 0, consumeCapability = .true
  checkpoint = checkpoint~string~translate
  namePattern = namePattern~string~translate
  classPattern = classPattern~string~translate
  action = action~string~translate
  purpose = purpose~string~translate
  capabilityArg = capabilityArg
  consumeCapability = consumeCapability

::method matches public
  expose checkpoint namePattern classPattern
  use strict arg checkpointName, targetName, targetClass = ""
  if checkpoint \= checkpointName~string~translate then return .false
  if \self~wild(targetName~string~translate, namePattern) then return .false
  if \self~wild(targetClass~string~translate, classPattern) then return .false
  return .true

::method wild private
  use strict arg value, pattern
  if pattern = "*" then return .true
  star = pattern~pos("*")
  if star = 0 then return value = pattern
  before = pattern~left(star - 1)
  after = pattern~substr(star + 1)
  if before \= "" then if value~left(before~length) \= before then return .false
  if after \= "" then if value~right(after~length) \= after then return .false
  return .true


::class AlchemySecurityPolicy public
::attribute defaultAction get

::method init
  expose rules defaultAction
  use strict arg defaultAction = "DENY"
  rules = .array~new
  defaultAction = defaultAction~string~translate

::method allow public
  expose rules
  use strict arg checkpoint, namePattern = "*", classPattern = "*"
  rules~append(.AlchemySecurityRule~new(checkpoint, namePattern, classPattern, "ALLOW"))
  return self

::method deny public
  expose rules
  use strict arg checkpoint, namePattern = "*", classPattern = "*"
  rules~append(.AlchemySecurityRule~new(checkpoint, namePattern, classPattern, "DENY"))
  return self

::method requireCapability public
  expose rules
  use strict arg namePattern, classPattern, purpose, capabilityArg = 0, consumeCapability = .true
  rules~append(.AlchemySecurityRule~new("METHOD", namePattern, classPattern, "CAPABILITY", purpose, capabilityArg, consumeCapability))
  return self

::method evaluate public
  expose rules defaultAction
  use strict arg checkpoint, info, authority = .nil
  targetName = ""
  targetClass = ""
  if info~hasIndex("NAME") then targetName = info["NAME"]~string
  if checkpoint~string~translate = "COMMAND" & info~hasIndex("COMMAND") then targetName = info["COMMAND"]~string
  if checkpoint~string~translate = "METHOD" & info~hasIndex("OBJECT") then do
    obj = info["OBJECT"]
    targetClass = obj~class~id
  end

  /* Deny rules always win, then capability rules, then allow rules. */
  do pass = 1 to 3
    do rule over rules
      if \rule~matches(checkpoint, targetName, targetClass) then iterate
      if pass = 1 & rule~action = "DENY" then return .AlchemySecurityDecision~new(.false, "explicit deny")
      if pass = 2 & rule~action = "CAPABILITY" then do
        if authority == .nil then return .AlchemySecurityDecision~new(.false, "capability authority unavailable", rule~purpose, rule~capabilityArg)
        args = info["ARGUMENTS"]
        if args == .nil | args~items = 0 then return .AlchemySecurityDecision~new(.false, "capability argument missing", rule~purpose, rule~capabilityArg)
        idx = rule~capabilityArg
        if idx <= 0 then idx = args~items
        cap = args~at(idx)
        obj = info["OBJECT"]
        if obj~hasMethod("ALCHEMYOBJECTID") then objectId = obj~alchemyObjectId
        else objectId = obj~identityHash~string
        if \authority~verify(cap, objectId, targetName, rule~purpose, rule~consumeCapability) then return .AlchemySecurityDecision~new(.false, "capability verification failed", rule~purpose, idx)
        return .AlchemySecurityDecision~new(.true, "capability verified", rule~purpose, idx)
      end
      if pass = 3 & rule~action = "ALLOW" then return .AlchemySecurityDecision~new(.true, "explicit allow")
    end
  end
  return .AlchemySecurityDecision~new(defaultAction = "ALLOW", "default " || defaultAction)


::class AlchemyCompositeSecurityPolicy public
::method init
  expose servicePolicy tenantPolicy
  use strict arg servicePolicy, tenantPolicy = .nil
  if servicePolicy == .nil then raise syntax 88.900 array("servicePolicy is required")

::method evaluate public
  expose servicePolicy tenantPolicy
  use strict arg checkpoint, info, authority = .nil
  service = servicePolicy~evaluate(checkpoint, info, authority)
  if \service~allowed then return .AlchemySecurityDecision~new(.false, "service policy: " || service~reason, service~purpose, service~capabilityArg)
  if tenantPolicy == .nil then return service
  tenant = tenantPolicy~evaluate(checkpoint, info, authority)
  if \tenant~allowed then return .AlchemySecurityDecision~new(.false, "tenant policy: " || tenant~reason, tenant~purpose, tenant~capabilityArg)
  return .AlchemySecurityDecision~new(.true, "service+tenant allow", service~purpose, service~capabilityArg)


::class AlchemySecurityManager public
::attribute auditEvents get
::attribute runtimeProfile get
::attribute quotaSet get

::method init
  expose policy authority runtimeProfile auditEvents quotaSet
  use strict arg policy, authority = .nil, runtimeProfile = .nil, quotaSet = .nil
  if policy == .nil then raise syntax 88.900 array("AlchemySecurityManager requires policy")
  if runtimeProfile == .nil then runtimeProfile = .AlchemySecurityRuntimeProfile~current
  if \runtimeProfile~observed then raise syntax 98.948 array("Alchemy Security Manager runtime semantics are unverified: " || runtimeProfile~versionText)
  auditEvents = .array~new
  quotaSet = quotaSet

::method method public
  use strict arg info
  return self~checkpoint("METHOD", info)
::method call public
  use strict arg info
  return self~checkpoint("CALL", info)
::method command public
  use strict arg info
  return self~checkpoint("COMMAND", info)
::method requires public
  use strict arg info
  return self~checkpoint("REQUIRES", info)
::method local public
  use strict arg info
  return self~checkpoint("LOCAL", info)
::method environment public
  use strict arg info
  return self~checkpoint("ENVIRONMENT", info)
::method stream public
  use strict arg info
  return self~checkpoint("STREAM", info)

::method unknown public
  use strict arg name, args
  if args~items = 0 then raise syntax 98.948 array("Unknown security checkpoint " || name)
  return self~checkpoint(name, args~at(1))

::method checkpoint private
  expose policy authority runtimeProfile auditEvents quotaSet
  use strict arg checkpoint, info
  decision = policy~evaluate(checkpoint, info, authority)
  quotaDecision = .nil
  allowed = decision~allowed
  reason = decision~reason
  if allowed & quotaSet \== .nil then do
    quotaDecision = quotaSet~consume(checkpoint, info)
    if \quotaDecision~allowed then do
      allowed = .false
      reason = quotaDecision~reason
    end
  end
  ev = .directory~new
  ev["time"] = date("S") || "T" || time("L")
  ev["checkpoint"] = checkpoint~string~translate
  if info~hasIndex("NAME") then ev["name"] = info["NAME"]
  ev["allowed"] = allowed
  ev["reason"] = reason
  if quotaDecision \== .nil then ev["quota"] = quotaDecision~evidence
  auditEvents~append(ev)
  if \allowed then raise syntax 98.948 array(checkpoint || " blocked by Alchemy Security Manager: " || reason)
  return runtimeProfile~continueProcessingReturn

::requires "AlchemyEvidence.cls"
