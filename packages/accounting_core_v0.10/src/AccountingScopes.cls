/*
 * Accounting Core v0.9 scope, reporting-boundary and sealed-report mechanics.
 *
 * These objects describe orthogonal statutory/accounting scopes.  They do not
 * calculate VAT/GST, define regulator rules or create postings themselves.
 */

::options digits 50

::class AccountingDimensionKeys public
::constant ESTABLISHMENT_REF "accounting.establishmentRef"
::constant TAX_REGISTRATION_REF "accounting.taxRegistrationRef"
::constant TAX_ELECTION_REF "accounting.taxElectionRef"
::constant TAX_ELECTION_IDENTITY "accounting.taxElectionIdentity"
::constant SETTLEMENT_ELECTION_REF "accounting.settlementElectionRef"
::constant SETTLEMENT_ELECTION_IDENTITY "accounting.settlementElectionIdentity"
::constant REGULATORY_REGISTRATION_REF "accounting.regulatoryRegistrationRef"
::constant CLIENT_MONEY_ARRANGEMENT_REF "accounting.clientMoneyArrangementRef"
::constant MATTER_REF "accounting.matterRef"
::constant RELATIONSHIP_KIND "accounting.relationshipKind"

::class AccountingScopeUtil public
::method requireOptionalDate class
  use arg value, label
  text = value~string~strip
  if text = "" then return ""
  return .AccountingUtil~requireDate(text, label)

::method activeOn class
  use arg effectiveFrom, effectiveTo, status, dateArg
  date = .AccountingUtil~requireDate(dateArg, "scope date")
  if status~string~upper \= "ACTIVE" then return .false
  if date < effectiveFrom then return .false
  if effectiveTo \= "" & date > effectiveTo then return .false
  return .true

::method validateRange class
  use arg fromArg, toArg, label
  fromDate = .AccountingUtil~requireDate(fromArg, label || " effectiveFrom")
  toDate = self~requireOptionalDate(toArg, label || " effectiveTo")
  if toDate \= "" & toDate < fromDate then raise syntax 93.900 additional(label || " effectiveTo precedes effectiveFrom")
  return fromDate || "|" || toDate

::class AccountingEstablishment public
::attribute establishmentId get
::attribute legalEntityId get
::attribute jurisdiction get
::attribute placeOfBusinessType get
::attribute effectiveFrom get
::attribute effectiveTo get
::attribute status get
::method init
  expose establishmentId legalEntityId jurisdiction placeOfBusinessType effectiveFrom effectiveTo status evidenceRefs metadata
  use arg idArg, entityArg, jurisdictionArg, typeArg = "PLACE_OF_BUSINESS", fromArg = "1900-01-01", toArg = "", statusArg = "ACTIVE", evidenceArg = .nil, metadataArg = .nil
  establishmentId = .AccountingUtil~requireText(idArg, "establishmentId")
  legalEntityId = .AccountingUtil~requireText(entityArg, "establishment legalEntityId")
  jurisdiction = .AccountingUtil~requireText(jurisdictionArg, "establishment jurisdiction")~upper
  placeOfBusinessType = .AccountingUtil~requireText(typeArg, "placeOfBusinessType")~upper
  effectiveFrom = .AccountingUtil~requireDate(fromArg, "establishment effectiveFrom")
  effectiveTo = .AccountingScopeUtil~requireOptionalDate(toArg, "establishment effectiveTo")
  if effectiveTo \= "" & effectiveTo < effectiveFrom then raise syntax 93.900 additional("establishment effectiveTo precedes effectiveFrom")
  status = .AccountingUtil~requireText(statusArg, "establishment status")~upper
  evidenceRefs = .AccountingUtil~copyArray(evidenceArg)
  metadata = .AccountingUtil~copyDirectory(metadataArg)

::method activeOn
  expose effectiveFrom effectiveTo status
  use arg dateArg
  return .AccountingScopeUtil~activeOn(effectiveFrom, effectiveTo, status, dateArg)

::method evidenceRefs
  expose evidenceRefs
  return .AccountingUtil~copyArray(evidenceRefs)

::method metadata
  expose metadata
  return .AccountingUtil~copyDirectory(metadata)

::class AccountingTaxRegistration public
::attribute taxRegistrationId get
::attribute legalEntityId get
::attribute jurisdiction get
::attribute taxAuthorityRef get
::attribute taxType get
::attribute registrationNumber get
::attribute establishmentRef get
::attribute registrationBasis get
::attribute effectiveFrom get
::attribute effectiveTo get
::attribute status get
::method init
  expose taxRegistrationId legalEntityId jurisdiction taxAuthorityRef taxType registrationNumber establishmentRef registrationBasis effectiveFrom effectiveTo status evidenceRefs metadata
  use arg idArg, entityArg, jurisdictionArg, authorityArg, taxTypeArg, registrationNumberArg, establishmentArg = "", basisArg = "", fromArg = "1900-01-01", toArg = "", statusArg = "ACTIVE", evidenceArg = .nil, metadataArg = .nil
  taxRegistrationId = .AccountingUtil~requireText(idArg, "taxRegistrationId")
  legalEntityId = .AccountingUtil~requireText(entityArg, "tax registration legalEntityId")
  jurisdiction = .AccountingUtil~requireText(jurisdictionArg, "tax registration jurisdiction")~upper
  taxAuthorityRef = .AccountingUtil~requireText(authorityArg, "taxAuthorityRef")
  taxType = .AccountingUtil~requireText(taxTypeArg, "taxType")~upper
  registrationNumber = .AccountingUtil~requireText(registrationNumberArg, "registrationNumber")
  establishmentRef = establishmentArg~string~strip
  registrationBasis = basisArg~string~strip
  effectiveFrom = .AccountingUtil~requireDate(fromArg, "tax registration effectiveFrom")
  effectiveTo = .AccountingScopeUtil~requireOptionalDate(toArg, "tax registration effectiveTo")
  if effectiveTo \= "" & effectiveTo < effectiveFrom then raise syntax 93.900 additional("tax registration effectiveTo precedes effectiveFrom")
  status = .AccountingUtil~requireText(statusArg, "tax registration status")~upper
  evidenceRefs = .AccountingUtil~copyArray(evidenceArg)
  metadata = .AccountingUtil~copyDirectory(metadataArg)

::method activeOn
  expose effectiveFrom effectiveTo status
  use arg dateArg
  return .AccountingScopeUtil~activeOn(effectiveFrom, effectiveTo, status, dateArg)

::method evidenceRefs
  expose evidenceRefs
  return .AccountingUtil~copyArray(evidenceRefs)

::method metadata
  expose metadata
  return .AccountingUtil~copyDirectory(metadata)

::class AccountingTaxElection public
::attribute taxElectionId get
::attribute taxElectionIdentity get
::attribute legalEntityId get
::attribute taxRegistrationRef get
::attribute rulesetRef get
::attribute rulesetIdentity get
::attribute roundingAlgorithmRef get
::attribute calculationGranularity get
::attribute returnScheme get
::attribute effectiveFrom get
::attribute effectiveTo get
::attribute status get
::method init
  expose taxElectionId taxElectionIdentity legalEntityId taxRegistrationRef rulesetRef rulesetIdentity roundingAlgorithmRef calculationGranularity returnScheme effectiveFrom effectiveTo status evidenceRefs metadata
  use arg idArg, identityArg, entityArg, registrationArg, rulesetRefArg, rulesetIdentityArg, roundingAlgorithmArg, granularityArg, returnSchemeArg = "", fromArg = "1900-01-01", toArg = "", statusArg = "ACTIVE", evidenceArg = .nil, metadataArg = .nil
  taxElectionId = .AccountingUtil~requireText(idArg, "taxElectionId")
  taxElectionIdentity = .AccountingUtil~requireText(identityArg, "taxElectionIdentity")
  legalEntityId = .AccountingUtil~requireText(entityArg, "tax election legalEntityId")
  taxRegistrationRef = .AccountingUtil~requireText(registrationArg, "taxRegistrationRef")
  rulesetRef = .AccountingUtil~requireText(rulesetRefArg, "tax rulesetRef")
  rulesetIdentity = .AccountingUtil~requireText(rulesetIdentityArg, "tax rulesetIdentity")
  roundingAlgorithmRef = .AccountingUtil~requireText(roundingAlgorithmArg, "roundingAlgorithmRef")
  calculationGranularity = .AccountingUtil~requireText(granularityArg, "calculationGranularity")~upper
  returnScheme = returnSchemeArg~string~strip
  effectiveFrom = .AccountingUtil~requireDate(fromArg, "tax election effectiveFrom")
  effectiveTo = .AccountingScopeUtil~requireOptionalDate(toArg, "tax election effectiveTo")
  if effectiveTo \= "" & effectiveTo < effectiveFrom then raise syntax 93.900 additional("tax election effectiveTo precedes effectiveFrom")
  status = .AccountingUtil~requireText(statusArg, "tax election status")~upper
  evidenceRefs = .AccountingUtil~copyArray(evidenceArg)
  metadata = .AccountingUtil~copyDirectory(metadataArg)

::method activeOn
  expose effectiveFrom effectiveTo status
  use arg dateArg
  return .AccountingScopeUtil~activeOn(effectiveFrom, effectiveTo, status, dateArg)

::method evidenceRefs
  expose evidenceRefs
  return .AccountingUtil~copyArray(evidenceRefs)

::method metadata
  expose metadata
  return .AccountingUtil~copyDirectory(metadata)


::class AccountingSettlementRoundingElection public
::attribute settlementElectionId get
::attribute settlementElectionIdentity get
::attribute legalEntityId get
::attribute jurisdiction get
::attribute currency get
::attribute rulesetRef get
::attribute rulesetIdentity get
::attribute roundingAlgorithmRef get
::attribute roundingQuantumMinor get
::attribute effectiveFrom get
::attribute effectiveTo get
::attribute status get
::method init
  expose settlementElectionId settlementElectionIdentity legalEntityId jurisdiction currency rulesetRef rulesetIdentity roundingAlgorithmRef roundingQuantumMinor effectiveFrom effectiveTo status tenderClasses evidenceRefs metadata
  use arg idArg, identityArg, entityArg, jurisdictionArg, currencyArg, rulesetRefArg, rulesetIdentityArg, roundingAlgorithmArg, quantumArg, tenderClassesArg, fromArg = "1900-01-01", toArg = "", statusArg = "ACTIVE", evidenceArg = .nil, metadataArg = .nil
  settlementElectionId = .AccountingUtil~requireText(idArg, "settlementElectionId")
  settlementElectionIdentity = .AccountingUtil~requireText(identityArg, "settlementElectionIdentity")
  legalEntityId = .AccountingUtil~requireText(entityArg, "settlement election legalEntityId")
  jurisdiction = .AccountingUtil~requireText(jurisdictionArg, "settlement jurisdiction")~upper
  currency = .AccountingUtil~requireText(currencyArg, "settlement currency")~upper
  rulesetRef = .AccountingUtil~requireText(rulesetRefArg, "settlement rulesetRef")
  rulesetIdentity = .AccountingUtil~requireText(rulesetIdentityArg, "settlement rulesetIdentity")
  roundingAlgorithmRef = .AccountingUtil~requireText(roundingAlgorithmArg, "settlement roundingAlgorithmRef")~upper
  roundingQuantumMinor = .AccountingUtil~requireWholeNonNegative(quantumArg, "settlement roundingQuantumMinor")
  if roundingQuantumMinor = "0" then raise syntax 93.900 additional("settlement roundingQuantumMinor must be greater than zero")
  tenderClasses = .AccountingUtil~copyArray(tenderClassesArg)
  if tenderClasses~items = 0 then raise syntax 93.900 additional("settlement tender classes required")
  effectiveFrom = .AccountingUtil~requireDate(fromArg, "settlement election effectiveFrom")
  effectiveTo = .AccountingScopeUtil~requireOptionalDate(toArg, "settlement election effectiveTo")
  if effectiveTo \= "" & effectiveTo < effectiveFrom then raise syntax 93.900 additional("settlement election effectiveTo precedes effectiveFrom")
  status = .AccountingUtil~requireText(statusArg, "settlement election status")~upper
  evidenceRefs = .AccountingUtil~copyArray(evidenceArg)
  metadata = .AccountingUtil~copyDirectory(metadataArg)
::method activeOn
  expose effectiveFrom effectiveTo status
  use arg dateArg
  return .AccountingScopeUtil~activeOn(effectiveFrom, effectiveTo, status, dateArg)
::method tenderClasses
  expose tenderClasses
  return .AccountingUtil~copyArray(tenderClasses)
::method appliesToTender
  expose tenderClasses
  use arg tenderArg
  tender = tenderArg~string~upper
  do item over tenderClasses
    value = item~string~upper
    if value = "*" | value = tender then return .true
  end
  return .false
::method evidenceRefs
  expose evidenceRefs
  return .AccountingUtil~copyArray(evidenceRefs)
::method metadata
  expose metadata
  return .AccountingUtil~copyDirectory(metadata)

::class AccountingRegulatoryRegistration public
::attribute regulatoryRegistrationId get
::attribute legalEntityId get
::attribute jurisdiction get
::attribute regulatorRef get
::attribute registrationNumber get
::attribute establishmentRef get
::attribute reportingPolicyRef get
::attribute reportingPolicyIdentity get
::attribute effectiveFrom get
::attribute effectiveTo get
::attribute status get
::method init
  expose regulatoryRegistrationId legalEntityId jurisdiction regulatorRef registrationNumber establishmentRef reportingPolicyRef reportingPolicyIdentity effectiveFrom effectiveTo status evidenceRefs metadata
  use arg idArg, entityArg, jurisdictionArg, regulatorArg, registrationNumberArg, establishmentArg = "", policyRefArg = "", policyIdentityArg = "", fromArg = "1900-01-01", toArg = "", statusArg = "ACTIVE", evidenceArg = .nil, metadataArg = .nil
  regulatoryRegistrationId = .AccountingUtil~requireText(idArg, "regulatoryRegistrationId")
  legalEntityId = .AccountingUtil~requireText(entityArg, "regulatory registration legalEntityId")
  jurisdiction = .AccountingUtil~requireText(jurisdictionArg, "regulatory registration jurisdiction")~upper
  regulatorRef = .AccountingUtil~requireText(regulatorArg, "regulatorRef")
  registrationNumber = .AccountingUtil~requireText(registrationNumberArg, "regulatory registration number")
  establishmentRef = establishmentArg~string~strip
  reportingPolicyRef = policyRefArg~string~strip
  reportingPolicyIdentity = policyIdentityArg~string~strip
  effectiveFrom = .AccountingUtil~requireDate(fromArg, "regulatory registration effectiveFrom")
  effectiveTo = .AccountingScopeUtil~requireOptionalDate(toArg, "regulatory registration effectiveTo")
  if effectiveTo \= "" & effectiveTo < effectiveFrom then raise syntax 93.900 additional("regulatory registration effectiveTo precedes effectiveFrom")
  status = .AccountingUtil~requireText(statusArg, "regulatory registration status")~upper
  evidenceRefs = .AccountingUtil~copyArray(evidenceArg)
  metadata = .AccountingUtil~copyDirectory(metadataArg)

::method activeOn
  expose effectiveFrom effectiveTo status
  use arg dateArg
  return .AccountingScopeUtil~activeOn(effectiveFrom, effectiveTo, status, dateArg)

::method evidenceRefs
  expose evidenceRefs
  return .AccountingUtil~copyArray(evidenceRefs)

::method metadata
  expose metadata
  return .AccountingUtil~copyDirectory(metadata)

::class AccountingClientMoneyArrangement public
::attribute arrangementId get
::attribute legalEntityId get
::attribute jurisdiction get
::attribute regulatorRegistrationRef get
::attribute establishmentRef get
::attribute clientAccountRef get
::attribute currency get
::attribute effectiveFrom get
::attribute effectiveTo get
::attribute status get
::method init
  expose arrangementId legalEntityId jurisdiction regulatorRegistrationRef establishmentRef clientAccountRef currency effectiveFrom effectiveTo status evidenceRefs metadata
  use arg idArg, entityArg, jurisdictionArg, regulatorRegistrationArg, establishmentArg, clientAccountArg, currencyArg, fromArg = "1900-01-01", toArg = "", statusArg = "ACTIVE", evidenceArg = .nil, metadataArg = .nil
  arrangementId = .AccountingUtil~requireText(idArg, "client money arrangementId")
  legalEntityId = .AccountingUtil~requireText(entityArg, "client money legalEntityId")
  jurisdiction = .AccountingUtil~requireText(jurisdictionArg, "client money jurisdiction")~upper
  regulatorRegistrationRef = .AccountingUtil~requireText(regulatorRegistrationArg, "client money regulatorRegistrationRef")
  establishmentRef = .AccountingUtil~requireText(establishmentArg, "client money establishmentRef")
  clientAccountRef = .AccountingUtil~requireText(clientAccountArg, "clientAccountRef")
  currency = .AccountingUtil~requireText(currencyArg, "client money currency")~upper
  effectiveFrom = .AccountingUtil~requireDate(fromArg, "client money effectiveFrom")
  effectiveTo = .AccountingScopeUtil~requireOptionalDate(toArg, "client money effectiveTo")
  if effectiveTo \= "" & effectiveTo < effectiveFrom then raise syntax 93.900 additional("client money effectiveTo precedes effectiveFrom")
  status = .AccountingUtil~requireText(statusArg, "client money status")~upper
  evidenceRefs = .AccountingUtil~copyArray(evidenceArg)
  metadata = .AccountingUtil~copyDirectory(metadataArg)

::method activeOn
  expose effectiveFrom effectiveTo status
  use arg dateArg
  return .AccountingScopeUtil~activeOn(effectiveFrom, effectiveTo, status, dateArg)

::method evidenceRefs
  expose evidenceRefs
  return .AccountingUtil~copyArray(evidenceRefs)

::method metadata
  expose metadata
  return .AccountingUtil~copyDirectory(metadata)

::class AccountingScopeValidationResult public
::attribute ok get
::attribute errorCode get
::attribute message get
::method success class
  return self~new(.true, "", "")
::method failure class
  use arg codeArg, messageArg
  return self~new(.false, codeArg, messageArg)
::method init
  expose ok errorCode message
  use arg okArg, codeArg, messageArg
  ok = okArg
  errorCode = codeArg~string
  message = messageArg~string

::class AccountingScopeRegistry public
::method init
  expose legalEntityId establishments taxRegistrations taxElections settlementElections regulatoryRegistrations clientMoneyArrangements
  use arg entityArg
  legalEntityId = .AccountingUtil~requireText(entityArg, "scope registry legalEntityId")
  establishments = .directory~new
  taxRegistrations = .directory~new
  taxElections = .directory~new
  settlementElections = .directory~new
  regulatoryRegistrations = .directory~new
  clientMoneyArrangements = .directory~new

::attribute legalEntityId get

::method registerEstablishment
  expose legalEntityId establishments
  use arg item
  if item == .nil | \item~isA(.AccountingEstablishment) then raise syntax 93.900 additional("AccountingEstablishment required")
  self~assertEntity(item~legalEntityId)
  self~assertUnique(establishments, item~establishmentId, "establishment")
  establishments[item~establishmentId] = item
  return item

::method registerTaxRegistration
  expose legalEntityId taxRegistrations establishments
  use arg item
  if item == .nil | \item~isA(.AccountingTaxRegistration) then raise syntax 93.900 additional("AccountingTaxRegistration required")
  self~assertEntity(item~legalEntityId)
  self~assertUnique(taxRegistrations, item~taxRegistrationId, "tax registration")
  if item~establishmentRef \= "" then self~requireEstablishment(item~establishmentRef)
  taxRegistrations[item~taxRegistrationId] = item
  return item

::method registerTaxElection
  expose legalEntityId taxElections
  use arg item
  if item == .nil | \item~isA(.AccountingTaxElection) then raise syntax 93.900 additional("AccountingTaxElection required")
  self~assertEntity(item~legalEntityId)
  self~assertUnique(taxElections, item~taxElectionId, "tax election")
  do existingId over taxElections
    if taxElections[existingId]~taxElectionIdentity = item~taxElectionIdentity then raise syntax 93.900 additional("Duplicate tax election identity: " || item~taxElectionIdentity)
  end
  registration = self~taxRegistration(item~taxRegistrationRef)
  if registration == .nil then raise syntax 93.900 additional("Unknown tax registration: " || item~taxRegistrationRef)
  do existingId over taxElections
    existing = taxElections[existingId]
    if existing~taxRegistrationRef \= item~taxRegistrationRef then iterate
    if self~rangesOverlap(existing, item) then raise syntax 93.900 additional("Overlapping tax elections for " || item~taxRegistrationRef)
  end
  taxElections[item~taxElectionId] = item
  return item


::method registerSettlementElection
  expose legalEntityId settlementElections
  use arg item
  if item == .nil | \item~isA(.AccountingSettlementRoundingElection) then raise syntax 93.900 additional("AccountingSettlementRoundingElection required")
  self~assertEntity(item~legalEntityId)
  self~assertUnique(settlementElections, item~settlementElectionId, "settlement election")
  do existingId over settlementElections
    existing = settlementElections[existingId]
    if existing~settlementElectionIdentity = item~settlementElectionIdentity then raise syntax 93.900 additional("Duplicate settlement election identity: " || item~settlementElectionIdentity)
    if existing~jurisdiction = item~jurisdiction & existing~currency = item~currency then do
      if self~rangesOverlap(existing, item) & self~tenderClassesOverlap(existing, item) then raise syntax 93.900 additional("Overlapping settlement elections for " || item~jurisdiction || ":" || item~currency || " tender scope")
    end
  end
  settlementElections[item~settlementElectionId] = item
  return item

::method settlementElection
  expose settlementElections
  use arg idArg
  return settlementElections[idArg~string]

::method registerRegulatoryRegistration
  expose legalEntityId regulatoryRegistrations
  use arg item
  if item == .nil | \item~isA(.AccountingRegulatoryRegistration) then raise syntax 93.900 additional("AccountingRegulatoryRegistration required")
  self~assertEntity(item~legalEntityId)
  self~assertUnique(regulatoryRegistrations, item~regulatoryRegistrationId, "regulatory registration")
  if item~establishmentRef \= "" then self~requireEstablishment(item~establishmentRef)
  regulatoryRegistrations[item~regulatoryRegistrationId] = item
  return item

::method registerClientMoneyArrangement
  expose legalEntityId clientMoneyArrangements
  use arg item
  if item == .nil | \item~isA(.AccountingClientMoneyArrangement) then raise syntax 93.900 additional("AccountingClientMoneyArrangement required")
  self~assertEntity(item~legalEntityId)
  self~assertUnique(clientMoneyArrangements, item~arrangementId, "client money arrangement")
  establishment = self~requireEstablishment(item~establishmentRef)
  regulator = self~requireRegulatoryRegistration(item~regulatorRegistrationRef)
  if regulator~establishmentRef \= "" & regulator~establishmentRef \= establishment~establishmentId then raise syntax 93.900 additional("client money regulator/establishment mismatch")
  clientMoneyArrangements[item~arrangementId] = item
  return item

::method establishment
  expose establishments
  use arg idArg
  return establishments[idArg~string]

::method taxRegistration
  expose taxRegistrations
  use arg idArg
  return taxRegistrations[idArg~string]

::method taxElection
  expose taxElections
  use arg idArg
  return taxElections[idArg~string]

::method resolveTaxElection
  expose taxElections
  use arg registrationRef, dateArg
  found = .nil
  do itemId over taxElections
    item = taxElections[itemId]
    if item~taxRegistrationRef \= registrationRef~string then iterate
    if \item~activeOn(dateArg) then iterate
    if found \== .nil then raise syntax 93.900 additional("Ambiguous tax election for " || registrationRef || ":" || dateArg)
    found = item
  end
  return found

::method regulatoryRegistration
  expose regulatoryRegistrations
  use arg idArg
  return regulatoryRegistrations[idArg~string]

::method clientMoneyArrangement
  expose clientMoneyArrangements
  use arg idArg
  return clientMoneyArrangements[idArg~string]

::method validateDraft
  expose legalEntityId
  use arg draft
  if draft == .nil | \draft~isA(.AccountingJournalDraft) then return .AccountingScopeValidationResult~failure("DRAFT_REQUIRED", "AccountingJournalDraft required")
  do line over draft~lines
    result = self~validateLine(line, draft~postingDate)
    if \result~ok then return result
  end
  return .AccountingScopeValidationResult~success

::method validateLine
  use arg line, postingDate
  if line == .nil | \line~isA(.AccountingJournalLine) then return .AccountingScopeValidationResult~failure("LINE_REQUIRED", "AccountingJournalLine required")
  dimensions = line~dimensions
  establishment = .nil
  taxRegistration = .nil
  regulator = .nil
  arrangement = .nil

  if dimensions~hasIndex(.AccountingDimensionKeys~ESTABLISHMENT_REF) then do
    ref = dimensions[.AccountingDimensionKeys~ESTABLISHMENT_REF]~string
    establishment = self~establishment(ref)
    if establishment == .nil then return .AccountingScopeValidationResult~failure("ESTABLISHMENT_NOT_FOUND", ref)
    if \establishment~activeOn(postingDate) then return .AccountingScopeValidationResult~failure("ESTABLISHMENT_NOT_ACTIVE", ref || ":" || postingDate)
  end

  if dimensions~hasIndex(.AccountingDimensionKeys~TAX_REGISTRATION_REF) then do
    ref = dimensions[.AccountingDimensionKeys~TAX_REGISTRATION_REF]~string
    taxRegistration = self~taxRegistration(ref)
    if taxRegistration == .nil then return .AccountingScopeValidationResult~failure("TAX_REGISTRATION_NOT_FOUND", ref)
    if \taxRegistration~activeOn(postingDate) then return .AccountingScopeValidationResult~failure("TAX_REGISTRATION_NOT_ACTIVE", ref || ":" || postingDate)
    if taxRegistration~establishmentRef \= "" then do
      if establishment == .nil then return .AccountingScopeValidationResult~failure("TAX_ESTABLISHMENT_REQUIRED", ref)
      if taxRegistration~establishmentRef \= establishment~establishmentId then return .AccountingScopeValidationResult~failure("TAX_ESTABLISHMENT_MISMATCH", ref)
    end
  end

  taxElection = .nil
  if dimensions~hasIndex(.AccountingDimensionKeys~TAX_ELECTION_REF) then do
    ref = dimensions[.AccountingDimensionKeys~TAX_ELECTION_REF]~string
    taxElection = self~taxElection(ref)
    if taxElection == .nil then return .AccountingScopeValidationResult~failure("TAX_ELECTION_NOT_FOUND", ref)
    if \taxElection~activeOn(postingDate) then return .AccountingScopeValidationResult~failure("TAX_ELECTION_NOT_ACTIVE", ref || ":" || postingDate)
    if \dimensions~hasIndex(.AccountingDimensionKeys~TAX_ELECTION_IDENTITY) then return .AccountingScopeValidationResult~failure("TAX_ELECTION_IDENTITY_REQUIRED", ref)
    if dimensions[.AccountingDimensionKeys~TAX_ELECTION_IDENTITY]~string \= taxElection~taxElectionIdentity then return .AccountingScopeValidationResult~failure("TAX_ELECTION_IDENTITY_MISMATCH", ref)
    if taxRegistration == .nil then return .AccountingScopeValidationResult~failure("TAX_REGISTRATION_REQUIRED_FOR_ELECTION", ref)
    if taxElection~taxRegistrationRef \= taxRegistration~taxRegistrationId then return .AccountingScopeValidationResult~failure("TAX_ELECTION_REGISTRATION_MISMATCH", ref)
  end
  if taxRegistration \== .nil then do
    expectedElection = self~resolveTaxElection(taxRegistration~taxRegistrationId, postingDate)
    if expectedElection \== .nil then do
      if taxElection == .nil then return .AccountingScopeValidationResult~failure("TAX_ELECTION_REQUIRED", taxRegistration~taxRegistrationId || ":" || postingDate)
      if taxElection~taxElectionId \= expectedElection~taxElectionId then return .AccountingScopeValidationResult~failure("TAX_ELECTION_INCONSISTENT", taxRegistration~taxRegistrationId || ":" || taxElection~taxElectionId)
    end
  end

  if dimensions~hasIndex(.AccountingDimensionKeys~REGULATORY_REGISTRATION_REF) then do
    ref = dimensions[.AccountingDimensionKeys~REGULATORY_REGISTRATION_REF]~string
    regulator = self~regulatoryRegistration(ref)
    if regulator == .nil then return .AccountingScopeValidationResult~failure("REGULATORY_REGISTRATION_NOT_FOUND", ref)
    if \regulator~activeOn(postingDate) then return .AccountingScopeValidationResult~failure("REGULATORY_REGISTRATION_NOT_ACTIVE", ref || ":" || postingDate)
    if regulator~establishmentRef \= "" then do
      if establishment == .nil then return .AccountingScopeValidationResult~failure("REGULATORY_ESTABLISHMENT_REQUIRED", ref)
      if regulator~establishmentRef \= establishment~establishmentId then return .AccountingScopeValidationResult~failure("REGULATORY_ESTABLISHMENT_MISMATCH", ref)
    end
  end

  if dimensions~hasIndex(.AccountingDimensionKeys~CLIENT_MONEY_ARRANGEMENT_REF) then do
    ref = dimensions[.AccountingDimensionKeys~CLIENT_MONEY_ARRANGEMENT_REF]~string
    arrangement = self~clientMoneyArrangement(ref)
    if arrangement == .nil then return .AccountingScopeValidationResult~failure("CLIENT_MONEY_ARRANGEMENT_NOT_FOUND", ref)
    if \arrangement~activeOn(postingDate) then return .AccountingScopeValidationResult~failure("CLIENT_MONEY_ARRANGEMENT_NOT_ACTIVE", ref || ":" || postingDate)
    if line~currency \= arrangement~currency then return .AccountingScopeValidationResult~failure("CLIENT_MONEY_CURRENCY_MISMATCH", ref || ":" || line~currency)
    if establishment == .nil then return .AccountingScopeValidationResult~failure("CLIENT_MONEY_ESTABLISHMENT_REQUIRED", ref)
    if arrangement~establishmentRef \= establishment~establishmentId then return .AccountingScopeValidationResult~failure("CLIENT_MONEY_ESTABLISHMENT_MISMATCH", ref)
    if regulator == .nil then return .AccountingScopeValidationResult~failure("CLIENT_MONEY_REGULATOR_REQUIRED", ref)
    if arrangement~regulatorRegistrationRef \= regulator~regulatoryRegistrationId then return .AccountingScopeValidationResult~failure("CLIENT_MONEY_REGULATOR_MISMATCH", ref)
  end

  if dimensions~hasIndex(.AccountingDimensionKeys~RELATIONSHIP_KIND) then do
    kind = dimensions[.AccountingDimensionKeys~RELATIONSHIP_KIND]~string~upper
    if wordpos(kind, "EXTERNAL INTRA_ENTITY INTER_ESTABLISHMENT INTERCOMPANY") = 0 then return .AccountingScopeValidationResult~failure("RELATIONSHIP_KIND_INVALID", kind)
  end
  return .AccountingScopeValidationResult~success

::method requireEstablishment private
  use arg idArg
  item = self~establishment(idArg)
  if item == .nil then raise syntax 93.900 additional("Unknown establishment: " || idArg)
  return item

::method requireRegulatoryRegistration private
  use arg idArg
  item = self~regulatoryRegistration(idArg)
  if item == .nil then raise syntax 93.900 additional("Unknown regulatory registration: " || idArg)
  return item

::method assertEntity private
  expose legalEntityId
  use arg itemEntity
  if itemEntity~string \= legalEntityId then raise syntax 93.900 additional("scope legal entity mismatch: " || itemEntity || " != " || legalEntityId)
  return .true

::method assertUnique private
  use arg directory, idArg, label
  if directory~hasIndex(idArg~string) then raise syntax 93.900 additional("Duplicate " || label || ": " || idArg)
  return .true


::method tenderClassesOverlap private
  use arg left, right
  leftTenders = left~tenderClasses
  rightTenders = right~tenderClasses
  do l over leftTenders
    lt = l~string~upper
    if lt = "*" then return .true
    do r over rightTenders
      rt = r~string~upper
      if rt = "*" | rt = lt then return .true
    end
  end
  return .false

::method rangesOverlap private
  use arg left, right
  if left~effectiveTo \= "" & left~effectiveTo < right~effectiveFrom then return .false
  if right~effectiveTo \= "" & right~effectiveTo < left~effectiveFrom then return .false
  return .true

::class AccountingReportingBoundary public
::attribute boundaryId get
::attribute reportingAuthorityRef get
::attribute reportType get
::attribute effectiveFrom get
::attribute effectiveTo get
::attribute reportingPolicyRef get
::attribute reportingPolicyIdentity get
::method init
  expose boundaryId reportingAuthorityRef reportType effectiveFrom effectiveTo reportingPolicyRef reportingPolicyIdentity includedLegalEntities includedBookIds dimensionSelectors evidenceRefs metadata
  use arg idArg, authorityArg, reportTypeArg, fromArg, toArg = "", legalEntitiesArg = .nil, bookIdsArg = .nil, selectorsArg = .nil, policyRefArg = "", policyIdentityArg = "", evidenceArg = .nil, metadataArg = .nil
  boundaryId = .AccountingUtil~requireText(idArg, "reporting boundaryId")
  reportingAuthorityRef = .AccountingUtil~requireText(authorityArg, "reportingAuthorityRef")
  reportType = .AccountingUtil~requireText(reportTypeArg, "reportType")~upper
  effectiveFrom = .AccountingUtil~requireDate(fromArg, "reporting boundary effectiveFrom")
  effectiveTo = .AccountingScopeUtil~requireOptionalDate(toArg, "reporting boundary effectiveTo")
  if effectiveTo \= "" & effectiveTo < effectiveFrom then raise syntax 93.900 additional("reporting boundary effectiveTo precedes effectiveFrom")
  includedLegalEntities = .AccountingUtil~copyArray(legalEntitiesArg)
  includedBookIds = .AccountingUtil~copyArray(bookIdsArg)
  dimensionSelectors = .AccountingUtil~copyDirectory(selectorsArg)
  do key over dimensionSelectors
    if \dimensionSelectors[key]~isA(.Array) then raise syntax 93.900 additional("reporting selector values must be arrays: " || key)
  end
  reportingPolicyRef = policyRefArg~string~strip
  reportingPolicyIdentity = policyIdentityArg~string~strip
  evidenceRefs = .AccountingUtil~copyArray(evidenceArg)
  metadata = .AccountingUtil~copyDirectory(metadataArg)

::method includedLegalEntities
  expose includedLegalEntities
  return .AccountingUtil~copyArray(includedLegalEntities)

::method includedBookIds
  expose includedBookIds
  return .AccountingUtil~copyArray(includedBookIds)

::method dimensionSelectors
  expose dimensionSelectors
  return .AccountingUtil~copyDirectory(dimensionSelectors)

::method evidenceRefs
  expose evidenceRefs
  return .AccountingUtil~copyArray(evidenceRefs)

::method metadata
  expose metadata
  return .AccountingUtil~copyDirectory(metadata)

::method activeOn
  expose effectiveFrom effectiveTo
  use arg dateArg
  date = .AccountingUtil~requireDate(dateArg, "reporting boundary date")
  if date < effectiveFrom then return .false
  if effectiveTo \= "" & date > effectiveTo then return .false
  return .true

::method fingerprint
  expose boundaryId reportingAuthorityRef reportType effectiveFrom effectiveTo reportingPolicyRef reportingPolicyIdentity includedLegalEntities includedBookIds dimensionSelectors evidenceRefs metadata
  return boundaryId || "|" || reportingAuthorityRef || "|" || reportType || "|" || effectiveFrom || "|" || effectiveTo || "|" || reportingPolicyRef || "|" || reportingPolicyIdentity || "|" || .AccountingUtil~canonicalArray(includedLegalEntities) || "|" || .AccountingUtil~canonicalArray(includedBookIds) || "|" || .AccountingUtil~canonicalDirectory(dimensionSelectors) || "|" || .AccountingUtil~canonicalArray(evidenceRefs) || "|" || .AccountingUtil~canonicalDirectory(metadata)

::class AccountingReportingLine public
::attribute legalEntityId get
::attribute bookId get
::attribute entryId get
::attribute lineNumber get
::attribute postingDate get
::attribute accountId get
::attribute currency get
::attribute debitMinor get
::attribute creditMinor get
::attribute sourceEventRef get
::attribute correlationRef get
::attribute entryFingerprint get
::attribute lineFingerprint get
::method init
  expose legalEntityId bookId entryId lineNumber postingDate accountId currency debitMinor creditMinor sourceEventRef correlationRef entryFingerprint lineFingerprint dimensions
  use arg entityArg, bookArg, entry, lineNumberArg, line
  legalEntityId = entityArg~string
  bookId = bookArg~string
  entryId = entry~entryId
  lineNumber = lineNumberArg
  postingDate = entry~postingDate
  accountId = line~accountId
  currency = line~currency
  debitMinor = line~debitMinor
  creditMinor = line~creditMinor
  sourceEventRef = entry~sourceEventRef
  correlationRef = entry~correlationRef
  entryFingerprint = entry~fingerprint
  lineFingerprint = line~fingerprint
  dimensions = line~dimensions

::method dimensions
  expose dimensions
  return .AccountingUtil~copyDirectory(dimensions)

::method fingerprint
  expose legalEntityId bookId entryId lineNumber postingDate accountId currency debitMinor creditMinor sourceEventRef correlationRef entryFingerprint lineFingerprint dimensions
  return legalEntityId || "|" || bookId || "|" || entryId || "|" || entryFingerprint || "|" || lineNumber || "|" || postingDate || "|" || accountId || "|" || currency || "|" || debitMinor || "|" || creditMinor || "|" || sourceEventRef || "|" || correlationRef || "|" || lineFingerprint || "|" || .AccountingUtil~canonicalDirectory(dimensions)

::method projection
  expose legalEntityId bookId entryId lineNumber postingDate accountId currency debitMinor creditMinor sourceEventRef correlationRef entryFingerprint lineFingerprint dimensions
  p = .directory~new
  p["legal_entity_id"] = legalEntityId
  p["book_id"] = bookId
  p["entry_id"] = entryId
  p["entry_fingerprint"] = entryFingerprint
  p["line_number"] = lineNumber~string
  p["line_fingerprint"] = lineFingerprint
  p["posting_date"] = postingDate
  p["account_id"] = accountId
  p["currency"] = currency
  p["debit_minor"] = debitMinor~string
  p["credit_minor"] = creditMinor~string
  p["source_event_ref"] = sourceEventRef
  p["correlation_ref"] = correlationRef
  p["dimensions"] = .AccountingUtil~copyDirectory(dimensions)
  return p

::class AccountingReportingView public
::attribute boundaryId get
::attribute boundaryFingerprint get
::attribute startDate get
::attribute endDate get
::method init
  expose boundaryId boundaryFingerprint startDate endDate lines
  use arg boundary, startArg, endArg, linesArg
  boundaryId = boundary~boundaryId
  boundaryFingerprint = boundary~fingerprint
  startDate = startArg~string
  endDate = endArg~string
  lines = .AccountingUtil~copyArray(linesArg)

::method lines
  expose lines
  return .AccountingUtil~copyArray(lines)

::method lineCount
  expose lines
  return lines~items

::method totals
  expose lines
  numeric digits 50
  totals = .directory~new
  do line over lines
    key = line~currency
    if \totals~hasIndex(key) then do
      row = .directory~new
      row["debit_minor"] = "0"
      row["credit_minor"] = "0"
      totals[key] = row
    end
    row = totals[key]
    row["debit_minor"] = (row["debit_minor"] + line~debitMinor)~string
    row["credit_minor"] = (row["credit_minor"] + line~creditMinor)~string
  end
  return .AccountingUtil~copyDirectory(totals)

::method totalsByAccount
  expose lines
  numeric digits 50
  totals = .directory~new
  do line over lines
    key = line~accountId || "|" || line~currency
    if \totals~hasIndex(key) then do
      row = .directory~new
      row["account_id"] = line~accountId
      row["currency"] = line~currency
      row["debit_minor"] = "0"
      row["credit_minor"] = "0"
      totals[key] = row
    end
    row = totals[key]
    row["debit_minor"] = (row["debit_minor"] + line~debitMinor)~string
    row["credit_minor"] = (row["credit_minor"] + line~creditMinor)~string
  end
  return .AccountingUtil~copyDirectory(totals)

::method totalsByDimensions
  expose lines
  use arg dimensionKeys
  return .AccountingReportingAggregation~totalsByDimensions(lines, dimensionKeys)

::class AccountingReportingAggregation public
::method totalsByDimensions class
  use arg linesArg, dimensionKeys
  numeric digits 50
  if linesArg == .nil | \linesArg~isA(.Array) then raise syntax 93.900 additional("report lines array required")
  if dimensionKeys == .nil | \dimensionKeys~isA(.Array) | dimensionKeys~items = 0 then raise syntax 93.900 additional("dimension keys array required")
  totals = .directory~new
  do line over linesArg
    dims = line~dimensions
    selectedDims = .directory~new
    groupKey = ""
    do dimensionKey over dimensionKeys
      name = .AccountingUtil~requireText(dimensionKey, "report dimension key")
      value = ""
      if dims~hasIndex(name) then value = dims[name]~string
      selectedDims[name] = value
      groupKey = groupKey || name || "=" || value || ";"
    end
    groupKey = groupKey || "currency=" || line~currency
    if \totals~hasIndex(groupKey) then do
      row = .directory~new
      row["dimensions"] = selectedDims
      row["currency"] = line~currency
      row["debit_minor"] = "0"
      row["credit_minor"] = "0"
      totals[groupKey] = row
    end
    row = totals[groupKey]
    row["debit_minor"] = (row["debit_minor"] + line~debitMinor)~string
    row["credit_minor"] = (row["credit_minor"] + line~creditMinor)~string
  end
  return .AccountingUtil~copyDirectory(totals)

::class AccountingReportingService public
::method buildView class
  use arg boundary, booksArg, startArg = "", endArg = ""
  if boundary == .nil | \boundary~isA(.AccountingReportingBoundary) then raise syntax 93.900 additional("AccountingReportingBoundary required")
  if booksArg == .nil | \booksArg~isA(.Array) then raise syntax 93.900 additional("Accounting books array required")
  startDate = startArg~string~strip
  endDate = endArg~string~strip
  if startDate \= "" then startDate = .AccountingUtil~requireDate(startDate, "report startDate")
  if endDate \= "" then endDate = .AccountingUtil~requireDate(endDate, "report endDate")
  if startDate \= "" & endDate \= "" & endDate < startDate then raise syntax 93.900 additional("report endDate precedes startDate")

  selected = .array~new
  do book over booksArg
    if book == .nil | \book~isA(.AccountingBook) then raise syntax 93.900 additional("AccountingBook required in report source")
    if \self~bookIncluded(boundary, book) then iterate
    do entry over book~entries
      if startDate \= "" & entry~postingDate < startDate then iterate
      if endDate \= "" & entry~postingDate > endDate then iterate
      if \boundary~activeOn(entry~postingDate) then iterate
      lineNumber = 0
      do line over entry~lines
        lineNumber += 1
        if \self~lineIncluded(boundary, line) then iterate
        selected~append(.AccountingReportingLine~new(book~legalEntityId, book~bookId, entry, lineNumber, line))
      end
    end
  end
  return .AccountingReportingView~new(boundary, startDate, endDate, selected)

::method sealSnapshot class
  use arg snapshotIdArg, boundary, booksArg, startArg = "", endArg = "", sealRefArg = "", evidenceArg = .nil, metadataArg = .nil
  snapshotId = .AccountingUtil~requireText(snapshotIdArg, "reporting snapshotId")
  sealRef = .AccountingUtil~requireText(sealRefArg, "reporting sealRef")
  view = self~buildView(boundary, booksArg, startArg, endArg)
  sourceStates = .array~new
  do book over booksArg
    if \self~bookIncluded(boundary, book) then iterate
    sourceStates~append(.AccountingReportingSourceBookState~fromBook(book))
  end
  return .AccountingReportingSnapshot~new(snapshotId, boundary, view, sourceStates, sealRef, evidenceArg, metadataArg)

::method verifySnapshot class
  use arg snapshot, boundary, booksArg
  if snapshot == .nil | \snapshot~isA(.AccountingReportingSnapshot) then return .AccountingReportingVerificationResult~failure("SNAPSHOT_REQUIRED", "AccountingReportingSnapshot required")
  if boundary == .nil | \boundary~isA(.AccountingReportingBoundary) then return .AccountingReportingVerificationResult~failure("BOUNDARY_REQUIRED", "AccountingReportingBoundary required")
  if snapshot~boundaryFingerprint \= boundary~fingerprint then return .AccountingReportingVerificationResult~failure("BOUNDARY_MISMATCH", boundary~boundaryId)
  if booksArg == .nil | \booksArg~isA(.Array) then return .AccountingReportingVerificationResult~failure("BOOKS_REQUIRED", "Accounting books array required")

  states = snapshot~sourceBookStates
  stateKeys = .directory~new
  do state over states
    stateKeys[state~legalEntityId || "|" || state~bookId] = state
  end

  advanced = .false
  do book over booksArg
    if book == .nil | \book~isA(.AccountingBook) then return .AccountingReportingVerificationResult~failure("BOOK_REQUIRED", "AccountingBook required in report source")
    if \self~bookIncluded(boundary, book) then iterate
    key = book~legalEntityId || "|" || book~bookId
    if \stateKeys~hasIndex(key) then return .AccountingReportingVerificationResult~failure("SOURCE_BOOK_SET_CHANGED", key)
  end

  do state over states
    book = self~findBook(booksArg, state~legalEntityId, state~bookId)
    if book == .nil then return .AccountingReportingVerificationResult~failure("SOURCE_BOOK_MISSING", state~legalEntityId || "|" || state~bookId)
    entries = book~entries
    recorded = state~entryIdentities
    if entries~items < recorded~items then return .AccountingReportingVerificationResult~failure("SOURCE_BOOK_TRUNCATED", state~bookId)
    do i = 1 to recorded~items
      saved = recorded[i]
      current = entries[i]
      if current~entryId \= saved["entry_id"]~string | current~postingDate \= saved["posting_date"]~string | current~fingerprint \= saved["fingerprint"]~string then -
        return .AccountingReportingVerificationResult~failure("SOURCE_ENTRY_MISMATCH", state~bookId || ":" || i)
    end
    if entries~items > recorded~items then do
      advanced = .true
      do i = recorded~items + 1 to entries~items
        entry = entries[i]
        if self~entryCouldChangeSnapshot(snapshot, boundary, entry) then return .AccountingReportingVerificationResult~failure("REPORT_POPULATION_STALE", state~bookId || ":" || entry~entryId)
      end
    end
  end
  if advanced then return .AccountingReportingVerificationResult~success("VALID_SOURCE_ADVANCED")
  return .AccountingReportingVerificationResult~success("VALID")

::method findBook class private
  use arg booksArg, entityArg, bookIdArg
  do book over booksArg
    if book~legalEntityId = entityArg~string & book~bookId = bookIdArg~string then return book
  end
  return .nil

::method entryCouldChangeSnapshot class private
  use arg snapshot, boundary, entry
  if snapshot~startDate \= "" & entry~postingDate < snapshot~startDate then return .false
  if snapshot~endDate \= "" & entry~postingDate > snapshot~endDate then return .false
  if \boundary~activeOn(entry~postingDate) then return .false
  do line over entry~lines
    if self~lineIncluded(boundary, line) then return .true
  end
  return .false

::method bookIncluded class private
  use arg boundary, book
  entities = boundary~includedLegalEntities
  if entities~items > 0 & \self~containsText(entities, book~legalEntityId) then return .false
  bookIds = boundary~includedBookIds
  if bookIds~items > 0 & \self~containsText(bookIds, book~bookId) then return .false
  return .true

::method lineIncluded class private
  use arg boundary, line
  selectors = boundary~dimensionSelectors
  if selectors~items = 0 then return .true
  dimensions = line~dimensions
  do key over selectors
    if \dimensions~hasIndex(key) then return .false
    if \self~containsText(selectors[key], dimensions[key]) then return .false
  end
  return .true

::method containsText class private
  use arg values, target
  text = target~string
  do item over values
    if item~string = text then return .true
  end
  return .false

::class AccountingReportingSourceBookState public
::attribute legalEntityId get
::attribute bookId get
::attribute reportingBasis get
::attribute arithmeticProfile get
::attribute entryCount get
::method fromBook class
  use arg book
  if book == .nil | \book~isA(.AccountingBook) then raise syntax 93.900 additional("AccountingBook required")
  identities = .array~new
  do entry over book~entries
    row = .directory~new
    row["entry_id"] = entry~entryId
    row["posting_date"] = entry~postingDate
    row["fingerprint"] = entry~fingerprint
    identities~append(row)
  end
  return self~new(book~legalEntityId, book~bookId, book~reportingBasis, book~arithmeticProfile, identities)

::method init
  expose legalEntityId bookId reportingBasis arithmeticProfile entryCount entryIdentities
  use arg entityArg, bookArg, basisArg, profileArg, identitiesArg
  legalEntityId = .AccountingUtil~requireText(entityArg, "source book legalEntityId")
  bookId = .AccountingUtil~requireText(bookArg, "source book bookId")
  reportingBasis = .AccountingUtil~requireText(basisArg, "source book reportingBasis")
  arithmeticProfile = .AccountingUtil~requireText(profileArg, "source book arithmeticProfile")
  entryIdentities = .AccountingUtil~copyArray(identitiesArg)
  entryCount = entryIdentities~items

::method entryIdentities
  expose entryIdentities
  return .AccountingUtil~copyArray(entryIdentities)

::method fingerprint
  expose legalEntityId bookId reportingBasis arithmeticProfile entryCount entryIdentities
  return legalEntityId || "|" || bookId || "|" || reportingBasis || "|" || arithmeticProfile || "|" || entryCount || "|" || .AccountingUtil~canonicalArray(entryIdentities)

::method projection
  expose legalEntityId bookId reportingBasis arithmeticProfile entryCount entryIdentities
  p = .directory~new
  p["legal_entity_id"] = legalEntityId
  p["book_id"] = bookId
  p["reporting_basis"] = reportingBasis
  p["arithmetic_profile"] = arithmeticProfile
  p["entry_count"] = entryCount~string
  p["entry_identities"] = .AccountingUtil~copyArray(entryIdentities)
  p["fingerprint"] = self~fingerprint
  return p

::class AccountingReportingSnapshot public
::attribute snapshotId get
::attribute boundaryId get
::attribute boundaryFingerprint get
::attribute startDate get
::attribute endDate get
::attribute sealRef get
::method init
  expose snapshotId boundaryId boundaryFingerprint startDate endDate sealRef sourceBookStates lines evidenceRefs metadata
  use arg snapshotIdArg, boundary, view, sourceStatesArg, sealRefArg, evidenceArg = .nil, metadataArg = .nil
  snapshotId = .AccountingUtil~requireText(snapshotIdArg, "reporting snapshotId")
  if boundary == .nil | \boundary~isA(.AccountingReportingBoundary) then raise syntax 93.900 additional("AccountingReportingBoundary required")
  if view == .nil | \view~isA(.AccountingReportingView) then raise syntax 93.900 additional("AccountingReportingView required")
  boundaryId = boundary~boundaryId
  boundaryFingerprint = boundary~fingerprint
  startDate = view~startDate
  endDate = view~endDate
  sealRef = .AccountingUtil~requireText(sealRefArg, "reporting sealRef")
  sourceBookStates = .AccountingUtil~copyArray(sourceStatesArg)
  lines = view~lines
  evidenceRefs = .AccountingUtil~copyArray(evidenceArg)
  metadata = .AccountingUtil~copyDirectory(metadataArg)

::method sourceBookStates
  expose sourceBookStates
  return .AccountingUtil~copyArray(sourceBookStates)

::method lines
  expose lines
  return .AccountingUtil~copyArray(lines)

::method evidenceRefs
  expose evidenceRefs
  return .AccountingUtil~copyArray(evidenceRefs)

::method metadata
  expose metadata
  return .AccountingUtil~copyDirectory(metadata)

::method lineCount
  expose lines
  return lines~items

::method totals
  expose lines
  numeric digits 50
  totals = .directory~new
  do line over lines
    key = line~currency
    if \totals~hasIndex(key) then do
      row = .directory~new
      row["debit_minor"] = "0"
      row["credit_minor"] = "0"
      totals[key] = row
    end
    row = totals[key]
    row["debit_minor"] = (row["debit_minor"] + line~debitMinor)~string
    row["credit_minor"] = (row["credit_minor"] + line~creditMinor)~string
  end
  return .AccountingUtil~copyDirectory(totals)

::method totalsByAccount
  expose lines
  numeric digits 50
  totals = .directory~new
  do line over lines
    key = line~accountId || "|" || line~currency
    if \totals~hasIndex(key) then do
      row = .directory~new
      row["account_id"] = line~accountId
      row["currency"] = line~currency
      row["debit_minor"] = "0"
      row["credit_minor"] = "0"
      totals[key] = row
    end
    row = totals[key]
    row["debit_minor"] = (row["debit_minor"] + line~debitMinor)~string
    row["credit_minor"] = (row["credit_minor"] + line~creditMinor)~string
  end
  return .AccountingUtil~copyDirectory(totals)

::method totalsByDimensions
  expose lines
  use arg dimensionKeys
  return .AccountingReportingAggregation~totalsByDimensions(lines, dimensionKeys)

::method fingerprint
  expose snapshotId boundaryId boundaryFingerprint startDate endDate sealRef sourceBookStates lines evidenceRefs metadata
  text = snapshotId || "|" || boundaryId || "|" || boundaryFingerprint || "|" || startDate || "|" || endDate || "|" || sealRef || "|"
  do state over sourceBookStates
    text = text || state~fingerprint || "||"
  end
  do line over lines
    text = text || line~fingerprint || "||"
  end
  return text || .AccountingUtil~canonicalArray(evidenceRefs) || "|" || .AccountingUtil~canonicalDirectory(metadata)

::method projection
  expose snapshotId boundaryId boundaryFingerprint startDate endDate sealRef sourceBookStates lines evidenceRefs metadata
  p = .directory~new
  p["api"] = .AccountingBuild~REPORTING_SNAPSHOT_API
  p["snapshot_id"] = snapshotId
  p["boundary_id"] = boundaryId
  p["boundary_fingerprint"] = boundaryFingerprint
  p["start_date"] = startDate
  p["end_date"] = endDate
  p["seal_ref"] = sealRef
  states = .array~new
  do state over sourceBookStates
    states~append(state~projection)
  end
  p["source_books"] = states
  projectedLines = .array~new
  do line over lines
    projectedLines~append(line~projection)
  end
  p["lines"] = projectedLines
  p["evidence_refs"] = .AccountingUtil~copyArray(evidenceRefs)
  p["metadata"] = .AccountingUtil~copyDirectory(metadata)
  p["fingerprint"] = self~fingerprint
  return p

::class AccountingReportingVerificationResult public
::attribute ok get
::attribute status get
::attribute errorCode get
::attribute message get
::method success class
  use arg statusArg
  return self~new(.true, statusArg, "", "")
::method failure class
  use arg codeArg, messageArg
  return self~new(.false, "INVALID", codeArg, messageArg)
::method init
  expose ok status errorCode message
  use arg okArg, statusArg, codeArg, messageArg
  ok = okArg
  status = statusArg~string
  errorCode = codeArg~string
  message = messageArg~string

::requires "AccountingCore.cls"
