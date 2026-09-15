/*
 * Regulated Intermediary Distribution v0.4
 *
 * Product-neutral regulated distribution domain.  It owns intermediary
 * distribution authority, exact product references and the regulated sales /
 * application journey.  It does not own provider product terms, underwriting,
 * investment execution, insurance binding, customer money or customer master.
 */

::class RIDBuild public
::constant VERSION "0.5"
::constant API_VERSION "regulated.intermediary.distribution/0.5"
::constant PRODUCT "ooRexx Regulated Intermediary Distribution"

::class RIDResult public
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
  use arg valueArg = .nil, detailArg = ""
  return self~new(.true, "OK", detailArg, valueArg)
::method failure class
  use arg codeArg, detailArg = "", valueArg = .nil
  return self~new(.false, codeArg, detailArg, valueArg)

::class RIDCanonical public
::method token class
  use arg value
  if value == .nil then return ""
  return value~string~strip~upper
::method required class
  use arg name, value
  if value == .nil then raise syntax 88.980 array(name || " is required")
  text = value~string~strip
  if text = "" then raise syntax 88.980 array(name || " is required")
  return text
::method match class
  use arg pattern, value
  p = self~token(pattern)
  if p = "*" then return .true
  return p = self~token(value)
::method contains class
  use arg source, wanted
  wanted = self~token(wanted)
  if source == .nil then return .false
  do item over source
    if self~token(item) = wanted then return .true
  end
  return .false
::method copyArray class
  use arg source
  out = .array~new
  if source == .nil then return out
  do item over source; out~append(item); end
  return out
::method addUniqueToken class
  use arg target, value
  token = self~token(value)
  if token = "" then return target
  if \self~contains(target, token) then target~append(token)
  return target
::method specificity class
  use arg values
  score = 0
  do v over values
    if self~token(v) <> "*" then score += 1
  end
  return score
::method field class
  use arg value
  if value == .nil then text = ""
  else text = value~string
  return text~length || ":" || text

::class RIDProviderIdentity public
::attribute legalEntityId get
::attribute providerSystem get
::attribute groupOwnerRef get
::attribute evidenceRef get
::method init
  expose legalEntityId providerSystem groupOwnerRef evidenceRef
  use arg legalEntityIdArg, providerSystemArg, groupOwnerRefArg = "", evidenceRefArg = ""
  legalEntityId = .RIDCanonical~required("legalEntityId", legalEntityIdArg)~upper
  providerSystem = .RIDCanonical~required("providerSystem", providerSystemArg)~upper
  groupOwnerRef = groupOwnerRefArg~string
  evidenceRef = evidenceRefArg~string
::method authorityKey
  expose legalEntityId providerSystem
  return legalEntityId || "|" || providerSystem

::class RIDProductReference public
::attribute productRefId get
::attribute providerIdentity get
::attribute productId get
::attribute productVersion get
::attribute productSemanticIdentity get
::attribute productFamily get
::attribute jurisdiction get
::attribute regulatoryClass get
::attribute sourceRef get
::method init
  expose productRefId providerIdentity productId productVersion productSemanticIdentity productFamily jurisdiction regulatoryClass sourceRef
  use arg productRefIdArg, providerIdentityArg, productIdArg, productVersionArg, productSemanticIdentityArg, productFamilyArg, jurisdictionArg, regulatoryClassArg = "", sourceRefArg = ""
  productRefId = .RIDCanonical~required("productRefId", productRefIdArg)~upper
  if providerIdentityArg == .nil then raise syntax 88.981 array("providerIdentity must be RIDProviderIdentity")
  if \providerIdentityArg~isA(.RIDProviderIdentity) then raise syntax 88.981 array("providerIdentity must be RIDProviderIdentity")
  providerIdentity = providerIdentityArg
  productId = .RIDCanonical~required("productId", productIdArg)
  productVersion = .RIDCanonical~required("productVersion", productVersionArg)
  productSemanticIdentity = .RIDCanonical~required("productSemanticIdentity", productSemanticIdentityArg)
  productFamily = .RIDCanonical~required("productFamily", productFamilyArg)~upper
  jurisdiction = .RIDCanonical~required("jurisdiction", jurisdictionArg)~upper
  regulatoryClass = regulatoryClassArg~string~upper
  sourceRef = sourceRefArg~string
::method exactIdentity
  expose providerIdentity productId productVersion productSemanticIdentity jurisdiction
  return providerIdentity~authorityKey || "|" || jurisdiction || "|" || productId || "|" || productVersion || "|" || productSemanticIdentity

::class RIDProductDistributionApproval public
::attribute approvalId get
::attribute productRefId get
::attribute productSemanticIdentity get
::attribute effectiveFrom get
::attribute effectiveUntil get
::attribute policyId get
::attribute policyVersion get
::attribute policyIdentity get
::attribute evidenceRef get
::method init
  expose approvalId productRefId productSemanticIdentity effectiveFrom effectiveUntil policyId policyVersion policyIdentity evidenceRef activities adviceModes
  use arg approvalIdArg, productRefIdArg, productSemanticIdentityArg, effectiveFromArg = .nil, effectiveUntilArg = .nil, policyIdArg = "", policyVersionArg = "", policyIdentityArg = "", evidenceRefArg = ""
  approvalId = .RIDCanonical~required("approvalId", approvalIdArg)~upper
  productRefId = .RIDCanonical~required("productRefId", productRefIdArg)~upper
  productSemanticIdentity = .RIDCanonical~required("productSemanticIdentity", productSemanticIdentityArg)
  if effectiveFromArg == .nil then effectiveFrom = .DateTime~new
  else effectiveFrom = effectiveFromArg
  effectiveUntil = effectiveUntilArg
  policyId = policyIdArg~string~upper
  policyVersion = policyVersionArg~string
  policyIdentity = policyIdentityArg~string
  evidenceRef = evidenceRefArg~string
  activities = .array~new
  adviceModes = .array~new
::method allowActivity
  expose activities
  use arg activity
  .RIDCanonical~addUniqueToken(activities, activity)
  return self
::method allowAdviceMode
  expose adviceModes
  use arg mode
  .RIDCanonical~addUniqueToken(adviceModes, mode)
  return self
::method activities
  expose activities
  return .RIDCanonical~copyArray(activities)
::method adviceModes
  expose adviceModes
  return .RIDCanonical~copyArray(adviceModes)
::method activeAt
  expose effectiveFrom effectiveUntil
  use arg moment
  if moment < effectiveFrom then return .false
  if effectiveUntil == .nil then return .true
  if effectiveUntil~string = "" then return .true
  return moment < effectiveUntil
::method permits
  expose activities adviceModes
  use arg activity, adviceMode, moment
  if \self~activeAt(moment) then return .false
  if \.RIDCanonical~contains(activities, activity) then return .false
  if adviceModes~items = 0 then return .true
  return .RIDCanonical~contains(adviceModes, adviceMode)

::class RIDIntermediaryFirm public
::attribute firmId get
::attribute legalEntityRef get
::attribute regulatorRef get
::attribute status get
::method init
  expose firmId legalEntityRef regulatorRef status
  use arg firmIdArg, legalEntityRefArg, regulatorRefArg = "", statusArg = "ACTIVE"
  firmId = .RIDCanonical~required("firmId", firmIdArg)~upper
  legalEntityRef = .RIDCanonical~required("legalEntityRef", legalEntityRefArg)
  regulatorRef = regulatorRefArg~string
  status = .RIDCanonical~token(statusArg)
::method setStatus package
  expose status
  use arg statusArg
  status = .RIDCanonical~token(statusArg)
  return status

::class RIDIntermediaryRepresentative public
::attribute representativeId get
::attribute firmId get
::attribute identityRef get
::attribute status get
::method init
  expose representativeId firmId identityRef status
  use arg representativeIdArg, firmIdArg, identityRefArg, statusArg = "ACTIVE"
  representativeId = .RIDCanonical~required("representativeId", representativeIdArg)~upper
  firmId = .RIDCanonical~required("firmId", firmIdArg)~upper
  identityRef = .RIDCanonical~required("identityRef", identityRefArg)
  status = .RIDCanonical~token(statusArg)
::method setStatus package
  expose status
  use arg statusArg
  status = .RIDCanonical~token(statusArg)
  return status

::class RIDIntermediaryRegistry public
::method init
  expose firms reps
  firms = .directory~new
  reps = .directory~new
::method registerFirm
  expose firms
  use arg firm
  if firm == .nil then return .RIDResult~failure("INVALID_FIRM")
  if \firm~isA(.RIDIntermediaryFirm) then return .RIDResult~failure("INVALID_FIRM")
  if firms[firm~firmId] <> .nil then return .RIDResult~failure("FIRM_EXISTS")
  firms[firm~firmId] = firm
  return .RIDResult~success(firm)
::method registerRepresentative
  expose firms reps
  use arg rep
  if rep == .nil then return .RIDResult~failure("INVALID_REPRESENTATIVE")
  if \rep~isA(.RIDIntermediaryRepresentative) then return .RIDResult~failure("INVALID_REPRESENTATIVE")
  if firms[rep~firmId] == .nil then return .RIDResult~failure("UNKNOWN_FIRM")
  if reps[rep~representativeId] <> .nil then return .RIDResult~failure("REPRESENTATIVE_EXISTS")
  reps[rep~representativeId] = rep
  return .RIDResult~success(rep)
::method firm
  expose firms
  use arg firmId
  return firms[.RIDCanonical~token(firmId)]
::method representative
  expose reps
  use arg representativeId
  return reps[.RIDCanonical~token(representativeId)]
::method setFirmStatus
  f = self~firm(arg(1))
  if f == .nil then return .RIDResult~failure("UNKNOWN_FIRM")
  f~setStatus(arg(2))
  return .RIDResult~success(f)
::method setRepresentativeStatus
  r = self~representative(arg(1))
  if r == .nil then return .RIDResult~failure("UNKNOWN_REPRESENTATIVE")
  r~setStatus(arg(2))
  return .RIDResult~success(r)
::method activePair
  use arg firmId, representativeId
  f = self~firm(firmId)
  if f == .nil then return .RIDResult~failure("UNKNOWN_FIRM")
  r = self~representative(representativeId)
  if r == .nil then return .RIDResult~failure("UNKNOWN_REPRESENTATIVE")
  if r~firmId <> f~firmId then return .RIDResult~failure("REPRESENTATIVE_FIRM_MISMATCH")
  if f~status <> "ACTIVE" then return .RIDResult~failure("FIRM_NOT_ACTIVE")
  if r~status <> "ACTIVE" then return .RIDResult~failure("REPRESENTATIVE_NOT_ACTIVE")
  return .RIDResult~success(r)

::class RIDAuthorityGrant public
::attribute grantId get
::attribute authorityClass get
::attribute principalKind get
::attribute principalId get
::attribute firmId get
::attribute jurisdiction get
::attribute productFamily get
::attribute activity get
::attribute effectiveFrom get
::attribute effectiveUntil get
::attribute sourceSystem get
::attribute sourceRef get
::method init
  expose grantId authorityClass principalKind principalId firmId jurisdiction productFamily activity effectiveFrom effectiveUntil sourceSystem sourceRef
  use arg grantIdArg, authorityClassArg, principalKindArg, principalIdArg, firmIdArg, jurisdictionArg, productFamilyArg, activityArg, effectiveFromArg = .nil, effectiveUntilArg = .nil, sourceSystemArg = "", sourceRefArg = ""
  grantId = .RIDCanonical~required("grantId", grantIdArg)~upper
  authorityClass = .RIDCanonical~required("authorityClass", authorityClassArg)~upper
  principalKind = .RIDCanonical~required("principalKind", principalKindArg)~upper
  principalId = .RIDCanonical~required("principalId", principalIdArg)~upper
  firmId = firmIdArg~string~upper
  jurisdiction = .RIDCanonical~required("jurisdiction", jurisdictionArg)~upper
  productFamily = .RIDCanonical~required("productFamily", productFamilyArg)~upper
  activity = .RIDCanonical~required("activity", activityArg)~upper
  if effectiveFromArg == .nil then effectiveFrom = .DateTime~new
  else effectiveFrom = effectiveFromArg
  effectiveUntil = effectiveUntilArg
  sourceSystem = .RIDCanonical~required("sourceSystem", sourceSystemArg)~upper
  sourceRef = .RIDCanonical~required("sourceRef", sourceRefArg)
::method activeAt
  expose effectiveFrom effectiveUntil
  use arg moment
  if moment < effectiveFrom then return .false
  if effectiveUntil == .nil then return .true
  if effectiveUntil~string = "" then return .true
  return moment < effectiveUntil
::method matches
  expose authorityClass principalKind principalId firmId jurisdiction productFamily activity
  use arg authorityClassArg, principalKindArg, principalIdArg, firmIdArg, jurisdictionArg, productFamilyArg, activityArg, moment
  if \self~activeAt(moment) then return .false
  if \.RIDCanonical~match(authorityClass, authorityClassArg) then return .false
  if \.RIDCanonical~match(principalKind, principalKindArg) then return .false
  if \.RIDCanonical~match(principalId, principalIdArg) then return .false
  if firmId <> "" then if \.RIDCanonical~match(firmId, firmIdArg) then return .false
  if \.RIDCanonical~match(jurisdiction, jurisdictionArg) then return .false
  if \.RIDCanonical~match(productFamily, productFamilyArg) then return .false
  if \.RIDCanonical~match(activity, activityArg) then return .false
  return .true

::class RIDAuthorityControlEvent public
::attribute controlId get
::attribute grantId get
::attribute state get
::attribute effectiveAt get
::attribute sourceSystem get
::attribute sourceRef get
::method init
  expose controlId grantId state effectiveAt sourceSystem sourceRef
  use arg controlIdArg, grantIdArg, stateArg, effectiveAtArg = .nil, sourceSystemArg = "", sourceRefArg = ""
  controlId = .RIDCanonical~required("controlId", controlIdArg)~upper
  grantId = .RIDCanonical~required("grantId", grantIdArg)~upper
  state = .RIDCanonical~required("state", stateArg)~upper
  if state <> "ACTIVE" & state <> "SUSPENDED" & state <> "REVOKED" then raise syntax 88.982 array("Invalid authority control state")
  if effectiveAtArg == .nil then effectiveAt = .DateTime~new
  else effectiveAt = effectiveAtArg
  sourceSystem = .RIDCanonical~required("sourceSystem", sourceSystemArg)~upper
  sourceRef = .RIDCanonical~required("sourceRef", sourceRefArg)

::class RIDAuthorityRegistry public
::method init
  expose grants controls
  grants = .directory~new
  controls = .array~new
::method addGrant
  expose grants
  use arg grant
  if grant == .nil then return .RIDResult~failure("INVALID_AUTHORITY_GRANT")
  if \grant~isA(.RIDAuthorityGrant) then return .RIDResult~failure("INVALID_AUTHORITY_GRANT")
  if grants[grant~grantId] <> .nil then return .RIDResult~failure("GRANT_EXISTS")
  grants[grant~grantId] = grant
  return .RIDResult~success(grant)
::method addControl
  expose grants controls
  use arg control
  if control == .nil then return .RIDResult~failure("INVALID_AUTHORITY_CONTROL")
  if \control~isA(.RIDAuthorityControlEvent) then return .RIDResult~failure("INVALID_AUTHORITY_CONTROL")
  if grants[control~grantId] == .nil then return .RIDResult~failure("UNKNOWN_GRANT")
  controls~append(control)
  return .RIDResult~success(control)
::method currentStateFor private
  expose controls
  use arg grantId, moment
  state = "ACTIVE"
  latest = .nil
  do c over controls
    if c~grantId = grantId & c~effectiveAt <= moment then do
      if latest == .nil then do
        latest = c~effectiveAt
        state = c~state
      end
      else if c~effectiveAt >= latest then do
        latest = c~effectiveAt
        state = c~state
      end
    end
  end
  return state
::method hasAuthority
  expose grants
  use arg authorityClass, principalKind, principalId, firmId, jurisdiction, productFamily, activity, moment
  do id over grants~allIndexes
    g = grants[id]
    if g~matches(authorityClass, principalKind, principalId, firmId, jurisdiction, productFamily, activity, moment) then do
      if self~currentStateFor(g~grantId, moment) = "ACTIVE" then return .true
    end
  end
  return .false

::class RIDAuthorityRequirement public
::attribute requirementId get
::attribute authorityClass get
::attribute principalKind get
::method init
  expose requirementId authorityClass principalKind
  use arg requirementIdArg, authorityClassArg, principalKindArg
  requirementId = .RIDCanonical~required("requirementId", requirementIdArg)~upper
  authorityClass = .RIDCanonical~required("authorityClass", authorityClassArg)~upper
  principalKind = .RIDCanonical~required("principalKind", principalKindArg)~upper

::class RIDEvidenceReference public
::attribute evidenceId get
::attribute evidenceType get
::attribute semanticKind get
::attribute sourceSystem get
::attribute sourceRef get
::attribute authorityClass get
::attribute recordedAt get
::attribute visibilityClass get
::attribute productSemanticIdentity get
::method init
  expose evidenceId evidenceType semanticKind sourceSystem sourceRef authorityClass recordedAt visibilityClass productSemanticIdentity
  use arg evidenceIdArg, evidenceTypeArg, semanticKindArg, sourceSystemArg, sourceRefArg, authorityClassArg = "EVIDENCE", recordedAtArg = .nil, visibilityClassArg = "INTERNAL", productSemanticIdentityArg = ""
  evidenceId = .RIDCanonical~required("evidenceId", evidenceIdArg)~upper
  evidenceType = .RIDCanonical~required("evidenceType", evidenceTypeArg)~upper
  semanticKind = .RIDCanonical~required("semanticKind", semanticKindArg)~upper
  sourceSystem = .RIDCanonical~required("sourceSystem", sourceSystemArg)~upper
  sourceRef = .RIDCanonical~required("sourceRef", sourceRefArg)
  authorityClass = .RIDCanonical~token(authorityClassArg)
  if recordedAtArg == .nil then recordedAt = .DateTime~new
  else recordedAt = recordedAtArg
  visibilityClass = .RIDCanonical~token(visibilityClassArg)
  productSemanticIdentity = productSemanticIdentityArg~string

::class RIDActionRule public
::attribute ruleId get
::attribute productFamily get
::attribute adviceMode get
::attribute fromState get
::attribute action get
::attribute targetState get
::attribute activity get
::method init
  expose ruleId productFamily adviceMode fromState action targetState activity evidenceRequirements authorityRequirements
  use arg ruleIdArg, productFamilyArg, adviceModeArg, fromStateArg, actionArg, targetStateArg, activityArg = ""
  ruleId = .RIDCanonical~required("ruleId", ruleIdArg)~upper
  productFamily = .RIDCanonical~required("productFamily", productFamilyArg)~upper
  adviceMode = .RIDCanonical~required("adviceMode", adviceModeArg)~upper
  fromState = .RIDCanonical~required("fromState", fromStateArg)~upper
  action = .RIDCanonical~required("action", actionArg)~upper
  targetState = .RIDCanonical~required("targetState", targetStateArg)~upper
  activity = .RIDCanonical~token(activityArg)
  evidenceRequirements = .array~new
  authorityRequirements = .array~new
::method requireEvidence
  expose evidenceRequirements
  use arg evidenceType
  .RIDCanonical~addUniqueToken(evidenceRequirements, evidenceType)
  return self
::method requireAuthority
  expose authorityRequirements
  use arg requirement
  if requirement == .nil then raise syntax 88.983 array("requireAuthority needs RIDAuthorityRequirement")
  if \requirement~isA(.RIDAuthorityRequirement) then raise syntax 88.983 array("requireAuthority needs RIDAuthorityRequirement")
  authorityRequirements~append(requirement)
  return self
::method evidenceRequirements
  expose evidenceRequirements
  return .RIDCanonical~copyArray(evidenceRequirements)
::method authorityRequirements
  expose authorityRequirements
  return .RIDCanonical~copyArray(authorityRequirements)
::method matches
  expose productFamily adviceMode fromState action
  use arg productFamilyArg, adviceModeArg, fromStateArg, actionArg
  return .RIDCanonical~match(productFamily, productFamilyArg) & .RIDCanonical~match(adviceMode, adviceModeArg) & .RIDCanonical~match(fromState, fromStateArg) & .RIDCanonical~match(action, actionArg)
::method specificity
  expose productFamily adviceMode fromState action
  a = .array~of(productFamily, adviceMode, fromState, action)
  return .RIDCanonical~specificity(a)

::class RIDDistributionPolicy public
::attribute policyId get
::attribute version get
::attribute semanticIdentity get
::attribute sealed get
::method init
  expose policyId version semanticIdentity sealed rules
  use arg policyIdArg, versionArg, semanticIdentityArg
  policyId = .RIDCanonical~required("policyId", policyIdArg)~upper
  version = .RIDCanonical~required("version", versionArg)
  semanticIdentity = .RIDCanonical~required("semanticIdentity", semanticIdentityArg)
  sealed = .false
  rules = .array~new
::method addRule
  expose rules sealed
  use arg rule
  if sealed then raise syntax 88.984 array("Policy is sealed")
  if rule == .nil then raise syntax 88.984 array("Invalid action rule")
  if \rule~isA(.RIDActionRule) then raise syntax 88.984 array("Invalid action rule")
  rules~append(rule)
  return self
::method seal
  expose sealed
  sealed = .true
  return self
::method resolve
  expose rules sealed
  use arg productFamily, adviceMode, fromState, action
  if \sealed then return .RIDResult~failure("POLICY_NOT_SEALED")
  best = .nil; score = -1
  do r over rules
    if r~matches(productFamily, adviceMode, fromState, action) then do
      s = r~specificity
      if s > score then do; best = r; score = s; end
      else if s = score then return .RIDResult~failure("AMBIGUOUS_POLICY_RULE")
    end
  end
  if best == .nil then return .RIDResult~failure("NO_POLICY_RULE")
  return .RIDResult~success(best)

::class RIDProviderStatusEvidence public
::attribute eventId get
::attribute providerEntityId get
::attribute providerSystem get
::attribute providerCaseRef get
::attribute productSemanticIdentity get
::attribute sequence get
::attribute status get
::attribute occurredAt get
::attribute sourceRef get
::method init
  expose eventId providerEntityId providerSystem providerCaseRef productSemanticIdentity sequence status occurredAt sourceRef
  use arg eventIdArg, providerEntityIdArg, providerSystemArg, providerCaseRefArg, productSemanticIdentityArg, sequenceArg, statusArg, occurredAtArg = .nil, sourceRefArg = ""
  eventId = .RIDCanonical~required("eventId", eventIdArg)~upper
  providerEntityId = .RIDCanonical~required("providerEntityId", providerEntityIdArg)~upper
  providerSystem = .RIDCanonical~required("providerSystem", providerSystemArg)~upper
  providerCaseRef = .RIDCanonical~required("providerCaseRef", providerCaseRefArg)
  productSemanticIdentity = .RIDCanonical~required("productSemanticIdentity", productSemanticIdentityArg)
  sequence = sequenceArg + 0
  if sequence < 1 then raise syntax 88.985 array("provider sequence must be >= 1")
  status = .RIDCanonical~required("status", statusArg)~upper
  if occurredAtArg == .nil then occurredAt = .DateTime~new
  else occurredAt = occurredAtArg
  sourceRef = .RIDCanonical~required("sourceRef", sourceRefArg)
::method canonicalMessage
  expose eventId providerEntityId providerSystem providerCaseRef productSemanticIdentity sequence status occurredAt sourceRef
  return "RID_PROVIDER_STATUS/1|" ||,
    .RIDCanonical~field(eventId) || .RIDCanonical~field(providerEntityId) || .RIDCanonical~field(providerSystem) ||,
    .RIDCanonical~field(providerCaseRef) || .RIDCanonical~field(productSemanticIdentity) || .RIDCanonical~field(sequence) ||,
    .RIDCanonical~field(status) || .RIDCanonical~field(occurredAt~string) || .RIDCanonical~field(sourceRef)

::class RIDCaseEvent public
::attribute eventId get
::attribute eventType get
::attribute caseId get
::attribute actorId get
::attribute actorRole get
::attribute occurredAt get
::attribute fromState get
::attribute toState get
::attribute policyId get
::attribute policyVersion get
::attribute policyIdentity get
::attribute policyRuleId get
::attribute evidenceRef get
::method init
  expose eventId eventType caseId actorId actorRole occurredAt fromState toState policyId policyVersion policyIdentity policyRuleId evidenceRef
  use arg eventIdArg, eventTypeArg, caseIdArg, actorIdArg, actorRoleArg, occurredAtArg, fromStateArg = "", toStateArg = "", policyIdArg = "", policyVersionArg = "", policyIdentityArg = "", policyRuleIdArg = "", evidenceRefArg = ""
  eventId = eventIdArg~string~upper
  eventType = eventTypeArg~string~upper
  caseId = caseIdArg~string~upper
  actorId = actorIdArg~string
  actorRole = actorRoleArg~string~upper
  occurredAt = occurredAtArg
  fromState = fromStateArg~string~upper
  toState = toStateArg~string~upper
  policyId = policyIdArg~string~upper
  policyVersion = policyVersionArg~string
  policyIdentity = policyIdentityArg~string
  policyRuleId = policyRuleIdArg~string~upper
  evidenceRef = evidenceRefArg~string

::class RIDDistributionCase public
::attribute caseId get
::attribute subjectRef get
::attribute firmId get
::attribute representativeId get
::attribute productRefId get
::attribute productSemanticIdentity get
::attribute adviceMode get
::attribute jurisdiction get
::attribute state get
::attribute openedAt get
::attribute updatedAt get
::attribute providerCaseRef get
::attribute providerStatus get
::attribute providerSequence get
::attribute providerEventId get
::method init
  expose caseId subjectRef firmId representativeId productRefId productSemanticIdentity adviceMode jurisdiction state openedAt updatedAt providerCaseRef providerStatus providerSequence providerEventId evidences events providerEventFingerprints providerSequenceEvents providerHistory
  use arg caseIdArg, subjectRefArg, firmIdArg, representativeIdArg, productRefIdArg, productSemanticIdentityArg, adviceModeArg, jurisdictionArg, openedAtArg = .nil
  caseId = .RIDCanonical~required("caseId", caseIdArg)~upper
  subjectRef = .RIDCanonical~required("subjectRef", subjectRefArg)
  firmId = .RIDCanonical~required("firmId", firmIdArg)~upper
  representativeId = .RIDCanonical~required("representativeId", representativeIdArg)~upper
  productRefId = .RIDCanonical~required("productRefId", productRefIdArg)~upper
  productSemanticIdentity = .RIDCanonical~required("productSemanticIdentity", productSemanticIdentityArg)
  adviceMode = .RIDCanonical~required("adviceMode", adviceModeArg)~upper
  jurisdiction = .RIDCanonical~required("jurisdiction", jurisdictionArg)~upper
  state = "OPEN"
  if openedAtArg == .nil then openedAt = .DateTime~new
  else openedAt = openedAtArg
  updatedAt = openedAt
  providerCaseRef = ""
  providerStatus = "NOT_SUBMITTED"
  providerSequence = 0
  providerEventId = ""
  providerEventFingerprints = .directory~new
  providerSequenceEvents = .directory~new
  providerHistory = .array~new
  evidences = .array~new
  events = .array~new
::method evidence
  expose evidences
  use arg evidenceId
  wanted = .RIDCanonical~token(evidenceId)
  do e over evidences
    if e~evidenceId = wanted then return e
  end
  return .nil
::method hasEvidenceType
  expose evidences
  use arg evidenceType
  wanted = .RIDCanonical~token(evidenceType)
  do e over evidences
    if e~evidenceType = wanted then return .true
  end
  return .false
::method attachEvidence package
  expose evidences updatedAt productSemanticIdentity
  use arg evidence
  if self~evidence(evidence~evidenceId) <> .nil then return .RIDResult~failure("EVIDENCE_EXISTS")
  if evidence~productSemanticIdentity <> "" then do
    if evidence~productSemanticIdentity <> productSemanticIdentity then return .RIDResult~failure("EVIDENCE_PRODUCT_IDENTITY_MISMATCH")
  end
  evidences~append(evidence)
  updatedAt = evidence~recordedAt
  return .RIDResult~success(evidence)
::method evidences
  expose evidences
  return .RIDCanonical~copyArray(evidences)
::method appendEvent package
  expose events
  use arg event
  events~append(event)
  return event
::method events
  expose events
  return .RIDCanonical~copyArray(events)
::method applyState package
  expose state updatedAt
  use arg newState, atTime
  state = .RIDCanonical~token(newState)
  updatedAt = atTime
  return state
::method providerEventFingerprint
  expose providerEventFingerprints
  use arg eventId
  value = providerEventFingerprints[.RIDCanonical~token(eventId)]
  if value == .nil then return ""
  return value~string
::method providerEventAtSequence
  expose providerSequenceEvents
  use arg sequence
  value = providerSequenceEvents[sequence~string]
  if value == .nil then return ""
  return value~string
::method registerProviderEvent package
  expose providerEventFingerprints providerSequenceEvents providerHistory
  use arg evidence
  providerEventFingerprints[evidence~eventId] = evidence~canonicalMessage
  providerSequenceEvents[evidence~sequence~string] = evidence~eventId
  providerHistory~append(evidence)
  return evidence~eventId
::method providerStatusHistory
  expose providerHistory
  return .RIDCanonical~copyArray(providerHistory)
::method applyProviderStatus package
  expose providerCaseRef providerStatus providerSequence providerEventId updatedAt
  use arg evidence
  providerCaseRef = evidence~providerCaseRef
  providerStatus = evidence~status
  providerSequence = evidence~sequence
  providerEventId = evidence~eventId
  updatedAt = evidence~occurredAt
  return providerStatus

::class RIDDistributionCatalog public
::method init
  expose products approvals
  products = .directory~new
  approvals = .directory~new
::method addProduct
  expose products
  use arg product
  if product == .nil then return .RIDResult~failure("INVALID_PRODUCT")
  if \product~isA(.RIDProductReference) then return .RIDResult~failure("INVALID_PRODUCT")
  if products[product~productRefId] <> .nil then return .RIDResult~failure("PRODUCT_REF_EXISTS")
  products[product~productRefId] = product
  return .RIDResult~success(product)
::method approveProduct
  expose products approvals
  use arg approval
  if approval == .nil then return .RIDResult~failure("INVALID_PRODUCT_APPROVAL")
  if \approval~isA(.RIDProductDistributionApproval) then return .RIDResult~failure("INVALID_PRODUCT_APPROVAL")
  p = products[approval~productRefId]
  if p == .nil then return .RIDResult~failure("UNKNOWN_PRODUCT")
  if p~productSemanticIdentity <> approval~productSemanticIdentity then return .RIDResult~failure("APPROVAL_PRODUCT_IDENTITY_MISMATCH")
  approvals[approval~productRefId] = approval
  return .RIDResult~success(approval)
::method product
  expose products
  use arg productRefId
  return products[.RIDCanonical~token(productRefId)]
::method approval
  expose approvals
  use arg productRefId
  return approvals[.RIDCanonical~token(productRefId)]

::class RIDDistributionEngine public
::method init
  expose intermediaryRegistry authorityRegistry catalog policy cases eventSequence
  use arg intermediaryRegistryArg, authorityRegistryArg, catalogArg, policyArg
  intermediaryRegistry = intermediaryRegistryArg
  authorityRegistry = authorityRegistryArg
  catalog = catalogArg
  policy = policyArg
  cases = .directory~new
  eventSequence = 0
::method nextEventId private
  expose eventSequence
  eventSequence += 1
  return "RID-EVT-" || eventSequence~format(6,0)
::method case
  expose cases
  use arg caseId
  return cases[.RIDCanonical~token(caseId)]
::method openCase
  expose intermediaryRegistry catalog cases policy
  use arg caseId, subjectRef, firmId, representativeId, productRefId, adviceMode, actorId, actorRole, atTime = .nil
  if atTime == .nil then atTime = .DateTime~new
  if cases[.RIDCanonical~token(caseId)] <> .nil then return .RIDResult~failure("CASE_EXISTS")
  pair = intermediaryRegistry~activePair(firmId, representativeId)
  if \pair~ok then return pair
  p = catalog~product(productRefId)
  if p == .nil then return .RIDResult~failure("UNKNOWN_PRODUCT")
  a = catalog~approval(productRefId)
  if a == .nil then return .RIDResult~failure("PRODUCT_NOT_APPROVED_FOR_DISTRIBUTION")
  if \a~activeAt(atTime) then return .RIDResult~failure("PRODUCT_DISTRIBUTION_APPROVAL_NOT_ACTIVE")
  if a~adviceModes~items > 0 then if \.RIDCanonical~contains(a~adviceModes, adviceMode) then return .RIDResult~failure("ADVICE_MODE_NOT_APPROVED")
  c = .RIDDistributionCase~new(caseId, subjectRef, firmId, representativeId, p~productRefId, p~productSemanticIdentity, adviceMode, p~jurisdiction, atTime)
  e = .RIDCaseEvent~new(self~nextEventId, "CASE_OPENED", c~caseId, actorId, actorRole, atTime, "", c~state, policy~policyId, policy~version, policy~semanticIdentity, "")
  c~appendEvent(e)
  cases[c~caseId] = c
  return .RIDResult~success(c)
::method attachEvidence
  c = self~case(arg(1))
  if c == .nil then return .RIDResult~failure("UNKNOWN_CASE")
  evidence = arg(2)
  if evidence == .nil then return .RIDResult~failure("INVALID_EVIDENCE")
  if \evidence~isA(.RIDEvidenceReference) then return .RIDResult~failure("INVALID_EVIDENCE")
  r = c~attachEvidence(evidence)
  if \r~ok then return r
  atTime = evidence~recordedAt
  ev = .RIDCaseEvent~new(self~nextEventId, "EVIDENCE_ATTACHED", c~caseId, arg(3), arg(4), atTime, c~state, c~state, "", "", "", "", evidence~evidenceId)
  c~appendEvent(ev)
  return .RIDResult~success(evidence)
::method act
  expose intermediaryRegistry authorityRegistry catalog policy
  use arg caseId, action, actorId, actorRole, atTime = .nil
  if atTime == .nil then atTime = .DateTime~new
  c = self~case(caseId)
  if c == .nil then return .RIDResult~failure("UNKNOWN_CASE")
  pair = intermediaryRegistry~activePair(c~firmId, c~representativeId)
  if \pair~ok then return pair
  p = catalog~product(c~productRefId)
  if p == .nil then return .RIDResult~failure("UNKNOWN_PRODUCT")
  a = catalog~approval(c~productRefId)
  if a == .nil then return .RIDResult~failure("PRODUCT_NOT_APPROVED_FOR_DISTRIBUTION")
  rr = policy~resolve(p~productFamily, c~adviceMode, c~state, action)
  if \rr~ok then return rr
  rule = rr~value
  if rule~activity <> "" then do
    if \a~permits(rule~activity, c~adviceMode, atTime) then return .RIDResult~failure("PRODUCT_ACTIVITY_NOT_APPROVED", rule~activity)
  end
  do req over rule~authorityRequirements
    select
      when req~principalKind = "FIRM" then principalId = c~firmId
      when req~principalKind = "REPRESENTATIVE" then principalId = c~representativeId
      otherwise return .RIDResult~failure("INVALID_AUTHORITY_REQUIREMENT", req~requirementId)
    end
    if \authorityRegistry~hasAuthority(req~authorityClass, req~principalKind, principalId, c~firmId, c~jurisdiction, p~productFamily, rule~activity, atTime) then return .RIDResult~failure("AUTHORITY_MISSING", req~requirementId)
  end
  do evidenceType over rule~evidenceRequirements
    if \c~hasEvidenceType(evidenceType) then return .RIDResult~failure("REQUIRED_EVIDENCE_MISSING", evidenceType)
  end
  fromState = c~state
  c~applyState(rule~targetState, atTime)
  e = .RIDCaseEvent~new(self~nextEventId, "CASE_ACTION", c~caseId, actorId, actorRole, atTime, fromState, c~state, policy~policyId, policy~version, policy~semanticIdentity, rule~ruleId)
  c~appendEvent(e)
  return .RIDResult~success(c)
::method recordProviderStatus
  expose catalog
  use arg caseId, statusEvidence, actorId = "PROVIDER_ADAPTER", actorRole = "SYSTEM"
  c = self~case(caseId)
  if c == .nil then return .RIDResult~failure("UNKNOWN_CASE")
  if statusEvidence == .nil then return .RIDResult~failure("INVALID_PROVIDER_STATUS_EVIDENCE")
  if \statusEvidence~isA(.RIDProviderStatusEvidence) then return .RIDResult~failure("INVALID_PROVIDER_STATUS_EVIDENCE")
  p = catalog~product(c~productRefId)
  if p == .nil then return .RIDResult~failure("UNKNOWN_PRODUCT")
  provider = p~providerIdentity
  if statusEvidence~providerEntityId <> provider~legalEntityId then return .RIDResult~failure("PROVIDER_ENTITY_MISMATCH")
  if statusEvidence~providerSystem <> provider~providerSystem then return .RIDResult~failure("PROVIDER_SYSTEM_MISMATCH")
  if statusEvidence~productSemanticIdentity <> c~productSemanticIdentity then return .RIDResult~failure("PROVIDER_PRODUCT_IDENTITY_MISMATCH")
  if c~providerCaseRef <> "" then if statusEvidence~providerCaseRef <> c~providerCaseRef then return .RIDResult~failure("PROVIDER_CASE_REF_MISMATCH")
  priorFingerprint = c~providerEventFingerprint(statusEvidence~eventId)
  if priorFingerprint <> "" then do
    if priorFingerprint = statusEvidence~canonicalMessage then return .RIDResult~success(c, "PROVIDER_EVENT_DUPLICATE")
    return .RIDResult~failure("PROVIDER_EVENT_ID_CONFLICT", statusEvidence~eventId)
  end
  priorSequenceEvent = c~providerEventAtSequence(statusEvidence~sequence)
  if priorSequenceEvent <> "" then return .RIDResult~failure("PROVIDER_SEQUENCE_CONFLICT", priorSequenceEvent)
  if statusEvidence~sequence < c~providerSequence then return .RIDResult~failure("STALE_PROVIDER_STATUS")
  c~applyProviderStatus(statusEvidence)
  c~registerProviderEvent(statusEvidence)
  ev = .RIDCaseEvent~new(self~nextEventId, "PROVIDER_STATUS_RECORDED", c~caseId, actorId, actorRole, statusEvidence~occurredAt, c~state, c~state, "", "", "", "", statusEvidence~eventId)
  c~appendEvent(ev)
  return .RIDResult~success(c)
::method casesForFirm
  expose cases
  use arg firmId
  out = .array~new; wanted = .RIDCanonical~token(firmId)
  do id over cases~allIndexes
    c = cases[id]
    if c~firmId = wanted then out~append(c)
  end
  return out
::method casesForSubject
  expose cases
  use arg subjectRef
  out = .array~new; wanted = subjectRef~string
  do id over cases~allIndexes
    c = cases[id]
    if c~subjectRef = wanted then out~append(c)
  end
  return out
