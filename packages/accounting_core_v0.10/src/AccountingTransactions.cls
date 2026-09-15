/*
 * Accounting transaction and executable policy boundary v0.6.
 *
 * Operational systems emit AccountingEvent objects. Exact, versioned entity
 * accounting policies turn those events into journal drafts. Accounting Core
 * remains responsible for mechanics and does not infer legal/economic meaning.
 */

::options digits 50

::class AccountingEvent public
::attribute sourceEventRef get
::attribute legalEntityId get
::attribute eventType get
::attribute eventDate get
::attribute correlationRef get
::attribute counterpartyEntityId get
::attribute sourceAuthorityRef get
::method init
  expose sourceEventRef legalEntityId eventType eventDate correlationRef counterpartyEntityId sourceAuthorityRef payload evidenceRefs metadata
  use arg sourceArg, entityArg, typeArg, dateArg, correlationArg = "", counterpartyArg = "", authorityArg = "", payloadArg = .nil, evidenceArg = .nil, metadataArg = .nil
  sourceEventRef = .AccountingUtil~requireText(sourceArg, "sourceEventRef")
  legalEntityId = .AccountingUtil~requireText(entityArg, "legalEntityId")
  eventType = .AccountingUtil~requireText(typeArg, "eventType")~upper
  eventDate = .AccountingUtil~requireDate(dateArg, "eventDate")
  correlationRef = correlationArg~string~strip
  counterpartyEntityId = counterpartyArg~string~strip
  sourceAuthorityRef = authorityArg~string~strip
  payload = .AccountingUtil~copyDirectory(payloadArg)
  evidenceRefs = .AccountingUtil~copyArray(evidenceArg)
  metadata = .AccountingUtil~copyDirectory(metadataArg)

::method payload
  expose payload
  return .AccountingUtil~copyDirectory(payload)

::method evidenceRefs
  expose evidenceRefs
  return .AccountingUtil~copyArray(evidenceRefs)

::method metadata
  expose metadata
  return .AccountingUtil~copyDirectory(metadata)

::method value
  expose payload
  use arg key, defaultValue = .nil
  if payload~hasIndex(key~string) then return payload[key~string]
  return defaultValue

::method fingerprint
  expose sourceEventRef legalEntityId eventType eventDate correlationRef counterpartyEntityId sourceAuthorityRef payload evidenceRefs metadata
  return sourceEventRef || "|" || legalEntityId || "|" || eventType || "|" || eventDate || "|" || correlationRef || "|" || counterpartyEntityId || "|" || sourceAuthorityRef || "|" || -
    .AccountingUtil~canonicalDirectory(payload) || "|" || .AccountingUtil~canonicalArray(evidenceRefs) || "|" || .AccountingUtil~canonicalDirectory(metadata)

::class AccountingEventCodec public
::constant CONTRACT "accounting.event/0.1"

::method toProjection class
  use arg event
  if event == .nil | \event~isA(.AccountingEvent) then raise syntax 93.900 additional("AccountingEvent required")
  p = .directory~new
  p["contract_generation"] = self~CONTRACT
  p["source_event_ref"] = event~sourceEventRef
  p["legal_entity_id"] = event~legalEntityId
  p["event_type"] = event~eventType
  p["event_date"] = event~eventDate
  p["correlation_ref"] = event~correlationRef
  p["counterparty_entity_id"] = event~counterpartyEntityId
  p["source_authority_ref"] = event~sourceAuthorityRef
  p["payload"] = event~payload
  p["evidence_refs"] = event~evidenceRefs
  p["metadata"] = event~metadata
  return p

::method fromProjection class
  use arg projection
  if projection == .nil | \projection~isA(.Directory) then raise syntax 93.900 additional("Accounting event projection Directory required")
  contract = self~requiredText(projection, "contract_generation")
  if contract \= self~CONTRACT then raise syntax 93.900 additional("Unsupported accounting event contract: " || contract)
  payload = self~optionalDirectory(projection, "payload")
  evidence = self~optionalArray(projection, "evidence_refs")
  metadata = self~optionalDirectory(projection, "metadata")
  return .AccountingEvent~new(self~requiredText(projection, "source_event_ref"), self~requiredText(projection, "legal_entity_id"), self~requiredText(projection, "event_type"), self~requiredText(projection, "event_date"), -
    self~optionalText(projection, "correlation_ref"), self~optionalText(projection, "counterparty_entity_id"), self~optionalText(projection, "source_authority_ref"), payload, evidence, metadata)

::method requiredText class private
  use arg source, key
  if \source~hasIndex(key) then raise syntax 93.900 additional("Missing accounting event field: " || key)
  return .AccountingUtil~requireText(source[key], key)

::method optionalText class private
  use arg source, key
  if \source~hasIndex(key) | source[key] == .nil then return ""
  return source[key]~string

::method optionalDirectory class private
  use arg source, key
  if \source~hasIndex(key) | source[key] == .nil then return .directory~new
  if \source[key]~isA(.Directory) then raise syntax 93.900 additional(key || " must be a Directory")
  return source[key]

::method optionalArray class private
  use arg source, key
  if \source~hasIndex(key) | source[key] == .nil then return .array~new
  if \source[key]~isA(.Array) then raise syntax 93.900 additional(key || " must be an Array")
  return source[key]

::class AccountingPolicyDecision public
::attribute ok get
::attribute code get
::attribute detail get
::attribute draft get
::attribute rationale get
::method accept class
  use arg draftArg, rationaleArg = ""
  return self~new(.true, "ACCEPT", "", draftArg, rationaleArg)
::method reject class
  use arg codeArg, detailArg = "", rationaleArg = ""
  return self~new(.false, codeArg, detailArg, .nil, rationaleArg)
::method init
  expose ok code detail draft rationale
  use arg okArg, codeArg, detailArg, draftArg, rationaleArg
  ok = okArg
  code = codeArg~string
  detail = detailArg~string
  draft = draftArg
  rationale = rationaleArg~string

::class AccountingPolicy public
::attribute policyRef get
::attribute policyIdentity get
::attribute legalEntityId get
::attribute eventType get
::attribute effectiveFrom get
::attribute effectiveTo get
::method init
  expose policyRef policyIdentity legalEntityId eventType effectiveFrom effectiveTo
  use arg refArg, identityArg, entityArg, typeArg, fromArg, toArg = ""
  policyRef = .AccountingUtil~requireText(refArg, "policyRef")
  policyIdentity = .AccountingUtil~requireText(identityArg, "policyIdentity")
  legalEntityId = .AccountingUtil~requireText(entityArg, "policy legalEntityId")
  eventType = .AccountingUtil~requireText(typeArg, "policy eventType")~upper
  effectiveFrom = .AccountingUtil~requireDate(fromArg, "policy effectiveFrom")
  effectiveTo = toArg~string~strip
  if effectiveTo \= "" then do
    effectiveTo = .AccountingUtil~requireDate(effectiveTo, "policy effectiveTo")
    if effectiveTo < effectiveFrom then raise syntax 93.900 additional("policy effectiveTo precedes effectiveFrom")
  end

::method matches
  expose legalEntityId eventType effectiveFrom effectiveTo
  use arg event
  if event == .nil | \event~isA(.AccountingEvent) then return .false
  if event~legalEntityId \= legalEntityId then return .false
  if event~eventType \= eventType then return .false
  if event~eventDate < effectiveFrom then return .false
  if effectiveTo \= "" & event~eventDate > effectiveTo then return .false
  return .true

/* Policy subclasses normally call this helper so source-event and executable
 * policy identity are stamped into the immutable journal automatically. */
::method newDraft
  expose policyRef policyIdentity legalEntityId eventType
  use arg event, book, postingDate = "", narrative = "", extraEvidenceArg = .nil, metadataArg = .nil
  if event == .nil | \event~isA(.AccountingEvent) then raise syntax 93.900 additional("AccountingEvent required")
  if book == .nil | \book~isA(.AccountingBook) then raise syntax 93.900 additional("AccountingBook required")
  if event~legalEntityId \= legalEntityId | book~legalEntityId \= legalEntityId then raise syntax 93.900 additional("policy/entity mismatch")
  if event~eventType \= eventType then raise syntax 93.900 additional("policy/event type mismatch")
  if postingDate~string~strip = "" then postingDate = event~eventDate
  postingDate = .AccountingUtil~requireDate(postingDate, "postingDate")
  period = book~periodForDate(postingDate, .false)
  if period == .nil then raise syntax 93.900 additional("No open accounting period for postingDate: " || postingDate)

  evidence = .array~new
  do item over event~evidenceRefs
    self~appendUnique(evidence, item)
  end
  if extraEvidenceArg \== .nil then do item over extraEvidenceArg
    self~appendUnique(evidence, item)
  end

  metadata = event~metadata
  if metadataArg \== .nil then do key over metadataArg
    metadata[key] = metadataArg[key]
  end
  metadata["accounting.sourceAuthorityRef"] = event~sourceAuthorityRef
  metadata["accounting.eventType"] = event~eventType
  metadata["accounting.policyIdentity"] = policyIdentity
  metadata["accounting.sourceEventFingerprint"] = event~fingerprint
  if event~counterpartyEntityId \= "" then metadata["accounting.counterpartyEntityId"] = event~counterpartyEntityId

  return .AccountingJournalDraft~new(event~sourceEventRef, postingDate, period~periodId, policyRef, narrative, event~correlationRef, evidence, metadata, "", policyIdentity, event~fingerprint, event~eventType, event~counterpartyEntityId)

::method propose
  use arg event, book
  return .AccountingPolicyDecision~reject("POLICY_NOT_IMPLEMENTED", self~policyRef)

::method appendUnique private
  use arg target, value
  text = value~string
  do existing over target
    if existing~string = text then return
  end
  target~append(value)

::class AccountingPolicyResolution public
::attribute ok get
::attribute policy get
::attribute errorCode get
::attribute message get
::method success class
  use arg policyArg
  return self~new(.true, policyArg, "", "")
::method failure class
  use arg codeArg, messageArg
  return self~new(.false, .nil, codeArg, messageArg)
::method init
  expose ok policy errorCode message
  use arg okArg, policyArg, codeArg, messageArg
  ok = okArg
  policy = policyArg
  errorCode = codeArg~string
  message = messageArg~string

::class AccountingPolicyCatalog public
::method init
  expose policies identities
  policies = .array~new
  identities = .directory~new

::method register
  expose policies identities
  use arg policy
  if policy == .nil | \policy~isA(.AccountingPolicy) then raise syntax 93.900 additional("AccountingPolicy required")
  /* ooRexx methods do not inherit caller numeric settings by default.
   * Entity accounting policy packages must therefore compile at the same
   * precision as the accounting core. */
  packageDigits = policy~class~package~digits
  if packageDigits < .AccountingBuild~NUMERIC_DIGITS then raise syntax 93.900 additional("Accounting policy package must declare ::OPTIONS DIGITS 50; actual=" || packageDigits)
  if identities~hasIndex(policy~policyIdentity) then raise syntax 93.900 additional("Duplicate accounting policy identity: " || policy~policyIdentity)
  do existing over policies
    if existing~legalEntityId \= policy~legalEntityId then iterate
    if existing~eventType \= policy~eventType then iterate
    if self~rangesOverlap(existing, policy) then raise syntax 93.900 additional("Overlapping accounting policies for " || policy~legalEntityId || ":" || policy~eventType)
  end
  policies~append(policy)
  identities[policy~policyIdentity] = policy
  return policy

::method resolve
  expose policies
  use arg event
  if event == .nil | \event~isA(.AccountingEvent) then return .AccountingPolicyResolution~failure("EVENT_REQUIRED", "AccountingEvent required")
  found = .nil
  count = 0
  do policy over policies
    if \policy~matches(event) then iterate
    found = policy
    count += 1
  end
  if count = 0 then return .AccountingPolicyResolution~failure("POLICY_NOT_FOUND", event~legalEntityId || ":" || event~eventType || ":" || event~eventDate)
  if count > 1 then return .AccountingPolicyResolution~failure("POLICY_AMBIGUOUS", event~legalEntityId || ":" || event~eventType || ":" || event~eventDate)
  return .AccountingPolicyResolution~success(found)

::method policyByIdentity
  expose identities
  use arg identity
  return identities[identity~string]

::method policyIdentities
  expose identities
  ids = identities~allIndexes
  ids~sort
  return ids

::method rangesOverlap private
  use arg left, right
  if left~effectiveTo \= "" & left~effectiveTo < right~effectiveFrom then return .false
  if right~effectiveTo \= "" & right~effectiveTo < left~effectiveFrom then return .false
  return .true

::class AccountingTransactionResult public
::attribute ok get
::attribute status get
::attribute entry get
::attribute errorCode get
::attribute message get
::attribute policyRef get
::attribute policyIdentity get
::attribute decision get
::method success class
  use arg statusArg, entryArg, policyRefArg = "", policyIdentityArg = "", decisionArg = .nil
  return self~new(.true, statusArg, entryArg, "", "", policyRefArg, policyIdentityArg, decisionArg)
::method failure class
  use arg codeArg, messageArg = "", policyRefArg = "", policyIdentityArg = "", decisionArg = .nil
  return self~new(.false, "REJECTED", .nil, codeArg, messageArg, policyRefArg, policyIdentityArg, decisionArg)
::method init
  expose ok status entry errorCode message policyRef policyIdentity decision
  use arg okArg, statusArg, entryArg, codeArg, messageArg, policyRefArg, policyIdentityArg, decisionArg
  ok = okArg
  status = statusArg~string
  entry = entryArg
  errorCode = codeArg~string
  message = messageArg~string
  policyRef = policyRefArg~string
  policyIdentity = policyIdentityArg~string
  decision = decisionArg

::requires "AccountingCore.cls"
