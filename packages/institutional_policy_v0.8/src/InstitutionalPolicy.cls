/* InstitutionalPolicy.cls - shared institutional policy lifecycle, authority, deployment topology, progressive rollout and deterministic promotion and post-promotion rollback evidence gates v0.8 */

::class InstitutionalPolicyBuild public
::constant RELEASE "0.8"
::constant API_VERSION "institutional.policy/0.8"
::constant EXECUTION_MODEL "FIXED_REVIEWABLE_VERSIONED_ARTIFACT"
::constant MODE_OPERATIVE "OPERATIVE"
::constant MODE_COUNTERFACTUAL "COUNTERFACTUAL"

::constant AUTHORITY_AUTHOR "AUTHOR"
::constant AUTHORITY_APPROVER "APPROVER"
::constant AUTHORITY_PUBLISHER "PUBLISHER"
::constant AUTHORITY_EMERGENCY_PUBLISHER "EMERGENCY_PUBLISHER"
::constant AUTHORITY_SUSPENDER "SUSPEND"
::constant AUTHORITY_RESUMER "RESUME"
::constant AUTHORITY_WITHDRAWER "WITHDRAW"
::constant AUTHORITY_RATIFIER "RATIFY"
::constant AUTHORITY_DEPLOYER "DEPLOY"
::constant LIFECYCLE_SUSPEND "SUSPEND"
::constant LIFECYCLE_RESUME "RESUME"
::constant LIFECYCLE_WITHDRAW "WITHDRAW"
::constant LIFECYCLE_RATIFY "RATIFY"
::constant DEPLOYMENT_ACTIVE "ACTIVE"
::constant DEPLOYMENT_SUSPENDED "SUSPENDED"
::constant DEPLOYMENT_WITHDRAWN "WITHDRAWN"
::constant DEPLOYMENT_STAGED "STAGED"
::constant DEPLOYMENT_CANARY "CANARY"
::constant DEPLOYMENT_NOT_DEPLOYED "NOT_DEPLOYED"
::constant AUTHORITY_CLASS_GENERAL "GENERAL"
::constant AUTHORITY_CLASS_EMERGENCY "EMERGENCY"
::constant APPROVAL_EVIDENCE_OPTIONAL "OPTIONAL"
::constant APPROVAL_EVIDENCE_REQUIRED "REQUIRED"
::constant ASSURANCE_IDENTIFIER_ONLY "IDENTIFIER_ONLY"
::constant ASSURANCE_ROLE_AUTHORITY "ROLE_AUTHORITY"
::constant ASSURANCE_VERIFIED_APPROVAL "VERIFIED_APPROVAL_EVIDENCE"
::constant ROLLOUT_PROMOTION_ELIGIBLE "PROMOTION_ELIGIBLE"
::constant ROLLOUT_PROMOTION_BLOCKED "PROMOTION_BLOCKED"
::constant ROLLOUT_INSUFFICIENT_EVIDENCE "INSUFFICIENT_EVIDENCE"
::constant ROLLBACK_ELIGIBLE "ROLLBACK_ELIGIBLE"
::constant ROLLBACK_NOT_REQUIRED "ROLLBACK_NOT_REQUIRED"
::constant ROLLBACK_INSUFFICIENT_EVIDENCE "ROLLBACK_INSUFFICIENT_EVIDENCE"

::class InstitutionalPolicyResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get
::method init
  expose ok code detail value
  use arg okArg, codeArg, detailArg = "", valueArg = .nil
  ok = okArg
  code = codeArg~string
  detail = detailArg~string
  value = valueArg
::method success class
  use arg value = .nil, detail = ""
  return self~new(.true, "OK", detail, value)
::method failure class
  use arg code, detail = "", value = .nil
  return self~new(.false, code, detail, value)

::class InstitutionalPolicyCanonical public
::method field class
  use arg name, value = ""
  if value == .nil then rendered = ""
  else rendered = value~string
  return name~string~upper || "=" || rendered || '0a'x
::method payloadIdentity class
  use arg payload, explicitIdentity = ""
  if explicitIdentity~string <> "" then return explicitIdentity~string
  if payload == .nil then return ""
  if payload~hasMethod("SEMANTICIDENTITY") then return payload~semanticIdentity~string
  if payload~hasMethod("CANONICALTEXT") then return payload~canonicalText~string
  return payload~string
::method copyArray class
  use arg source
  out = .array~new
  if source == .nil then return out
  do item over source
    out~append(item)
  end
  return out
::method sortedStrings class
  use arg source
  out = .array~new
  if source == .nil then return out
  do item over source
    out~append(item~string)
  end
  out~sort
  return out

/* A generic deployed release around a domain-owned deterministic policy artefact.
   The payload may itself be LegalRuleGeneration, a security framework, a librarian
   ruleset, etc. Domain semantics remain owned by that payload. */
::class InstitutionalPolicyRelease public
::attribute policyId get
::attribute version get
::attribute effectiveFrom get
::attribute effectiveUntil get
::attribute authoredBy get
::attribute approvedBy get
::attribute supersedes get
::attribute payload get
::attribute executionModel get
::attribute sealed get
::method init
  expose policyId version effectiveFrom effectiveUntil authoredBy approvedBy supersedes payload payloadIdentity executionModel sealed
  use arg policyIdArg, versionArg, effectiveFromArg = .nil, effectiveUntilArg = .nil, authoredByArg = "", approvedByArg = "", supersedesArg = "", payloadArg = .nil, payloadIdentityArg = ""
  policyId = policyIdArg~string~upper
  version = versionArg~string
  if effectiveFromArg == .nil then effectiveFrom = .DateTime~new
  else effectiveFrom = effectiveFromArg
  if effectiveUntilArg == .nil then effectiveUntil = .nil
  else if effectiveUntilArg~string = "" then effectiveUntil = .nil
  else effectiveUntil = effectiveUntilArg
  authoredBy = authoredByArg~string
  approvedBy = approvedByArg~string
  supersedes = supersedesArg~string
  payload = payloadArg
  payloadIdentity = payloadIdentityArg~string
  executionModel = .InstitutionalPolicyBuild~EXECUTION_MODEL
  sealed = .false
::method activeAt
  expose effectiveFrom effectiveUntil
  use arg moment
  if moment < effectiveFrom then return .false
  if effectiveUntil == .nil then return .true
  return moment < effectiveUntil
::method publicationEligible
  expose sealed policyId version effectiveFrom effectiveUntil authoredBy approvedBy payload
  if \sealed then return .false
  if policyId = "" | version = "" then return .false
  if authoredBy = "" | approvedBy = "" then return .false
  if effectiveUntil <> .nil then if effectiveUntil <= effectiveFrom then return .false
  if payload <> .nil then do
    if payload~hasMethod("PUBLICATIONELIGIBLE") then do
      if payload~publicationEligible = .false then return .false
    end
    else if payload~hasMethod("SEALED") then do
      if payload~sealed = .false then return .false
    end
  end
  return .true
::method seal
  expose sealed payload payloadIdentity
  if sealed then return self
  if payload <> .nil then do
    if payload~hasMethod("SEALED") then do
      if payload~sealed = .false then raise syntax 88.910 array("InstitutionalPolicyRelease payload must be sealed before release")
    end
  end
  payloadIdentity = .InstitutionalPolicyCanonical~payloadIdentity(payload, payloadIdentity)
  sealed = .true
  return self
::method payloadIdentity
  expose payloadIdentity sealed
  if \sealed then raise syntax 88.911 array("payloadIdentity requires a sealed policy release")
  return payloadIdentity
::method canonicalText
  expose policyId version effectiveFrom effectiveUntil authoredBy approvedBy supersedes payloadIdentity executionModel sealed
  if \sealed then raise syntax 88.912 array("canonicalText requires a sealed policy release")
  text = "INSTITUTIONAL-POLICY-RELEASE/1" || '0a'x
  text ||= .InstitutionalPolicyCanonical~field("POLICY_ID", policyId)
  text ||= .InstitutionalPolicyCanonical~field("VERSION", version)
  text ||= .InstitutionalPolicyCanonical~field("EFFECTIVE_FROM", effectiveFrom)
  text ||= .InstitutionalPolicyCanonical~field("EFFECTIVE_UNTIL", effectiveUntil)
  text ||= .InstitutionalPolicyCanonical~field("AUTHORED_BY", authoredBy)
  text ||= .InstitutionalPolicyCanonical~field("APPROVED_BY", approvedBy)
  text ||= .InstitutionalPolicyCanonical~field("SUPERSEDES", supersedes)
  text ||= .InstitutionalPolicyCanonical~field("EXECUTION_MODEL", executionModel)
  text ||= .InstitutionalPolicyCanonical~field("PAYLOAD_IDENTITY", payloadIdentity)
  return text
::method semanticIdentity
  return self~canonicalText

::class InstitutionalPolicyPublicationRecord public
::attribute policyId get
::attribute version get
::attribute policyIdentity get
::attribute publishedAt get
::attribute supersedes get
::attribute authoredBy get
::attribute approvedBy get
::attribute publisherId get
::attribute authorityDecision get
::attribute assuranceMode get
::attribute emergency get
::attribute emergencyReason get
::attribute emergencyExpiresAt get
::method init
  expose policyId version policyIdentity publishedAt supersedes authoredBy approvedBy publisherId authorityDecision assuranceMode emergency emergencyReason emergencyExpiresAt
  use arg policy, publishedAtArg = .nil, authorityDecisionArg = .nil, publicationRequestArg = .nil
  policyId = policy~policyId
  version = policy~version
  policyIdentity = policy~semanticIdentity
  if publishedAtArg == .nil then publishedAt = .DateTime~new
  else publishedAt = publishedAtArg
  supersedes = policy~supersedes
  if policy~hasMethod("AUTHOREDBY") then authoredBy = policy~authoredBy
  else authoredBy = ""
  if policy~hasMethod("APPROVEDBY") then approvedBy = policy~approvedBy
  else approvedBy = ""
  authorityDecision = authorityDecisionArg
  publisherId = ""
  assuranceMode = .InstitutionalPolicyBuild~ASSURANCE_IDENTIFIER_ONLY
  emergency = .false
  emergencyReason = ""
  emergencyExpiresAt = .nil
  if authorityDecision <> .nil then do
    if authorityDecision~hasMethod("PUBLISHERID") then publisherId = authorityDecision~publisherId
    if authorityDecision~hasMethod("ASSURANCEMODE") then assuranceMode = authorityDecision~assuranceMode
    if authorityDecision~hasMethod("EMERGENCY") then emergency = authorityDecision~emergency
  end
  if publicationRequestArg <> .nil then do
    if publicationRequestArg~hasMethod("EMERGENCYREASON") then emergencyReason = publicationRequestArg~emergencyReason
    if publicationRequestArg~hasMethod("EMERGENCYEXPIRESAT") then emergencyExpiresAt = publicationRequestArg~emergencyExpiresAt
  end
::method canonicalText
  expose policyId version policyIdentity publishedAt supersedes authoredBy approvedBy publisherId authorityDecision assuranceMode emergency emergencyReason emergencyExpiresAt
  text = .InstitutionalPolicyCanonical~field("POLICY", policyId || "@" || version)
  text ||= .InstitutionalPolicyCanonical~field("POLICY_IDENTITY", policyIdentity)
  text ||= .InstitutionalPolicyCanonical~field("PUBLISHED_AT", publishedAt)
  text ||= .InstitutionalPolicyCanonical~field("SUPERSEDES", supersedes)
  text ||= .InstitutionalPolicyCanonical~field("AUTHORED_BY", authoredBy)
  text ||= .InstitutionalPolicyCanonical~field("APPROVED_BY", approvedBy)
  text ||= .InstitutionalPolicyCanonical~field("PUBLISHER", publisherId)
  text ||= .InstitutionalPolicyCanonical~field("ASSURANCE_MODE", assuranceMode)
  text ||= .InstitutionalPolicyCanonical~field("EMERGENCY", emergency)
  text ||= .InstitutionalPolicyCanonical~field("EMERGENCY_REASON", emergencyReason)
  text ||= .InstitutionalPolicyCanonical~field("EMERGENCY_EXPIRES_AT", emergencyExpiresAt)
  if authorityDecision <> .nil then text ||= .InstitutionalPolicyCanonical~field("AUTHORITY_DECISION", authorityDecision~canonicalText)
  return text

/* Authority is deliberately separated from domain semantics. These objects say
   who is entitled to author/approve/publish an institutional policy artefact;
   they do not say what the policy means. Cryptographic or workflow evidence is
   optional and supplied through a host verifier rather than hard-coded here. */
::class InstitutionalPolicyAuthorityGrant public
::attribute grantId get
::attribute principalId get
::attribute action get
::attribute policyId get
::attribute effectiveFrom get
::attribute effectiveUntil get
::attribute grantedBy get
::attribute evidenceRef get
::attribute authorityClass get
::attribute delegatedFromGrantId get
::attribute sealed get
::method init
  expose grantId principalId action policyId effectiveFrom effectiveUntil grantedBy evidenceRef authorityClass delegatedFromGrantId sealed
  use arg grantIdArg, principalIdArg, actionArg, policyIdArg = "*", effectiveFromArg = .nil, effectiveUntilArg = .nil, grantedByArg = "", evidenceRefArg = "", authorityClassArg = "GENERAL", delegatedFromGrantIdArg = ""
  grantId = grantIdArg~string
  principalId = principalIdArg~string
  action = actionArg~string~upper
  policyId = policyIdArg~string~upper
  if effectiveFromArg == .nil then effectiveFrom = .DateTime~new - .TimeSpan~new(0,0,0,0,1)
  else effectiveFrom = effectiveFromArg
  if effectiveUntilArg == .nil then effectiveUntil = .nil
  else if effectiveUntilArg~string = "" then effectiveUntil = .nil
  else effectiveUntil = effectiveUntilArg
  grantedBy = grantedByArg~string
  evidenceRef = evidenceRefArg~string
  authorityClass = authorityClassArg~string~upper
  delegatedFromGrantId = delegatedFromGrantIdArg~string
  sealed = .false
::method publicationEligible
  expose sealed grantId principalId action policyId effectiveFrom effectiveUntil authorityClass
  if \sealed then return .false
  if grantId = "" | principalId = "" | action = "" | policyId = "" | authorityClass = "" then return .false
  if effectiveUntil <> .nil then if effectiveUntil <= effectiveFrom then return .false
  return .true
::method activeAt
  expose effectiveFrom effectiveUntil
  use arg moment
  if moment < effectiveFrom then return .false
  if effectiveUntil == .nil then return .true
  return moment < effectiveUntil
::method allows
  use arg principalArg, actionArg, policyIdArg, moment
  return self~allowsClass(principalArg, actionArg, policyIdArg, moment, "")
::method allowsClass
  expose principalId action policyId authorityClass sealed
  use arg principalArg, actionArg, policyIdArg, moment, requiredClass = ""
  if \sealed then return .false
  if principalId <> principalArg~string then return .false
  if action <> actionArg~string~upper then return .false
  requestedPolicy = policyIdArg~string~upper
  if policyId <> "*" & policyId <> requestedPolicy then return .false
  if requiredClass~string <> "" then if authorityClass <> requiredClass~string~upper then return .false
  return self~activeAt(moment)
::method seal
  expose sealed
  sealed = .true
  return self
::method canonicalText
  expose grantId principalId action policyId effectiveFrom effectiveUntil grantedBy evidenceRef authorityClass delegatedFromGrantId sealed
  if \sealed then raise syntax 88.920 array("authority grant must be sealed")
  text = "INSTITUTIONAL-POLICY-AUTHORITY-GRANT/2" || '0a'x
  text ||= .InstitutionalPolicyCanonical~field("GRANT_ID", grantId)
  text ||= .InstitutionalPolicyCanonical~field("PRINCIPAL", principalId)
  text ||= .InstitutionalPolicyCanonical~field("ACTION", action)
  text ||= .InstitutionalPolicyCanonical~field("POLICY_ID", policyId)
  text ||= .InstitutionalPolicyCanonical~field("AUTHORITY_CLASS", authorityClass)
  text ||= .InstitutionalPolicyCanonical~field("DELEGATED_FROM", delegatedFromGrantId)
  text ||= .InstitutionalPolicyCanonical~field("EFFECTIVE_FROM", effectiveFrom)
  text ||= .InstitutionalPolicyCanonical~field("EFFECTIVE_UNTIL", effectiveUntil)
  text ||= .InstitutionalPolicyCanonical~field("GRANTED_BY", grantedBy)
  text ||= .InstitutionalPolicyCanonical~field("EVIDENCE_REF", evidenceRef)
  return text
::method semanticIdentity
  return self~canonicalText

::class InstitutionalPolicyAuthorityRevocation public
::attribute revocationId get
::attribute grantId get
::attribute effectiveAt get
::attribute revokedBy get
::attribute evidenceRef get
::attribute sealed get
::method init
  expose revocationId grantId effectiveAt revokedBy evidenceRef sealed
  use arg revocationIdArg, grantIdArg, effectiveAtArg = .nil, revokedByArg = "", evidenceRefArg = ""
  revocationId = revocationIdArg~string
  grantId = grantIdArg~string
  if effectiveAtArg == .nil then effectiveAt = .DateTime~new
  else effectiveAt = effectiveAtArg
  revokedBy = revokedByArg~string
  evidenceRef = evidenceRefArg~string
  sealed = .false
::method appliesAt
  expose effectiveAt
  use arg moment
  return moment >= effectiveAt
::method seal
  expose sealed revocationId grantId revokedBy
  if revocationId = "" | grantId = "" | revokedBy = "" then raise syntax 88.933 array("authority revocation identity fields required")
  sealed = .true
  return self
::method canonicalText
  expose revocationId grantId effectiveAt revokedBy evidenceRef sealed
  if \sealed then raise syntax 88.934 array("authority revocation must be sealed")
  text = "INSTITUTIONAL-POLICY-AUTHORITY-REVOCATION/1" || '0a'x
  text ||= .InstitutionalPolicyCanonical~field("REVOCATION_ID", revocationId)
  text ||= .InstitutionalPolicyCanonical~field("GRANT_ID", grantId)
  text ||= .InstitutionalPolicyCanonical~field("EFFECTIVE_AT", effectiveAt)
  text ||= .InstitutionalPolicyCanonical~field("REVOKED_BY", revokedBy)
  text ||= .InstitutionalPolicyCanonical~field("EVIDENCE_REF", evidenceRef)
  return text
::method semanticIdentity
  return self~canonicalText

::class InstitutionalPolicyApprovalRequirement public
::attribute requirementId get
::attribute authorityClass get
::attribute minimumCount get
::attribute evidenceMode get
::attribute distinctFromAuthor get
::attribute sealed get
::method init
  expose requirementId authorityClass minimumCount evidenceMode distinctFromAuthor sealed
  use arg requirementIdArg, authorityClassArg = "GENERAL", minimumCountArg = 1, evidenceModeArg = "OPTIONAL", distinctFromAuthorArg = .true
  requirementId = requirementIdArg~string
  authorityClass = authorityClassArg~string~upper
  minimumCount = minimumCountArg + 0
  evidenceMode = evidenceModeArg~string~upper
  distinctFromAuthor = distinctFromAuthorArg
  sealed = .false
::method publicationEligible
  expose sealed requirementId authorityClass minimumCount evidenceMode
  if \sealed then return .false
  if requirementId = "" | authorityClass = "" | minimumCount < 1 then return .false
  if evidenceMode <> .InstitutionalPolicyBuild~APPROVAL_EVIDENCE_OPTIONAL & evidenceMode <> .InstitutionalPolicyBuild~APPROVAL_EVIDENCE_REQUIRED then return .false
  return .true
::method seal
  expose sealed
  sealed = .true
  return self
::method canonicalText
  expose requirementId authorityClass minimumCount evidenceMode distinctFromAuthor sealed
  if \sealed then raise syntax 88.935 array("approval requirement must be sealed")
  text = "INSTITUTIONAL-POLICY-APPROVAL-REQUIREMENT/1" || '0a'x
  text ||= .InstitutionalPolicyCanonical~field("REQUIREMENT_ID", requirementId)
  text ||= .InstitutionalPolicyCanonical~field("AUTHORITY_CLASS", authorityClass)
  text ||= .InstitutionalPolicyCanonical~field("MINIMUM_COUNT", minimumCount)
  text ||= .InstitutionalPolicyCanonical~field("EVIDENCE_MODE", evidenceMode)
  text ||= .InstitutionalPolicyCanonical~field("DISTINCT_FROM_AUTHOR", distinctFromAuthor)
  return text
::method semanticIdentity
  return self~canonicalText

::class InstitutionalPolicyAuthorityRule public
::attribute ruleId get
::attribute policyId get
::attribute distinctAuthorApprover get
::attribute approvalEvidenceMode get
::attribute emergencyAllowed get
::attribute emergencyMaxSeconds get
::attribute sealed get
::method init
  expose ruleId policyId distinctAuthorApprover approvalEvidenceMode emergencyAllowed emergencyMaxSeconds approvalRequirements sealed
  use arg ruleIdArg, policyIdArg = "*", distinctArg = .true, evidenceModeArg = "OPTIONAL", emergencyAllowedArg = .false, emergencyMaxSecondsArg = 0
  ruleId = ruleIdArg~string
  policyId = policyIdArg~string~upper
  distinctAuthorApprover = distinctArg
  approvalEvidenceMode = evidenceModeArg~string~upper
  emergencyAllowed = emergencyAllowedArg
  emergencyMaxSeconds = emergencyMaxSecondsArg + 0
  approvalRequirements = .array~new
  sealed = .false
::method addApprovalRequirement
  expose approvalRequirements sealed
  use arg requirement
  if sealed then return .InstitutionalPolicyResult~failure("AUTHORITY_RULE_SEALED")
  if requirement == .nil then return .InstitutionalPolicyResult~failure("APPROVAL_REQUIREMENT_REQUIRED")
  if requirement~publicationEligible = .false then return .InstitutionalPolicyResult~failure("APPROVAL_REQUIREMENT_INVALID")
  do existing over approvalRequirements
    if existing~requirementId = requirement~requirementId then return .InstitutionalPolicyResult~failure("APPROVAL_REQUIREMENT_DUPLICATE", requirement~requirementId)
  end
  approvalRequirements~append(requirement)
  return .InstitutionalPolicyResult~success(requirement)
::method approvalRequirements
  expose approvalRequirements
  return .InstitutionalPolicyCanonical~copyArray(approvalRequirements)
::method publicationEligible
  expose sealed ruleId policyId approvalEvidenceMode emergencyAllowed emergencyMaxSeconds approvalRequirements
  if \sealed then return .false
  if ruleId = "" | policyId = "" then return .false
  if approvalEvidenceMode <> .InstitutionalPolicyBuild~APPROVAL_EVIDENCE_OPTIONAL & approvalEvidenceMode <> .InstitutionalPolicyBuild~APPROVAL_EVIDENCE_REQUIRED then return .false
  if emergencyAllowed & emergencyMaxSeconds <= 0 then return .false
  do requirement over approvalRequirements
    if requirement~publicationEligible = .false then return .false
  end
  return .true
::method appliesTo
  expose policyId
  use arg policyIdArg
  return policyId = "*" | policyId = policyIdArg~string~upper
::method seal
  expose sealed
  sealed = .true
  return self
::method canonicalText
  expose ruleId policyId distinctAuthorApprover approvalEvidenceMode emergencyAllowed emergencyMaxSeconds approvalRequirements sealed
  if \sealed then raise syntax 88.921 array("authority rule must be sealed")
  text = "INSTITUTIONAL-POLICY-AUTHORITY-RULE/2" || '0a'x
  text ||= .InstitutionalPolicyCanonical~field("RULE_ID", ruleId)
  text ||= .InstitutionalPolicyCanonical~field("POLICY_ID", policyId)
  text ||= .InstitutionalPolicyCanonical~field("DISTINCT_AUTHOR_APPROVER", distinctAuthorApprover)
  text ||= .InstitutionalPolicyCanonical~field("APPROVAL_EVIDENCE_MODE", approvalEvidenceMode)
  text ||= .InstitutionalPolicyCanonical~field("EMERGENCY_ALLOWED", emergencyAllowed)
  text ||= .InstitutionalPolicyCanonical~field("EMERGENCY_MAX_SECONDS", emergencyMaxSeconds)
  reqTexts = .array~new
  do requirement over approvalRequirements
    reqTexts~append(requirement~semanticIdentity)
  end
  do reqText over .InstitutionalPolicyCanonical~sortedStrings(reqTexts)
    text ||= .InstitutionalPolicyCanonical~field("APPROVAL_REQUIREMENT", reqText)
  end
  return text
::method semanticIdentity
  return self~canonicalText

::class InstitutionalPolicyAuthorityProfile subclass AlchemyObject public
::attribute profileId get
::attribute version get
::attribute effectiveFrom get
::attribute effectiveUntil get
::attribute supersedes get
::attribute sealed get
::method init
  expose profileId version effectiveFrom effectiveUntil supersedes grants revocations rules sealed
  use arg profileIdArg, versionArg, effectiveFromArg = .nil, effectiveUntilArg = .nil, metadataArg = .nil, sealer = .nil, authority = .nil, supersedesArg = ""
  profileId = profileIdArg~string~upper
  version = versionArg~string
  if effectiveFromArg == .nil then effectiveFrom = .DateTime~new - .TimeSpan~new(0,0,0,0,1)
  else effectiveFrom = effectiveFromArg
  if effectiveUntilArg == .nil then effectiveUntil = .nil
  else if effectiveUntilArg~string = "" then effectiveUntil = .nil
  else effectiveUntil = effectiveUntilArg
  supersedes = supersedesArg~string
  grants = .array~new
  revocations = .array~new
  rules = .array~new
  sealed = .false
  if metadataArg == .nil then metadataArg = .InstitutionalPolicySupport~metadata("fixed authority profile governing institutional policy publication")
  self~init:super(metadataArg, sealer, authority)
  self~registerStateVariable("grants", "INTERNAL", "sealed principal authority grants")
  self~registerStateVariable("revocations", "INTERNAL", "sealed authority revocations")
  self~registerStateVariable("rules", "INTERNAL", "sealed policy publication authority rules")
::method addGrant
  expose grants sealed
  use arg grant
  if sealed then return .InstitutionalPolicyResult~failure("AUTHORITY_PROFILE_SEALED")
  if grant == .nil then return .InstitutionalPolicyResult~failure("AUTHORITY_GRANT_REQUIRED")
  if grant~hasMethod("PUBLICATIONELIGIBLE") = .false | grant~publicationEligible = .false then return .InstitutionalPolicyResult~failure("AUTHORITY_GRANT_INVALID")
  do existing over grants
    if existing~grantId = grant~grantId then return .InstitutionalPolicyResult~failure("AUTHORITY_GRANT_DUPLICATE", grant~grantId)
  end
  grants~append(grant)
  return .InstitutionalPolicyResult~success(grant)
::method addRevocation
  expose revocations sealed
  use arg revocation
  if sealed then return .InstitutionalPolicyResult~failure("AUTHORITY_PROFILE_SEALED")
  if revocation == .nil then return .InstitutionalPolicyResult~failure("AUTHORITY_REVOCATION_REQUIRED")
  if revocation~sealed = .false then return .InstitutionalPolicyResult~failure("AUTHORITY_REVOCATION_INVALID")
  do existing over revocations
    if existing~revocationId = revocation~revocationId then return .InstitutionalPolicyResult~failure("AUTHORITY_REVOCATION_DUPLICATE", revocation~revocationId)
  end
  revocations~append(revocation)
  return .InstitutionalPolicyResult~success(revocation)
::method addRule
  expose rules sealed
  use arg rule
  if sealed then return .InstitutionalPolicyResult~failure("AUTHORITY_PROFILE_SEALED")
  if rule == .nil then return .InstitutionalPolicyResult~failure("AUTHORITY_RULE_REQUIRED")
  if rule~hasMethod("PUBLICATIONELIGIBLE") = .false | rule~publicationEligible = .false then return .InstitutionalPolicyResult~failure("AUTHORITY_RULE_INVALID")
  do existing over rules
    if existing~ruleId = rule~ruleId then return .InstitutionalPolicyResult~failure("AUTHORITY_RULE_DUPLICATE", rule~ruleId)
  end
  rules~append(rule)
  return .InstitutionalPolicyResult~success(rule)
::method setSupersedes
  expose supersedes sealed
  use arg versionArg
  if sealed then return .InstitutionalPolicyResult~failure("AUTHORITY_PROFILE_SEALED")
  supersedes = versionArg~string
  return .InstitutionalPolicyResult~success(self)
::method activeAt
  expose effectiveFrom effectiveUntil
  use arg moment
  if moment < effectiveFrom then return .false
  if effectiveUntil == .nil then return .true
  return moment < effectiveUntil
::method findGrantById private
  expose grants
  use arg grantId
  do grant over grants
    if grant~grantId = grantId~string then return grant
  end
  return .nil
::method grantRevokedAt private
  expose revocations
  use arg grantId, moment
  do revocation over revocations
    if revocation~grantId = grantId~string & revocation~appliesAt(moment) then return .true
  end
  grant = self~findGrantById(grantId)
  if grant <> .nil then if grant~delegatedFromGrantId <> "" then return self~grantRevokedAt(grant~delegatedFromGrantId, moment)
  return .false
::method authorityGrant
  expose grants sealed
  use arg principalId, action, policyId, moment, requiredClass = ""
  if \sealed then return .InstitutionalPolicyResult~failure("AUTHORITY_PROFILE_NOT_SEALED")
  matches = .array~new
  do grant over grants
    if grant~allowsClass(principalId, action, policyId, moment, requiredClass) then do
      if self~grantRevokedAt(grant~grantId, moment) = .false then matches~append(grant)
    end
  end
  if matches~items = 0 then return .InstitutionalPolicyResult~failure("POLICY_AUTHORITY_NOT_GRANTED", principalId || "/" || action || "/" || policyId || "/" || requiredClass)
  if matches~items > 1 then return .InstitutionalPolicyResult~failure("POLICY_AUTHORITY_AMBIGUOUS", principalId || "/" || action || "/" || policyId || "/" || requiredClass)
  return .InstitutionalPolicyResult~success(matches[1])
::method authorityRule
  expose rules sealed
  use arg policyId
  if \sealed then return .InstitutionalPolicyResult~failure("AUTHORITY_PROFILE_NOT_SEALED")
  exact = .nil
  wildcard = .nil
  do rule over rules
    if rule~policyId = policyId~string~upper then exact = rule
    else if rule~policyId = "*" then wildcard = rule
  end
  if exact <> .nil then return .InstitutionalPolicyResult~success(exact)
  if wildcard <> .nil then return .InstitutionalPolicyResult~success(wildcard)
  return .InstitutionalPolicyResult~failure("POLICY_AUTHORITY_RULE_NOT_FOUND", policyId~string)
::method seal
  expose sealed profileId version effectiveFrom effectiveUntil supersedes grants revocations rules
  if profileId = "" | version = "" then raise syntax 88.922 array("authority profile identity required")
  if effectiveUntil <> .nil then if effectiveUntil <= effectiveFrom then raise syntax 88.923 array("authority profile effective range invalid")
  do grant over grants
    if grant~publicationEligible = .false then raise syntax 88.924 array("authority profile contains invalid grant")
  end
  do revocation over revocations
    if self~findGrantById(revocation~grantId) == .nil then raise syntax 88.936 array("authority revocation references unknown grant " || revocation~grantId)
  end
  do grant over grants
    if grant~delegatedFromGrantId <> "" then do
      parent = self~findGrantById(grant~delegatedFromGrantId)
      if parent == .nil then raise syntax 88.937 array("delegated authority references unknown parent grant " || grant~delegatedFromGrantId)
      if parent~action <> grant~action then raise syntax 88.938 array("delegated authority action exceeds parent grant")
      if parent~policyId <> "*" & parent~policyId <> grant~policyId then raise syntax 88.939 array("delegated authority policy scope exceeds parent grant")
      if parent~authorityClass <> grant~authorityClass then raise syntax 88.940 array("delegated authority class must match parent grant")
      if grant~grantedBy <> "" then if grant~grantedBy <> parent~principalId then raise syntax 88.947 array("delegated authority grantedBy must identify parent principal")
      if grant~effectiveFrom < parent~effectiveFrom then raise syntax 88.941 array("delegated authority starts before parent grant")
      if parent~effectiveUntil <> .nil then do
        if grant~effectiveUntil == .nil then raise syntax 88.942 array("delegated authority may not outlive bounded parent grant")
        if grant~effectiveUntil > parent~effectiveUntil then raise syntax 88.943 array("delegated authority outlives parent grant")
      end
      seen = .directory~new
      cursor = grant
      do while cursor~delegatedFromGrantId <> ""
        if seen~hasIndex(cursor~grantId) then raise syntax 88.946 array("delegated authority cycle detected at " || cursor~grantId)
        seen[cursor~grantId] = .true
        cursor = self~findGrantById(cursor~delegatedFromGrantId)
        if cursor == .nil then leave
      end
    end
  end
  do rule over rules
    if rule~publicationEligible = .false then raise syntax 88.925 array("authority profile contains invalid rule")
  end
  sealed = .true
  return self
::method grants
  expose grants
  return .InstitutionalPolicyCanonical~copyArray(grants)
::method revocations
  expose revocations
  return .InstitutionalPolicyCanonical~copyArray(revocations)
::method rules
  expose rules
  return .InstitutionalPolicyCanonical~copyArray(rules)
::method canonicalText
  expose profileId version effectiveFrom effectiveUntil supersedes grants revocations rules sealed
  if \sealed then raise syntax 88.926 array("authority profile must be sealed")
  text = "INSTITUTIONAL-POLICY-AUTHORITY-PROFILE/2" || '0a'x
  text ||= .InstitutionalPolicyCanonical~field("PROFILE_ID", profileId)
  text ||= .InstitutionalPolicyCanonical~field("VERSION", version)
  text ||= .InstitutionalPolicyCanonical~field("EFFECTIVE_FROM", effectiveFrom)
  text ||= .InstitutionalPolicyCanonical~field("EFFECTIVE_UNTIL", effectiveUntil)
  text ||= .InstitutionalPolicyCanonical~field("SUPERSEDES", supersedes)
  grantTexts = .array~new
  do grant over grants
    grantTexts~append(grant~semanticIdentity)
  end
  do grantText over .InstitutionalPolicyCanonical~sortedStrings(grantTexts)
    text ||= .InstitutionalPolicyCanonical~field("GRANT", grantText)
  end
  revTexts = .array~new
  do revocation over revocations
    revTexts~append(revocation~semanticIdentity)
  end
  do revText over .InstitutionalPolicyCanonical~sortedStrings(revTexts)
    text ||= .InstitutionalPolicyCanonical~field("REVOCATION", revText)
  end
  ruleTexts = .array~new
  do rule over rules
    ruleTexts~append(rule~semanticIdentity)
  end
  do ruleText over .InstitutionalPolicyCanonical~sortedStrings(ruleTexts)
    text ||= .InstitutionalPolicyCanonical~field("RULE", ruleText)
  end
  return text
::method semanticIdentity
  return self~canonicalText

::class InstitutionalPolicyAuthorityProfileCatalog subclass AlchemyObject public
::method init
  expose profiles byVersion resultClass
  use arg metadataArg = .nil, sealer = .nil, authority = .nil
  profiles = .directory~new
  byVersion = .directory~new
  resultClass = .InstitutionalPolicyResult
  if metadataArg == .nil then metadataArg = .InstitutionalPolicySupport~metadata("effective-dated institutional policy authority profile catalogue")
  self~init:super(metadataArg, sealer, authority)
  self~registerStateVariable("profiles", "INTERNAL", "published immutable authority profiles")
  self~registerMethodContract("PUBLISH", "publish a sealed authority profile with unambiguous effective range", .array~of("PROFILE"), "INSTITUTIONALPOLICYRESULT", .false, "AUTO", "INTERNAL", "SENSITIVE", "MUTATE", "USE")
  self~registerMethodContract("RESOLVE", "resolve authority profile operative at historical time", .array~of("PROFILE_ID", "AT_TIME"), "INSTITUTIONALPOLICYRESULT", .false, "AUTO", "INTERNAL", "SENSITIVE", "READ", "NONE")
::method rangesOverlap private
  use arg a, b
  if a~effectiveUntil <> .nil then if a~effectiveUntil <= b~effectiveFrom then return .false
  if b~effectiveUntil <> .nil then if b~effectiveUntil <= a~effectiveFrom then return .false
  return .true
::method publish
  expose profiles byVersion resultClass
  use arg profile
  if profile == .nil then return resultClass~failure("AUTHORITY_PROFILE_REQUIRED")
  if profile~sealed = .false then return resultClass~failure("AUTHORITY_PROFILE_NOT_SEALED")
  key = profile~profileId || "@" || profile~version
  if byVersion~hasIndex(key) then return resultClass~failure("AUTHORITY_PROFILE_VERSION_DUPLICATE", key)
  if profile~supersedes <> "" then do
    priorKey = profile~profileId || "@" || profile~supersedes
    if byVersion~hasIndex(priorKey) = .false then return resultClass~failure("SUPERSEDED_AUTHORITY_PROFILE_NOT_FOUND", priorKey)
  end
  if profiles~hasIndex(profile~profileId) then do existing over profiles[profile~profileId]
    if self~rangesOverlap(existing, profile) then return resultClass~failure("AUTHORITY_PROFILE_EFFECTIVE_RANGE_OVERLAP", existing~version || " with " || profile~version)
  end
  if profiles~hasIndex(profile~profileId) = .false then profiles[profile~profileId] = .array~new
  profiles[profile~profileId]~append(profile)
  byVersion[key] = profile
  self~recordRelationship("PUBLISHES_AUTHORITY_PROFILE", profile, "fixed institutional policy governance authority", "INTERNAL")
  return resultClass~success(profile)
::method resolve
  expose profiles resultClass
  use arg profileId, atTime = .nil
  if atTime == .nil then atTime = .DateTime~new
  key = profileId~string~upper
  if profiles~hasIndex(key) = .false then return resultClass~failure("AUTHORITY_PROFILE_NOT_FOUND", key)
  matches = .array~new
  do profile over profiles[key]
    if profile~activeAt(atTime) then matches~append(profile)
  end
  if matches~items = 0 then return resultClass~failure("AUTHORITY_PROFILE_NOT_EFFECTIVE", key)
  if matches~items > 1 then return resultClass~failure("AUTHORITY_PROFILE_AMBIGUOUS", key || " at " || atTime)
  return resultClass~success(matches[1])
::method profileVersion
  expose byVersion resultClass
  use arg profileId, version
  key = profileId~string~upper || "@" || version~string
  if byVersion~hasIndex(key) = .false then return resultClass~failure("AUTHORITY_PROFILE_VERSION_NOT_FOUND", key)
  return resultClass~success(byVersion[key])

::class InstitutionalPolicyAuthorityBinding public
::attribute profileCatalog get
::attribute profileId get
::method init
  expose profileCatalog profileId
  use arg catalogArg, profileIdArg
  if catalogArg == .nil then raise syntax 88.944 array("authority binding requires profile catalogue")
  profileCatalog = catalogArg
  profileId = profileIdArg~string~upper
  if profileId = "" then raise syntax 88.945 array("authority binding profile id required")
::method resolveAt
  expose profileCatalog profileId
  use arg moment
  return profileCatalog~resolve(profileId, moment)

::class InstitutionalPolicyApprovalAttestation public
::attribute attestationId get
::attribute policyId get
::attribute version get
::attribute policyIdentity get
::attribute approverId get
::attribute approvedAt get
::attribute evidenceKind get
::attribute evidenceRef get
::attribute sealed get
::method init
  expose attestationId policyId version policyIdentity approverId approvedAt evidenceKind evidenceRef sealed
  use arg attestationIdArg, policyIdArg, versionArg, policyIdentityArg, approverIdArg, approvedAtArg = .nil, evidenceKindArg = "WORKFLOW_RECORD", evidenceRefArg = ""
  attestationId = attestationIdArg~string
  policyId = policyIdArg~string~upper
  version = versionArg~string
  policyIdentity = policyIdentityArg~string
  approverId = approverIdArg~string
  if approvedAtArg == .nil then approvedAt = .DateTime~new
  else approvedAt = approvedAtArg
  evidenceKind = evidenceKindArg~string~upper
  evidenceRef = evidenceRefArg~string
  sealed = .false
::method matches
  expose policyId version policyIdentity approverId sealed
  use arg policy, expectedApprover = ""
  if \sealed then return .false
  if policyId <> policy~policyId then return .false
  if version <> policy~version then return .false
  if policyIdentity <> policy~semanticIdentity then return .false
  if expectedApprover~string <> "" then if approverId <> expectedApprover~string then return .false
  return .true
::method seal
  expose sealed attestationId policyId version policyIdentity approverId evidenceKind
  if attestationId = "" | policyId = "" | version = "" | policyIdentity = "" | approverId = "" | evidenceKind = "" then raise syntax 88.927 array("approval attestation identity fields required")
  sealed = .true
  return self
::method canonicalText
  expose attestationId policyId version policyIdentity approverId approvedAt evidenceKind evidenceRef sealed
  if \sealed then raise syntax 88.928 array("approval attestation must be sealed")
  text = "INSTITUTIONAL-POLICY-APPROVAL-ATTESTATION/1" || '0a'x
  text ||= .InstitutionalPolicyCanonical~field("ATTESTATION_ID", attestationId)
  text ||= .InstitutionalPolicyCanonical~field("POLICY", policyId || "@" || version)
  text ||= .InstitutionalPolicyCanonical~field("POLICY_IDENTITY", policyIdentity)
  text ||= .InstitutionalPolicyCanonical~field("APPROVER", approverId)
  text ||= .InstitutionalPolicyCanonical~field("APPROVED_AT", approvedAt)
  text ||= .InstitutionalPolicyCanonical~field("EVIDENCE_KIND", evidenceKind)
  text ||= .InstitutionalPolicyCanonical~field("EVIDENCE_REF", evidenceRef)
  return text
::method evidenceIdentity
  return self~canonicalText

::class InstitutionalPolicyEvidenceVerification public
::attribute verified get
::attribute code get
::attribute detail get
::attribute evidenceIdentity get
::method init
  expose verified code detail evidenceIdentity
  use arg verifiedArg, codeArg, detailArg = "", identityArg = ""
  verified = verifiedArg
  code = codeArg~string~upper
  detail = detailArg~string
  evidenceIdentity = identityArg~string

::class InstitutionalPolicyPublicationRequest public
::attribute policyId get
::attribute version get
::attribute policyIdentity get
::attribute publisherId get
::attribute requestedAt get
::attribute emergency get
::attribute emergencyReason get
::attribute emergencyExpiresAt get
::method init
  expose policyId version policyIdentity publisherId requestedAt approvals emergency emergencyReason emergencyExpiresAt
  use arg policy, publisherIdArg, requestedAtArg = .nil, emergencyArg = .false, emergencyReasonArg = "", emergencyExpiresAtArg = .nil
  if policy == .nil then raise syntax 88.929 array("publication request requires policy")
  policyId = policy~policyId
  version = policy~version
  policyIdentity = policy~semanticIdentity
  publisherId = publisherIdArg~string
  if requestedAtArg == .nil then requestedAt = .DateTime~new
  else requestedAt = requestedAtArg
  approvals = .array~new
  emergency = emergencyArg
  emergencyReason = emergencyReasonArg~string
  emergencyExpiresAt = emergencyExpiresAtArg
::method addApproval
  expose approvals
  use arg approval
  if approval == .nil then return .false
  approvals~append(approval)
  return .true
::method approvals
  expose approvals
  return .InstitutionalPolicyCanonical~copyArray(approvals)
::method matches
  expose policyId version policyIdentity
  use arg policy
  if policy == .nil then return .false
  return policyId = policy~policyId & version = policy~version & policyIdentity = policy~semanticIdentity

::class InstitutionalPolicyApprovalSelection public
::attribute requirementId get
::attribute approverId get
::attribute grantId get
::attribute authorityClass get
::attribute evidenceIdentity get
::attribute evidenceVerified get
::method init
  expose requirementId approverId grantId authorityClass evidenceIdentity evidenceVerified
  use arg requirementIdArg, approverIdArg, grantIdArg, authorityClassArg, evidenceIdentityArg = "", evidenceVerifiedArg = .false
  requirementId = requirementIdArg~string
  approverId = approverIdArg~string
  grantId = grantIdArg~string
  authorityClass = authorityClassArg~string~upper
  evidenceIdentity = evidenceIdentityArg~string
  evidenceVerified = evidenceVerifiedArg
::method canonicalText
  expose requirementId approverId grantId authorityClass evidenceIdentity evidenceVerified
  text = "INSTITUTIONAL-POLICY-APPROVAL-SELECTION/1" || '0a'x
  text ||= .InstitutionalPolicyCanonical~field("REQUIREMENT_ID", requirementId)
  text ||= .InstitutionalPolicyCanonical~field("APPROVER", approverId)
  text ||= .InstitutionalPolicyCanonical~field("GRANT_ID", grantId)
  text ||= .InstitutionalPolicyCanonical~field("AUTHORITY_CLASS", authorityClass)
  text ||= .InstitutionalPolicyCanonical~field("EVIDENCE_VERIFIED", evidenceVerified)
  text ||= .InstitutionalPolicyCanonical~field("EVIDENCE_IDENTITY", evidenceIdentity)
  return text

::class InstitutionalPolicyAuthorityDecision public
::attribute ok get
::attribute code get
::attribute detail get
::attribute assuranceMode get
::attribute authorityProfileId get
::attribute authorityProfileVersion get
::attribute authorityProfileIdentity get
::attribute authorId get
::attribute authorGrantId get
::attribute approverId get
::attribute approverGrantId get
::attribute publisherId get
::attribute publisherGrantId get
::attribute emergency get
::attribute emergencyGrantId get
::attribute evaluatedAt get
::method init
  expose ok code detail assuranceMode authorityProfileId authorityProfileVersion authorityProfileIdentity authorId authorGrantId approverId approverGrantId publisherId publisherGrantId approvalEvidenceIdentities approvalSelections emergency emergencyGrantId evaluatedAt
  use arg okArg, codeArg, detailArg, assuranceArg, profile, authorIdArg = "", authorGrantIdArg = "", approverIdArg = "", approverGrantIdArg = "", publisherIdArg = "", publisherGrantIdArg = "", evidenceIdsArg = .nil, evaluatedAtArg = .nil, approvalSelectionsArg = .nil, emergencyArg = .false, emergencyGrantIdArg = ""
  ok = okArg
  code = codeArg~string~upper
  detail = detailArg~string
  assuranceMode = assuranceArg~string~upper
  if profile == .nil then do
    authorityProfileId = ""
    authorityProfileVersion = ""
    authorityProfileIdentity = ""
  end
  else do
    authorityProfileId = profile~profileId
    authorityProfileVersion = profile~version
    authorityProfileIdentity = profile~semanticIdentity
  end
  authorId = authorIdArg~string
  authorGrantId = authorGrantIdArg~string
  approverId = approverIdArg~string
  approverGrantId = approverGrantIdArg~string
  publisherId = publisherIdArg~string
  publisherGrantId = publisherGrantIdArg~string
  approvalEvidenceIdentities = .array~new
  if evidenceIdsArg <> .nil then do item over evidenceIdsArg
    approvalEvidenceIdentities~append(item~string)
  end
  approvalSelections = .array~new
  if approvalSelectionsArg <> .nil then do selection over approvalSelectionsArg
    approvalSelections~append(selection)
  end
  emergency = emergencyArg
  emergencyGrantId = emergencyGrantIdArg~string
  if evaluatedAtArg == .nil then evaluatedAt = .DateTime~new
  else evaluatedAt = evaluatedAtArg
::method approvalEvidenceIdentities
  expose approvalEvidenceIdentities
  return .InstitutionalPolicyCanonical~copyArray(approvalEvidenceIdentities)
::method approvalSelections
  expose approvalSelections
  return .InstitutionalPolicyCanonical~copyArray(approvalSelections)
::method canonicalText
  expose ok code detail assuranceMode authorityProfileId authorityProfileVersion authorityProfileIdentity authorId authorGrantId approverId approverGrantId publisherId publisherGrantId approvalEvidenceIdentities approvalSelections emergency emergencyGrantId evaluatedAt
  text = "INSTITUTIONAL-POLICY-AUTHORITY-DECISION/2" || '0a'x
  text ||= .InstitutionalPolicyCanonical~field("OK", ok)
  text ||= .InstitutionalPolicyCanonical~field("CODE", code)
  text ||= .InstitutionalPolicyCanonical~field("DETAIL", detail)
  text ||= .InstitutionalPolicyCanonical~field("ASSURANCE_MODE", assuranceMode)
  text ||= .InstitutionalPolicyCanonical~field("PROFILE", authorityProfileId || "@" || authorityProfileVersion)
  text ||= .InstitutionalPolicyCanonical~field("PROFILE_IDENTITY", authorityProfileIdentity)
  text ||= .InstitutionalPolicyCanonical~field("AUTHOR", authorId)
  text ||= .InstitutionalPolicyCanonical~field("AUTHOR_GRANT", authorGrantId)
  text ||= .InstitutionalPolicyCanonical~field("APPROVER", approverId)
  text ||= .InstitutionalPolicyCanonical~field("APPROVER_GRANT", approverGrantId)
  text ||= .InstitutionalPolicyCanonical~field("PUBLISHER", publisherId)
  text ||= .InstitutionalPolicyCanonical~field("PUBLISHER_GRANT", publisherGrantId)
  text ||= .InstitutionalPolicyCanonical~field("EMERGENCY", emergency)
  text ||= .InstitutionalPolicyCanonical~field("EMERGENCY_GRANT", emergencyGrantId)
  selectionTexts = .array~new
  do selection over approvalSelections
    selectionTexts~append(selection~canonicalText)
  end
  do selectionText over .InstitutionalPolicyCanonical~sortedStrings(selectionTexts)
    text ||= .InstitutionalPolicyCanonical~field("APPROVAL_SELECTION", selectionText)
  end
  do evidenceId over .InstitutionalPolicyCanonical~sortedStrings(approvalEvidenceIdentities)
    text ||= .InstitutionalPolicyCanonical~field("APPROVAL_EVIDENCE", evidenceId)
  end
  text ||= .InstitutionalPolicyCanonical~field("EVALUATED_AT", evaluatedAt)
  return text

::class InstitutionalPolicyAuthorityEvaluator subclass AlchemyObject public
::attribute authorityProfile get
::attribute authorityBinding get
::attribute evidenceVerifier get
::method init
  expose authorityProfile authorityBinding evidenceVerifier
  use arg profileArg, evidenceVerifierArg = .nil, metadataArg = .nil, sealer = .nil, authority = .nil
  if profileArg == .nil then raise syntax 88.930 array("authority evaluator requires profile or binding")
  authorityProfile = .nil
  authorityBinding = .nil
  if profileArg~hasMethod("RESOLVEAT") then authorityBinding = profileArg
  else do
    if profileArg~sealed = .false then raise syntax 88.931 array("authority evaluator requires sealed profile")
    authorityProfile = profileArg
  end
  evidenceVerifier = evidenceVerifierArg
  if metadataArg == .nil then metadataArg = .InstitutionalPolicySupport~metadata("institutional policy author/approver/publisher authority evaluator")
  self~init:super(metadataArg, sealer, authority)
  if authorityProfile <> .nil then self~recordRelationship("AUTHORITY_PROFILE", authorityProfile, "fixed policy publication authority", "INTERNAL")
  if authorityBinding <> .nil then self~recordRelationship("AUTHORITY_PROFILE_BINDING", authorityBinding, "effective-dated policy publication authority resolution", "INTERNAL")
  if evidenceVerifier <> .nil then self~recordRelationship("APPROVAL_EVIDENCE_VERIFIER", evidenceVerifier, "optional host-owned approval evidence verification", "INTERNAL")
::method resolveProfile private
  expose authorityProfile authorityBinding
  use arg atTime
  if authorityProfile <> .nil then return .InstitutionalPolicyResult~success(authorityProfile)
  return authorityBinding~resolveAt(atTime)
::method fail private
  use arg code, detail, profile = .nil, authorId = "", approverId = "", publisherId = "", atTime = .nil, selections = .nil, emergency = .false, emergencyGrantId = ""
  return .InstitutionalPolicyAuthorityDecision~new(.false, code, detail, .InstitutionalPolicyBuild~ASSURANCE_ROLE_AUTHORITY, profile, authorId, "", approverId, "", publisherId, "", .nil, atTime, selections, emergency, emergencyGrantId)
::method verifyApproval private
  expose evidenceVerifier
  use arg approval, policy, profile
  if evidenceVerifier == .nil then return .InstitutionalPolicyEvidenceVerification~new(.false,"NO_VERIFIER")
  verification = evidenceVerifier~verify(approval, policy, profile)
  if verification == .nil then return .InstitutionalPolicyEvidenceVerification~new(.false,"NO_VERIFICATION_RESULT")
  return verification
::method selectRequirements private
  expose evidenceVerifier
  use arg policy, request, profile, rule, authorId
  requirements = rule~approvalRequirements
  if evidenceVerifier == .nil then do requirement over requirements
    if requirement~evidenceMode = .InstitutionalPolicyBuild~APPROVAL_EVIDENCE_REQUIRED then return .InstitutionalPolicyResult~failure("APPROVAL_EVIDENCE_VERIFIER_REQUIRED", requirement~requirementId)
  end
  selections = .array~new
  evidenceIds = .array~new
  usedApprovers = .directory~new
  verifiedAny = .false
  approvalByKey = .directory~new
  approvalKeys = .array~new
  do approval over request~approvals
    key = approval~approverId || "|" || approval~attestationId || "|" || approval~evidenceIdentity
    if approvalByKey~hasIndex(key) = .false then do
      approvalByKey[key] = approval
      approvalKeys~append(key)
    end
  end
  approvalKeys~sort
  do requirement over requirements
    count = 0
    do approvalKey over approvalKeys
      if count >= requirement~minimumCount then leave
      approval = approvalByKey[approvalKey]
      if approval~matches(policy) = .false then iterate
      approver = approval~approverId
      if requirement~distinctFromAuthor then if approver = authorId then iterate
      if usedApprovers~hasIndex(approver) then iterate
      grantResult = profile~authorityGrant(approver, .InstitutionalPolicyBuild~AUTHORITY_APPROVER, policy~policyId, request~requestedAt, requirement~authorityClass)
      if grantResult~ok = .false then iterate
      verified = .false
      evidenceIdentity = ""
      if evidenceVerifier <> .nil then do
        verification = self~verifyApproval(approval, policy, profile)
        if verification~verified then do
          verified = .true
          verifiedAny = .true
          evidenceIdentity = verification~evidenceIdentity
          if evidenceIdentity = "" then evidenceIdentity = approval~evidenceIdentity
          evidenceIds~append(evidenceIdentity)
        end
      end
      if requirement~evidenceMode = .InstitutionalPolicyBuild~APPROVAL_EVIDENCE_REQUIRED & \verified then iterate
      selection = .InstitutionalPolicyApprovalSelection~new(requirement~requirementId, approver, grantResult~value~grantId, requirement~authorityClass, evidenceIdentity, verified)
      selections~append(selection)
      usedApprovers[approver] = .true
      count += 1
    end
    if count < requirement~minimumCount then return .InstitutionalPolicyResult~failure("APPROVAL_REQUIREMENT_UNSATISFIED", requirement~requirementId || " requires " || requirement~minimumCount || " " || requirement~authorityClass || " approver(s)", selections)
  end
  bundle = .directory~new
  bundle["SELECTIONS"] = selections
  bundle["EVIDENCE_IDS"] = evidenceIds
  bundle["VERIFIED_ANY"] = verifiedAny
  return .InstitutionalPolicyResult~success(bundle)
::method emergencyWindowValid private
  use arg policy, request, rule
  if \request~emergency then return .InstitutionalPolicyResult~success
  if \rule~emergencyAllowed then return .InstitutionalPolicyResult~failure("EMERGENCY_PUBLICATION_NOT_ALLOWED", policy~policyId)
  if request~emergencyReason = "" then return .InstitutionalPolicyResult~failure("EMERGENCY_REASON_REQUIRED", policy~policyId)
  if request~emergencyExpiresAt == .nil then return .InstitutionalPolicyResult~failure("EMERGENCY_EXPIRY_REQUIRED", policy~policyId)
  if request~emergencyExpiresAt <= request~requestedAt then return .InstitutionalPolicyResult~failure("EMERGENCY_EXPIRY_INVALID", policy~policyId)
  if policy~effectiveFrom < request~requestedAt then return .InstitutionalPolicyResult~failure("EMERGENCY_POLICY_RETROACTIVE", policy~policyId)
  if policy~effectiveUntil == .nil then return .InstitutionalPolicyResult~failure("EMERGENCY_POLICY_MUST_EXPIRE", policy~policyId)
  if policy~effectiveUntil > request~emergencyExpiresAt then return .InstitutionalPolicyResult~failure("EMERGENCY_POLICY_OUTLIVES_AUTHORITY", policy~policyId)
  maxEnd = request~requestedAt + .InstitutionalPolicyTime~seconds(rule~emergencyMaxSeconds)
  if request~emergencyExpiresAt > maxEnd then return .InstitutionalPolicyResult~failure("EMERGENCY_AUTHORITY_EXCEEDS_MAX_LIFETIME", rule~emergencyMaxSeconds)
  if policy~effectiveUntil > maxEnd then return .InstitutionalPolicyResult~failure("EMERGENCY_POLICY_EXCEEDS_MAX_LIFETIME", rule~emergencyMaxSeconds)
  return .InstitutionalPolicyResult~success
::method evaluate
  expose evidenceVerifier
  use arg policy, request
  if policy == .nil then return self~fail("POLICY_REQUIRED", "")
  if request == .nil then return self~fail("PUBLICATION_REQUEST_REQUIRED", policy~policyId)
  atTime = request~requestedAt
  authorId = ""
  legacyApproverId = ""
  if policy~hasMethod("AUTHOREDBY") then authorId = policy~authoredBy
  if policy~hasMethod("APPROVEDBY") then legacyApproverId = policy~approvedBy
  publisherId = request~publisherId
  if request~matches(policy) = .false then return self~fail("PUBLICATION_REQUEST_POLICY_MISMATCH", policy~policyId || "@" || policy~version, .nil, authorId, legacyApproverId, publisherId, atTime)
  profileResult = self~resolveProfile(atTime)
  if profileResult~ok = .false then return self~fail(profileResult~code, profileResult~detail, .nil, authorId, legacyApproverId, publisherId, atTime)
  profile = profileResult~value
  if profile~activeAt(atTime) = .false then return self~fail("AUTHORITY_PROFILE_NOT_EFFECTIVE", profile~profileId, profile, authorId, legacyApproverId, publisherId, atTime)
  ruleResult = profile~authorityRule(policy~policyId)
  if ruleResult~ok = .false then return self~fail(ruleResult~code, ruleResult~detail, profile, authorId, legacyApproverId, publisherId, atTime)
  rule = ruleResult~value
  authorGrant = profile~authorityGrant(authorId, .InstitutionalPolicyBuild~AUTHORITY_AUTHOR, policy~policyId, atTime)
  if authorGrant~ok = .false then return self~fail("AUTHOR_AUTHORITY_DENIED", authorGrant~detail, profile, authorId, legacyApproverId, publisherId, atTime)

  emergencyGrantId = ""
  if request~emergency then do
    window = self~emergencyWindowValid(policy, request, rule)
    if window~ok = .false then return self~fail(window~code, window~detail, profile, authorId, legacyApproverId, publisherId, atTime, .nil, .true)
    emergencyGrant = profile~authorityGrant(publisherId, .InstitutionalPolicyBuild~AUTHORITY_EMERGENCY_PUBLISHER, policy~policyId, atTime, .InstitutionalPolicyBuild~AUTHORITY_CLASS_EMERGENCY)
    if emergencyGrant~ok = .false then return self~fail("EMERGENCY_PUBLISHER_AUTHORITY_DENIED", emergencyGrant~detail, profile, authorId, legacyApproverId, publisherId, atTime, .nil, .true)
    publisherGrantId = emergencyGrant~value~grantId
    emergencyGrantId = publisherGrantId
  end
  else do
    publisherGrant = profile~authorityGrant(publisherId, .InstitutionalPolicyBuild~AUTHORITY_PUBLISHER, policy~policyId, atTime)
    if publisherGrant~ok = .false then return self~fail("PUBLISHER_AUTHORITY_DENIED", publisherGrant~detail, profile, authorId, legacyApproverId, publisherId, atTime)
    publisherGrantId = publisherGrant~value~grantId
  end

  selections = .array~new
  evidenceIds = .array~new
  verifiedAny = .false
  requirements = rule~approvalRequirements
  if requirements~items > 0 then do
    selected = self~selectRequirements(policy, request, profile, rule, authorId)
    if selected~ok = .false then return self~fail(selected~code, selected~detail, profile, authorId, legacyApproverId, publisherId, atTime, selected~value)
    selections = selected~value["SELECTIONS"]
    evidenceIds = selected~value["EVIDENCE_IDS"]
    verifiedAny = selected~value["VERIFIED_ANY"]
  end
  else do
    if rule~distinctAuthorApprover then if authorId = legacyApproverId then return self~fail("AUTHOR_APPROVER_MUST_BE_DISTINCT", authorId, profile, authorId, legacyApproverId, publisherId, atTime)
    approverGrant = profile~authorityGrant(legacyApproverId, .InstitutionalPolicyBuild~AUTHORITY_APPROVER, policy~policyId, atTime)
    if approverGrant~ok = .false then return self~fail("APPROVER_AUTHORITY_DENIED", approverGrant~detail, profile, authorId, legacyApproverId, publisherId, atTime)
    verifiedApproval = .false
    chosenEvidence = ""
    do approval over request~approvals
      if approval~matches(policy, legacyApproverId) = .false then iterate
      if evidenceVerifier == .nil then iterate
      verification = self~verifyApproval(approval, policy, profile)
      if verification~verified then do
        verifiedApproval = .true
        verifiedAny = .true
        chosenEvidence = verification~evidenceIdentity
        if chosenEvidence = "" then chosenEvidence = approval~evidenceIdentity
        evidenceIds~append(chosenEvidence)
        leave
      end
    end
    if rule~approvalEvidenceMode = .InstitutionalPolicyBuild~APPROVAL_EVIDENCE_REQUIRED then do
      if evidenceVerifier == .nil then return self~fail("APPROVAL_EVIDENCE_VERIFIER_REQUIRED", policy~policyId, profile, authorId, legacyApproverId, publisherId, atTime)
      if \verifiedApproval then return self~fail("APPROVAL_EVIDENCE_NOT_VERIFIED", policy~policyId || "@" || policy~version, profile, authorId, legacyApproverId, publisherId, atTime)
    end
    selections~append(.InstitutionalPolicyApprovalSelection~new("LEGACY-PRIMARY", legacyApproverId, approverGrant~value~grantId, approverGrant~value~authorityClass, chosenEvidence, verifiedApproval))
  end

  assurance = .InstitutionalPolicyBuild~ASSURANCE_ROLE_AUTHORITY
  if verifiedAny then assurance = .InstitutionalPolicyBuild~ASSURANCE_VERIFIED_APPROVAL
  firstApprover = legacyApproverId
  firstGrant = ""
  if selections~items > 0 then do
    firstApprover = selections[1]~approverId
    firstGrant = selections[1]~grantId
  end
  return .InstitutionalPolicyAuthorityDecision~new(.true, "AUTHORIZED", "publication authority satisfied", assurance, profile, authorId, authorGrant~value~grantId, firstApprover, firstGrant, publisherId, publisherGrantId, evidenceIds, atTime, selections, request~emergency, emergencyGrantId)

/* Avoid a dependency from the common policy component on Security Effect just
   to construct an exact TimeSpan from seconds. */
/* Publication lifecycle events are immutable operational evidence around an exact
   semantic policy artefact. They do not mutate or replace the policy itself. */
::class InstitutionalPolicyLifecycleRequest public
::attribute eventId get
::attribute eventType get
::attribute policyId get
::attribute version get
::attribute policyIdentity get
::attribute actorId get
::attribute requestedAt get
::attribute effectiveAt get
::attribute reason get
::attribute evidenceRef get
::method init
  expose eventId eventType policyId version policyIdentity actorId requestedAt effectiveAt reason evidenceRef
  use arg eventIdArg, eventTypeArg, policy, actorIdArg, effectiveAtArg = .nil, reasonArg = "", evidenceRefArg = "", requestedAtArg = .nil
  if policy == .nil then raise syntax 88.950 array("lifecycle request requires policy")
  eventId = eventIdArg~string
  eventType = eventTypeArg~string~upper
  policyId = policy~policyId
  version = policy~version
  policyIdentity = policy~semanticIdentity
  actorId = actorIdArg~string
  if requestedAtArg == .nil then requestedAt = .DateTime~new
  else requestedAt = requestedAtArg
  if effectiveAtArg == .nil then effectiveAt = requestedAt
  else effectiveAt = effectiveAtArg
  reason = reasonArg~string
  evidenceRef = evidenceRefArg~string
::method matches
  expose policyId version policyIdentity
  use arg policy
  if policy == .nil then return .false
  return policyId = policy~policyId & version = policy~version & policyIdentity = policy~semanticIdentity
::method validEventType
  expose eventType
  return eventType = .InstitutionalPolicyBuild~LIFECYCLE_SUSPEND | eventType = .InstitutionalPolicyBuild~LIFECYCLE_RESUME | eventType = .InstitutionalPolicyBuild~LIFECYCLE_WITHDRAW | eventType = .InstitutionalPolicyBuild~LIFECYCLE_RATIFY

::class InstitutionalPolicyLifecycleDecision public
::attribute ok get
::attribute code get
::attribute detail get
::attribute assuranceMode get
::attribute authorityProfileId get
::attribute authorityProfileVersion get
::attribute authorityProfileIdentity get
::attribute actorId get
::attribute action get
::attribute grantId get
::attribute evaluatedAt get
::method init
  expose ok code detail assuranceMode authorityProfileId authorityProfileVersion authorityProfileIdentity actorId action grantId evaluatedAt
  use arg okArg, codeArg, detailArg, profile = .nil, actorIdArg = "", actionArg = "", grantIdArg = "", evaluatedAtArg = .nil
  ok = okArg
  code = codeArg~string~upper
  detail = detailArg~string
  assuranceMode = .InstitutionalPolicyBuild~ASSURANCE_ROLE_AUTHORITY
  if profile == .nil then do
    authorityProfileId = ""
    authorityProfileVersion = ""
    authorityProfileIdentity = ""
  end
  else do
    authorityProfileId = profile~profileId
    authorityProfileVersion = profile~version
    authorityProfileIdentity = profile~semanticIdentity
  end
  actorId = actorIdArg~string
  action = actionArg~string~upper
  grantId = grantIdArg~string
  if evaluatedAtArg == .nil then evaluatedAt = .DateTime~new
  else evaluatedAt = evaluatedAtArg
::method canonicalText
  expose ok code detail assuranceMode authorityProfileId authorityProfileVersion authorityProfileIdentity actorId action grantId evaluatedAt
  text = "INSTITUTIONAL-POLICY-LIFECYCLE-AUTHORITY/1" || '0a'x
  text ||= .InstitutionalPolicyCanonical~field("OK", ok)
  text ||= .InstitutionalPolicyCanonical~field("CODE", code)
  text ||= .InstitutionalPolicyCanonical~field("DETAIL", detail)
  text ||= .InstitutionalPolicyCanonical~field("ASSURANCE_MODE", assuranceMode)
  text ||= .InstitutionalPolicyCanonical~field("PROFILE", authorityProfileId || "@" || authorityProfileVersion)
  text ||= .InstitutionalPolicyCanonical~field("PROFILE_IDENTITY", authorityProfileIdentity)
  text ||= .InstitutionalPolicyCanonical~field("ACTOR", actorId)
  text ||= .InstitutionalPolicyCanonical~field("ACTION", action)
  text ||= .InstitutionalPolicyCanonical~field("GRANT_ID", grantId)
  text ||= .InstitutionalPolicyCanonical~field("EVALUATED_AT", evaluatedAt)
  return text

::class InstitutionalPolicyLifecycleAuthorityEvaluator subclass AlchemyObject public
::method init
  expose authorityProfile authorityBinding
  use arg profileArg, metadataArg = .nil, sealer = .nil, authority = .nil
  if profileArg == .nil then raise syntax 88.951 array("lifecycle authority evaluator requires profile or binding")
  authorityProfile = .nil
  authorityBinding = .nil
  if profileArg~hasMethod("RESOLVEAT") then authorityBinding = profileArg
  else do
    if profileArg~sealed = .false then raise syntax 88.952 array("lifecycle authority evaluator requires sealed profile")
    authorityProfile = profileArg
  end
  if metadataArg == .nil then metadataArg = .InstitutionalPolicySupport~metadata("institutional policy suspend/resume/withdraw/ratify authority evaluator")
  self~init:super(metadataArg, sealer, authority)
::method resolveProfile private
  expose authorityProfile authorityBinding
  use arg atTime
  if authorityProfile <> .nil then return .InstitutionalPolicyResult~success(authorityProfile)
  return authorityBinding~resolveAt(atTime)
::method evaluate
  use arg policy, request
  if policy == .nil then return .InstitutionalPolicyLifecycleDecision~new(.false,"POLICY_REQUIRED","")
  if request == .nil then return .InstitutionalPolicyLifecycleDecision~new(.false,"LIFECYCLE_REQUEST_REQUIRED",policy~policyId)
  if request~matches(policy) = .false then return .InstitutionalPolicyLifecycleDecision~new(.false,"LIFECYCLE_REQUEST_POLICY_MISMATCH",policy~policyId || "@" || policy~version,.nil,request~actorId,request~eventType,"",request~effectiveAt)
  if request~validEventType = .false then return .InstitutionalPolicyLifecycleDecision~new(.false,"LIFECYCLE_EVENT_TYPE_INVALID",request~eventType,.nil,request~actorId,request~eventType,"",request~effectiveAt)
  if request~eventId = "" | request~actorId = "" | request~reason = "" then return .InstitutionalPolicyLifecycleDecision~new(.false,"LIFECYCLE_IDENTITY_FIELDS_REQUIRED",request~eventType,.nil,request~actorId,request~eventType,"",request~effectiveAt)
  if request~effectiveAt < request~requestedAt then return .InstitutionalPolicyLifecycleDecision~new(.false,"LIFECYCLE_RETROACTIVE_NOT_ALLOWED",request~eventType,.nil,request~actorId,request~eventType,"",request~requestedAt)
  profileResult = self~resolveProfile(request~requestedAt)
  if profileResult~ok = .false then return .InstitutionalPolicyLifecycleDecision~new(.false,profileResult~code,profileResult~detail,.nil,request~actorId,request~eventType,"",request~effectiveAt)
  profile = profileResult~value
  if profile~activeAt(request~effectiveAt) = .false then return .InstitutionalPolicyLifecycleDecision~new(.false,"LIFECYCLE_AUTHORITY_NOT_VALID_AT_EFFECTIVE_TIME",profile~profileId,profile,request~actorId,request~eventType,"",request~requestedAt)
  grantResult = profile~authorityGrant(request~actorId, request~eventType, policy~policyId, request~requestedAt)
  if grantResult~ok = .false then return .InstitutionalPolicyLifecycleDecision~new(.false,"LIFECYCLE_AUTHORITY_DENIED",grantResult~detail,profile,request~actorId,request~eventType,"",request~requestedAt)
  if grantResult~value~allows(request~actorId,request~eventType,policy~policyId,request~effectiveAt) = .false then return .InstitutionalPolicyLifecycleDecision~new(.false,"LIFECYCLE_GRANT_NOT_VALID_AT_EFFECTIVE_TIME",grantResult~value~grantId,profile,request~actorId,request~eventType,grantResult~value~grantId,request~requestedAt)
  return .InstitutionalPolicyLifecycleDecision~new(.true,"AUTHORIZED","lifecycle authority satisfied",profile,request~actorId,request~eventType,grantResult~value~grantId,request~requestedAt)

::class InstitutionalPolicyLifecycleEvent public
::attribute eventId get
::attribute eventType get
::attribute policyId get
::attribute version get
::attribute policyIdentity get
::attribute actorId get
::attribute requestedAt get
::attribute effectiveAt get
::attribute reason get
::attribute evidenceRef get
::attribute authorityDecision get
::attribute sealed get
::method init
  expose eventId eventType policyId version policyIdentity actorId requestedAt effectiveAt reason evidenceRef authorityDecision sealed
  use arg request, authorityDecisionArg
  if request == .nil then raise syntax 88.953 array("lifecycle event requires request")
  eventId = request~eventId
  eventType = request~eventType
  policyId = request~policyId
  version = request~version
  policyIdentity = request~policyIdentity
  actorId = request~actorId
  requestedAt = request~requestedAt
  effectiveAt = request~effectiveAt
  reason = request~reason
  evidenceRef = request~evidenceRef
  authorityDecision = authorityDecisionArg
  sealed = .false
::method seal
  expose sealed eventId eventType policyId version policyIdentity actorId reason authorityDecision
  if eventId = "" | eventType = "" | policyId = "" | version = "" | policyIdentity = "" | actorId = "" | reason = "" then raise syntax 88.954 array("lifecycle event identity fields required")
  if authorityDecision == .nil | authorityDecision~ok = .false then raise syntax 88.955 array("lifecycle event requires authorized decision")
  sealed = .true
  return self
::method canonicalText
  expose eventId eventType policyId version policyIdentity actorId requestedAt effectiveAt reason evidenceRef authorityDecision sealed
  if \sealed then raise syntax 88.956 array("lifecycle event must be sealed")
  text = "INSTITUTIONAL-POLICY-LIFECYCLE-EVENT/1" || '0a'x
  text ||= .InstitutionalPolicyCanonical~field("EVENT_ID", eventId)
  text ||= .InstitutionalPolicyCanonical~field("EVENT_TYPE", eventType)
  text ||= .InstitutionalPolicyCanonical~field("POLICY", policyId || "@" || version)
  text ||= .InstitutionalPolicyCanonical~field("POLICY_IDENTITY", policyIdentity)
  text ||= .InstitutionalPolicyCanonical~field("ACTOR", actorId)
  text ||= .InstitutionalPolicyCanonical~field("REQUESTED_AT", requestedAt)
  text ||= .InstitutionalPolicyCanonical~field("EFFECTIVE_AT", effectiveAt)
  text ||= .InstitutionalPolicyCanonical~field("REASON", reason)
  text ||= .InstitutionalPolicyCanonical~field("EVIDENCE_REF", evidenceRef)
  text ||= .InstitutionalPolicyCanonical~field("AUTHORITY_DECISION", authorityDecision~canonicalText)
  return text
::method semanticIdentity
  return self~canonicalText

::class InstitutionalPolicyDeploymentState public
::attribute policyId get
::attribute version get
::attribute policyIdentity get
::attribute atTime get
::attribute state get
::attribute ratified get
::method init
  expose policyId version policyIdentity atTime state ratified events
  use arg policy, atTimeArg, stateArg = "ACTIVE", ratifiedArg = .false, eventsArg = .nil
  policyId = policy~policyId
  version = policy~version
  policyIdentity = policy~semanticIdentity
  atTime = atTimeArg
  state = stateArg~string~upper
  ratified = ratifiedArg
  events = .InstitutionalPolicyCanonical~copyArray(eventsArg)
::method events
  expose events
  return .InstitutionalPolicyCanonical~copyArray(events)
::method canonicalText
  expose policyId version policyIdentity atTime state ratified events
  text = "INSTITUTIONAL-POLICY-DEPLOYMENT-STATE/1" || '0a'x
  text ||= .InstitutionalPolicyCanonical~field("POLICY", policyId || "@" || version)
  text ||= .InstitutionalPolicyCanonical~field("POLICY_IDENTITY", policyIdentity)
  text ||= .InstitutionalPolicyCanonical~field("AT_TIME", atTime)
  text ||= .InstitutionalPolicyCanonical~field("STATE", state)
  text ||= .InstitutionalPolicyCanonical~field("RATIFIED", ratified)
  eventTexts = .array~new
  do event over events
    eventTexts~append(event~semanticIdentity)
  end
  do eventText over .InstitutionalPolicyCanonical~sortedStrings(eventTexts)
    text ||= .InstitutionalPolicyCanonical~field("EVENT", eventText)
  end
  return text
::method semanticIdentity
  return self~canonicalText

/* Deployment topology is separate from publication and global lifecycle.
   A policy can be approved/published once and then deployed differently across
   services, regions, channels, tenants or cohorts. Topology bindings are
   immutable operational evidence and never alter the policy artefact. */
::class InstitutionalPolicyDeploymentPoint public
::attribute serviceId get
::attribute regionId get
::attribute channelId get
::attribute tenantId get
::attribute cohortId get
::method init
  expose serviceId regionId channelId tenantId cohortId
  use arg serviceIdArg = "", regionIdArg = "", channelIdArg = "", tenantIdArg = "", cohortIdArg = ""
  serviceId = serviceIdArg~string~upper
  regionId = regionIdArg~string~upper
  channelId = channelIdArg~string~upper
  tenantId = tenantIdArg~string~upper
  cohortId = cohortIdArg~string~upper
::method canonicalText
  expose serviceId regionId channelId tenantId cohortId
  text = "INSTITUTIONAL-POLICY-DEPLOYMENT-POINT/1" || '0a'x
  text ||= .InstitutionalPolicyCanonical~field("SERVICE", serviceId)
  text ||= .InstitutionalPolicyCanonical~field("REGION", regionId)
  text ||= .InstitutionalPolicyCanonical~field("CHANNEL", channelId)
  text ||= .InstitutionalPolicyCanonical~field("TENANT", tenantId)
  text ||= .InstitutionalPolicyCanonical~field("COHORT", cohortId)
  return text
::method semanticIdentity
  return self~canonicalText

::class InstitutionalPolicyDeploymentScope public
::attribute scopeId get
::attribute serviceId get
::attribute regionId get
::attribute channelId get
::attribute tenantId get
::attribute cohortId get
::attribute sealed get
::method init
  expose scopeId serviceId regionId channelId tenantId cohortId sealed
  use arg scopeIdArg, serviceIdArg = "*", regionIdArg = "*", channelIdArg = "*", tenantIdArg = "*", cohortIdArg = "*"
  scopeId = scopeIdArg~string
  serviceId = serviceIdArg~string~upper
  regionId = regionIdArg~string~upper
  channelId = channelIdArg~string~upper
  tenantId = tenantIdArg~string~upper
  cohortId = cohortIdArg~string~upper
  if serviceId = "" then serviceId = "*"
  if regionId = "" then regionId = "*"
  if channelId = "" then channelId = "*"
  if tenantId = "" then tenantId = "*"
  if cohortId = "" then cohortId = "*"
  sealed = .false
::method seal
  expose scopeId sealed
  if scopeId = "" then raise syntax 88.960 array("deployment scope id required")
  sealed = .true
  return self
::method specificity
  expose serviceId regionId channelId tenantId cohortId
  score = 0
  if serviceId <> "*" then score += 1
  if regionId <> "*" then score += 1
  if channelId <> "*" then score += 1
  if tenantId <> "*" then score += 1
  if cohortId <> "*" then score += 1
  return score
::method matches
  expose serviceId regionId channelId tenantId cohortId sealed
  use arg point
  if \sealed | point == .nil then return .false
  if serviceId <> "*" then if serviceId <> point~serviceId then return .false
  if regionId <> "*" then if regionId <> point~regionId then return .false
  if channelId <> "*" then if channelId <> point~channelId then return .false
  if tenantId <> "*" then if tenantId <> point~tenantId then return .false
  if cohortId <> "*" then if cohortId <> point~cohortId then return .false
  return .true
::method canonicalText
  expose scopeId serviceId regionId channelId tenantId cohortId sealed
  if \sealed then raise syntax 88.961 array("deployment scope must be sealed")
  text = "INSTITUTIONAL-POLICY-DEPLOYMENT-SCOPE/1" || '0a'x
  text ||= .InstitutionalPolicyCanonical~field("SCOPE_ID", scopeId)
  text ||= .InstitutionalPolicyCanonical~field("SERVICE", serviceId)
  text ||= .InstitutionalPolicyCanonical~field("REGION", regionId)
  text ||= .InstitutionalPolicyCanonical~field("CHANNEL", channelId)
  text ||= .InstitutionalPolicyCanonical~field("TENANT", tenantId)
  text ||= .InstitutionalPolicyCanonical~field("COHORT", cohortId)
  return text
::method semanticIdentity
  return self~canonicalText

::class InstitutionalPolicyDeploymentRequest public
::attribute deploymentId get
::attribute policyId get
::attribute version get
::attribute policyIdentity get
::attribute actorId get
::attribute requestedAt get
::attribute effectiveFrom get
::attribute effectiveUntil get
::attribute mode get
::attribute scope get
::attribute reason get
::attribute evidenceRef get
::method init
  expose deploymentId policyId version policyIdentity actorId requestedAt effectiveFrom effectiveUntil mode scope reason evidenceRef rolloutObservations
  use arg deploymentIdArg, policy, actorIdArg, scopeArg, modeArg = "ACTIVE", effectiveFromArg = .nil, effectiveUntilArg = .nil, reasonArg = "", evidenceRefArg = "", requestedAtArg = .nil, rolloutObservationsArg = .nil
  if policy == .nil then raise syntax 88.962 array("deployment request requires policy")
  deploymentId = deploymentIdArg~string
  policyId = policy~policyId
  version = policy~version
  policyIdentity = policy~semanticIdentity
  actorId = actorIdArg~string
  if requestedAtArg == .nil then requestedAt = .DateTime~new
  else requestedAt = requestedAtArg
  if effectiveFromArg == .nil then effectiveFrom = requestedAt
  else effectiveFrom = effectiveFromArg
  if effectiveUntilArg == .nil then effectiveUntil = .nil
  else if effectiveUntilArg~string = "" then effectiveUntil = .nil
  else effectiveUntil = effectiveUntilArg
  mode = modeArg~string~upper
  scope = scopeArg
  reason = reasonArg~string
  evidenceRef = evidenceRefArg~string
  rolloutObservations = .InstitutionalPolicyCanonical~copyArray(rolloutObservationsArg)
::method rolloutObservations
  expose rolloutObservations
  return .InstitutionalPolicyCanonical~copyArray(rolloutObservations)
::method matches
  expose policyId version policyIdentity
  use arg policy
  if policy == .nil then return .false
  return policyId = policy~policyId & version = policy~version & policyIdentity = policy~semanticIdentity
::method validMode
  expose mode
  return mode = .InstitutionalPolicyBuild~DEPLOYMENT_ACTIVE | mode = .InstitutionalPolicyBuild~DEPLOYMENT_STAGED | mode = .InstitutionalPolicyBuild~DEPLOYMENT_CANARY | mode = .InstitutionalPolicyBuild~DEPLOYMENT_SUSPENDED

::class InstitutionalPolicyDeploymentDecision public
::attribute ok get
::attribute code get
::attribute detail get
::attribute assuranceMode get
::attribute authorityProfileId get
::attribute authorityProfileVersion get
::attribute authorityProfileIdentity get
::attribute actorId get
::attribute action get
::attribute grantId get
::attribute evaluatedAt get
::method init
  expose ok code detail assuranceMode authorityProfileId authorityProfileVersion authorityProfileIdentity actorId action grantId evaluatedAt
  use arg okArg, codeArg, detailArg, profile = .nil, actorIdArg = "", grantIdArg = "", evaluatedAtArg = .nil
  ok = okArg
  code = codeArg~string~upper
  detail = detailArg~string
  assuranceMode = .InstitutionalPolicyBuild~ASSURANCE_ROLE_AUTHORITY
  if profile == .nil then do
    authorityProfileId = ""
    authorityProfileVersion = ""
    authorityProfileIdentity = ""
  end
  else do
    authorityProfileId = profile~profileId
    authorityProfileVersion = profile~version
    authorityProfileIdentity = profile~semanticIdentity
  end
  actorId = actorIdArg~string
  action = .InstitutionalPolicyBuild~AUTHORITY_DEPLOYER
  grantId = grantIdArg~string
  if evaluatedAtArg == .nil then evaluatedAt = .DateTime~new
  else evaluatedAt = evaluatedAtArg
::method canonicalText
  expose ok code detail assuranceMode authorityProfileId authorityProfileVersion authorityProfileIdentity actorId action grantId evaluatedAt
  text = "INSTITUTIONAL-POLICY-DEPLOYMENT-AUTHORITY/1" || '0a'x
  text ||= .InstitutionalPolicyCanonical~field("OK", ok)
  text ||= .InstitutionalPolicyCanonical~field("CODE", code)
  text ||= .InstitutionalPolicyCanonical~field("DETAIL", detail)
  text ||= .InstitutionalPolicyCanonical~field("ASSURANCE_MODE", assuranceMode)
  text ||= .InstitutionalPolicyCanonical~field("PROFILE", authorityProfileId || "@" || authorityProfileVersion)
  text ||= .InstitutionalPolicyCanonical~field("PROFILE_IDENTITY", authorityProfileIdentity)
  text ||= .InstitutionalPolicyCanonical~field("ACTOR", actorId)
  text ||= .InstitutionalPolicyCanonical~field("ACTION", action)
  text ||= .InstitutionalPolicyCanonical~field("GRANT_ID", grantId)
  text ||= .InstitutionalPolicyCanonical~field("EVALUATED_AT", evaluatedAt)
  return text

::class InstitutionalPolicyDeploymentAuthorityEvaluator subclass AlchemyObject public
::method init
  expose authorityProfile authorityBinding
  use arg profileArg, metadataArg = .nil, sealer = .nil, authority = .nil
  if profileArg == .nil then raise syntax 88.963 array("deployment authority evaluator requires profile or binding")
  authorityProfile = .nil
  authorityBinding = .nil
  if profileArg~hasMethod("RESOLVEAT") then authorityBinding = profileArg
  else do
    if profileArg~sealed = .false then raise syntax 88.964 array("deployment authority evaluator requires sealed profile")
    authorityProfile = profileArg
  end
  if metadataArg == .nil then metadataArg = .InstitutionalPolicySupport~metadata("institutional policy deployment topology authority evaluator")
  self~init:super(metadataArg, sealer, authority)
::method resolveProfile private
  expose authorityProfile authorityBinding
  use arg atTime
  if authorityProfile <> .nil then return .InstitutionalPolicyResult~success(authorityProfile)
  return authorityBinding~resolveAt(atTime)
::method evaluate
  use arg policy, request
  if policy == .nil then return .InstitutionalPolicyDeploymentDecision~new(.false,"POLICY_REQUIRED","")
  if request == .nil then return .InstitutionalPolicyDeploymentDecision~new(.false,"DEPLOYMENT_REQUEST_REQUIRED",policy~policyId)
  if request~matches(policy) = .false then return .InstitutionalPolicyDeploymentDecision~new(.false,"DEPLOYMENT_REQUEST_POLICY_MISMATCH",policy~policyId || "@" || policy~version,.nil,request~actorId,"",request~effectiveFrom)
  if request~deploymentId = "" | request~actorId = "" | request~reason = "" then return .InstitutionalPolicyDeploymentDecision~new(.false,"DEPLOYMENT_IDENTITY_FIELDS_REQUIRED",policy~policyId,.nil,request~actorId,"",request~requestedAt)
  if request~scope == .nil | request~scope~sealed = .false then return .InstitutionalPolicyDeploymentDecision~new(.false,"DEPLOYMENT_SCOPE_NOT_SEALED",policy~policyId,.nil,request~actorId,"",request~requestedAt)
  if request~validMode = .false then return .InstitutionalPolicyDeploymentDecision~new(.false,"DEPLOYMENT_MODE_INVALID",request~mode,.nil,request~actorId,"",request~requestedAt)
  if request~effectiveFrom < request~requestedAt then return .InstitutionalPolicyDeploymentDecision~new(.false,"DEPLOYMENT_RETROACTIVE_NOT_ALLOWED",request~deploymentId,.nil,request~actorId,"",request~requestedAt)
  if request~effectiveUntil <> .nil then if request~effectiveUntil <= request~effectiveFrom then return .InstitutionalPolicyDeploymentDecision~new(.false,"DEPLOYMENT_EFFECTIVE_RANGE_INVALID",request~deploymentId,.nil,request~actorId,"",request~requestedAt)
  if request~mode = .InstitutionalPolicyBuild~DEPLOYMENT_CANARY then if request~scope~specificity = 0 then return .InstitutionalPolicyDeploymentDecision~new(.false,"CANARY_SCOPE_REQUIRED",request~deploymentId,.nil,request~actorId,"",request~requestedAt)
  profileResult = self~resolveProfile(request~requestedAt)
  if profileResult~ok = .false then return .InstitutionalPolicyDeploymentDecision~new(.false,profileResult~code,profileResult~detail,.nil,request~actorId,"",request~requestedAt)
  profile = profileResult~value
  if profile~activeAt(request~effectiveFrom) = .false then return .InstitutionalPolicyDeploymentDecision~new(.false,"DEPLOYMENT_AUTHORITY_NOT_VALID_AT_EFFECTIVE_TIME",profile~profileId,profile,request~actorId,"",request~requestedAt)
  grantResult = profile~authorityGrant(request~actorId, .InstitutionalPolicyBuild~AUTHORITY_DEPLOYER, policy~policyId, request~requestedAt)
  if grantResult~ok = .false then return .InstitutionalPolicyDeploymentDecision~new(.false,"DEPLOYMENT_AUTHORITY_DENIED",grantResult~detail,profile,request~actorId,"",request~requestedAt)
  if grantResult~value~allows(request~actorId,.InstitutionalPolicyBuild~AUTHORITY_DEPLOYER,policy~policyId,request~effectiveFrom) = .false then return .InstitutionalPolicyDeploymentDecision~new(.false,"DEPLOYMENT_GRANT_NOT_VALID_AT_EFFECTIVE_TIME",grantResult~value~grantId,profile,request~actorId,grantResult~value~grantId,request~requestedAt)
  return .InstitutionalPolicyDeploymentDecision~new(.true,"AUTHORIZED","deployment authority satisfied",profile,request~actorId,grantResult~value~grantId,request~requestedAt)
::method evaluateProgressive
  use arg priorPolicy, nextPolicy, request
  if priorPolicy == .nil | nextPolicy == .nil then return .InstitutionalPolicyDeploymentDecision~new(.false,"POLICY_REQUIRED","")
  if request == .nil then return .InstitutionalPolicyDeploymentDecision~new(.false,"PROGRESSIVE_ROLLOUT_REQUEST_REQUIRED",nextPolicy~policyId)
  if request~matches(priorPolicy,nextPolicy) = .false then return .InstitutionalPolicyDeploymentDecision~new(.false,"PROGRESSIVE_ROLLOUT_POLICY_MISMATCH",nextPolicy~policyId || "@" || nextPolicy~version,.nil,request~actorId,"",request~requestedAt)
  if request~rolloutId = "" | request~actorId = "" | request~reason = "" then return .InstitutionalPolicyDeploymentDecision~new(.false,"PROGRESSIVE_ROLLOUT_IDENTITY_FIELDS_REQUIRED",nextPolicy~policyId,.nil,request~actorId,"",request~requestedAt)
  if request~effectiveFrom < request~requestedAt then return .InstitutionalPolicyDeploymentDecision~new(.false,"PROGRESSIVE_ROLLOUT_RETROACTIVE_NOT_ALLOWED",request~rolloutId,.nil,request~actorId,"",request~requestedAt)
  if request~effectiveFrom <> nextPolicy~effectiveFrom then return .InstitutionalPolicyDeploymentDecision~new(.false,"PROGRESSIVE_ROLLOUT_START_MUST_MATCH_NEXT_POLICY",request~rolloutId,.nil,request~actorId,"",request~requestedAt)
  if request~effectiveUntil == .nil then return .InstitutionalPolicyDeploymentDecision~new(.false,"PROGRESSIVE_ROLLOUT_WINDOW_REQUIRED",request~rolloutId,.nil,request~actorId,"",request~requestedAt)
  if request~effectiveUntil <= request~effectiveFrom then return .InstitutionalPolicyDeploymentDecision~new(.false,"PROGRESSIVE_ROLLOUT_WINDOW_INVALID",request~rolloutId,.nil,request~actorId,"",request~requestedAt)
  if priorPolicy~activeAt(request~effectiveFrom) = .false | nextPolicy~activeAt(request~effectiveFrom) = .false then return .InstitutionalPolicyDeploymentDecision~new(.false,"PROGRESSIVE_ROLLOUT_POLICIES_NOT_OVERLAPPING",request~rolloutId,.nil,request~actorId,"",request~requestedAt)
  profileResult = self~resolveProfile(request~requestedAt)
  if profileResult~ok = .false then return .InstitutionalPolicyDeploymentDecision~new(.false,profileResult~code,profileResult~detail,.nil,request~actorId,"",request~requestedAt)
  profile = profileResult~value
  if profile~activeAt(request~effectiveFrom) = .false then return .InstitutionalPolicyDeploymentDecision~new(.false,"DEPLOYMENT_AUTHORITY_NOT_VALID_AT_EFFECTIVE_TIME",profile~profileId,profile,request~actorId,"",request~requestedAt)
  grantResult = profile~authorityGrant(request~actorId, .InstitutionalPolicyBuild~AUTHORITY_DEPLOYER, nextPolicy~policyId, request~requestedAt)
  if grantResult~ok = .false then return .InstitutionalPolicyDeploymentDecision~new(.false,"DEPLOYMENT_AUTHORITY_DENIED",grantResult~detail,profile,request~actorId,"",request~requestedAt)
  if grantResult~value~allows(request~actorId,.InstitutionalPolicyBuild~AUTHORITY_DEPLOYER,nextPolicy~policyId,request~effectiveFrom) = .false then return .InstitutionalPolicyDeploymentDecision~new(.false,"DEPLOYMENT_GRANT_NOT_VALID_AT_EFFECTIVE_TIME",grantResult~value~grantId,profile,request~actorId,grantResult~value~grantId,request~requestedAt)
  return .InstitutionalPolicyDeploymentDecision~new(.true,"AUTHORIZED","progressive rollout overlap authority satisfied",profile,request~actorId,grantResult~value~grantId,request~requestedAt)

/* Rollout acceptance criteria are fixed evidence rules embedded in the
   authorized progressive rollout. The host supplies observations; this code
   deterministically decides whether the evidence is sufficient to promote. */
::class InstitutionalPolicyRolloutCriterion public
::attribute criterionId get
::attribute metricName get
::attribute comparator get
::attribute threshold get
::attribute minimumSampleSize get
::attribute sealed get
::method init
  expose criterionId metricName comparator threshold minimumSampleSize sealed
  use arg criterionIdArg, metricNameArg, comparatorArg, thresholdArg, minimumSampleSizeArg = 0
  criterionId = criterionIdArg~string
  metricName = metricNameArg~string~upper
  comparator = comparatorArg~string~upper
  threshold = thresholdArg + 0
  minimumSampleSize = minimumSampleSizeArg + 0
  sealed = .false
::method validComparator
  expose comparator
  return comparator = "GE" | comparator = "GT" | comparator = "LE" | comparator = "LT" | comparator = "EQ" | comparator = "NE"
::method passes
  expose comparator threshold
  use arg value
  actual = value + 0
  select
    when comparator = "GE" then return actual >= threshold
    when comparator = "GT" then return actual > threshold
    when comparator = "LE" then return actual <= threshold
    when comparator = "LT" then return actual < threshold
    when comparator = "EQ" then return actual = threshold
    when comparator = "NE" then return actual <> threshold
    otherwise return .false
  end
::method seal
  expose criterionId metricName minimumSampleSize sealed
  if criterionId = "" | metricName = "" then raise syntax 88.976 array("rollout criterion id and metric required")
  if self~validComparator = .false then raise syntax 88.977 array("rollout criterion comparator invalid")
  if minimumSampleSize < 0 then raise syntax 88.978 array("rollout criterion minimum sample size cannot be negative")
  sealed = .true
  return self
::method canonicalText
  expose criterionId metricName comparator threshold minimumSampleSize sealed
  if \sealed then raise syntax 88.979 array("rollout criterion must be sealed")
  text = "INSTITUTIONAL-POLICY-ROLLOUT-CRITERION/1" || '0a'x
  text ||= .InstitutionalPolicyCanonical~field("CRITERION_ID", criterionId)
  text ||= .InstitutionalPolicyCanonical~field("METRIC", metricName)
  text ||= .InstitutionalPolicyCanonical~field("COMPARATOR", comparator)
  text ||= .InstitutionalPolicyCanonical~field("THRESHOLD", threshold)
  text ||= .InstitutionalPolicyCanonical~field("MINIMUM_SAMPLE_SIZE", minimumSampleSize)
  return text
::method semanticIdentity
  return self~canonicalText

::class InstitutionalPolicyRolloutGate public
::attribute gateId get
::attribute version get
::attribute observationScope get
::attribute minimumWindowSeconds get
::attribute maximumEvidenceAgeSeconds get
::attribute sealed get
::method init
  expose gateId version observationScope minimumWindowSeconds maximumEvidenceAgeSeconds criteria sealed
  use arg gateIdArg, versionArg, observationScopeArg = .nil, minimumWindowSecondsArg = 0, maximumEvidenceAgeSecondsArg = 0
  gateId = gateIdArg~string
  version = versionArg~string
  observationScope = observationScopeArg
  minimumWindowSeconds = minimumWindowSecondsArg + 0
  maximumEvidenceAgeSeconds = maximumEvidenceAgeSecondsArg + 0
  criteria = .array~new
  sealed = .false
::method addCriterion
  expose criteria sealed
  use arg criterion
  if sealed then return .false
  if criterion == .nil | criterion~sealed = .false then return .false
  do existing over criteria
    if existing~criterionId = criterion~criterionId then return .false
    if existing~metricName = criterion~metricName then return .false
  end
  criteria~append(criterion)
  return .true
::method criteria
  expose criteria
  return .InstitutionalPolicyCanonical~copyArray(criteria)
::method seal
  expose gateId version observationScope minimumWindowSeconds maximumEvidenceAgeSeconds criteria sealed
  if gateId = "" | version = "" then raise syntax 88.980 array("rollout gate id and version required")
  if criteria~items = 0 then raise syntax 88.981 array("rollout gate requires at least one criterion")
  if minimumWindowSeconds < 0 | maximumEvidenceAgeSeconds < 0 then raise syntax 88.982 array("rollout gate timing values cannot be negative")
  if observationScope <> .nil then if observationScope~sealed = .false then raise syntax 88.983 array("rollout gate observation scope must be sealed")
  sealed = .true
  return self
::method canonicalText
  expose gateId version observationScope minimumWindowSeconds maximumEvidenceAgeSeconds criteria sealed
  if \sealed then raise syntax 88.984 array("rollout gate must be sealed")
  text = "INSTITUTIONAL-POLICY-ROLLOUT-GATE/1" || '0a'x
  text ||= .InstitutionalPolicyCanonical~field("GATE", gateId || "@" || version)
  if observationScope == .nil then text ||= .InstitutionalPolicyCanonical~field("OBSERVATION_SCOPE", "")
  else text ||= .InstitutionalPolicyCanonical~field("OBSERVATION_SCOPE", observationScope~semanticIdentity)
  text ||= .InstitutionalPolicyCanonical~field("MINIMUM_WINDOW_SECONDS", minimumWindowSeconds)
  text ||= .InstitutionalPolicyCanonical~field("MAXIMUM_EVIDENCE_AGE_SECONDS", maximumEvidenceAgeSeconds)
  items = .array~new
  do criterion over criteria
    items~append(criterion~canonicalText)
  end
  items~sort
  do item over items
    text ||= .InstitutionalPolicyCanonical~field("CRITERION", item)
  end
  return text
::method semanticIdentity
  return self~canonicalText

::class InstitutionalPolicyRolloutObservation public
::attribute observationId get
::attribute rolloutId get
::attribute policyId get
::attribute nextVersion get
::attribute nextIdentity get
::attribute metricName get
::attribute value get
::attribute sampleSize get
::attribute windowFrom get
::attribute windowUntil get
::attribute sourceId get
::attribute evidenceRef get
::attribute sourceScope get
::attribute recordedAt get
::attribute sealed get
::method init
  expose observationId rolloutId policyId nextVersion nextIdentity metricName value sampleSize windowFrom windowUntil sourceId evidenceRef sourceScope recordedAt sealed
  use arg observationIdArg, rolloutBinding, metricNameArg, valueArg, sampleSizeArg, windowFromArg, windowUntilArg, sourceIdArg, evidenceRefArg = "", sourceScopeArg = .nil, recordedAtArg = .nil
  if rolloutBinding == .nil then raise syntax 88.985 array("rollout observation requires progressive binding")
  observationId = observationIdArg~string
  rolloutId = rolloutBinding~rolloutId
  policyId = rolloutBinding~policyId
  nextVersion = rolloutBinding~nextVersion
  nextIdentity = rolloutBinding~nextIdentity
  metricName = metricNameArg~string~upper
  value = valueArg + 0
  sampleSize = sampleSizeArg + 0
  windowFrom = windowFromArg
  windowUntil = windowUntilArg
  sourceId = sourceIdArg~string
  evidenceRef = evidenceRefArg~string
  sourceScope = sourceScopeArg
  if recordedAtArg == .nil then recordedAt = .DateTime~new
  else recordedAt = recordedAtArg
  sealed = .false
::method matches
  expose rolloutId policyId nextVersion nextIdentity
  use arg rolloutBinding
  if rolloutBinding == .nil then return .false
  return rolloutId = rolloutBinding~rolloutId & policyId = rolloutBinding~policyId & nextVersion = rolloutBinding~nextVersion & nextIdentity = rolloutBinding~nextIdentity
::method seal
  expose observationId metricName sampleSize windowFrom windowUntil sourceId sourceScope recordedAt sealed
  if observationId = "" | metricName = "" | sourceId = "" then raise syntax 88.986 array("rollout observation identity fields required")
  if sampleSize < 0 then raise syntax 88.987 array("rollout observation sample size cannot be negative")
  if windowFrom == .nil | windowUntil == .nil | windowUntil <= windowFrom then raise syntax 88.988 array("rollout observation requires positive evidence window")
  if recordedAt < windowUntil then raise syntax 88.989 array("rollout observation cannot be recorded before its evidence window ends")
  if sourceScope <> .nil then if sourceScope~sealed = .false then raise syntax 88.990 array("rollout observation source scope must be sealed")
  sealed = .true
  return self
::method canonicalText
  expose observationId rolloutId policyId nextVersion nextIdentity metricName value sampleSize windowFrom windowUntil sourceId evidenceRef sourceScope recordedAt sealed
  if \sealed then raise syntax 88.991 array("rollout observation must be sealed")
  text = "INSTITUTIONAL-POLICY-ROLLOUT-OBSERVATION/1" || '0a'x
  text ||= .InstitutionalPolicyCanonical~field("OBSERVATION_ID", observationId)
  text ||= .InstitutionalPolicyCanonical~field("ROLLOUT_ID", rolloutId)
  text ||= .InstitutionalPolicyCanonical~field("POLICY_ID", policyId)
  text ||= .InstitutionalPolicyCanonical~field("NEXT_VERSION", nextVersion)
  text ||= .InstitutionalPolicyCanonical~field("NEXT_IDENTITY", nextIdentity)
  text ||= .InstitutionalPolicyCanonical~field("METRIC", metricName)
  text ||= .InstitutionalPolicyCanonical~field("VALUE", value)
  text ||= .InstitutionalPolicyCanonical~field("SAMPLE_SIZE", sampleSize)
  text ||= .InstitutionalPolicyCanonical~field("WINDOW_FROM", windowFrom)
  text ||= .InstitutionalPolicyCanonical~field("WINDOW_UNTIL", windowUntil)
  text ||= .InstitutionalPolicyCanonical~field("SOURCE_ID", sourceId)
  text ||= .InstitutionalPolicyCanonical~field("EVIDENCE_REF", evidenceRef)
  if sourceScope == .nil then text ||= .InstitutionalPolicyCanonical~field("SOURCE_SCOPE", "")
  else text ||= .InstitutionalPolicyCanonical~field("SOURCE_SCOPE", sourceScope~semanticIdentity)
  text ||= .InstitutionalPolicyCanonical~field("RECORDED_AT", recordedAt)
  return text
::method semanticIdentity
  return self~canonicalText

::class InstitutionalPolicyRolloutCriterionResult public
::attribute criterionId get
::attribute metricName get
::attribute outcome get
::attribute detail get
::attribute observationIdentity get
::method init
  expose criterionId metricName outcome detail observationIdentity
  use arg criterion, outcomeArg, detailArg = "", observationArg = .nil
  criterionId = criterion~criterionId
  metricName = criterion~metricName
  outcome = outcomeArg~string~upper
  detail = detailArg~string
  if observationArg == .nil then observationIdentity = ""
  else observationIdentity = observationArg~semanticIdentity
::method canonicalText
  expose criterionId metricName outcome detail observationIdentity
  text = "INSTITUTIONAL-POLICY-ROLLOUT-CRITERION-RESULT/1" || '0a'x
  text ||= .InstitutionalPolicyCanonical~field("CRITERION_ID", criterionId)
  text ||= .InstitutionalPolicyCanonical~field("METRIC", metricName)
  text ||= .InstitutionalPolicyCanonical~field("OUTCOME", outcome)
  text ||= .InstitutionalPolicyCanonical~field("DETAIL", detail)
  text ||= .InstitutionalPolicyCanonical~field("OBSERVATION_IDENTITY", observationIdentity)
  return text

::class InstitutionalPolicyRolloutAssessment public
::attribute assessmentId get
::attribute rolloutId get
::attribute policyId get
::attribute nextVersion get
::attribute nextIdentity get
::attribute targetScopeIdentity get
::attribute gateIdentity get
::attribute outcome get
::attribute evaluatedAt get
::attribute validUntil get
::attribute sealed get
::method init
  expose assessmentId rolloutId policyId nextVersion nextIdentity targetScopeIdentity gateIdentity outcome evaluatedAt validUntil criterionResults observations sealed
  use arg assessmentIdArg, rolloutBinding, targetScope, gate, outcomeArg, evaluatedAtArg, criterionResultsArg = .nil, observationsArg = .nil
  assessmentId = assessmentIdArg~string
  rolloutId = rolloutBinding~rolloutId
  policyId = rolloutBinding~policyId
  nextVersion = rolloutBinding~nextVersion
  nextIdentity = rolloutBinding~nextIdentity
  targetScopeIdentity = targetScope~semanticIdentity
  gateIdentity = gate~semanticIdentity
  outcome = outcomeArg~string~upper
  evaluatedAt = evaluatedAtArg
  if gate~maximumEvidenceAgeSeconds > 0 then validUntil = evaluatedAt + .InstitutionalPolicyTime~seconds(gate~maximumEvidenceAgeSeconds)
  else validUntil = .nil
  criterionResults = .InstitutionalPolicyCanonical~copyArray(criterionResultsArg)
  observations = .InstitutionalPolicyCanonical~copyArray(observationsArg)
  sealed = .false
::method criterionResults
  expose criterionResults
  return .InstitutionalPolicyCanonical~copyArray(criterionResults)
::method observations
  expose observations
  return .InstitutionalPolicyCanonical~copyArray(observations)
::method matchesDeployment
  expose rolloutId policyId nextVersion nextIdentity targetScopeIdentity outcome evaluatedAt validUntil sealed
  use arg rolloutBinding, request
  if \sealed | rolloutBinding == .nil | request == .nil then return .false
  if rolloutId <> rolloutBinding~rolloutId | policyId <> rolloutBinding~policyId | nextVersion <> rolloutBinding~nextVersion | nextIdentity <> rolloutBinding~nextIdentity then return .false
  if targetScopeIdentity <> request~scope~semanticIdentity then return .false
  if outcome <> .InstitutionalPolicyBuild~ROLLOUT_PROMOTION_ELIGIBLE then return .false
  if evaluatedAt > request~requestedAt | evaluatedAt > request~effectiveFrom then return .false
  if validUntil <> .nil then if request~effectiveFrom > validUntil then return .false
  return .true
::method seal
  expose assessmentId outcome sealed
  if assessmentId = "" then raise syntax 88.992 array("rollout assessment id required")
  if outcome <> .InstitutionalPolicyBuild~ROLLOUT_PROMOTION_ELIGIBLE & outcome <> .InstitutionalPolicyBuild~ROLLOUT_PROMOTION_BLOCKED & outcome <> .InstitutionalPolicyBuild~ROLLOUT_INSUFFICIENT_EVIDENCE then raise syntax 88.993 array("rollout assessment outcome invalid")
  sealed = .true
  return self
::method canonicalText
  expose assessmentId rolloutId policyId nextVersion nextIdentity targetScopeIdentity gateIdentity outcome evaluatedAt validUntil criterionResults observations sealed
  if \sealed then raise syntax 88.994 array("rollout assessment must be sealed")
  text = "INSTITUTIONAL-POLICY-ROLLOUT-ASSESSMENT/1" || '0a'x
  text ||= .InstitutionalPolicyCanonical~field("ASSESSMENT_ID", assessmentId)
  text ||= .InstitutionalPolicyCanonical~field("ROLLOUT_ID", rolloutId)
  text ||= .InstitutionalPolicyCanonical~field("POLICY_ID", policyId)
  text ||= .InstitutionalPolicyCanonical~field("NEXT_VERSION", nextVersion)
  text ||= .InstitutionalPolicyCanonical~field("NEXT_IDENTITY", nextIdentity)
  text ||= .InstitutionalPolicyCanonical~field("TARGET_SCOPE", targetScopeIdentity)
  text ||= .InstitutionalPolicyCanonical~field("GATE_IDENTITY", gateIdentity)
  text ||= .InstitutionalPolicyCanonical~field("OUTCOME", outcome)
  text ||= .InstitutionalPolicyCanonical~field("EVALUATED_AT", evaluatedAt)
  text ||= .InstitutionalPolicyCanonical~field("VALID_UNTIL", validUntil)
  cr = .array~new
  do result over criterionResults
    cr~append(result~canonicalText)
  end
  cr~sort
  do item over cr
    text ||= .InstitutionalPolicyCanonical~field("CRITERION_RESULT", item)
  end
  obs = .array~new
  do observation over observations
    obs~append(observation~semanticIdentity)
  end
  obs~sort
  do item over obs
    text ||= .InstitutionalPolicyCanonical~field("OBSERVATION", item)
  end
  return text
::method semanticIdentity
  return self~canonicalText

::class InstitutionalPolicyRolloutEvaluator subclass AlchemyObject public
::method init
  use arg metadataArg = .nil, sealer = .nil, authority = .nil
  if metadataArg == .nil then metadataArg = .InstitutionalPolicySupport~metadata("deterministic progressive rollout evidence gate evaluator")
  self~init:super(metadataArg, sealer, authority)
  self~registerMethodContract("EVALUATE", "evaluate fixed rollout acceptance criteria against immutable observations", .array~of("ASSESSMENT_ID", "ROLLOUT_BINDING", "TARGET_SCOPE", "OBSERVATIONS", "EVALUATED_AT"), "INSTITUTIONALPOLICYRESULT", .false, "AUTO", "INTERNAL", "SENSITIVE", "READ", "USE")
::method evaluate
  use arg assessmentId, rolloutBinding, targetScope, observationsArg = .nil, evaluatedAt = .nil
  if evaluatedAt == .nil then evaluatedAt = .DateTime~new
  if rolloutBinding == .nil then return .InstitutionalPolicyResult~failure("PROGRESSIVE_ROLLOUT_REQUIRED")
  gate = rolloutBinding~gate
  if gate == .nil then return .InstitutionalPolicyResult~failure("ROLLOUT_GATE_NOT_CONFIGURED", rolloutBinding~rolloutId)
  if targetScope == .nil | targetScope~sealed = .false then return .InstitutionalPolicyResult~failure("ROLLOUT_TARGET_SCOPE_NOT_SEALED", rolloutBinding~rolloutId)
  if rolloutBinding~activeAt(evaluatedAt) = .false then return .InstitutionalPolicyResult~failure("ROLLOUT_ASSESSMENT_OUTSIDE_AUTHORIZATION_WINDOW", rolloutBinding~rolloutId)
  observations = .InstitutionalPolicyCanonical~copyArray(observationsArg)
  byMetric = .directory~new
  do observation over observations
    if observation == .nil | observation~sealed = .false then return .InstitutionalPolicyResult~failure("ROLLOUT_OBSERVATION_NOT_SEALED", rolloutBinding~rolloutId)
    if observation~matches(rolloutBinding) = .false then return .InstitutionalPolicyResult~failure("ROLLOUT_OBSERVATION_MISMATCH", observation~observationId)
    if observation~recordedAt > evaluatedAt | observation~windowUntil > evaluatedAt then return .InstitutionalPolicyResult~failure("ROLLOUT_OBSERVATION_FROM_FUTURE", observation~observationId)
    if gate~maximumEvidenceAgeSeconds > 0 then do
      evidenceAge = (evaluatedAt - observation~recordedAt)~totalSeconds
      if evidenceAge > gate~maximumEvidenceAgeSeconds then return .InstitutionalPolicyResult~failure("ROLLOUT_OBSERVATION_STALE", observation~observationId)
    end
    if gate~observationScope <> .nil then do
      if observation~sourceScope == .nil then return .InstitutionalPolicyResult~failure("ROLLOUT_OBSERVATION_SCOPE_REQUIRED", observation~observationId)
      if observation~sourceScope~semanticIdentity <> gate~observationScope~semanticIdentity then return .InstitutionalPolicyResult~failure("ROLLOUT_OBSERVATION_SCOPE_MISMATCH", observation~observationId)
    end
    metric = observation~metricName
    if byMetric~hasIndex(metric) then return .InstitutionalPolicyResult~failure("ROLLOUT_METRIC_AMBIGUOUS", metric)
    byMetric[metric] = observation
  end
  results = .array~new
  finalOutcome = .InstitutionalPolicyBuild~ROLLOUT_PROMOTION_ELIGIBLE
  do criterion over gate~criteria
    metric = criterion~metricName
    if byMetric~hasIndex(metric) = .false then do
      results~append(.InstitutionalPolicyRolloutCriterionResult~new(criterion,.InstitutionalPolicyBuild~ROLLOUT_INSUFFICIENT_EVIDENCE,"required metric missing"))
      if finalOutcome <> .InstitutionalPolicyBuild~ROLLOUT_PROMOTION_BLOCKED then finalOutcome = .InstitutionalPolicyBuild~ROLLOUT_INSUFFICIENT_EVIDENCE
      iterate
    end
    observation = byMetric[metric]
    windowSeconds = (observation~windowUntil - observation~windowFrom)~totalSeconds
    if observation~sampleSize < criterion~minimumSampleSize then do
      results~append(.InstitutionalPolicyRolloutCriterionResult~new(criterion,.InstitutionalPolicyBuild~ROLLOUT_INSUFFICIENT_EVIDENCE,"sample size " || observation~sampleSize || " below " || criterion~minimumSampleSize,observation))
      if finalOutcome <> .InstitutionalPolicyBuild~ROLLOUT_PROMOTION_BLOCKED then finalOutcome = .InstitutionalPolicyBuild~ROLLOUT_INSUFFICIENT_EVIDENCE
      iterate
    end
    if windowSeconds < gate~minimumWindowSeconds then do
      results~append(.InstitutionalPolicyRolloutCriterionResult~new(criterion,.InstitutionalPolicyBuild~ROLLOUT_INSUFFICIENT_EVIDENCE,"evidence window " || windowSeconds || " seconds below " || gate~minimumWindowSeconds,observation))
      if finalOutcome <> .InstitutionalPolicyBuild~ROLLOUT_PROMOTION_BLOCKED then finalOutcome = .InstitutionalPolicyBuild~ROLLOUT_INSUFFICIENT_EVIDENCE
      iterate
    end
    if criterion~passes(observation~value) then results~append(.InstitutionalPolicyRolloutCriterionResult~new(criterion,.InstitutionalPolicyBuild~ROLLOUT_PROMOTION_ELIGIBLE,"criterion satisfied",observation))
    else do
      results~append(.InstitutionalPolicyRolloutCriterionResult~new(criterion,.InstitutionalPolicyBuild~ROLLOUT_PROMOTION_BLOCKED,"criterion breached",observation))
      finalOutcome = .InstitutionalPolicyBuild~ROLLOUT_PROMOTION_BLOCKED
    end
  end
  assessment = .InstitutionalPolicyRolloutAssessment~new(assessmentId,rolloutBinding,targetScope,gate,finalOutcome,evaluatedAt,results,observations)~seal
  self~recordRelationship("EVALUATES_ROLLOUT", assessment, "fixed rollout gate assessment", "INTERNAL")
  return .InstitutionalPolicyResult~success(assessment)

/* Post-promotion rollback gates are separate from promotion gates.  Their
   criteria describe measurable degradation conditions.  A fixed ANY/ALL
   trigger mode determines when automatic rollback becomes eligible.  Manual
   authorized rollback remains an independent institutional action. */
::class InstitutionalPolicyRollbackGate public
::attribute gateId get
::attribute version get
::attribute observationScope get
::attribute minimumWindowSeconds get
::attribute maximumEvidenceAgeSeconds get
::attribute triggerMode get
::attribute sealed get
::method init
  expose gateId version observationScope minimumWindowSeconds maximumEvidenceAgeSeconds triggerMode criteria sealed
  use arg gateIdArg, versionArg, observationScopeArg = .nil, minimumWindowSecondsArg = 0, maximumEvidenceAgeSecondsArg = 0, triggerModeArg = "ANY"
  gateId = gateIdArg~string
  version = versionArg~string
  observationScope = observationScopeArg
  minimumWindowSeconds = minimumWindowSecondsArg + 0
  maximumEvidenceAgeSeconds = maximumEvidenceAgeSecondsArg + 0
  triggerMode = triggerModeArg~string~upper
  criteria = .array~new
  sealed = .false
::method addCriterion
  expose criteria sealed
  use arg criterion
  if sealed then return .false
  if criterion == .nil | criterion~sealed = .false then return .false
  do existing over criteria
    if existing~criterionId = criterion~criterionId then return .false
    if existing~metricName = criterion~metricName then return .false
  end
  criteria~append(criterion)
  return .true
::method criteria
  expose criteria
  return .InstitutionalPolicyCanonical~copyArray(criteria)
::method seal
  expose gateId version observationScope minimumWindowSeconds maximumEvidenceAgeSeconds triggerMode criteria sealed
  if gateId = "" | version = "" then raise syntax 88.1001 array("rollback gate id and version required")
  if criteria~items = 0 then raise syntax 88.1002 array("rollback gate requires at least one criterion")
  if minimumWindowSeconds < 0 | maximumEvidenceAgeSeconds < 0 then raise syntax 88.1003 array("rollback gate timing values cannot be negative")
  if triggerMode <> "ANY" & triggerMode <> "ALL" then raise syntax 88.1004 array("rollback gate trigger mode must be ANY or ALL")
  if observationScope <> .nil then if observationScope~sealed = .false then raise syntax 88.1005 array("rollback gate observation scope must be sealed")
  sealed = .true
  return self
::method canonicalText
  expose gateId version observationScope minimumWindowSeconds maximumEvidenceAgeSeconds triggerMode criteria sealed
  if \sealed then raise syntax 88.1006 array("rollback gate must be sealed")
  text = "INSTITUTIONAL-POLICY-ROLLBACK-GATE/1" || '0a'x
  text ||= .InstitutionalPolicyCanonical~field("GATE", gateId || "@" || version)
  if observationScope == .nil then text ||= .InstitutionalPolicyCanonical~field("OBSERVATION_SCOPE", "")
  else text ||= .InstitutionalPolicyCanonical~field("OBSERVATION_SCOPE", observationScope~semanticIdentity)
  text ||= .InstitutionalPolicyCanonical~field("MINIMUM_WINDOW_SECONDS", minimumWindowSeconds)
  text ||= .InstitutionalPolicyCanonical~field("MAXIMUM_EVIDENCE_AGE_SECONDS", maximumEvidenceAgeSeconds)
  text ||= .InstitutionalPolicyCanonical~field("TRIGGER_MODE", triggerMode)
  items = .array~new
  do criterion over criteria
    items~append(criterion~canonicalText)
  end
  items~sort
  do item over items
    text ||= .InstitutionalPolicyCanonical~field("CRITERION", item)
  end
  return text
::method semanticIdentity
  return self~canonicalText

::class InstitutionalPolicyRollbackAssessment public
::attribute assessmentId get
::attribute rolloutId get
::attribute policyId get
::attribute priorVersion get
::attribute priorIdentity get
::attribute nextVersion get
::attribute nextIdentity get
::attribute targetScopeIdentity get
::attribute gateIdentity get
::attribute outcome get
::attribute evaluatedAt get
::attribute validUntil get
::attribute sealed get
::method init
  expose assessmentId rolloutId policyId priorVersion priorIdentity nextVersion nextIdentity targetScopeIdentity gateIdentity outcome evaluatedAt validUntil criterionResults observations sealed
  use arg assessmentIdArg, rolloutBinding, targetScope, gate, outcomeArg, evaluatedAtArg, criterionResultsArg = .nil, observationsArg = .nil
  assessmentId = assessmentIdArg~string
  rolloutId = rolloutBinding~rolloutId
  policyId = rolloutBinding~policyId
  priorVersion = rolloutBinding~priorVersion
  priorIdentity = rolloutBinding~priorIdentity
  nextVersion = rolloutBinding~nextVersion
  nextIdentity = rolloutBinding~nextIdentity
  targetScopeIdentity = targetScope~semanticIdentity
  gateIdentity = gate~semanticIdentity
  outcome = outcomeArg~string~upper
  evaluatedAt = evaluatedAtArg
  if gate~maximumEvidenceAgeSeconds > 0 then validUntil = evaluatedAt + .InstitutionalPolicyTime~seconds(gate~maximumEvidenceAgeSeconds)
  else validUntil = .nil
  criterionResults = .InstitutionalPolicyCanonical~copyArray(criterionResultsArg)
  observations = .InstitutionalPolicyCanonical~copyArray(observationsArg)
  sealed = .false
::method criterionResults
  expose criterionResults
  return .InstitutionalPolicyCanonical~copyArray(criterionResults)
::method observations
  expose observations
  return .InstitutionalPolicyCanonical~copyArray(observations)
::method matchesDeployment
  expose rolloutId policyId priorVersion priorIdentity targetScopeIdentity outcome evaluatedAt validUntil sealed
  use arg rolloutBinding, request
  if \sealed | rolloutBinding == .nil | request == .nil then return .false
  if rolloutId <> rolloutBinding~rolloutId | policyId <> rolloutBinding~policyId | priorVersion <> rolloutBinding~priorVersion | priorIdentity <> rolloutBinding~priorIdentity then return .false
  if request~version <> priorVersion | request~policyIdentity <> priorIdentity then return .false
  if targetScopeIdentity <> request~scope~semanticIdentity then return .false
  if outcome <> .InstitutionalPolicyBuild~ROLLBACK_ELIGIBLE then return .false
  if evaluatedAt > request~requestedAt | evaluatedAt > request~effectiveFrom then return .false
  if validUntil <> .nil then if request~effectiveFrom > validUntil then return .false
  return .true
::method seal
  expose assessmentId outcome sealed
  if assessmentId = "" then raise syntax 88.1007 array("rollback assessment id required")
  if outcome <> .InstitutionalPolicyBuild~ROLLBACK_ELIGIBLE & outcome <> .InstitutionalPolicyBuild~ROLLBACK_NOT_REQUIRED & outcome <> .InstitutionalPolicyBuild~ROLLBACK_INSUFFICIENT_EVIDENCE then raise syntax 88.1008 array("rollback assessment outcome invalid")
  sealed = .true
  return self
::method canonicalText
  expose assessmentId rolloutId policyId priorVersion priorIdentity nextVersion nextIdentity targetScopeIdentity gateIdentity outcome evaluatedAt validUntil criterionResults observations sealed
  if \sealed then raise syntax 88.1009 array("rollback assessment must be sealed")
  text = "INSTITUTIONAL-POLICY-ROLLBACK-ASSESSMENT/1" || '0a'x
  text ||= .InstitutionalPolicyCanonical~field("ASSESSMENT_ID", assessmentId)
  text ||= .InstitutionalPolicyCanonical~field("ROLLOUT_ID", rolloutId)
  text ||= .InstitutionalPolicyCanonical~field("POLICY_ID", policyId)
  text ||= .InstitutionalPolicyCanonical~field("PRIOR_VERSION", priorVersion)
  text ||= .InstitutionalPolicyCanonical~field("PRIOR_IDENTITY", priorIdentity)
  text ||= .InstitutionalPolicyCanonical~field("NEXT_VERSION", nextVersion)
  text ||= .InstitutionalPolicyCanonical~field("NEXT_IDENTITY", nextIdentity)
  text ||= .InstitutionalPolicyCanonical~field("TARGET_SCOPE", targetScopeIdentity)
  text ||= .InstitutionalPolicyCanonical~field("GATE_IDENTITY", gateIdentity)
  text ||= .InstitutionalPolicyCanonical~field("OUTCOME", outcome)
  text ||= .InstitutionalPolicyCanonical~field("EVALUATED_AT", evaluatedAt)
  text ||= .InstitutionalPolicyCanonical~field("VALID_UNTIL", validUntil)
  cr = .array~new
  do result over criterionResults
    cr~append(result~canonicalText)
  end
  cr~sort
  do item over cr
    text ||= .InstitutionalPolicyCanonical~field("CRITERION_RESULT", item)
  end
  obs = .array~new
  do observation over observations
    obs~append(observation~semanticIdentity)
  end
  obs~sort
  do item over obs
    text ||= .InstitutionalPolicyCanonical~field("OBSERVATION", item)
  end
  return text
::method semanticIdentity
  return self~canonicalText

::class InstitutionalPolicyRollbackEvaluator subclass AlchemyObject public
::method init
  use arg metadataArg = .nil, sealer = .nil, authority = .nil
  if metadataArg == .nil then metadataArg = .InstitutionalPolicySupport~metadata("deterministic post-promotion rollback evidence gate evaluator")
  self~init:super(metadataArg, sealer, authority)
  self~registerMethodContract("EVALUATE", "evaluate fixed post-promotion degradation criteria against immutable observations", .array~of("ASSESSMENT_ID", "ROLLOUT_BINDING", "TARGET_SCOPE", "OBSERVATIONS", "EVALUATED_AT"), "INSTITUTIONALPOLICYRESULT", .false, "AUTO", "INTERNAL", "SENSITIVE", "READ", "USE")
::method evaluate
  use arg assessmentId, rolloutBinding, targetScope, observationsArg = .nil, evaluatedAt = .nil
  if evaluatedAt == .nil then evaluatedAt = .DateTime~new
  if rolloutBinding == .nil then return .InstitutionalPolicyResult~failure("PROGRESSIVE_ROLLOUT_REQUIRED")
  gate = rolloutBinding~rollbackGate
  if gate == .nil then return .InstitutionalPolicyResult~failure("ROLLBACK_GATE_NOT_CONFIGURED", rolloutBinding~rolloutId)
  if targetScope == .nil | targetScope~sealed = .false then return .InstitutionalPolicyResult~failure("ROLLBACK_TARGET_SCOPE_NOT_SEALED", rolloutBinding~rolloutId)
  if rolloutBinding~activeAt(evaluatedAt) = .false then return .InstitutionalPolicyResult~failure("ROLLBACK_ASSESSMENT_OUTSIDE_AUTHORIZATION_WINDOW", rolloutBinding~rolloutId)
  observations = .InstitutionalPolicyCanonical~copyArray(observationsArg)
  byMetric = .directory~new
  do observation over observations
    if observation == .nil | observation~sealed = .false then return .InstitutionalPolicyResult~failure("ROLLBACK_OBSERVATION_NOT_SEALED", rolloutBinding~rolloutId)
    if observation~matches(rolloutBinding) = .false then return .InstitutionalPolicyResult~failure("ROLLBACK_OBSERVATION_MISMATCH", observation~observationId)
    if observation~recordedAt > evaluatedAt | observation~windowUntil > evaluatedAt then return .InstitutionalPolicyResult~failure("ROLLBACK_OBSERVATION_FROM_FUTURE", observation~observationId)
    if gate~maximumEvidenceAgeSeconds > 0 then do
      evidenceAge = (evaluatedAt - observation~recordedAt)~totalSeconds
      if evidenceAge > gate~maximumEvidenceAgeSeconds then return .InstitutionalPolicyResult~failure("ROLLBACK_OBSERVATION_STALE", observation~observationId)
    end
    if gate~observationScope <> .nil then do
      if observation~sourceScope == .nil then return .InstitutionalPolicyResult~failure("ROLLBACK_OBSERVATION_SCOPE_REQUIRED", observation~observationId)
      if observation~sourceScope~semanticIdentity <> gate~observationScope~semanticIdentity then return .InstitutionalPolicyResult~failure("ROLLBACK_OBSERVATION_SCOPE_MISMATCH", observation~observationId)
    end
    metric = observation~metricName
    if byMetric~hasIndex(metric) then return .InstitutionalPolicyResult~failure("ROLLBACK_METRIC_AMBIGUOUS", metric)
    byMetric[metric] = observation
  end
  results = .array~new
  insufficient = .false
  triggerCount = 0
  criterionCount = 0
  do criterion over gate~criteria
    criterionCount += 1
    metric = criterion~metricName
    if byMetric~hasIndex(metric) = .false then do
      results~append(.InstitutionalPolicyRolloutCriterionResult~new(criterion,.InstitutionalPolicyBuild~ROLLBACK_INSUFFICIENT_EVIDENCE,"required metric missing"))
      insufficient = .true
      iterate
    end
    observation = byMetric[metric]
    windowSeconds = (observation~windowUntil - observation~windowFrom)~totalSeconds
    if observation~sampleSize < criterion~minimumSampleSize then do
      results~append(.InstitutionalPolicyRolloutCriterionResult~new(criterion,.InstitutionalPolicyBuild~ROLLBACK_INSUFFICIENT_EVIDENCE,"sample size " || observation~sampleSize || " below " || criterion~minimumSampleSize,observation))
      insufficient = .true
      iterate
    end
    if windowSeconds < gate~minimumWindowSeconds then do
      results~append(.InstitutionalPolicyRolloutCriterionResult~new(criterion,.InstitutionalPolicyBuild~ROLLBACK_INSUFFICIENT_EVIDENCE,"evidence window " || windowSeconds || " seconds below " || gate~minimumWindowSeconds,observation))
      insufficient = .true
      iterate
    end
    if criterion~passes(observation~value) then do
      triggerCount += 1
      results~append(.InstitutionalPolicyRolloutCriterionResult~new(criterion,.InstitutionalPolicyBuild~ROLLBACK_ELIGIBLE,"degradation criterion triggered",observation))
    end
    else results~append(.InstitutionalPolicyRolloutCriterionResult~new(criterion,.InstitutionalPolicyBuild~ROLLBACK_NOT_REQUIRED,"degradation criterion not triggered",observation))
  end
  if insufficient then finalOutcome = .InstitutionalPolicyBuild~ROLLBACK_INSUFFICIENT_EVIDENCE
  else if gate~triggerMode = "ALL" then do
    if triggerCount = criterionCount then finalOutcome = .InstitutionalPolicyBuild~ROLLBACK_ELIGIBLE
    else finalOutcome = .InstitutionalPolicyBuild~ROLLBACK_NOT_REQUIRED
  end
  else do
    if triggerCount > 0 then finalOutcome = .InstitutionalPolicyBuild~ROLLBACK_ELIGIBLE
    else finalOutcome = .InstitutionalPolicyBuild~ROLLBACK_NOT_REQUIRED
  end
  assessment = .InstitutionalPolicyRollbackAssessment~new(assessmentId,rolloutBinding,targetScope,gate,finalOutcome,evaluatedAt,results,observations)~seal
  self~recordRelationship("EVALUATES_ROLLBACK", assessment, "fixed post-promotion rollback gate assessment", "INTERNAL")
  return .InstitutionalPolicyResult~success(assessment)

/* Progressive rollout authorizes a bounded overlap between two exact reviewed
   versions. Version selection still comes from ordinary immutable deployment
   bindings; this object only makes the otherwise-forbidden temporal overlap
   explicit, authorized and auditable. */
::class InstitutionalPolicyProgressiveRequest public
::attribute rolloutId get
::attribute policyId get
::attribute priorVersion get
::attribute priorIdentity get
::attribute nextVersion get
::attribute nextIdentity get
::attribute actorId get
::attribute requestedAt get
::attribute effectiveFrom get
::attribute effectiveUntil get
::attribute reason get
::attribute evidenceRef get
::attribute gate get
::attribute rollbackGate get
::method init
  expose rolloutId policyId priorVersion priorIdentity nextVersion nextIdentity actorId requestedAt effectiveFrom effectiveUntil reason evidenceRef gate rollbackGate
  use arg rolloutIdArg, priorPolicy, nextPolicy, actorIdArg, effectiveUntilArg, reasonArg = "", evidenceRefArg = "", requestedAtArg = .nil, gateArg = .nil, rollbackGateArg = .nil
  if priorPolicy == .nil | nextPolicy == .nil then raise syntax 88.970 array("progressive rollout request requires prior and next policies")
  rolloutId = rolloutIdArg~string
  policyId = nextPolicy~policyId
  priorVersion = priorPolicy~version
  priorIdentity = priorPolicy~semanticIdentity
  nextVersion = nextPolicy~version
  nextIdentity = nextPolicy~semanticIdentity
  actorId = actorIdArg~string
  if requestedAtArg == .nil then requestedAt = .DateTime~new
  else requestedAt = requestedAtArg
  effectiveFrom = nextPolicy~effectiveFrom
  if effectiveUntilArg == .nil then effectiveUntil = .nil
  else if effectiveUntilArg~string = "" then effectiveUntil = .nil
  else effectiveUntil = effectiveUntilArg
  reason = reasonArg~string
  evidenceRef = evidenceRefArg~string
  gate = gateArg
  if gate <> .nil then if gate~sealed = .false then raise syntax 88.995 array("progressive rollout gate must be sealed")
  rollbackGate = rollbackGateArg
  if rollbackGate <> .nil then if rollbackGate~sealed = .false then raise syntax 88.998 array("progressive rollback gate must be sealed")
::method matches
  expose policyId priorVersion priorIdentity nextVersion nextIdentity
  use arg priorPolicy, nextPolicy
  if priorPolicy == .nil | nextPolicy == .nil then return .false
  return policyId = nextPolicy~policyId & policyId = priorPolicy~policyId & priorVersion = priorPolicy~version & priorIdentity = priorPolicy~semanticIdentity & nextVersion = nextPolicy~version & nextIdentity = nextPolicy~semanticIdentity

::class InstitutionalPolicyProgressiveBinding public
::attribute rolloutId get
::attribute policyId get
::attribute priorVersion get
::attribute priorIdentity get
::attribute nextVersion get
::attribute nextIdentity get
::attribute actorId get
::attribute requestedAt get
::attribute effectiveFrom get
::attribute effectiveUntil get
::attribute reason get
::attribute evidenceRef get
::attribute authorityDecision get
::attribute gate get
::attribute rollbackGate get
::attribute sealed get
::method init
  expose rolloutId policyId priorVersion priorIdentity nextVersion nextIdentity actorId requestedAt effectiveFrom effectiveUntil reason evidenceRef authorityDecision gate rollbackGate sealed
  use arg request, authorityDecisionArg
  if request == .nil then raise syntax 88.971 array("progressive rollout binding requires request")
  rolloutId = request~rolloutId
  policyId = request~policyId
  priorVersion = request~priorVersion
  priorIdentity = request~priorIdentity
  nextVersion = request~nextVersion
  nextIdentity = request~nextIdentity
  actorId = request~actorId
  requestedAt = request~requestedAt
  effectiveFrom = request~effectiveFrom
  effectiveUntil = request~effectiveUntil
  reason = request~reason
  evidenceRef = request~evidenceRef
  authorityDecision = authorityDecisionArg
  gate = request~gate
  rollbackGate = request~rollbackGate
  sealed = .false
::method activeAt
  expose effectiveFrom effectiveUntil
  use arg moment
  if moment < effectiveFrom then return .false
  if effectiveUntil == .nil then return .true
  return moment < effectiveUntil
::method seal
  expose rolloutId policyId priorVersion priorIdentity nextVersion nextIdentity actorId effectiveFrom effectiveUntil reason authorityDecision gate rollbackGate sealed
  if rolloutId = "" | policyId = "" | priorVersion = "" | priorIdentity = "" | nextVersion = "" | nextIdentity = "" | actorId = "" | reason = "" then raise syntax 88.972 array("progressive rollout binding identity fields required")
  if effectiveUntil == .nil | effectiveUntil <= effectiveFrom then raise syntax 88.973 array("progressive rollout requires a bounded positive authorization window")
  if authorityDecision == .nil | authorityDecision~ok = .false then raise syntax 88.974 array("progressive rollout binding requires authorized decision")
  if gate <> .nil then if gate~sealed = .false then raise syntax 88.996 array("progressive rollout binding requires sealed gate")
  if rollbackGate <> .nil then if rollbackGate~sealed = .false then raise syntax 88.999 array("progressive rollout binding requires sealed rollback gate")
  sealed = .true
  return self
::method canonicalText
  expose rolloutId policyId priorVersion priorIdentity nextVersion nextIdentity actorId requestedAt effectiveFrom effectiveUntil reason evidenceRef authorityDecision gate rollbackGate sealed
  if \sealed then raise syntax 88.975 array("progressive rollout binding must be sealed")
  text = "INSTITUTIONAL-POLICY-PROGRESSIVE-ROLLOUT/3" || '0a'x
  text ||= .InstitutionalPolicyCanonical~field("ROLLOUT_ID", rolloutId)
  text ||= .InstitutionalPolicyCanonical~field("POLICY_ID", policyId)
  text ||= .InstitutionalPolicyCanonical~field("PRIOR_VERSION", priorVersion)
  text ||= .InstitutionalPolicyCanonical~field("PRIOR_IDENTITY", priorIdentity)
  text ||= .InstitutionalPolicyCanonical~field("NEXT_VERSION", nextVersion)
  text ||= .InstitutionalPolicyCanonical~field("NEXT_IDENTITY", nextIdentity)
  text ||= .InstitutionalPolicyCanonical~field("ACTOR", actorId)
  text ||= .InstitutionalPolicyCanonical~field("REQUESTED_AT", requestedAt)
  text ||= .InstitutionalPolicyCanonical~field("EFFECTIVE_FROM", effectiveFrom)
  text ||= .InstitutionalPolicyCanonical~field("EFFECTIVE_UNTIL", effectiveUntil)
  text ||= .InstitutionalPolicyCanonical~field("REASON", reason)
  text ||= .InstitutionalPolicyCanonical~field("EVIDENCE_REF", evidenceRef)
  if gate == .nil then text ||= .InstitutionalPolicyCanonical~field("ROLLOUT_GATE", "")
  else text ||= .InstitutionalPolicyCanonical~field("ROLLOUT_GATE", gate~semanticIdentity)
  if rollbackGate == .nil then text ||= .InstitutionalPolicyCanonical~field("ROLLBACK_GATE", "")
  else text ||= .InstitutionalPolicyCanonical~field("ROLLBACK_GATE", rollbackGate~semanticIdentity)
  text ||= .InstitutionalPolicyCanonical~field("AUTHORITY_DECISION", authorityDecision~canonicalText)
  return text
::method semanticIdentity
  return self~canonicalText

::class InstitutionalPolicyDeploymentBinding public
::attribute deploymentId get
::attribute policyId get
::attribute version get
::attribute policyIdentity get
::attribute actorId get
::attribute requestedAt get
::attribute effectiveFrom get
::attribute effectiveUntil get
::attribute mode get
::attribute scope get
::attribute reason get
::attribute evidenceRef get
::attribute authorityDecision get
::attribute rolloutAssessment get
::attribute rollbackAssessment get
::attribute sealed get
::method init
  expose deploymentId policyId version policyIdentity actorId requestedAt effectiveFrom effectiveUntil mode scope reason evidenceRef authorityDecision rolloutAssessment rollbackAssessment sealed
  use arg request, authorityDecisionArg, rolloutAssessmentArg = .nil, rollbackAssessmentArg = .nil
  if request == .nil then raise syntax 88.965 array("deployment binding requires request")
  deploymentId = request~deploymentId
  policyId = request~policyId
  version = request~version
  policyIdentity = request~policyIdentity
  actorId = request~actorId
  requestedAt = request~requestedAt
  effectiveFrom = request~effectiveFrom
  effectiveUntil = request~effectiveUntil
  mode = request~mode
  scope = request~scope
  reason = request~reason
  evidenceRef = request~evidenceRef
  authorityDecision = authorityDecisionArg
  rolloutAssessment = rolloutAssessmentArg
  rollbackAssessment = rollbackAssessmentArg
  sealed = .false
::method activeAt
  expose effectiveFrom effectiveUntil
  use arg moment
  if moment < effectiveFrom then return .false
  if effectiveUntil == .nil then return .true
  return moment < effectiveUntil
::method seal
  expose sealed deploymentId policyId version policyIdentity actorId scope reason authorityDecision rolloutAssessment rollbackAssessment
  if deploymentId = "" | policyId = "" | version = "" | policyIdentity = "" | actorId = "" | reason = "" then raise syntax 88.966 array("deployment binding identity fields required")
  if scope == .nil | scope~sealed = .false then raise syntax 88.967 array("deployment binding requires sealed scope")
  if authorityDecision == .nil | authorityDecision~ok = .false then raise syntax 88.968 array("deployment binding requires authorized decision")
  if rolloutAssessment <> .nil then if rolloutAssessment~sealed = .false then raise syntax 88.997 array("deployment binding rollout assessment must be sealed")
  if rollbackAssessment <> .nil then if rollbackAssessment~sealed = .false then raise syntax 88.1010 array("deployment binding rollback assessment must be sealed")
  sealed = .true
  return self
::method canonicalText
  expose deploymentId policyId version policyIdentity actorId requestedAt effectiveFrom effectiveUntil mode scope reason evidenceRef authorityDecision rolloutAssessment rollbackAssessment sealed
  if \sealed then raise syntax 88.969 array("deployment binding must be sealed")
  text = "INSTITUTIONAL-POLICY-DEPLOYMENT-BINDING/3" || '0a'x
  text ||= .InstitutionalPolicyCanonical~field("DEPLOYMENT_ID", deploymentId)
  text ||= .InstitutionalPolicyCanonical~field("POLICY", policyId || "@" || version)
  text ||= .InstitutionalPolicyCanonical~field("POLICY_IDENTITY", policyIdentity)
  text ||= .InstitutionalPolicyCanonical~field("ACTOR", actorId)
  text ||= .InstitutionalPolicyCanonical~field("REQUESTED_AT", requestedAt)
  text ||= .InstitutionalPolicyCanonical~field("EFFECTIVE_FROM", effectiveFrom)
  text ||= .InstitutionalPolicyCanonical~field("EFFECTIVE_UNTIL", effectiveUntil)
  text ||= .InstitutionalPolicyCanonical~field("MODE", mode)
  text ||= .InstitutionalPolicyCanonical~field("SCOPE", scope~semanticIdentity)
  text ||= .InstitutionalPolicyCanonical~field("REASON", reason)
  text ||= .InstitutionalPolicyCanonical~field("EVIDENCE_REF", evidenceRef)
  if rolloutAssessment == .nil then text ||= .InstitutionalPolicyCanonical~field("ROLLOUT_ASSESSMENT", "")
  else text ||= .InstitutionalPolicyCanonical~field("ROLLOUT_ASSESSMENT", rolloutAssessment~semanticIdentity)
  if rollbackAssessment == .nil then text ||= .InstitutionalPolicyCanonical~field("ROLLBACK_ASSESSMENT", "")
  else text ||= .InstitutionalPolicyCanonical~field("ROLLBACK_ASSESSMENT", rollbackAssessment~semanticIdentity)
  text ||= .InstitutionalPolicyCanonical~field("AUTHORITY_DECISION", authorityDecision~canonicalText)
  return text
::method semanticIdentity
  return self~canonicalText

::class InstitutionalPolicyTopologyState public
::attribute policyId get
::attribute version get
::attribute policyIdentity get
::attribute point get
::attribute atTime get
::attribute mode get
::attribute operative get
::attribute source get
::attribute binding get
::attribute globalDeploymentState get
::method init
  expose policyId version policyIdentity point atTime mode operative source binding globalDeploymentState
  use arg policy, pointArg, atTimeArg, modeArg, operativeArg, sourceArg = "", bindingArg = .nil, globalStateArg = .nil
  policyId = policy~policyId
  version = policy~version
  policyIdentity = policy~semanticIdentity
  point = pointArg
  atTime = atTimeArg
  mode = modeArg~string~upper
  operative = operativeArg
  source = sourceArg~string~upper
  binding = bindingArg
  globalDeploymentState = globalStateArg
::method canonicalText
  expose policyId version policyIdentity point atTime mode operative source binding globalDeploymentState
  text = "INSTITUTIONAL-POLICY-TOPOLOGY-STATE/1" || '0a'x
  text ||= .InstitutionalPolicyCanonical~field("POLICY", policyId || "@" || version)
  text ||= .InstitutionalPolicyCanonical~field("POLICY_IDENTITY", policyIdentity)
  if point <> .nil then text ||= .InstitutionalPolicyCanonical~field("POINT", point~semanticIdentity)
  else text ||= .InstitutionalPolicyCanonical~field("POINT", "")
  text ||= .InstitutionalPolicyCanonical~field("AT_TIME", atTime)
  text ||= .InstitutionalPolicyCanonical~field("MODE", mode)
  text ||= .InstitutionalPolicyCanonical~field("OPERATIVE", operative)
  text ||= .InstitutionalPolicyCanonical~field("SOURCE", source)
  if binding <> .nil then text ||= .InstitutionalPolicyCanonical~field("BINDING", binding~semanticIdentity)
  else text ||= .InstitutionalPolicyCanonical~field("BINDING", "")
  if globalDeploymentState <> .nil then text ||= .InstitutionalPolicyCanonical~field("GLOBAL_DEPLOYMENT", globalDeploymentState~semanticIdentity)
  else text ||= .InstitutionalPolicyCanonical~field("GLOBAL_DEPLOYMENT", "")
  return text
::method semanticIdentity
  return self~canonicalText

::class InstitutionalPolicyTime public
::method seconds class
  use arg totalSeconds
  total = totalSeconds + 0
  if total < 0 then total = 0
  days = total % 86400
  rem = total // 86400
  hours = rem % 3600
  rem = rem // 3600
  minutes = rem % 60
  seconds = rem // 60
  return .TimeSpan~new(days, hours, minutes, seconds, 0)

::class InstitutionalPolicySupport public
::method metadata class
  use arg purpose
  d = .directory~new
  d["component"] = "INSTITUTIONAL_POLICY"
  d["package"] = "institutional_policy"
  d["package_version"] = .InstitutionalPolicyBuild~RELEASE
  d["api"] = .InstitutionalPolicyBuild~API_VERSION
  d["purpose"] = purpose~string
  d["authorship"] = .array~of("OpenAI implementation under Architect direction")
  d["standards"] = .array~of("ALCHEMY-HOUSE-OBJECT-0.8", .InstitutionalPolicyBuild~API_VERSION)
  d["execution_model"] = .InstitutionalPolicyBuild~EXECUTION_MODEL
  d["design_limitations"] = .array~of("catalog stores policy objects in memory; durable backing belongs to host integration", "domain-specific rule meaning remains in domain modules", "v0.8 adds fixed post-promotion rollback gates alongside promotion gates; automatic rollback eligibility is deterministic and evidence-backed, manual authorized rollback remains independent, and deployment metrics never become customer evidence", "runtime LLM generation is not an operative policy mechanism")
  return d

/* Duck-typed catalogue. Any domain object implementing the protocol can be
   published; it need not inherit InstitutionalPolicyRelease. */
::class InstitutionalPolicyCatalog subclass AlchemyObject public
::method init
  expose policies byVersion publicationRecords lifecycleEvents lifecycleById topologyBindings topologyById progressiveBindings progressiveById rolloutAssessments rolloutAssessmentById rollbackAssessments rollbackAssessmentById resultClass authorityEvaluator lifecycleEvaluator deploymentEvaluator rolloutEvaluator rollbackEvaluator
  use arg metadataArg = .nil, sealer = .nil, authority = .nil, resultClassArg = .nil, authorityEvaluatorArg = .nil, lifecycleEvaluatorArg = .nil, deploymentEvaluatorArg = .nil
  policies = .directory~new
  byVersion = .directory~new
  publicationRecords = .directory~new
  lifecycleEvents = .directory~new
  lifecycleById = .directory~new
  topologyBindings = .directory~new
  topologyById = .directory~new
  progressiveBindings = .directory~new
  progressiveById = .directory~new
  rolloutAssessments = .directory~new
  rolloutAssessmentById = .directory~new
  rollbackAssessments = .directory~new
  rollbackAssessmentById = .directory~new
  rolloutEvaluator = .InstitutionalPolicyRolloutEvaluator~new
  rollbackEvaluator = .InstitutionalPolicyRollbackEvaluator~new
  authorityEvaluator = authorityEvaluatorArg
  lifecycleEvaluator = lifecycleEvaluatorArg
  deploymentEvaluator = deploymentEvaluatorArg
  if resultClassArg == .nil then resultClass = .InstitutionalPolicyResult
  else resultClass = resultClassArg
  if metadataArg == .nil then metadataArg = .InstitutionalPolicySupport~metadata("published immutable institutional policy catalogue")
  self~init:super(metadataArg, sealer, authority)
  self~registerStateVariable("policies", "INTERNAL", "published immutable policy artefacts")
  self~registerStateVariable("publicationRecords", "INTERNAL", "operational publication evidence for each policy version")
  self~registerStateVariable("authorityEvaluator", "INTERNAL", "optional fixed author/approver/publisher authority evaluator")
  self~registerStateVariable("lifecycleEvents", "INTERNAL", "immutable effective-dated global deployment lifecycle evidence")
  self~registerStateVariable("lifecycleEvaluator", "INTERNAL", "optional fixed suspend/resume/withdraw/ratify authority evaluator")
  self~registerStateVariable("topologyBindings", "INTERNAL", "immutable scoped deployment topology evidence for exact policy versions")
  self~registerStateVariable("deploymentEvaluator", "INTERNAL", "optional fixed policy deployment authority evaluator")
  self~registerStateVariable("progressiveBindings", "INTERNAL", "immutable bounded authority evidence permitting exact-version progressive overlap")
  self~registerStateVariable("rolloutAssessments", "INTERNAL", "immutable deterministic rollout acceptance assessments used by promotion attempts")
  self~registerStateVariable("rollbackAssessments", "INTERNAL", "immutable deterministic post-promotion rollback assessments")
  self~registerMethodContract("PUBLISH", "publish approved sealed deterministic policy artefact with optional authority request", .array~of("POLICY", "PUBLICATION_REQUEST"), "INSTITUTIONALPOLICYRESULT", .false, "AUTO", "INTERNAL", "SENSITIVE", "MUTATE", "USE")
  self~registerMethodContract("RESOLVE", "resolve policy operative at historical time", .array~of("POLICY_ID", "AT_TIME"), "INSTITUTIONALPOLICYRESULT", .false, "AUTO", "INTERNAL", "SENSITIVE", "READ", "NONE")
  self~registerMethodContract("PUBLICATIONRECORD", "read immutable publication evidence for a policy version", .array~of("POLICY_ID", "VERSION"), "INSTITUTIONALPOLICYRESULT", .false, "AUTO", "INTERNAL", "SENSITIVE", "READ", "NONE")
  self~registerMethodContract("APPLYLIFECYCLE", "record authorized immutable deployment lifecycle event", .array~of("POLICY_ID", "VERSION", "REQUEST"), "INSTITUTIONALPOLICYRESULT", .false, "AUTO", "INTERNAL", "SENSITIVE", "MUTATE", "USE")
  self~registerMethodContract("DEPLOYMENTSTATE", "resolve global deployment lifecycle state for an exact published version at time", .array~of("POLICY_ID", "VERSION", "AT_TIME"), "INSTITUTIONALPOLICYRESULT", .false, "AUTO", "INTERNAL", "SENSITIVE", "READ", "NONE")
  self~registerMethodContract("APPLYDEPLOYMENT", "record authorized immutable scoped deployment binding for an exact policy version", .array~of("POLICY_ID", "VERSION", "REQUEST"), "INSTITUTIONALPOLICYRESULT", .false, "AUTO", "INTERNAL", "SENSITIVE", "MUTATE", "USE")
  self~registerMethodContract("TOPOLOGYSTATE", "resolve scoped deployment mode for an exact policy version at a deployment point and time", .array~of("POLICY_ID", "VERSION", "POINT", "AT_TIME"), "INSTITUTIONALPOLICYRESULT", .false, "AUTO", "INTERNAL", "SENSITIVE", "READ", "NONE")
  self~registerMethodContract("RESOLVEFORCONTEXT", "resolve exact policy version operative for a deployment point at historical time, including progressive rollout", .array~of("POLICY_ID", "POINT", "AT_TIME"), "INSTITUTIONALPOLICYRESULT", .false, "AUTO", "INTERNAL", "SENSITIVE", "READ", "NONE")
  self~registerMethodContract("PROGRESSIVEBINDING", "read immutable authority evidence permitting bounded overlap for a successor version", .array~of("POLICY_ID", "NEXT_VERSION"), "INSTITUTIONALPOLICYRESULT", .false, "AUTO", "INTERNAL", "SENSITIVE", "READ", "NONE")
  self~registerMethodContract("ROLLOUTASSESSMENTS", "read immutable rollout gate assessments for a successor version", .array~of("POLICY_ID", "NEXT_VERSION"), "ARRAY", .false, "AUTO", "INTERNAL", "SENSITIVE", "READ", "NONE")
  self~registerMethodContract("ASSESSROLLBACK", "deterministically assess post-promotion degradation for an authorized progressive rollout", .array~of("POLICY_ID", "NEXT_VERSION", "TARGET_SCOPE", "OBSERVATIONS", "EVALUATED_AT", "ASSESSMENT_ID"), "INSTITUTIONALPOLICYRESULT", .false, "AUTO", "INTERNAL", "SENSITIVE", "READ", "USE")
  self~registerMethodContract("APPLYAUTOMATEDROLLBACK", "record an authorized rollback deployment only when the fixed post-promotion rollback gate is eligible", .array~of("POLICY_ID", "PRIOR_VERSION", "REQUEST"), "INSTITUTIONALPOLICYRESULT", .false, "AUTO", "INTERNAL", "SENSITIVE", "MUTATE", "USE")
  self~registerMethodContract("ROLLBACKASSESSMENTS", "read immutable post-promotion rollback assessments for a successor version", .array~of("POLICY_ID", "NEXT_VERSION"), "ARRAY", .false, "AUTO", "INTERNAL", "SENSITIVE", "READ", "NONE")
::method validateProtocol private
  use arg framework
  if framework == .nil then return "POLICY_REQUIRED"
  required = .array~of("POLICYID","VERSION","EFFECTIVEFROM","EFFECTIVEUNTIL","SUPERSEDES","SEALED","PUBLICATIONELIGIBLE","ACTIVEAT","SEMANTICIDENTITY","EXECUTIONMODEL")
  do methodName over required
    if framework~hasMethod(methodName) = .false then return "POLICY_PROTOCOL_INVALID:" || methodName
  end
  return "OK"
::method ensureBucket private
  expose policies
  use arg key
  if policies~hasIndex(key) = .false then policies[key] = .array~new
  return policies[key]
::method rangesOverlap private
  use arg a, b
  if a~effectiveUntil <> .nil then if a~effectiveUntil <= b~effectiveFrom then return .false
  if b~effectiveUntil <> .nil then if b~effectiveUntil <= a~effectiveFrom then return .false
  return .true
::method publish
  expose policies byVersion publicationRecords progressiveBindings progressiveById resultClass authorityEvaluator deploymentEvaluator
  use arg framework, publicationRequest = .nil, progressiveRequest = .nil
  protocol = self~validateProtocol(framework)
  if protocol <> "OK" then return resultClass~failure(protocol)
  if framework~sealed = .false then return resultClass~failure("POLICY_NOT_SEALED")
  if framework~policyId~string = "" | framework~version~string = "" then return resultClass~failure("POLICY_IDENTITY_FIELDS_REQUIRED")
  if framework~executionModel~string~upper <> .InstitutionalPolicyBuild~EXECUTION_MODEL then return resultClass~failure("POLICY_EXECUTION_MODEL_NOT_FIXED", framework~executionModel)
  if framework~effectiveUntil <> .nil then if framework~effectiveUntil <= framework~effectiveFrom then return resultClass~failure("POLICY_EFFECTIVE_RANGE_INVALID")
  if framework~publicationEligible = .false then return resultClass~failure("POLICY_NOT_APPROVED")
  semanticIdentity = framework~semanticIdentity~string
  if semanticIdentity = "" then return resultClass~failure("POLICY_SEMANTIC_IDENTITY_REQUIRED")
  authorityDecision = .nil
  if authorityEvaluator <> .nil then do
    authorityDecision = authorityEvaluator~evaluate(framework, publicationRequest)
    if authorityDecision~ok = .false then return resultClass~failure(authorityDecision~code, authorityDecision~detail, authorityDecision)
  end
  key = framework~policyId || "@" || framework~version
  if byVersion~hasIndex(key) then return resultClass~failure("POLICY_VERSION_DUPLICATE", key)
  if framework~supersedes <> "" then do
    priorKey = framework~policyId || "@" || framework~supersedes
    if byVersion~hasIndex(priorKey) = .false then return resultClass~failure("SUPERSEDED_POLICY_NOT_FOUND", priorKey)
  end
  overlaps = .array~new
  if policies~hasIndex(framework~policyId) then do existing over policies[framework~policyId]
    if self~rangesOverlap(existing, framework) then overlaps~append(existing)
  end
  progressiveBinding = .nil
  if overlaps~items > 0 then do
    if progressiveRequest == .nil then return resultClass~failure("POLICY_EFFECTIVE_RANGE_OVERLAP", overlaps[1]~version || " with " || framework~version)
    if overlaps~items <> 1 then return resultClass~failure("PROGRESSIVE_ROLLOUT_MULTIPLE_PRIORS_UNSUPPORTED", framework~policyId)
    prior = overlaps[1]
    if framework~supersedes <> prior~version then return resultClass~failure("PROGRESSIVE_ROLLOUT_SUPERSEDES_REQUIRED", prior~version || " -> " || framework~version)
    if deploymentEvaluator == .nil | deploymentEvaluator~hasMethod("EVALUATEPROGRESSIVE") = .false then return resultClass~failure("PROGRESSIVE_ROLLOUT_AUTHORITY_EVALUATOR_REQUIRED", key)
    if progressiveById~hasIndex(progressiveRequest~rolloutId) then return resultClass~failure("PROGRESSIVE_ROLLOUT_ID_DUPLICATE", progressiveRequest~rolloutId)
    if progressiveRequest~matches(prior,framework) = .false then return resultClass~failure("PROGRESSIVE_ROLLOUT_POLICY_MISMATCH", key)
    progressiveDecision = deploymentEvaluator~evaluateProgressive(prior, framework, progressiveRequest)
    if progressiveDecision~ok = .false then return resultClass~failure(progressiveDecision~code, progressiveDecision~detail, progressiveDecision)
    if progressiveBindings~hasIndex(framework~policyId) then do existingRollout over progressiveBindings[framework~policyId]
      if existingRollout~activeAt(progressiveRequest~effectiveFrom) then return resultClass~failure("PROGRESSIVE_ROLLOUT_WINDOW_OVERLAP", progressiveRequest~rolloutId)
      if progressiveRequest~effectiveUntil <> .nil then if existingRollout~activeAt(progressiveRequest~effectiveUntil - .TimeSpan~new(0,0,0,0,1)) then return resultClass~failure("PROGRESSIVE_ROLLOUT_WINDOW_OVERLAP", progressiveRequest~rolloutId)
    end
    progressiveBinding = .InstitutionalPolicyProgressiveBinding~new(progressiveRequest, progressiveDecision)~seal
  end
  bucket = self~ensureBucket(framework~policyId)
  bucket~append(framework)
  byVersion[key] = framework
  publishedAt = .nil
  if publicationRequest <> .nil then publishedAt = publicationRequest~requestedAt
  publicationRecords[key] = .InstitutionalPolicyPublicationRecord~new(framework, publishedAt, authorityDecision, publicationRequest)
  if progressiveBinding <> .nil then do
    if progressiveBindings~hasIndex(framework~policyId) = .false then progressiveBindings[framework~policyId] = .array~new
    progressiveBindings[framework~policyId]~append(progressiveBinding)
    progressiveById[progressiveBinding~rolloutId] = progressiveBinding
    self~recordRelationship("AUTHORIZES_PROGRESSIVE_ROLLOUT", progressiveBinding, "bounded exact-version overlap authorization", "INTERNAL")
  end
  self~recordRelationship("PUBLISHES", framework, "approved sealed deterministic policy", "INTERNAL")
  return resultClass~success(framework)
::method policyVersion
  expose byVersion resultClass
  use arg policyId, version
  key = policyId~string~upper || "@" || version~string
  if byVersion~hasIndex(key) = .false then return resultClass~failure("POLICY_VERSION_NOT_FOUND", key)
  return resultClass~success(byVersion[key])
::method progressiveBinding
  expose progressiveBindings resultClass
  use arg policyId, nextVersion
  key = policyId~string~upper
  if progressiveBindings~hasIndex(key) = .false then return resultClass~failure("PROGRESSIVE_ROLLOUT_NOT_FOUND", key || "@" || nextVersion~string)
  matches = .array~new
  do binding over progressiveBindings[key]
    if binding~nextVersion = nextVersion~string then matches~append(binding)
  end
  if matches~items = 0 then return resultClass~failure("PROGRESSIVE_ROLLOUT_NOT_FOUND", key || "@" || nextVersion~string)
  if matches~items > 1 then return resultClass~failure("PROGRESSIVE_ROLLOUT_AMBIGUOUS", key || "@" || nextVersion~string)
  return resultClass~success(matches[1])
::method rolloutAssessments
  expose rolloutAssessments
  use arg policyId, nextVersion
  key = policyId~string~upper || "@" || nextVersion~string
  if rolloutAssessments~hasIndex(key) = .false then return .array~new
  return .InstitutionalPolicyCanonical~copyArray(rolloutAssessments[key])
::method rollbackAssessments
  expose rollbackAssessments
  use arg policyId, nextVersion
  key = policyId~string~upper || "@" || nextVersion~string
  if rollbackAssessments~hasIndex(key) = .false then return .array~new
  return .InstitutionalPolicyCanonical~copyArray(rollbackAssessments[key])
::method assessRollback
  expose progressiveBindings rollbackAssessments rollbackAssessmentById rollbackEvaluator resultClass
  use arg policyId, nextVersion, targetScope, observationsArg = .nil, evaluatedAt = .nil, assessmentId = ""
  if evaluatedAt == .nil then evaluatedAt = .DateTime~new
  key = policyId~string~upper
  if assessmentId = "" then assessmentId = "ROLLBACK-ASSESS:" || key || "@" || nextVersion~string || ":" || evaluatedAt~string
  if progressiveBindings~hasIndex(key) = .false then return resultClass~failure("PROGRESSIVE_ROLLOUT_NOT_FOUND", key || "@" || nextVersion~string)
  rollout = .nil
  do candidate over progressiveBindings[key]
    if candidate~nextVersion = nextVersion~string & candidate~activeAt(evaluatedAt) then do
      if rollout <> .nil then return resultClass~failure("PROGRESSIVE_ROLLOUT_AMBIGUOUS", key || "@" || nextVersion~string)
      rollout = candidate
    end
  end
  if rollout == .nil then return resultClass~failure("PROGRESSIVE_ROLLOUT_NOT_EFFECTIVE", key || "@" || nextVersion~string)
  result = rollbackEvaluator~evaluate(assessmentId, rollout, targetScope, observationsArg, evaluatedAt)
  if result~ok = .false then return resultClass~failure(result~code, result~detail, result~value)
  assessment = result~value
  if rollbackAssessmentById~hasIndex(assessment~assessmentId) then return resultClass~failure("ROLLBACK_ASSESSMENT_ID_DUPLICATE", assessment~assessmentId)
  assessmentKey = key || "@" || rollout~nextVersion
  if rollbackAssessments~hasIndex(assessmentKey) = .false then rollbackAssessments[assessmentKey] = .array~new
  rollbackAssessments[assessmentKey]~append(assessment)
  rollbackAssessmentById[assessment~assessmentId] = assessment
  self~recordRelationship("ASSESSES_ROLLBACK", assessment, "deterministic post-promotion rollback evidence", "INTERNAL")
  return resultClass~success(assessment)

::method progressiveAt private
  expose progressiveBindings resultClass
  use arg policyId, atTime
  key = policyId~string~upper
  if progressiveBindings~hasIndex(key) = .false then return resultClass~failure("PROGRESSIVE_ROLLOUT_NOT_FOUND", key)
  active = .array~new
  expiredSeen = .false
  do binding over progressiveBindings[key]
    if binding~activeAt(atTime) then active~append(binding)
    else if binding~effectiveUntil <> .nil then if atTime >= binding~effectiveUntil then expiredSeen = .true
  end
  if active~items = 1 then return resultClass~success(active[1])
  if active~items > 1 then return resultClass~failure("PROGRESSIVE_ROLLOUT_AMBIGUOUS", key || " at " || atTime)
  if expiredSeen then return resultClass~failure("PROGRESSIVE_ROLLOUT_AUTHORIZATION_EXPIRED", key || " at " || atTime)
  return resultClass~failure("PROGRESSIVE_ROLLOUT_NOT_EFFECTIVE", key || " at " || atTime)
::method lifecycleKey private
  use arg policyId, version
  return policyId~string~upper || "@" || version~string
::method applyLifecycle
  expose byVersion lifecycleEvents lifecycleById resultClass lifecycleEvaluator
  use arg policyId, version, request
  key = self~lifecycleKey(policyId, version)
  if byVersion~hasIndex(key) = .false then return resultClass~failure("POLICY_VERSION_NOT_FOUND", key)
  policy = byVersion[key]
  if request == .nil then return resultClass~failure("LIFECYCLE_REQUEST_REQUIRED", key)
  if request~matches(policy) = .false then return resultClass~failure("LIFECYCLE_REQUEST_POLICY_MISMATCH", key)
  if request~validEventType = .false then return resultClass~failure("LIFECYCLE_EVENT_TYPE_INVALID", request~eventType)
  if lifecycleEvaluator == .nil then return resultClass~failure("LIFECYCLE_AUTHORITY_EVALUATOR_REQUIRED", key)
  if lifecycleById~hasIndex(request~eventId) then return resultClass~failure("LIFECYCLE_EVENT_ID_DUPLICATE", request~eventId)
  decision = lifecycleEvaluator~evaluate(policy, request)
  if decision~ok = .false then return resultClass~failure(decision~code, decision~detail, decision)
  if lifecycleEvents~hasIndex(key) then do existing over lifecycleEvents[key]
    if existing~effectiveAt = request~effectiveAt then do
      if existing~eventType <> .InstitutionalPolicyBuild~LIFECYCLE_RATIFY & request~eventType <> .InstitutionalPolicyBuild~LIFECYCLE_RATIFY then return resultClass~failure("POLICY_LIFECYCLE_EVENT_TIME_COLLISION", key || " at " || request~effectiveAt)
    end
    if existing~eventType = .InstitutionalPolicyBuild~LIFECYCLE_WITHDRAW & existing~effectiveAt <= request~effectiveAt then do
      if request~eventType <> .InstitutionalPolicyBuild~LIFECYCLE_RATIFY then return resultClass~failure("POLICY_ALREADY_WITHDRAWN", key)
    end
  end
  event = .InstitutionalPolicyLifecycleEvent~new(request, decision)~seal
  if lifecycleEvents~hasIndex(key) = .false then lifecycleEvents[key] = .array~new
  lifecycleEvents[key]~append(event)
  lifecycleById[event~eventId] = event
  self~recordRelationship("POLICY_LIFECYCLE", event, "immutable authorized deployment lifecycle evidence", "INTERNAL")
  return resultClass~success(event)
::method lifecycleEvents
  expose lifecycleEvents
  use arg policyId, version
  key = self~lifecycleKey(policyId, version)
  if lifecycleEvents~hasIndex(key) = .false then return .array~new
  return .InstitutionalPolicyCanonical~copyArray(lifecycleEvents[key])
::method deploymentState
  expose byVersion lifecycleEvents resultClass
  use arg policyId, version, atTime = .nil
  if atTime == .nil then atTime = .DateTime~new
  key = self~lifecycleKey(policyId, version)
  if byVersion~hasIndex(key) = .false then return resultClass~failure("POLICY_VERSION_NOT_FOUND", key)
  policy = byVersion[key]
  state = .InstitutionalPolicyBuild~DEPLOYMENT_ACTIVE
  ratified = .false
  applied = .array~new
  if lifecycleEvents~hasIndex(key) then do
    eventBySort = .directory~new
    sortKeys = .array~new
    do event over lifecycleEvents[key]
      if event~effectiveAt <= atTime then do
        sortKey = event~effectiveAt~string || "|" || event~eventId
        eventBySort[sortKey] = event
        sortKeys~append(sortKey)
      end
    end
    sortKeys~sort
    do sortKey over sortKeys
      event = eventBySort[sortKey]
      applied~append(event)
      select
        when event~eventType = .InstitutionalPolicyBuild~LIFECYCLE_SUSPEND then if state <> .InstitutionalPolicyBuild~DEPLOYMENT_WITHDRAWN then state = .InstitutionalPolicyBuild~DEPLOYMENT_SUSPENDED
        when event~eventType = .InstitutionalPolicyBuild~LIFECYCLE_RESUME then if state <> .InstitutionalPolicyBuild~DEPLOYMENT_WITHDRAWN then state = .InstitutionalPolicyBuild~DEPLOYMENT_ACTIVE
        when event~eventType = .InstitutionalPolicyBuild~LIFECYCLE_WITHDRAW then state = .InstitutionalPolicyBuild~DEPLOYMENT_WITHDRAWN
        when event~eventType = .InstitutionalPolicyBuild~LIFECYCLE_RATIFY then ratified = .true
        otherwise nop
      end
    end
  end
  return resultClass~success(.InstitutionalPolicyDeploymentState~new(policy, atTime, state, ratified, applied))
::method applyDeployment
  expose byVersion topologyBindings topologyById progressiveBindings rolloutAssessments rolloutAssessmentById resultClass deploymentEvaluator rolloutEvaluator
  use arg policyId, version, request
  key = self~lifecycleKey(policyId, version)
  if byVersion~hasIndex(key) = .false then return resultClass~failure("POLICY_VERSION_NOT_FOUND", key)
  policy = byVersion[key]
  if request == .nil then return resultClass~failure("DEPLOYMENT_REQUEST_REQUIRED", key)
  if request~matches(policy) = .false then return resultClass~failure("DEPLOYMENT_REQUEST_POLICY_MISMATCH", key)
  if deploymentEvaluator == .nil then return resultClass~failure("DEPLOYMENT_AUTHORITY_EVALUATOR_REQUIRED", key)
  if topologyById~hasIndex(request~deploymentId) then return resultClass~failure("DEPLOYMENT_ID_DUPLICATE", request~deploymentId)
  if policy~activeAt(request~effectiveFrom) = .false then return resultClass~failure("DEPLOYMENT_OUTSIDE_POLICY_WINDOW", request~effectiveFrom)
  if request~effectiveUntil <> .nil then do
    if policy~effectiveUntil <> .nil then if request~effectiveUntil > policy~effectiveUntil then return resultClass~failure("DEPLOYMENT_OUTSIDE_POLICY_WINDOW", request~effectiveUntil)
  end
  decision = deploymentEvaluator~evaluate(policy, request)
  if decision~ok = .false then return resultClass~failure(decision~code, decision~detail, decision)

  rolloutAssessment = .nil
  if request~mode = .InstitutionalPolicyBuild~DEPLOYMENT_ACTIVE & progressiveBindings~hasIndex(policy~policyId) then do
    matchingRollout = .nil
    do candidate over progressiveBindings[policy~policyId]
      if candidate~nextVersion = policy~version & candidate~nextIdentity = policy~semanticIdentity & candidate~activeAt(request~effectiveFrom) then do
        if matchingRollout <> .nil then return resultClass~failure("PROGRESSIVE_ROLLOUT_AMBIGUOUS", policy~policyId || "@" || policy~version)
        matchingRollout = candidate
      end
    end
    if matchingRollout <> .nil then if matchingRollout~gate <> .nil then do
      assessmentResult = rolloutEvaluator~evaluate("ROLLOUT-ASSESS:" || request~deploymentId, matchingRollout, request~scope, request~rolloutObservations, request~requestedAt)
      if assessmentResult~ok = .false then return resultClass~failure(assessmentResult~code, assessmentResult~detail, assessmentResult~value)
      rolloutAssessment = assessmentResult~value
      assessmentKey = policy~policyId || "@" || policy~version
      if rolloutAssessmentById~hasIndex(rolloutAssessment~assessmentId) then return resultClass~failure("ROLLOUT_ASSESSMENT_ID_DUPLICATE", rolloutAssessment~assessmentId)
      if rolloutAssessments~hasIndex(assessmentKey) = .false then rolloutAssessments[assessmentKey] = .array~new
      rolloutAssessments[assessmentKey]~append(rolloutAssessment)
      rolloutAssessmentById[rolloutAssessment~assessmentId] = rolloutAssessment
      self~recordRelationship("ASSESSES_ROLLOUT", rolloutAssessment, "deterministic rollout promotion evidence", "INTERNAL")
      if rolloutAssessment~outcome <> .InstitutionalPolicyBuild~ROLLOUT_PROMOTION_ELIGIBLE then return resultClass~failure("ROLLOUT_PROMOTION_NOT_ELIGIBLE", rolloutAssessment~outcome, rolloutAssessment)
      if rolloutAssessment~matchesDeployment(matchingRollout, request) = .false then return resultClass~failure("ROLLOUT_PROMOTION_ASSESSMENT_MISMATCH", request~deploymentId, rolloutAssessment)
    end
  end

  return self~recordDeploymentBinding(key, request, decision, rolloutAssessment, .nil)
::method recordDeploymentBinding private
  expose topologyBindings topologyById resultClass
  use arg key, request, decision, rolloutAssessment = .nil, rollbackAssessment = .nil
  if topologyBindings~hasIndex(key) then do existing over topologyBindings[key]
    if existing~scope~semanticIdentity = request~scope~semanticIdentity & existing~effectiveFrom = request~effectiveFrom then return resultClass~failure("DEPLOYMENT_SCOPE_TIME_COLLISION", request~scope~scopeId || " at " || request~effectiveFrom)
  end
  binding = .InstitutionalPolicyDeploymentBinding~new(request, decision, rolloutAssessment, rollbackAssessment)~seal
  if topologyBindings~hasIndex(key) = .false then topologyBindings[key] = .array~new
  topologyBindings[key]~append(binding)
  topologyById[binding~deploymentId] = binding
  self~recordRelationship("DEPLOYS", binding, "immutable authorized scoped policy deployment evidence", "INTERNAL")
  return resultClass~success(binding)
::method applyAutomatedRollback
  expose byVersion topologyBindings topologyById progressiveBindings resultClass deploymentEvaluator
  use arg policyId, priorVersion, request
  key = self~lifecycleKey(policyId, priorVersion)
  if byVersion~hasIndex(key) = .false then return resultClass~failure("POLICY_VERSION_NOT_FOUND", key)
  prior = byVersion[key]
  if request == .nil then return resultClass~failure("DEPLOYMENT_REQUEST_REQUIRED", key)
  if request~matches(prior) = .false then return resultClass~failure("DEPLOYMENT_REQUEST_POLICY_MISMATCH", key)
  if request~mode <> .InstitutionalPolicyBuild~DEPLOYMENT_ACTIVE then return resultClass~failure("AUTOMATED_ROLLBACK_REQUIRES_ACTIVE_MODE", request~deploymentId)
  if deploymentEvaluator == .nil then return resultClass~failure("DEPLOYMENT_AUTHORITY_EVALUATOR_REQUIRED", key)
  if topologyById~hasIndex(request~deploymentId) then return resultClass~failure("DEPLOYMENT_ID_DUPLICATE", request~deploymentId)
  decision = deploymentEvaluator~evaluate(prior, request)
  if decision~ok = .false then return resultClass~failure(decision~code, decision~detail, decision)
  pkey = policyId~string~upper
  if progressiveBindings~hasIndex(pkey) = .false then return resultClass~failure("PROGRESSIVE_ROLLOUT_NOT_FOUND", pkey)
  rollout = .nil
  do candidate over progressiveBindings[pkey]
    if candidate~priorVersion = prior~version & candidate~priorIdentity = prior~semanticIdentity & candidate~activeAt(request~effectiveFrom) then do
      if rollout <> .nil then return resultClass~failure("PROGRESSIVE_ROLLOUT_AMBIGUOUS", pkey || " rollback")
      rollout = candidate
    end
  end
  if rollout == .nil then return resultClass~failure("PROGRESSIVE_ROLLOUT_NOT_EFFECTIVE", pkey || " rollback")
  if rollout~rollbackGate == .nil then return resultClass~failure("ROLLBACK_GATE_NOT_CONFIGURED", rollout~rolloutId)
  nextKey = self~lifecycleKey(policyId, rollout~nextVersion)
  promoted = .false
  if topologyBindings~hasIndex(nextKey) then do candidateBinding over topologyBindings[nextKey]
    if candidateBinding~mode = .InstitutionalPolicyBuild~DEPLOYMENT_ACTIVE & candidateBinding~scope~semanticIdentity = request~scope~semanticIdentity & candidateBinding~effectiveFrom <= request~requestedAt then promoted = .true
  end
  if \promoted then return resultClass~failure("ROLLBACK_SUCCESSOR_NOT_PROMOTED_FOR_SCOPE", request~scope~scopeId)
  assessmentResult = self~assessRollback(policyId, rollout~nextVersion, request~scope, request~rolloutObservations, request~requestedAt, "ROLLBACK-ASSESS:" || request~deploymentId)
  if assessmentResult~ok = .false then return assessmentResult
  rollbackAssessment = assessmentResult~value
  if rollbackAssessment~outcome <> .InstitutionalPolicyBuild~ROLLBACK_ELIGIBLE then return resultClass~failure("ROLLBACK_NOT_ELIGIBLE", rollbackAssessment~outcome, rollbackAssessment)
  if rollbackAssessment~matchesDeployment(rollout, request) = .false then return resultClass~failure("ROLLBACK_ASSESSMENT_MISMATCH", request~deploymentId, rollbackAssessment)
  return self~recordDeploymentBinding(key, request, decision, .nil, rollbackAssessment)
::method deploymentBindings
  expose topologyBindings
  use arg policyId, version
  key = self~lifecycleKey(policyId, version)
  if topologyBindings~hasIndex(key) = .false then return .array~new
  return .InstitutionalPolicyCanonical~copyArray(topologyBindings[key])
::method topologyState
  expose byVersion topologyBindings resultClass
  use arg policyId, version, point, atTime = .nil
  if atTime == .nil then atTime = .DateTime~new
  key = self~lifecycleKey(policyId, version)
  if byVersion~hasIndex(key) = .false then return resultClass~failure("POLICY_VERSION_NOT_FOUND", key)
  policy = byVersion[key]
  if policy~activeAt(atTime) = .false then return resultClass~failure("POLICY_NOT_EFFECTIVE", key)
  globalStateResult = self~deploymentState(policy~policyId, policy~version, atTime)
  if globalStateResult~ok = .false then return globalStateResult
  globalState = globalStateResult~value
  if globalState~state = .InstitutionalPolicyBuild~DEPLOYMENT_SUSPENDED then return resultClass~success(.InstitutionalPolicyTopologyState~new(policy,point,atTime,.InstitutionalPolicyBuild~DEPLOYMENT_SUSPENDED,.false,"GLOBAL_LIFECYCLE",.nil,globalState))
  if globalState~state = .InstitutionalPolicyBuild~DEPLOYMENT_WITHDRAWN then return resultClass~success(.InstitutionalPolicyTopologyState~new(policy,point,atTime,.InstitutionalPolicyBuild~DEPLOYMENT_WITHDRAWN,.false,"GLOBAL_LIFECYCLE",.nil,globalState))
  if topologyBindings~hasIndex(key) = .false then return resultClass~success(.InstitutionalPolicyTopologyState~new(policy,point,atTime,.InstitutionalPolicyBuild~DEPLOYMENT_ACTIVE,.true,"LEGACY_GLOBAL",.nil,globalState))
  hadEffectiveBinding = .false
  do binding over topologyBindings[key]
    if binding~effectiveFrom <= atTime then hadEffectiveBinding = .true
  end
  if hadEffectiveBinding = .false then return resultClass~success(.InstitutionalPolicyTopologyState~new(policy,point,atTime,.InstitutionalPolicyBuild~DEPLOYMENT_ACTIVE,.true,"LEGACY_GLOBAL",.nil,globalState))
  if point == .nil then return resultClass~failure("DEPLOYMENT_POINT_REQUIRED", key)
  best = .nil
  bestSpecificity = -1
  bestFrom = .nil
  ambiguous = .false
  do binding over topologyBindings[key]
    if binding~activeAt(atTime) & binding~scope~matches(point) then do
      specificity = binding~scope~specificity
      if best == .nil then do
        best = binding
        bestSpecificity = specificity
        bestFrom = binding~effectiveFrom
        ambiguous = .false
      end
      else if specificity > bestSpecificity then do
        best = binding
        bestSpecificity = specificity
        bestFrom = binding~effectiveFrom
        ambiguous = .false
      end
      else if specificity = bestSpecificity then do
        if binding~effectiveFrom > bestFrom then do
          best = binding
          bestFrom = binding~effectiveFrom
          ambiguous = .false
        end
        else if binding~effectiveFrom = bestFrom then ambiguous = .true
      end
    end
  end
  if ambiguous then return resultClass~failure("POLICY_DEPLOYMENT_AMBIGUOUS", key || " at " || atTime)
  if best == .nil then return resultClass~success(.InstitutionalPolicyTopologyState~new(policy,point,atTime,.InstitutionalPolicyBuild~DEPLOYMENT_NOT_DEPLOYED,.false,"TOPOLOGY",.nil,globalState))
  mode = best~mode
  operative = mode = .InstitutionalPolicyBuild~DEPLOYMENT_ACTIVE | mode = .InstitutionalPolicyBuild~DEPLOYMENT_CANARY
  return resultClass~success(.InstitutionalPolicyTopologyState~new(policy,point,atTime,mode,operative,"TOPOLOGY",best,globalState))
::method resolveForContext
  expose policies resultClass
  use arg policyId, point, atTime = .nil
  if atTime == .nil then atTime = .DateTime~new
  key = policyId~string~upper
  if policies~hasIndex(key) = .false then return resultClass~failure("POLICY_NOT_FOUND", key)
  matches = .array~new
  active = .array~new
  do policy over policies[key]
    if policy~activeAt(atTime) then do
      matches~append(policy)
      global = self~deploymentState(policy~policyId, policy~version, atTime)
      if global~ok then if global~value~state <> .InstitutionalPolicyBuild~DEPLOYMENT_SUSPENDED & global~value~state <> .InstitutionalPolicyBuild~DEPLOYMENT_WITHDRAWN then active~append(policy)
    end
  end
  if matches~items = 0 then return resultClass~failure("POLICY_NOT_EFFECTIVE", key)
  if matches~items = 1 then do
    policy = matches[1]
    global = self~deploymentState(policy~policyId, policy~version, atTime)
    if global~ok = .false then return global
    if global~value~state = .InstitutionalPolicyBuild~DEPLOYMENT_SUSPENDED then return resultClass~failure("POLICY_SUSPENDED", policy~policyId || "@" || policy~version, global~value)
    if global~value~state = .InstitutionalPolicyBuild~DEPLOYMENT_WITHDRAWN then return resultClass~failure("POLICY_WITHDRAWN", policy~policyId || "@" || policy~version, global~value)
    topology = self~topologyState(policy~policyId, policy~version, point, atTime)
    if topology~ok = .false then return topology
    state = topology~value
    if state~mode = .InstitutionalPolicyBuild~DEPLOYMENT_NOT_DEPLOYED then return resultClass~failure("POLICY_NOT_DEPLOYED", policy~policyId || "@" || policy~version, state)
    if state~mode = .InstitutionalPolicyBuild~DEPLOYMENT_STAGED then return resultClass~failure("POLICY_STAGED", policy~policyId || "@" || policy~version, state)
    if state~mode = .InstitutionalPolicyBuild~DEPLOYMENT_SUSPENDED then return resultClass~failure("POLICY_SCOPE_SUSPENDED", policy~policyId || "@" || policy~version, state)
    if state~mode = .InstitutionalPolicyBuild~DEPLOYMENT_WITHDRAWN then return resultClass~failure("POLICY_WITHDRAWN", policy~policyId || "@" || policy~version, state)
    if state~operative = .false then return resultClass~failure("POLICY_NOT_OPERATIVE_AT_DEPLOYMENT_POINT", policy~policyId || "@" || policy~version, state)
    return resultClass~success(policy)
  end
  if active~items = 1 then do
    policy = active[1]
    topology = self~topologyState(policy~policyId, policy~version, point, atTime)
    if topology~ok = .false then return topology
    state = topology~value
    if state~mode = .InstitutionalPolicyBuild~DEPLOYMENT_NOT_DEPLOYED then return resultClass~failure("POLICY_NOT_DEPLOYED", policy~policyId || "@" || policy~version, state)
    if state~mode = .InstitutionalPolicyBuild~DEPLOYMENT_STAGED then return resultClass~failure("POLICY_STAGED", policy~policyId || "@" || policy~version, state)
    if state~mode = .InstitutionalPolicyBuild~DEPLOYMENT_SUSPENDED then return resultClass~failure("POLICY_SCOPE_SUSPENDED", policy~policyId || "@" || policy~version, state)
    if state~mode = .InstitutionalPolicyBuild~DEPLOYMENT_WITHDRAWN then return resultClass~failure("POLICY_WITHDRAWN", policy~policyId || "@" || policy~version, state)
    if state~operative = .false then return resultClass~failure("POLICY_NOT_OPERATIVE_AT_DEPLOYMENT_POINT", policy~policyId || "@" || policy~version, state)
    return resultClass~success(policy)
  end
  if active~items = 0 then return resultClass~failure("POLICY_NOT_OPERATIVE", key || " at " || atTime)
  if active~items <> 2 then return resultClass~failure("POLICY_AMBIGUOUS", key || " at " || atTime)
  rolloutResult = self~progressiveAt(key, atTime)
  if rolloutResult~ok = .false then return rolloutResult
  rollout = rolloutResult~value
  prior = .nil
  next = .nil
  do policy over active
    if policy~version = rollout~priorVersion & policy~semanticIdentity = rollout~priorIdentity then prior = policy
    if policy~version = rollout~nextVersion & policy~semanticIdentity = rollout~nextIdentity then next = policy
  end
  if prior == .nil | next == .nil then return resultClass~failure("PROGRESSIVE_ROLLOUT_ACTIVE_VERSION_MISMATCH", key)
  if point == .nil then return resultClass~failure("DEPLOYMENT_POINT_REQUIRED", key)
  priorStateResult = self~topologyState(prior~policyId, prior~version, point, atTime)
  if priorStateResult~ok = .false then return priorStateResult
  nextStateResult = self~topologyState(next~policyId, next~version, point, atTime)
  if nextStateResult~ok = .false then return nextStateResult
  priorState = priorStateResult~value
  nextState = nextStateResult~value
  priorCandidate = priorState~operative
  nextCandidate = nextState~operative
  if nextState~source = "LEGACY_GLOBAL" then nextCandidate = .false
  if priorCandidate = .false & nextCandidate = .false then return resultClass~failure("POLICY_NOT_DEPLOYED", key || " progressive at " || atTime)
  if priorCandidate & \nextCandidate then return resultClass~success(prior)
  if nextCandidate & \priorCandidate then return resultClass~success(next)
  priorSpecificity = -1
  priorFrom = prior~effectiveFrom
  if priorState~binding <> .nil then do
    priorSpecificity = priorState~binding~scope~specificity
    priorFrom = priorState~binding~effectiveFrom
  end
  nextSpecificity = -1
  nextFrom = next~effectiveFrom
  if nextState~binding <> .nil then do
    nextSpecificity = nextState~binding~scope~specificity
    nextFrom = nextState~binding~effectiveFrom
  end
  if nextSpecificity > priorSpecificity then return resultClass~success(next)
  if priorSpecificity > nextSpecificity then return resultClass~success(prior)
  if nextFrom > priorFrom then return resultClass~success(next)
  if priorFrom > nextFrom then return resultClass~success(prior)
  return resultClass~failure("PROGRESSIVE_POLICY_ROUTE_AMBIGUOUS", key || " at " || atTime)
::method executionContextForContext
  expose resultClass
  use arg policyId, point, atTime = .nil
  if atTime == .nil then atTime = .DateTime~new
  resolved = self~resolveForContext(policyId, point, atTime)
  if resolved~ok = .false then return resolved
  policy = resolved~value
  topology = self~topologyState(policy~policyId, policy~version, point, atTime)
  if topology~ok = .false then return topology
  return resultClass~success(.InstitutionalPolicyExecutionContext~new(policy, atTime, .InstitutionalPolicyBuild~MODE_OPERATIVE, topology~value))
::method resolve
  expose policies resultClass
  use arg policyId, atTime = .nil
  if atTime == .nil then atTime = .DateTime~new
  key = policyId~string~upper
  if policies~hasIndex(key) = .false then return resultClass~failure("POLICY_NOT_FOUND", key)
  matches = .array~new
  available = .array~new
  do framework over policies[key]
    if framework~activeAt(atTime) then do
      matches~append(framework)
      deployment = self~deploymentState(framework~policyId, framework~version, atTime)
      if deployment~ok then if deployment~value~state <> .InstitutionalPolicyBuild~DEPLOYMENT_SUSPENDED & deployment~value~state <> .InstitutionalPolicyBuild~DEPLOYMENT_WITHDRAWN then available~append(framework)
    end
  end
  if matches~items = 0 then return resultClass~failure("POLICY_NOT_EFFECTIVE", key)
  if matches~items = 1 then do
    framework = matches[1]
    deployment = self~deploymentState(framework~policyId, framework~version, atTime)
    if deployment~ok = .false then return deployment
    if deployment~value~state = .InstitutionalPolicyBuild~DEPLOYMENT_SUSPENDED then return resultClass~failure("POLICY_SUSPENDED", framework~policyId || "@" || framework~version, deployment~value)
    if deployment~value~state = .InstitutionalPolicyBuild~DEPLOYMENT_WITHDRAWN then return resultClass~failure("POLICY_WITHDRAWN", framework~policyId || "@" || framework~version, deployment~value)
    return resultClass~success(framework)
  end
  if available~items = 1 then return resultClass~success(available[1])
  if available~items = 0 then return resultClass~failure("POLICY_NOT_OPERATIVE", key || " at " || atTime)
  rolloutResult = self~progressiveAt(key, atTime)
  if rolloutResult~ok = .false then return rolloutResult
  return resultClass~failure("DEPLOYMENT_POINT_REQUIRED", key || " progressive rollout at " || atTime, rolloutResult~value)
::method executionContext
  expose resultClass
  use arg policyId, atTime = .nil
  if atTime == .nil then atTime = .DateTime~new
  resolved = self~resolve(policyId, atTime)
  if resolved~ok = .false then return resolved
  policy = resolved~value
  deployment = self~deploymentState(policy~policyId, policy~version, atTime)
  if deployment~ok = .false then return deployment
  return resultClass~success(.InstitutionalPolicyExecutionContext~new(policy, atTime, .InstitutionalPolicyBuild~MODE_OPERATIVE, deployment~value))
::method publicationRecord
  expose publicationRecords resultClass
  use arg policyId, version
  key = policyId~string~upper || "@" || version~string
  if publicationRecords~hasIndex(key) = .false then return resultClass~failure("PUBLICATION_RECORD_NOT_FOUND", key)
  return resultClass~success(publicationRecords[key])
::method versions
  expose policies
  use arg policyId
  key = policyId~string~upper
  if policies~hasIndex(key) = .false then return .array~new
  return .InstitutionalPolicyCanonical~copyArray(policies[key])

::class InstitutionalPolicyReplayGuard public
::method validatePolicy class private
  use arg policy
  if policy == .nil then return .InstitutionalPolicyResult~failure("POLICY_REQUIRED")
  required = .array~of("POLICYID","VERSION","EFFECTIVEFROM","EFFECTIVEUNTIL","SEALED","SEMANTICIDENTITY","EXECUTIONMODEL")
  do methodName over required
    if policy~hasMethod(methodName) = .false then return .InstitutionalPolicyResult~failure("POLICY_PROTOCOL_INVALID", methodName)
  end
  if policy~sealed = .false then return .InstitutionalPolicyResult~failure("POLICY_NOT_SEALED")
  if policy~policyId~string = "" | policy~version~string = "" then return .InstitutionalPolicyResult~failure("POLICY_IDENTITY_FIELDS_REQUIRED")
  if policy~executionModel~string~upper <> .InstitutionalPolicyBuild~EXECUTION_MODEL then return .InstitutionalPolicyResult~failure("POLICY_EXECUTION_MODEL_NOT_FIXED", policy~executionModel)
  if policy~effectiveUntil <> .nil then if policy~effectiveUntil <= policy~effectiveFrom then return .InstitutionalPolicyResult~failure("POLICY_EFFECTIVE_RANGE_INVALID")
  if policy~semanticIdentity~string = "" then return .InstitutionalPolicyResult~failure("POLICY_SEMANTIC_IDENTITY_REQUIRED")
  return .InstitutionalPolicyResult~success(policy)
::method operative class
  use arg policy, actionTime
  validation = self~validatePolicy(policy)
  if validation~ok = .false then return validation
  if policy~hasMethod("PUBLICATIONELIGIBLE") then if policy~publicationEligible = .false then return .InstitutionalPolicyResult~failure("POLICY_NOT_APPROVED")
  if policy~hasMethod("ACTIVEAT") = .false then return .InstitutionalPolicyResult~failure("POLICY_PROTOCOL_INVALID", "ACTIVEAT")
  if policy~activeAt(actionTime) = .false then return .InstitutionalPolicyResult~failure("POLICY_NOT_EFFECTIVE")
  return .InstitutionalPolicyResult~success(.InstitutionalPolicyExecutionContext~new(policy, actionTime, .InstitutionalPolicyBuild~MODE_OPERATIVE))
::method operativeFromCatalog class
  use arg catalog, policyId, actionTime
  if catalog == .nil then return .InstitutionalPolicyResult~failure("POLICY_CATALOG_REQUIRED")
  if catalog~hasMethod("EXECUTIONCONTEXT") = .false then return .InstitutionalPolicyResult~failure("POLICY_CATALOG_PROTOCOL_INVALID", "EXECUTIONCONTEXT")
  return catalog~executionContext(policyId, actionTime)
::method counterfactual class
  use arg policy, actionTime
  validation = self~validatePolicy(policy)
  if validation~ok = .false then return validation
  return .InstitutionalPolicyResult~success(.InstitutionalPolicyExecutionContext~new(policy, actionTime, .InstitutionalPolicyBuild~MODE_COUNTERFACTUAL))

::class InstitutionalPolicyExecutionContext public
::attribute policy get
::attribute actionTime get
::attribute evaluationMode get
::attribute policyIdentity get
::attribute deploymentIdentity get
::method init
  expose policy actionTime evaluationMode policyIdentity deploymentIdentity
  use arg policyArg, actionTimeArg, evaluationModeArg, deploymentStateArg = .nil
  policy = policyArg
  actionTime = actionTimeArg
  evaluationMode = evaluationModeArg~string~upper
  policyIdentity = policyArg~semanticIdentity
  deploymentIdentity = ""
  if deploymentStateArg <> .nil then deploymentIdentity = deploymentStateArg~semanticIdentity
::method canonicalText
  expose policy actionTime evaluationMode policyIdentity deploymentIdentity
  text = .InstitutionalPolicyCanonical~field("POLICY", policy~policyId || "@" || policy~version)
  text ||= .InstitutionalPolicyCanonical~field("ACTION_TIME", actionTime)
  text ||= .InstitutionalPolicyCanonical~field("EVALUATION_MODE", evaluationMode)
  text ||= .InstitutionalPolicyCanonical~field("POLICY_IDENTITY", policyIdentity)
  text ||= .InstitutionalPolicyCanonical~field("DEPLOYMENT_IDENTITY", deploymentIdentity)
  return text

::class InstitutionalPolicyComparison public
::attribute fromPolicyRef get
::attribute toPolicyRef get
::attribute outcomeChanged get
::attribute traceChanged get
::attribute fromOutcomeIdentity get
::attribute toOutcomeIdentity get
::attribute fromTraceIdentity get
::attribute toTraceIdentity get
::method init
  expose fromPolicyRef toPolicyRef outcomeChanged traceChanged fromOutcomeIdentity toOutcomeIdentity fromTraceIdentity toTraceIdentity
  use arg fromPolicy, toPolicy, fromOutcomeIdentityArg, toOutcomeIdentityArg, fromTraceIdentityArg = "", toTraceIdentityArg = ""
  fromPolicyRef = fromPolicy~policyId || "@" || fromPolicy~version
  toPolicyRef = toPolicy~policyId || "@" || toPolicy~version
  fromOutcomeIdentity = fromOutcomeIdentityArg~string
  toOutcomeIdentity = toOutcomeIdentityArg~string
  fromTraceIdentity = fromTraceIdentityArg~string
  toTraceIdentity = toTraceIdentityArg~string
  outcomeChanged = fromOutcomeIdentity <> toOutcomeIdentity
  traceChanged = fromTraceIdentity <> toTraceIdentity
::method canonicalText
  expose fromPolicyRef toPolicyRef outcomeChanged traceChanged fromOutcomeIdentity toOutcomeIdentity fromTraceIdentity toTraceIdentity
  text = .InstitutionalPolicyCanonical~field("FROM_POLICY", fromPolicyRef)
  text ||= .InstitutionalPolicyCanonical~field("TO_POLICY", toPolicyRef)
  text ||= .InstitutionalPolicyCanonical~field("FROM_OUTCOME", fromOutcomeIdentity)
  text ||= .InstitutionalPolicyCanonical~field("TO_OUTCOME", toOutcomeIdentity)
  text ||= .InstitutionalPolicyCanonical~field("FROM_TRACE", fromTraceIdentity)
  text ||= .InstitutionalPolicyCanonical~field("TO_TRACE", toTraceIdentity)
  text ||= .InstitutionalPolicyCanonical~field("OUTCOME_CHANGED", outcomeChanged)
  text ||= .InstitutionalPolicyCanonical~field("TRACE_CHANGED", traceChanged)
  return text

::requires 'AlchemyObject.cls'
