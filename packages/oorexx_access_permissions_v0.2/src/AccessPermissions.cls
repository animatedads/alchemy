/* AccessPermissions.cls - ooRexx Access Control / Authentication Attribution / Permissions v0.2
 *
 * Boundaries:
 *   Authentication: cryptographic attribution/integrity only; grants no authority.
 *   Access Control: coarse admission to a protected domain.
 *   Permissions: exact subject x object x method authority, with Security Effect semantics.
 *   Security Manager: external enforcement point; see AlchemyAccessPermissionsAdapter.cls.
 */

::class AccessPermissionsBuild public
::constant RELEASE "0.2"
::constant API_VERSION "access.permissions/0.2"
::constant POLICY_SCHEMA "access.permissions.policy/0.2"
::constant PROOF_SCHEMA "access.permissions.proof/0.1"
::constant DECISION_SCHEMA "access.permissions.decision/0.1"
::constant EXECUTION_MODEL "DETERMINISTIC_POLICY_DEFAULT_DENY"

::class AccessPermissionsResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get
::method init
  expose ok code detail value
  use strict arg okArg, codeArg, detailArg = "", valueArg = .nil
  ok = okArg
  code = codeArg~string~upper
  detail = detailArg~string
  value = valueArg
::method success class
  use strict arg value = .nil, detail = ""
  return self~new(.true, "OK", detail, value)
::method failure class
  use strict arg code, detail = "", value = .nil
  return self~new(.false, code, detail, value)

::class AccessPermissionsCanonical public
::method field class
  use strict arg name, value = ""
  if value == .nil then value = ""
  value = value~string
  return name~string~upper || ":" || value~length || ":" || value || '0a'x
::method copyArray class
  use strict arg source = .nil
  out = .array~new
  if source == .nil then return out
  do item over source
    out~append(item)
  end
  return out
::method copyDirectory class
  use strict arg source = .nil
  out = .directory~new
  if source == .nil then return out
  do key over source~allIndexes
    out[key] = source[key]
  end
  return out
::method sortedStrings class
  use strict arg source
  remaining = self~copyArray(source)
  out = .array~new
  do while remaining~items > 0
    bestIndex = 1
    best = remaining[1]~string
    i = 2
    do while i <= remaining~items
      candidate = remaining[i]~string
      if candidate < best then do
        best = candidate
        bestIndex = i
      end
      i += 1
    end
    out~append(best)
    next = .array~new
    i = 1
    do while i <= remaining~items
      if i <> bestIndex then next~append(remaining[i])
      i += 1
    end
    remaining = next
  end
  return out
::method hash class
  use strict arg text
  return .SHA256~new(text~string)~digest
::method wild class
  use strict arg value, pattern
  value = value~string~upper
  pattern = pattern~string~upper
  if pattern = "*" then return .true
  star = pattern~pos("*")
  if star = 0 then return value = pattern
  before = pattern~left(star - 1)
  after = pattern~substr(star + 1)
  if before <> "" then if value~left(before~length) <> before then return .false
  if after <> "" then if value~right(after~length) <> after then return .false
  return .true
::method securityDispositionRank class
  use strict arg disposition
  disposition = disposition~string~upper
  select
    when disposition = "ALLOW" then return 0
    when disposition = "CAUTION" then return 1
    when disposition = "REVIEW_REQUIRED" then return 2
    when disposition = "HOLD" then return 3
    when disposition = "REJECT" then return 4
    otherwise return 99
  end

/* A principal binds a stable principal id to a cryptographic key id.  The key
 * remains in a trusted key ring; the principal object does not contain it. */
::class AccessPrincipal public
::attribute principalId get
::attribute keyId get
::attribute algorithm get
::attribute sealed get
::method init
  expose principalId keyId algorithm sealed
  use strict arg principalIdArg, keyIdArg, algorithmArg = "SIPHASH-2-4-128"
  principalId = principalIdArg~string
  keyId = keyIdArg~string
  algorithm = algorithmArg~string~upper
  sealed = .false
::method seal
  expose principalId keyId algorithm sealed
  if principalId = "" | keyId = "" then raise syntax 88.900 array("principal identity fields required")
  if algorithm = "" then raise syntax 88.900 array("principal algorithm required")
  sealed = .true
  return self
::method canonicalText
  expose principalId keyId algorithm sealed
  if \sealed then raise syntax 88.900 array("principal must be sealed")
  text = "ACCESS-PRINCIPAL/1" || '0a'x
  text ||= .AccessPermissionsCanonical~field("PRINCIPAL_ID", principalId)
  text ||= .AccessPermissionsCanonical~field("KEY_ID", keyId)
  text ||= .AccessPermissionsCanonical~field("ALGORITHM", algorithm)
  return text
::method semanticIdentity
  return self~canonicalText

/* Signed attribution to arbitrary exact evidence.  It proves provenance and
 * integrity only.  No permission or access authority follows from validity. */
::class AuthenticationAssertion public
::attribute principalId get
::attribute keyId get
::attribute algorithm get
::attribute purpose get
::attribute payloadIdentity get
::attribute issuedAt get
::attribute nonce get
::attribute tag get
::method init
  expose principalId keyId algorithm purpose payloadIdentity issuedAt nonce tag
  use strict arg principalIdArg, keyIdArg, algorithmArg, purposeArg, payloadIdentityArg, issuedAtArg, nonceArg, tagArg = ""
  principalId = principalIdArg~string
  keyId = keyIdArg~string
  algorithm = algorithmArg~string~upper
  purpose = purposeArg~string~upper
  payloadIdentity = payloadIdentityArg~string
  issuedAt = issuedAtArg~string
  nonce = nonceArg~string
  tag = tagArg~string~lower
::method unsignedCanonicalText
  expose principalId keyId algorithm purpose payloadIdentity issuedAt nonce
  text = "ACCESS-AUTHENTICATION-ASSERTION/1" || '0a'x
  text ||= .AccessPermissionsCanonical~field("PRINCIPAL_ID", principalId)
  text ||= .AccessPermissionsCanonical~field("KEY_ID", keyId)
  text ||= .AccessPermissionsCanonical~field("ALGORITHM", algorithm)
  text ||= .AccessPermissionsCanonical~field("PURPOSE", purpose)
  text ||= .AccessPermissionsCanonical~field("PAYLOAD_IDENTITY", payloadIdentity)
  text ||= .AccessPermissionsCanonical~field("ISSUED_AT", issuedAt)
  text ||= .AccessPermissionsCanonical~field("NONCE", nonce)
  return text
::method canonicalText
  expose tag
  return self~unsignedCanonicalText || .AccessPermissionsCanonical~field("TAG", tag)
::method semanticIdentity
  return self~canonicalText
::method issue class
  use strict arg principal, keyRing, purpose, payloadIdentity, nonce = ""
  if principal == .nil | \principal~sealed then raise syntax 88.900 array("sealed principal required")
  if keyRing == .nil | \keyRing~hasKey(principal~keyId) then raise syntax 88.900 array("principal key unavailable")
  if keyRing~activeKeyId <> principal~keyId then raise syntax 88.900 array("principal key must be the issuer key ring active key")
  if nonce = "" then nonce = principal~principalId || ":" || date("B") || ":" || time("L") || ":" || random(100000,999999)
  issuedAt = date("S") || "T" || time("L")
  draft = self~new(principal~principalId, principal~keyId, principal~algorithm, purpose, payloadIdentity, issuedAt, nonce)
  proof = keyRing~sign(draft~unsignedCanonicalText)
  if proof~keyId <> principal~keyId then raise syntax 88.900 array("issuer key changed during authentication assertion signing")
  return self~new(principal~principalId, principal~keyId, proof~algorithm, purpose, payloadIdentity, issuedAt, nonce, proof~tag)

::class AuthenticationVerifier public
::method init
  expose keyRing
  use strict arg keyRingArg
  if keyRingArg == .nil then raise syntax 88.900 array("AuthenticationVerifier requires trusted key ring")
  keyRing = keyRingArg
::method verify
  expose keyRing
  use strict arg assertion, principal, expectedPurpose, expectedPayloadIdentity
  if assertion == .nil | principal == .nil then return .AccessPermissionsResult~failure("AUTHENTICATION_EVIDENCE_REQUIRED")
  if \principal~sealed then return .AccessPermissionsResult~failure("PRINCIPAL_NOT_SEALED")
  if assertion~principalId <> principal~principalId | assertion~keyId <> principal~keyId then return .AccessPermissionsResult~failure("AUTHENTICATION_PRINCIPAL_MISMATCH")
  if assertion~algorithm <> principal~algorithm then return .AccessPermissionsResult~failure("AUTHENTICATION_ALGORITHM_MISMATCH")
  if assertion~purpose <> expectedPurpose~string~upper then return .AccessPermissionsResult~failure("AUTHENTICATION_PURPOSE_MISMATCH")
  if assertion~payloadIdentity <> expectedPayloadIdentity~string then return .AccessPermissionsResult~failure("AUTHENTICATION_PAYLOAD_MISMATCH")
  proof = .CryptoMacProof~new(assertion~algorithm, assertion~keyId, assertion~tag)
  if \keyRing~verify(assertion~unsignedCanonicalText, proof) then return .AccessPermissionsResult~failure("AUTHENTICATION_TAG_INVALID")
  return .AccessPermissionsResult~success(principal, "cryptographic attribution verified; no authority implied")

/* Generic cryptographic proof for a sealed policy or immutable decision. */
::class AccessPermissionsProof public
::attribute kind get
::attribute algorithm get
::attribute keyId get
::attribute artifactIdentity get
::attribute tag get
::method init
  expose kind algorithm keyId artifactIdentity tag
  use strict arg kindArg, algorithmArg, keyIdArg, artifactIdentityArg, tagArg
  kind = kindArg~string~upper
  algorithm = algorithmArg~string~upper
  keyId = keyIdArg~string
  artifactIdentity = artifactIdentityArg~string
  tag = tagArg~string~lower
::method unsignedCanonicalText
  expose kind algorithm keyId artifactIdentity
  text = "ACCESS-PERMISSIONS-PROOF/1" || '0a'x
  text ||= .AccessPermissionsCanonical~field("KIND", kind)
  text ||= .AccessPermissionsCanonical~field("ALGORITHM", algorithm)
  text ||= .AccessPermissionsCanonical~field("KEY_ID", keyId)
  text ||= .AccessPermissionsCanonical~field("ARTIFACT_IDENTITY", artifactIdentity)
  return text
::method verifyWith
  expose algorithm keyId tag
  use strict arg keyRing
  if keyRing == .nil then return .false
  proof = .CryptoMacProof~new(algorithm, keyId, tag)
  return keyRing~verify(self~unsignedCanonicalText, proof)

::class AccessPermissionsSigner public
::attribute keyId get
::attribute algorithm get
::method init
  expose keyRing keyId algorithm
  use strict arg keyRingArg, keyIdArg = ""
  if keyRingArg == .nil then raise syntax 88.900 array("AccessPermissionsSigner requires key ring")
  keyRing = keyRingArg
  if keyIdArg = "" then keyId = keyRing~activeKeyId
  else keyId = keyIdArg~string
  if keyId = "" | \keyRing~hasKey(keyId) then raise syntax 88.900 array("proof key unavailable")
  if keyRing~activeKeyId <> keyId then raise syntax 88.900 array("proof key must be the signer key ring active key")
  probe = keyRing~sign("ACCESS-PERMISSIONS-SIGNER-PROBE")
  if probe~keyId <> keyId then raise syntax 88.900 array("signer key changed during initialization")
  algorithm = probe~algorithm
::method signIdentity
  expose keyRing keyId algorithm
  use strict arg kind, artifactIdentity
  if keyRing~activeKeyId <> keyId then raise syntax 88.900 array("proof signer key is no longer active")
  draft = .AccessPermissionsProof~new(kind, algorithm, keyId, artifactIdentity, "")
  proof = keyRing~sign(draft~unsignedCanonicalText)
  if proof~keyId <> keyId then raise syntax 88.900 array("signer key changed during proof creation")
  return .AccessPermissionsProof~new(kind, proof~algorithm, proof~keyId, artifactIdentity, proof~tag)
::method signArtifact
  use strict arg kind, artifact
  if artifact == .nil | \artifact~hasMethod("SEMANTICIDENTITY") then raise syntax 88.900 array("signable artifact with semanticIdentity required")
  return self~signIdentity(kind, artifact~semanticIdentity)

::class AccessControlRequest public
::attribute requestId get
::attribute principalId get
::attribute domainId get
::attribute entryPoint get
::attribute intendedAt get
::attribute sealed get
::method init
  expose requestId principalId domainId entryPoint intendedAt attributes sealed
  use strict arg requestIdArg, principalIdArg, domainIdArg, entryPointArg = "DEFAULT", intendedAtArg = .nil
  requestId = requestIdArg~string
  principalId = principalIdArg~string
  domainId = domainIdArg~string~upper
  entryPoint = entryPointArg~string~upper
  if intendedAtArg == .nil then intendedAt = .DateTime~new
  else intendedAt = intendedAtArg
  attributes = .directory~new
  sealed = .false
::method putAttribute
  expose attributes sealed
  use strict arg name, value
  if sealed then return .false
  if value == .nil then value = ""
  attributes[name~string~upper] = value~string
  return .true
::method attribute
  expose attributes
  use strict arg name
  name = name~string~upper
  if attributes~hasIndex(name) then return attributes[name]
  return .nil
::method seal
  expose requestId principalId domainId entryPoint sealed
  if requestId = "" | principalId = "" | domainId = "" | entryPoint = "" then raise syntax 88.900 array("access-control request identity fields required")
  sealed = .true
  return self
::method canonicalText
  expose requestId principalId domainId entryPoint intendedAt attributes sealed
  if \sealed then raise syntax 88.900 array("access-control request must be sealed")
  text = "ACCESS-CONTROL-REQUEST/1" || '0a'x
  text ||= .AccessPermissionsCanonical~field("REQUEST_ID", requestId)
  text ||= .AccessPermissionsCanonical~field("PRINCIPAL_ID", principalId)
  text ||= .AccessPermissionsCanonical~field("DOMAIN_ID", domainId)
  text ||= .AccessPermissionsCanonical~field("ENTRY_POINT", entryPoint)
  text ||= .AccessPermissionsCanonical~field("INTENDED_AT", intendedAt)
  pairs = .array~new
  do key over attributes~allIndexes
    pairs~append(key~string~upper || "=" || attributes[key]~string)
  end
  do pair over .AccessPermissionsCanonical~sortedStrings(pairs)
    text ||= .AccessPermissionsCanonical~field("ATTRIBUTE", pair)
  end
  return text
::method semanticIdentity
  return self~canonicalText

::class AccessControlRule public
::attribute ruleId get
::attribute priority get
::attribute action get
::attribute subjectPattern get
::attribute domainPattern get
::attribute entryPattern get
::attribute sealed get
::method init
  expose ruleId priority action subjectPattern domainPattern entryPattern requiredAttributes sealed
  use strict arg ruleIdArg, priorityArg, actionArg, subjectPatternArg = "*", domainPatternArg = "*", entryPatternArg = "*"
  ruleId = ruleIdArg~string~upper
  priority = priorityArg + 0
  action = actionArg~string~upper
  subjectPattern = subjectPatternArg~string~upper
  domainPattern = domainPatternArg~string~upper
  entryPattern = entryPatternArg~string~upper
  requiredAttributes = .directory~new
  sealed = .false
::method requireAttribute
  expose requiredAttributes sealed
  use strict arg name, pattern
  if sealed then return .false
  name = name~string~upper
  if name = "" then return .false
  requiredAttributes[name] = pattern~string~upper
  return .true
::method requiredAttributes
  expose requiredAttributes
  return .AccessPermissionsCanonical~copyDirectory(requiredAttributes)
::method seal
  expose ruleId action sealed
  if ruleId = "" then raise syntax 88.900 array("access-control rule id required")
  if action <> "ALLOW" & action <> "DENY" then raise syntax 88.900 array("access-control action must be ALLOW or DENY")
  sealed = .true
  return self
::method matches
  expose subjectPattern domainPattern entryPattern requiredAttributes sealed
  use strict arg request
  if \sealed | request == .nil | \request~sealed then return .false
  if \.AccessPermissionsCanonical~wild(request~principalId, subjectPattern) then return .false
  if \.AccessPermissionsCanonical~wild(request~domainId, domainPattern) then return .false
  if \.AccessPermissionsCanonical~wild(request~entryPoint, entryPattern) then return .false
  do name over requiredAttributes~allIndexes
    value = request~attribute(name)
    if value == .nil then return .false
    if \.AccessPermissionsCanonical~wild(value, requiredAttributes[name]) then return .false
  end
  return .true
::method canonicalText
  expose ruleId priority action subjectPattern domainPattern entryPattern requiredAttributes sealed
  if \sealed then raise syntax 88.900 array("access-control rule must be sealed")
  text = .AccessPermissionsCanonical~field("RULE_ID", ruleId)
  text ||= .AccessPermissionsCanonical~field("PRIORITY", priority)
  text ||= .AccessPermissionsCanonical~field("ACTION", action)
  text ||= .AccessPermissionsCanonical~field("SUBJECT", subjectPattern)
  text ||= .AccessPermissionsCanonical~field("DOMAIN", domainPattern)
  text ||= .AccessPermissionsCanonical~field("ENTRY", entryPattern)
  requirements = .array~new
  do name over requiredAttributes~allIndexes
    requirements~append(name~string~upper || "=" || requiredAttributes[name]~string~upper)
  end
  do requirement over .AccessPermissionsCanonical~sortedStrings(requirements)
    text ||= .AccessPermissionsCanonical~field("REQUIRED_ATTRIBUTE", requirement)
  end
  return text

::class AccessControlPolicy public
::attribute policyId get
::attribute version get
::attribute effectiveFrom get
::attribute effectiveUntil get
::attribute defaultAction get
::attribute authoredBy get
::attribute approvedBy get
::attribute supersedes get
::attribute executionModel get
::attribute sealed get
::method init
  expose policyId version effectiveFrom effectiveUntil defaultAction authoredBy approvedBy supersedes executionModel rules sealed
  use strict arg policyIdArg, versionArg, defaultActionArg = "DENY", effectiveFromArg = .nil, effectiveUntilArg = .nil, authoredByArg = "", approvedByArg = "", supersedesArg = ""
  policyId = policyIdArg~string~upper
  version = versionArg~string
  defaultAction = defaultActionArg~string~upper
  if effectiveFromArg == .nil then effectiveFrom = .DateTime~new - .TimeSpan~new(0,0,0,0,1)
  else effectiveFrom = effectiveFromArg
  if effectiveUntilArg == .nil | effectiveUntilArg~string = "" then effectiveUntil = .nil
  else effectiveUntil = effectiveUntilArg
  authoredBy = authoredByArg~string
  approvedBy = approvedByArg~string
  supersedes = supersedesArg~string
  executionModel = .InstitutionalPolicyBuild~EXECUTION_MODEL
  rules = .array~new
  sealed = .false
::method addRule
  expose rules sealed
  use strict arg rule
  if sealed then return .false
  if rule == .nil | \rule~sealed then return .false
  do existing over rules
    if existing~ruleId = rule~ruleId then return .false
  end
  rules~append(rule)
  return .true
::method rules
  expose rules
  return .AccessPermissionsCanonical~copyArray(rules)
::method activeAt
  expose effectiveFrom effectiveUntil
  use strict arg moment
  if moment < effectiveFrom then return .false
  if effectiveUntil == .nil then return .true
  return moment < effectiveUntil
::method publicationEligible
  expose sealed authoredBy approvedBy
  return sealed & authoredBy <> "" & approvedBy <> ""
::method seal
  expose policyId version defaultAction effectiveFrom effectiveUntil sealed
  if policyId = "" | version = "" then raise syntax 88.900 array("access-control policy identity required")
  if defaultAction <> "DENY" then raise syntax 88.900 array("access-control requires default DENY")
  if effectiveUntil <> .nil then if effectiveUntil <= effectiveFrom then raise syntax 88.900 array("access-control effective range invalid")
  sealed = .true
  return self
::method canonicalText
  expose policyId version defaultAction effectiveFrom effectiveUntil authoredBy approvedBy supersedes executionModel rules sealed
  if \sealed then raise syntax 88.900 array("access-control policy must be sealed")
  text = "ACCESS-CONTROL-POLICY/1" || '0a'x
  text ||= .AccessPermissionsCanonical~field("POLICY_ID", policyId)
  text ||= .AccessPermissionsCanonical~field("VERSION", version)
  text ||= .AccessPermissionsCanonical~field("SCHEMA", .AccessPermissionsBuild~POLICY_SCHEMA)
  text ||= .AccessPermissionsCanonical~field("DEFAULT", defaultAction)
  text ||= .AccessPermissionsCanonical~field("EFFECTIVE_FROM", effectiveFrom)
  text ||= .AccessPermissionsCanonical~field("EFFECTIVE_UNTIL", effectiveUntil)
  text ||= .AccessPermissionsCanonical~field("AUTHORED_BY", authoredBy)
  text ||= .AccessPermissionsCanonical~field("APPROVED_BY", approvedBy)
  text ||= .AccessPermissionsCanonical~field("SUPERSEDES", supersedes)
  text ||= .AccessPermissionsCanonical~field("EXECUTION_MODEL", executionModel)
  rtexts = .array~new
  do rule over rules
    rtexts~append(rule~canonicalText)
  end
  do rtext over .AccessPermissionsCanonical~sortedStrings(rtexts)
    text ||= .AccessPermissionsCanonical~field("RULE", rtext)
  end
  return text
::method semanticIdentity
  return self~canonicalText

::class AccessControlDecision public
::attribute allowed get
::attribute code get
::attribute reason get
::attribute requestIdentity get
::attribute policyIdentity get
::attribute ruleId get
::attribute principalId get
::attribute domainId get
::attribute evaluatedAt get
::method init
  expose allowed code reason requestIdentity policyIdentity ruleId principalId domainId evaluatedAt
  use strict arg allowedArg, codeArg, reasonArg, request, policy, ruleIdArg = "", evaluatedAtArg = .nil
  allowed = allowedArg
  code = codeArg~string~upper
  reason = reasonArg~string
  requestIdentity = request~semanticIdentity
  policyIdentity = policy~semanticIdentity
  ruleId = ruleIdArg~string~upper
  principalId = request~principalId
  domainId = request~domainId
  if evaluatedAtArg == .nil then evaluatedAt = .DateTime~new
  else evaluatedAt = evaluatedAtArg
::method canonicalText
  expose allowed code reason requestIdentity policyIdentity ruleId principalId domainId evaluatedAt
  text = "ACCESS-CONTROL-DECISION/1" || '0a'x
  text ||= .AccessPermissionsCanonical~field("ALLOWED", allowed)
  text ||= .AccessPermissionsCanonical~field("CODE", code)
  text ||= .AccessPermissionsCanonical~field("REASON", reason)
  text ||= .AccessPermissionsCanonical~field("REQUEST_IDENTITY", requestIdentity)
  text ||= .AccessPermissionsCanonical~field("POLICY_IDENTITY", policyIdentity)
  text ||= .AccessPermissionsCanonical~field("RULE_ID", ruleId)
  text ||= .AccessPermissionsCanonical~field("PRINCIPAL_ID", principalId)
  text ||= .AccessPermissionsCanonical~field("DOMAIN_ID", domainId)
  text ||= .AccessPermissionsCanonical~field("EVALUATED_AT", evaluatedAt)
  return text
::method semanticIdentity
  return self~canonicalText

::class AccessControlAuthority public
::attribute signer get
::method init
  expose signer authenticationVerifier
  use strict arg signerArg = .nil, authenticationVerifierArg = .nil
  signer = signerArg
  authenticationVerifier = authenticationVerifierArg
::method decide
  expose signer authenticationVerifier
  use strict arg request, policy, assertion = .nil, principal = .nil
  if request == .nil | policy == .nil then return .AccessPermissionsResult~failure("ACCESS_INPUT_REQUIRED")
  if \request~sealed then return .AccessPermissionsResult~failure("ACCESS_REQUEST_NOT_SEALED")
  if \policy~sealed then return .AccessPermissionsResult~failure("ACCESS_POLICY_NOT_SEALED")
  if \policy~activeAt(request~intendedAt) then return .AccessPermissionsResult~failure("ACCESS_POLICY_NOT_EFFECTIVE")
  if request~principalId = "" then return .AccessPermissionsResult~failure("ACCESS_SUBJECT_REQUIRED")
  if assertion <> .nil | principal <> .nil then do
    if assertion == .nil | principal == .nil then return .AccessPermissionsResult~failure("ACCESS_ATTRIBUTION_INCOMPLETE")
    if request~principalId <> principal~principalId then return .AccessPermissionsResult~failure("ACCESS_ATTRIBUTION_SUBJECT_MISMATCH")
    if authenticationVerifier == .nil then return .AccessPermissionsResult~failure("ACCESS_ATTRIBUTION_VERIFIER_REQUIRED")
    auth = authenticationVerifier~verify(assertion, principal, "ACCESS_CONTROL", request~semanticIdentity)
    if \auth~ok then return auth
  end
  selected = self~selectRule(request, policy~rules)
  if selected == .nil then do
    allowed = policy~defaultAction = "ALLOW"
    decision = .AccessControlDecision~new(allowed, "DEFAULT_" || policy~defaultAction, "default " || policy~defaultAction, request, policy)
  end
  else do
    allowed = selected~action = "ALLOW"
    decision = .AccessControlDecision~new(allowed, "RULE_" || selected~action, "matched " || selected~ruleId, request, policy, selected~ruleId)
  end
  proof = .nil
  if signer <> .nil then proof = signer~signArtifact("ACCESS_CONTROL_DECISION", decision)
  envelope = .AuthorizationDecisionEnvelope~new("ACCESS_CONTROL", decision, proof)
  return .AccessPermissionsResult~success(envelope)
::method selectRule private
  use strict arg request, rules
  best = .nil
  do rule over rules
    if \rule~matches(request) then iterate
    if best == .nil then best = rule
    else if rule~priority > best~priority then best = rule
    else if rule~priority = best~priority then do
      if rule~action = "DENY" & best~action <> "DENY" then best = rule
      else if rule~action = best~action & rule~ruleId < best~ruleId then best = rule
    end
  end
  return best

/* Exact method/object permission request.  Security Effect is retained as
 * decision evidence: disposition, exact policy identity, trace identity, and
 * constraints are bound into this request before policy evaluation. */
::class PermissionRequest public
::attribute requestId get
::attribute principalId get
::attribute objectId get
::attribute objectClass get
::attribute methodName get
::attribute intendedAt get
::attribute securityDisposition get
::attribute securityPolicyIdentity get
::attribute securityTraceIdentity get
::attribute sealed get
::method init
  expose requestId principalId objectId objectClass methodName intendedAt securityDisposition securityPolicyIdentity securityTraceIdentity securityConstraints sealed
  use strict arg requestIdArg, principalIdArg, objectIdArg, objectClassArg, methodNameArg, intendedAtArg = .nil
  requestId = requestIdArg~string
  principalId = principalIdArg~string
  objectId = objectIdArg~string
  objectClass = objectClassArg~string~upper
  methodName = methodNameArg~string~upper
  if intendedAtArg == .nil then intendedAt = .DateTime~new
  else intendedAt = intendedAtArg
  securityDisposition = ""
  securityPolicyIdentity = ""
  securityTraceIdentity = ""
  securityConstraints = .array~new
  sealed = .false
::method bindSecurityAssessment
  expose principalId objectId methodName securityDisposition securityPolicyIdentity securityTraceIdentity securityConstraints sealed
  use strict arg assessment
  if sealed then return .false
  if assessment == .nil then return .false
  if assessment~action~subjectId <> principalId then return .false
  effectObjectId = assessment~action~attribute("OBJECT_ID")
  effectMethod = assessment~action~attribute("METHOD")
  if effectObjectId == .nil | effectMethod == .nil then return .false
  if effectObjectId~string <> objectId then return .false
  if effectMethod~string~upper <> methodName then return .false
  securityDisposition = assessment~disposition~string~upper
  securityPolicyIdentity = assessment~policy~semanticIdentity~string
  securityTraceIdentity = assessment~trace~canonicalText
  securityConstraints = .array~new
  do constraint over assessment~constraints
    securityConstraints~append(constraint~code~string~upper || ":" || constraint~scope~string~upper)
  end
  return .true
::method securityConstraints
  expose securityConstraints
  return .AccessPermissionsCanonical~copyArray(securityConstraints)
::method hasSecurityConstraint
  expose securityConstraints
  use strict arg pattern
  do value over securityConstraints
    if .AccessPermissionsCanonical~wild(value, pattern) then return .true
  end
  return .false
::method seal
  expose requestId principalId objectId objectClass methodName securityDisposition securityPolicyIdentity securityTraceIdentity sealed
  if requestId = "" | principalId = "" | objectId = "" | objectClass = "" | methodName = "" then raise syntax 88.900 array("permission request identity fields required")
  if securityDisposition = "" | securityPolicyIdentity = "" | securityTraceIdentity = "" then raise syntax 88.900 array("permission request requires Security Effect assessment")
  sealed = .true
  return self
::method canonicalText
  expose requestId principalId objectId objectClass methodName intendedAt securityDisposition securityPolicyIdentity securityTraceIdentity securityConstraints sealed
  if \sealed then raise syntax 88.900 array("permission request must be sealed")
  text = "PERMISSION-REQUEST/1" || '0a'x
  text ||= .AccessPermissionsCanonical~field("REQUEST_ID", requestId)
  text ||= .AccessPermissionsCanonical~field("PRINCIPAL_ID", principalId)
  text ||= .AccessPermissionsCanonical~field("OBJECT_ID", objectId)
  text ||= .AccessPermissionsCanonical~field("OBJECT_CLASS", objectClass)
  text ||= .AccessPermissionsCanonical~field("METHOD", methodName)
  text ||= .AccessPermissionsCanonical~field("INTENDED_AT", intendedAt)
  text ||= .AccessPermissionsCanonical~field("SECURITY_DISPOSITION", securityDisposition)
  text ||= .AccessPermissionsCanonical~field("SECURITY_POLICY_IDENTITY", securityPolicyIdentity)
  text ||= .AccessPermissionsCanonical~field("SECURITY_TRACE_IDENTITY", securityTraceIdentity)
  do item over .AccessPermissionsCanonical~sortedStrings(securityConstraints)
    text ||= .AccessPermissionsCanonical~field("SECURITY_CONSTRAINT", item)
  end
  return text
::method semanticIdentity
  return self~canonicalText

::class PermissionRule public
::attribute ruleId get
::attribute priority get
::attribute action get
::attribute subjectPattern get
::attribute objectPattern get
::attribute classPattern get
::attribute methodPattern get
::attribute maxSecurityDisposition get
::attribute securityPolicyIdentityPattern get
::attribute requiredSecurityConstraint get
::attribute sealed get
::method init
  expose ruleId priority action subjectPattern objectPattern classPattern methodPattern maxSecurityDisposition securityPolicyIdentityPattern requiredSecurityConstraint sealed
  use strict arg ruleIdArg, priorityArg, actionArg, subjectPatternArg = "*", objectPatternArg = "*", classPatternArg = "*", methodPatternArg = "*", maxSecurityDispositionArg = "ALLOW", securityPolicyIdentityPatternArg = "*", requiredSecurityConstraintArg = ""
  ruleId = ruleIdArg~string~upper
  priority = priorityArg + 0
  action = actionArg~string~upper
  subjectPattern = subjectPatternArg~string~upper
  objectPattern = objectPatternArg~string~upper
  classPattern = classPatternArg~string~upper
  methodPattern = methodPatternArg~string~upper
  maxSecurityDisposition = maxSecurityDispositionArg~string~upper
  securityPolicyIdentityPattern = securityPolicyIdentityPatternArg~string~upper
  requiredSecurityConstraint = requiredSecurityConstraintArg~string~upper
  sealed = .false
::method seal
  expose ruleId action maxSecurityDisposition sealed
  if ruleId = "" then raise syntax 88.900 array("permission rule id required")
  if action <> "ALLOW" & action <> "DENY" then raise syntax 88.900 array("permission action must be ALLOW or DENY")
  if .AccessPermissionsCanonical~securityDispositionRank(maxSecurityDisposition) = 99 then raise syntax 88.900 array("permission max Security Effect disposition invalid")
  sealed = .true
  return self
::method matches
  expose subjectPattern objectPattern classPattern methodPattern maxSecurityDisposition securityPolicyIdentityPattern requiredSecurityConstraint sealed
  use strict arg request
  if \sealed | request == .nil | \request~sealed then return .false
  if \.AccessPermissionsCanonical~wild(request~principalId, subjectPattern) then return .false
  if \.AccessPermissionsCanonical~wild(request~objectId, objectPattern) then return .false
  if \.AccessPermissionsCanonical~wild(request~objectClass, classPattern) then return .false
  if \.AccessPermissionsCanonical~wild(request~methodName, methodPattern) then return .false
  if .AccessPermissionsCanonical~securityDispositionRank(request~securityDisposition) > .AccessPermissionsCanonical~securityDispositionRank(maxSecurityDisposition) then return .false
  if \.AccessPermissionsCanonical~wild(request~securityPolicyIdentity, securityPolicyIdentityPattern) then return .false
  if requiredSecurityConstraint <> "" then if \request~hasSecurityConstraint(requiredSecurityConstraint) then return .false
  return .true
::method canonicalText
  expose ruleId priority action subjectPattern objectPattern classPattern methodPattern maxSecurityDisposition securityPolicyIdentityPattern requiredSecurityConstraint sealed
  if \sealed then raise syntax 88.900 array("permission rule must be sealed")
  text = .AccessPermissionsCanonical~field("RULE_ID", ruleId)
  text ||= .AccessPermissionsCanonical~field("PRIORITY", priority)
  text ||= .AccessPermissionsCanonical~field("ACTION", action)
  text ||= .AccessPermissionsCanonical~field("SUBJECT", subjectPattern)
  text ||= .AccessPermissionsCanonical~field("OBJECT", objectPattern)
  text ||= .AccessPermissionsCanonical~field("CLASS", classPattern)
  text ||= .AccessPermissionsCanonical~field("METHOD", methodPattern)
  text ||= .AccessPermissionsCanonical~field("MAX_SECURITY_DISPOSITION", maxSecurityDisposition)
  text ||= .AccessPermissionsCanonical~field("SECURITY_POLICY_IDENTITY", securityPolicyIdentityPattern)
  text ||= .AccessPermissionsCanonical~field("REQUIRED_SECURITY_CONSTRAINT", requiredSecurityConstraint)
  return text

::class PermissionPolicy public
::attribute policyId get
::attribute version get
::attribute effectiveFrom get
::attribute effectiveUntil get
::attribute defaultAction get
::attribute authoredBy get
::attribute approvedBy get
::attribute supersedes get
::attribute executionModel get
::attribute sealed get
::method init
  expose policyId version effectiveFrom effectiveUntil defaultAction authoredBy approvedBy supersedes executionModel rules sealed
  use strict arg policyIdArg, versionArg, defaultActionArg = "DENY", effectiveFromArg = .nil, effectiveUntilArg = .nil, authoredByArg = "", approvedByArg = "", supersedesArg = ""
  policyId = policyIdArg~string~upper
  version = versionArg~string
  defaultAction = defaultActionArg~string~upper
  if effectiveFromArg == .nil then effectiveFrom = .DateTime~new - .TimeSpan~new(0,0,0,0,1)
  else effectiveFrom = effectiveFromArg
  if effectiveUntilArg == .nil | effectiveUntilArg~string = "" then effectiveUntil = .nil
  else effectiveUntil = effectiveUntilArg
  authoredBy = authoredByArg~string
  approvedBy = approvedByArg~string
  supersedes = supersedesArg~string
  executionModel = .InstitutionalPolicyBuild~EXECUTION_MODEL
  rules = .array~new
  sealed = .false
::method addRule
  expose rules sealed
  use strict arg rule
  if sealed then return .false
  if rule == .nil | \rule~sealed then return .false
  do existing over rules
    if existing~ruleId = rule~ruleId then return .false
  end
  rules~append(rule)
  return .true
::method rules
  expose rules
  return .AccessPermissionsCanonical~copyArray(rules)
::method activeAt
  expose effectiveFrom effectiveUntil
  use strict arg moment
  if moment < effectiveFrom then return .false
  if effectiveUntil == .nil then return .true
  return moment < effectiveUntil
::method publicationEligible
  expose sealed authoredBy approvedBy
  return sealed & authoredBy <> "" & approvedBy <> ""
::method seal
  expose policyId version defaultAction effectiveFrom effectiveUntil sealed
  if policyId = "" | version = "" then raise syntax 88.900 array("permission policy identity required")
  if defaultAction <> "DENY" then raise syntax 88.900 array("permission requires default DENY")
  if effectiveUntil <> .nil then if effectiveUntil <= effectiveFrom then raise syntax 88.900 array("permission effective range invalid")
  sealed = .true
  return self
::method canonicalText
  expose policyId version defaultAction effectiveFrom effectiveUntil authoredBy approvedBy supersedes executionModel rules sealed
  if \sealed then raise syntax 88.900 array("permission policy must be sealed")
  text = "PERMISSION-POLICY/1" || '0a'x
  text ||= .AccessPermissionsCanonical~field("POLICY_ID", policyId)
  text ||= .AccessPermissionsCanonical~field("VERSION", version)
  text ||= .AccessPermissionsCanonical~field("SCHEMA", .AccessPermissionsBuild~POLICY_SCHEMA)
  text ||= .AccessPermissionsCanonical~field("DEFAULT", defaultAction)
  text ||= .AccessPermissionsCanonical~field("EFFECTIVE_FROM", effectiveFrom)
  text ||= .AccessPermissionsCanonical~field("EFFECTIVE_UNTIL", effectiveUntil)
  text ||= .AccessPermissionsCanonical~field("AUTHORED_BY", authoredBy)
  text ||= .AccessPermissionsCanonical~field("APPROVED_BY", approvedBy)
  text ||= .AccessPermissionsCanonical~field("SUPERSEDES", supersedes)
  text ||= .AccessPermissionsCanonical~field("EXECUTION_MODEL", executionModel)
  rtexts = .array~new
  do rule over rules
    rtexts~append(rule~canonicalText)
  end
  do rtext over .AccessPermissionsCanonical~sortedStrings(rtexts)
    text ||= .AccessPermissionsCanonical~field("RULE", rtext)
  end
  return text
::method semanticIdentity
  return self~canonicalText

::class PermissionDecision public
::attribute allowed get
::attribute code get
::attribute reason get
::attribute requestIdentity get
::attribute policyIdentity get
::attribute ruleId get
::attribute principalId get
::attribute objectId get
::attribute objectClass get
::attribute methodName get
::attribute securityDisposition get
::attribute securityPolicyIdentity get
::attribute securityTraceIdentity get
::attribute evaluatedAt get
::method init
  expose allowed code reason requestIdentity policyIdentity ruleId principalId objectId objectClass methodName securityDisposition securityPolicyIdentity securityTraceIdentity evaluatedAt
  use strict arg allowedArg, codeArg, reasonArg, request, policy, ruleIdArg = "", evaluatedAtArg = .nil
  allowed = allowedArg
  code = codeArg~string~upper
  reason = reasonArg~string
  requestIdentity = request~semanticIdentity
  policyIdentity = policy~semanticIdentity
  ruleId = ruleIdArg~string~upper
  principalId = request~principalId
  objectId = request~objectId
  objectClass = request~objectClass
  methodName = request~methodName
  securityDisposition = request~securityDisposition
  securityPolicyIdentity = request~securityPolicyIdentity
  securityTraceIdentity = request~securityTraceIdentity
  if evaluatedAtArg == .nil then evaluatedAt = .DateTime~new
  else evaluatedAt = evaluatedAtArg
::method canonicalText
  expose allowed code reason requestIdentity policyIdentity ruleId principalId objectId objectClass methodName securityDisposition securityPolicyIdentity securityTraceIdentity evaluatedAt
  text = "PERMISSION-DECISION/1" || '0a'x
  text ||= .AccessPermissionsCanonical~field("ALLOWED", allowed)
  text ||= .AccessPermissionsCanonical~field("CODE", code)
  text ||= .AccessPermissionsCanonical~field("REASON", reason)
  text ||= .AccessPermissionsCanonical~field("REQUEST_IDENTITY", requestIdentity)
  text ||= .AccessPermissionsCanonical~field("POLICY_IDENTITY", policyIdentity)
  text ||= .AccessPermissionsCanonical~field("RULE_ID", ruleId)
  text ||= .AccessPermissionsCanonical~field("PRINCIPAL_ID", principalId)
  text ||= .AccessPermissionsCanonical~field("OBJECT_ID", objectId)
  text ||= .AccessPermissionsCanonical~field("OBJECT_CLASS", objectClass)
  text ||= .AccessPermissionsCanonical~field("METHOD", methodName)
  text ||= .AccessPermissionsCanonical~field("SECURITY_DISPOSITION", securityDisposition)
  text ||= .AccessPermissionsCanonical~field("SECURITY_POLICY_IDENTITY", securityPolicyIdentity)
  text ||= .AccessPermissionsCanonical~field("SECURITY_TRACE_IDENTITY", securityTraceIdentity)
  text ||= .AccessPermissionsCanonical~field("EVALUATED_AT", evaluatedAt)
  return text
::method semanticIdentity
  return self~canonicalText

::class PermissionAuthority public
::attribute signer get
::method init
  expose signer authenticationVerifier
  use strict arg signerArg = .nil, authenticationVerifierArg = .nil
  signer = signerArg
  authenticationVerifier = authenticationVerifierArg
::method decide
  expose signer authenticationVerifier
  use strict arg request, policy, assertion = .nil, principal = .nil
  if request == .nil | policy == .nil then return .AccessPermissionsResult~failure("PERMISSION_INPUT_REQUIRED")
  if \request~sealed then return .AccessPermissionsResult~failure("PERMISSION_REQUEST_NOT_SEALED")
  if \policy~sealed then return .AccessPermissionsResult~failure("PERMISSION_POLICY_NOT_SEALED")
  if \policy~activeAt(request~intendedAt) then return .AccessPermissionsResult~failure("PERMISSION_POLICY_NOT_EFFECTIVE")
  if assertion <> .nil | principal <> .nil then do
    if assertion == .nil | principal == .nil then return .AccessPermissionsResult~failure("PERMISSION_ATTRIBUTION_INCOMPLETE")
    if request~principalId <> principal~principalId then return .AccessPermissionsResult~failure("PERMISSION_ATTRIBUTION_SUBJECT_MISMATCH")
    if authenticationVerifier == .nil then return .AccessPermissionsResult~failure("PERMISSION_ATTRIBUTION_VERIFIER_REQUIRED")
    auth = authenticationVerifier~verify(assertion, principal, "METHOD_PERMISSION", request~semanticIdentity)
    if \auth~ok then return auth
  end
  selected = self~selectRule(request, policy~rules)
  if selected == .nil then do
    allowed = policy~defaultAction = "ALLOW"
    decision = .PermissionDecision~new(allowed, "DEFAULT_" || policy~defaultAction, "default " || policy~defaultAction, request, policy)
  end
  else do
    allowed = selected~action = "ALLOW"
    decision = .PermissionDecision~new(allowed, "RULE_" || selected~action, "matched " || selected~ruleId, request, policy, selected~ruleId)
  end
  proof = .nil
  if signer <> .nil then proof = signer~signArtifact("PERMISSION_DECISION", decision)
  envelope = .AuthorizationDecisionEnvelope~new("PERMISSION", decision, proof)
  return .AccessPermissionsResult~success(envelope)
::method selectRule private
  use strict arg request, rules
  best = .nil
  do rule over rules
    if \rule~matches(request) then iterate
    if best == .nil then best = rule
    else if rule~priority > best~priority then best = rule
    else if rule~priority = best~priority then do
      if rule~action = "DENY" & best~action <> "DENY" then best = rule
      else if rule~action = best~action & rule~ruleId < best~ruleId then best = rule
    end
  end
  return best

::class AuthorizationDecisionEnvelope public
::attribute kind get
::attribute decision get
::attribute proof get
::method init
  expose kind decision proof
  use strict arg kindArg, decisionArg, proofArg = .nil
  kind = kindArg~string~upper
  decision = decisionArg
  proof = proofArg
::method proved
  expose proof
  return proof <> .nil
::method verifyProof
  expose kind decision proof
  use strict arg keyRing
  if proof == .nil then return .false
  if proof~kind <> kind || "_DECISION" then return .false
  if proof~artifactIdentity <> decision~semanticIdentity then return .false
  return proof~verifyWith(keyRing)
::method canonicalText
  expose kind decision proof
  text = "AUTHORIZATION-DECISION-ENVELOPE/1" || '0a'x
  text ||= .AccessPermissionsCanonical~field("KIND", kind)
  text ||= .AccessPermissionsCanonical~field("DECISION_IDENTITY", decision~semanticIdentity)
  if proof == .nil then text ||= .AccessPermissionsCanonical~field("PROOF", "")
  else text ||= .AccessPermissionsCanonical~field("PROOF", proof~tag)
  return text
::method semanticIdentity
  return self~canonicalText


::class AccessControlPolicyCatalog subclass InstitutionalPolicyCatalog public

::class PermissionPolicyCatalog subclass InstitutionalPolicyCatalog public

::requires 'crypto.cls'
::requires 'InstitutionalPolicy.cls'
::requires 'SecurityEffect.cls'
