/*
 * Accounting Engine v0.9 facade.
 *
 * transact() is the preferred operational integration boundary:
 * AccountingEvent -> exact entity policy -> immutable journal.
 * post()/postDraft() remain lower-level posting APIs for controlled accounting
 * tooling, migration and explicit manual/accountant workflows.
 */

::options digits 50

::class AccountingEngine public
::attribute legalEntityId get
::method init
  expose legalEntityId nativeBook assessmentBook policyCatalog scopeRegistry taxPolicyCatalog settlementPolicyCatalog
  use arg entityArg, bookIdArg = "STATUTORY", reportingBasisArg = "ENTITY_GAAP", nativeBookArg = .nil
  legalEntityId = .AccountingUtil~requireText(entityArg, "legalEntityId")
  if nativeBookArg == .nil then nativeBook = .AccountingBook~new(legalEntityId, bookIdArg, reportingBasisArg)
  else do
    if \nativeBookArg~isA(.AccountingBook) then raise syntax 93.900 additional("AccountingBook required")
    if nativeBookArg~legalEntityId \= legalEntityId then raise syntax 93.900 additional("Recovered book legal entity mismatch")
    nativeBook = nativeBookArg
  end
  assessmentBook = .AccountingAssessmentBook~new(legalEntityId)
  policyCatalog = .AccountingPolicyCatalog~new
  scopeRegistry = .AccountingScopeRegistry~new(legalEntityId)
  taxPolicyCatalog = .AccountingTaxPolicyCatalog~new
  settlementPolicyCatalog = .AccountingSettlementPolicyCatalog~new

::method book
  expose nativeBook
  return nativeBook

::method assessments
  expose assessmentBook
  return assessmentBook

::method policies
  expose policyCatalog
  return policyCatalog

::method scopes
  expose scopeRegistry
  return scopeRegistry

::method taxPolicies
  expose taxPolicyCatalog
  return taxPolicyCatalog

::method registerTaxPolicy
  expose taxPolicyCatalog
  use arg policy
  return taxPolicyCatalog~register(policy)

::method settlementPolicies
  expose settlementPolicyCatalog
  return settlementPolicyCatalog

::method registerSettlementPolicy
  expose settlementPolicyCatalog
  use arg policy
  return settlementPolicyCatalog~register(policy)

::method registerPolicy
  expose policyCatalog
  use arg policy
  return policyCatalog~register(policy)

/* Preferred operational path. Existing accounted events are checked before
 * policy dispatch, so replay cannot be changed by a later policy version. */
::method transact
  expose legalEntityId nativeBook policyCatalog scopeRegistry
  use arg event
  if event == .nil | \event~isA(.AccountingEvent) then return .AccountingTransactionResult~failure("EVENT_REQUIRED", "AccountingEvent required")
  if event~legalEntityId \= legalEntityId then return .AccountingTransactionResult~failure("LEGAL_ENTITY_MISMATCH", event~legalEntityId || " != " || legalEntityId)

  existing = nativeBook~sourceEntry(event~sourceEventRef)
  if existing \== .nil then do
    if existing~sourceEventFingerprint = "" then return .AccountingTransactionResult~failure("SOURCE_EVENT_IDENTITY_UNAVAILABLE", event~sourceEventRef, existing~policyRef, existing~policyIdentity)
    if existing~sourceEventFingerprint = event~fingerprint then return .AccountingTransactionResult~success("DUPLICATE", existing, existing~policyRef, existing~policyIdentity)
    return .AccountingTransactionResult~failure("SOURCE_EVENT_CONFLICT", event~sourceEventRef, existing~policyRef, existing~policyIdentity)
  end

  resolution = policyCatalog~resolve(event)
  if \resolution~ok then return .AccountingTransactionResult~failure(resolution~errorCode, resolution~message)
  policy = resolution~policy
  signal on syntax name policyExecutionFailure
  decision = policy~propose(event, nativeBook)
  signal off syntax
  if decision == .nil | \decision~isA(.AccountingPolicyDecision) then return .AccountingTransactionResult~failure("POLICY_DECISION_INVALID", policy~policyRef, policy~policyRef, policy~policyIdentity)
  if \decision~ok then return .AccountingTransactionResult~failure(decision~code, decision~detail, policy~policyRef, policy~policyIdentity, decision)

  draft = decision~draft
  if draft == .nil | \draft~isA(.AccountingJournalDraft) then return .AccountingTransactionResult~failure("POLICY_DRAFT_INVALID", "AccountingJournalDraft required", policy~policyRef, policy~policyIdentity, decision)

  validation = self~validatePolicyDraft(event, policy, draft)
  if validation \== "" then return .AccountingTransactionResult~failure("POLICY_DRAFT_BINDING_INVALID", validation, policy~policyRef, policy~policyIdentity, decision)

  scopeValidation = scopeRegistry~validateDraft(draft)
  if \scopeValidation~ok then return .AccountingTransactionResult~failure(scopeValidation~errorCode, scopeValidation~message, policy~policyRef, policy~policyIdentity, decision)

  posting = nativeBook~post(draft)
  if \posting~ok then return .AccountingTransactionResult~failure(posting~errorCode, posting~message, policy~policyRef, policy~policyIdentity, decision)
  return .AccountingTransactionResult~success(posting~status, posting~entry, policy~policyRef, policy~policyIdentity, decision)

policyExecutionFailure:
  signal off syntax
  return .AccountingTransactionResult~failure("POLICY_EXECUTION_FAILED", condition("D"), policy~policyRef, policy~policyIdentity)

::method transactProjection
  use arg projection
  signal on syntax name projectionInvalid
  event = .AccountingEventCodec~fromProjection(projection)
  signal off syntax
  return self~transact(event)
projectionInvalid:
  signal off syntax
  return .AccountingTransactionResult~failure("EVENT_PROJECTION_INVALID", condition("D"))

/* Generic tax determination.  The effective TaxElection chooses an exact
 * ruleset identity; the core dispatches only to the policy registered for that
 * identity and validates that the returned determination is bound to the
 * request, registration and election. */
::method determineTax
  expose legalEntityId scopeRegistry taxPolicyCatalog
  use arg request
  if request == .nil | \request~isA(.AccountingTaxRequest) then return .AccountingTaxResult~failure("TAX_REQUEST_REQUIRED", "AccountingTaxRequest required")
  if request~legalEntityId \= legalEntityId then return .AccountingTaxResult~failure("LEGAL_ENTITY_MISMATCH", request~legalEntityId || " != " || legalEntityId)
  registration = scopeRegistry~taxRegistration(request~taxRegistrationRef)
  if registration == .nil then return .AccountingTaxResult~failure("TAX_REGISTRATION_NOT_FOUND", request~taxRegistrationRef)
  if \registration~activeOn(request~taxPointDate) then return .AccountingTaxResult~failure("TAX_REGISTRATION_NOT_ACTIVE", request~taxRegistrationRef || ":" || request~taxPointDate)
  election = scopeRegistry~resolveTaxElection(registration~taxRegistrationId, request~taxPointDate)
  if election == .nil then return .AccountingTaxResult~failure("TAX_ELECTION_NOT_FOUND", registration~taxRegistrationId || ":" || request~taxPointDate)
  if request~calculationGranularity \= election~calculationGranularity then return .AccountingTaxResult~failure("TAX_CALCULATION_GRANULARITY_MISMATCH", request~calculationGranularity || " != " || election~calculationGranularity, election~taxElectionId, election~taxElectionIdentity)
  policy = taxPolicyCatalog~resolve(election~rulesetIdentity)
  if policy == .nil then return .AccountingTaxResult~failure("TAX_POLICY_NOT_FOUND", election~rulesetIdentity, election~taxElectionId, election~taxElectionIdentity)
  if policy~rulesetRef \= election~rulesetRef then return .AccountingTaxResult~failure("TAX_RULESET_REF_MISMATCH", policy~rulesetRef || " != " || election~rulesetRef, election~taxElectionId, election~taxElectionIdentity, policy~taxPolicyRef, policy~taxPolicyIdentity)

  signal on syntax name taxPolicyFailure
  decision = policy~determine(request, registration, election)
  signal off syntax
  if decision == .nil | \decision~isA(.AccountingTaxPolicyDecision) then return .AccountingTaxResult~failure("TAX_POLICY_DECISION_INVALID", policy~taxPolicyRef, election~taxElectionId, election~taxElectionIdentity, policy~taxPolicyRef, policy~taxPolicyIdentity)
  if \decision~ok then return .AccountingTaxResult~failure(decision~code, decision~detail, election~taxElectionId, election~taxElectionIdentity, policy~taxPolicyRef, policy~taxPolicyIdentity)
  determination = decision~determination
  if determination == .nil | \determination~isA(.AccountingTaxDetermination) then return .AccountingTaxResult~failure("TAX_DETERMINATION_INVALID", "AccountingTaxDetermination required", election~taxElectionId, election~taxElectionIdentity, policy~taxPolicyRef, policy~taxPolicyIdentity)
  binding = self~validateTaxDetermination(request, registration, election, policy, determination)
  if binding \= "" then return .AccountingTaxResult~failure("TAX_DETERMINATION_BINDING_INVALID", binding, election~taxElectionId, election~taxElectionIdentity, policy~taxPolicyRef, policy~taxPolicyIdentity)
  return .AccountingTaxResult~success(determination, election, policy)

taxPolicyFailure:
  signal off syntax
  return .AccountingTaxResult~failure("TAX_POLICY_EXECUTION_FAILED", condition("D"), election~taxElectionId, election~taxElectionIdentity, policy~taxPolicyRef, policy~taxPolicyIdentity)

::method determineTaxProjection
  use arg projection
  signal on syntax name taxProjectionInvalid
  request = .AccountingTaxRequestCodec~fromProjection(projection)
  signal off syntax
  return self~determineTax(request)
taxProjectionInvalid:
  signal off syntax
  return .AccountingTaxResult~failure("TAX_REQUEST_PROJECTION_INVALID", condition("D"))

::method transactTaxProjection
  use arg projection, accountingEventType = "TAX_DETERMINED"
  signal on syntax name taxPostingProjectionInvalid
  request = .AccountingTaxRequestCodec~fromProjection(projection)
  signal off syntax
  return self~transactTax(request, accountingEventType)
taxPostingProjectionInvalid:
  signal off syntax
  return .AccountingTaxPostingResult~failure("TAX_REQUEST_PROJECTION_INVALID", condition("D"))

/* End-to-end tax -> accounting path.  Once a determination has been posted,
 * durable replay is checked against the tax-request fingerprint before tax
 * policy dispatch.  A later ruleset therefore cannot reinterpret an already
 * accounted source tax event during recovery. */
::method transactTax
  expose nativeBook
  use arg request, accountingEventType = "TAX_DETERMINED"
  if request == .nil | \request~isA(.AccountingTaxRequest) then return .AccountingTaxPostingResult~failure("TAX_REQUEST_REQUIRED", "AccountingTaxRequest required")
  sourceRef = request~accountingSourceEventRef
  existing = nativeBook~sourceEntry(sourceRef)
  if existing \== .nil then do
    metadata = existing~metadata
    if \metadata~hasIndex("accounting.taxRequestFingerprint") then return .AccountingTaxPostingResult~failure("TAX_REQUEST_IDENTITY_UNAVAILABLE", sourceRef)
    if metadata["accounting.taxRequestFingerprint"]~string = request~fingerprint then return .AccountingTaxPostingResult~success("DUPLICATE", existing)
    return .AccountingTaxPostingResult~failure("SOURCE_TAX_EVENT_CONFLICT", sourceRef)
  end
  taxResult = self~determineTax(request)
  if \taxResult~ok then return .AccountingTaxPostingResult~failure(taxResult~errorCode, taxResult~message)
  determination = taxResult~determination
  tx = self~transact(determination~toAccountingEvent(accountingEventType))
  if \tx~ok then return .AccountingTaxPostingResult~failure(tx~errorCode, tx~message, determination)
  return .AccountingTaxPostingResult~success(tx~status, tx~entry, determination)


/* Settlement rounding is independent of tax calculation. The request names an
 * effective election explicitly; the election controls currency, quantum,
 * algorithm and applicable tender classes. */
::method determineSettlement
  expose legalEntityId scopeRegistry settlementPolicyCatalog
  use arg request
  if request == .nil | \request~isA(.AccountingSettlementRequest) then return .AccountingSettlementResult~failure("SETTLEMENT_REQUEST_REQUIRED", "AccountingSettlementRequest required")
  if request~legalEntityId \= legalEntityId then return .AccountingSettlementResult~failure("LEGAL_ENTITY_MISMATCH", request~legalEntityId || " != " || legalEntityId)
  election = scopeRegistry~settlementElection(request~settlementElectionRef)
  if election == .nil then return .AccountingSettlementResult~failure("SETTLEMENT_ELECTION_NOT_FOUND", request~settlementElectionRef)
  if \election~activeOn(request~settlementDate) then return .AccountingSettlementResult~failure("SETTLEMENT_ELECTION_NOT_ACTIVE", request~settlementElectionRef || ":" || request~settlementDate)
  if election~currency \= request~currency then return .AccountingSettlementResult~failure("SETTLEMENT_CURRENCY_MISMATCH", request~currency || " != " || election~currency)
  if \election~appliesToTender(request~tenderClass) then return .AccountingSettlementResult~failure("SETTLEMENT_TENDER_NOT_APPLICABLE", request~tenderClass)
  policy = settlementPolicyCatalog~resolve(election~rulesetIdentity)
  if policy == .nil then return .AccountingSettlementResult~failure("SETTLEMENT_POLICY_NOT_FOUND", election~rulesetIdentity)
  if policy~rulesetRef \= election~rulesetRef then return .AccountingSettlementResult~failure("SETTLEMENT_RULESET_REF_MISMATCH", policy~rulesetRef || " != " || election~rulesetRef)
  signal on syntax name settlementPolicyFailure
  decision = policy~determine(request, election)
  signal off syntax
  if decision == .nil | \decision~isA(.AccountingSettlementPolicyDecision) then return .AccountingSettlementResult~failure("SETTLEMENT_POLICY_DECISION_INVALID", policy~settlementPolicyRef)
  if \decision~ok then return .AccountingSettlementResult~failure(decision~code, decision~detail)
  determination = decision~determination
  if determination == .nil | \determination~isA(.AccountingSettlementDetermination) then return .AccountingSettlementResult~failure("SETTLEMENT_DETERMINATION_INVALID", "AccountingSettlementDetermination required")
  binding = self~validateSettlementDetermination(request, election, policy, determination)
  if binding \= "" then return .AccountingSettlementResult~failure("SETTLEMENT_DETERMINATION_BINDING_INVALID", binding)
  return .AccountingSettlementResult~success(determination)
settlementPolicyFailure:
  signal off syntax
  return .AccountingSettlementResult~failure("SETTLEMENT_POLICY_EXECUTION_FAILED", condition("D"))

::method determineSettlementProjection
  use arg projection
  signal on syntax name invalidSettlementProjection
  request = .AccountingSettlementRequestCodec~fromProjection(projection)
  signal off syntax
  return self~determineSettlement(request)
invalidSettlementProjection:
  signal off syntax
  return .AccountingSettlementResult~failure("SETTLEMENT_REQUEST_PROJECTION_INVALID", condition("D"))

::method transactSettlementProjection
  use arg projection, accountingEventType = "SETTLEMENT_ROUNDING_DETERMINED"
  signal on syntax name invalidSettlementPostingProjection
  request = .AccountingSettlementRequestCodec~fromProjection(projection)
  signal off syntax
  return self~transactSettlement(request, accountingEventType)
invalidSettlementPostingProjection:
  signal off syntax
  return .AccountingSettlementPostingResult~failure("SETTLEMENT_REQUEST_PROJECTION_INVALID", condition("D"))

::method transactSettlement
  expose nativeBook
  use arg request, accountingEventType = "SETTLEMENT_ROUNDING_DETERMINED"
  if request == .nil | \request~isA(.AccountingSettlementRequest) then return .AccountingSettlementPostingResult~failure("SETTLEMENT_REQUEST_REQUIRED", "AccountingSettlementRequest required")
  sourceRef = request~accountingSourceEventRef
  existing = nativeBook~sourceEntry(sourceRef)
  if existing \== .nil then do
    metadata = existing~metadata
    if \metadata~hasIndex("accounting.settlementRequestFingerprint") then return .AccountingSettlementPostingResult~failure("SETTLEMENT_REQUEST_IDENTITY_UNAVAILABLE", sourceRef)
    if metadata["accounting.settlementRequestFingerprint"]~string = request~fingerprint then return .AccountingSettlementPostingResult~success("DUPLICATE", existing)
    return .AccountingSettlementPostingResult~failure("SOURCE_SETTLEMENT_EVENT_CONFLICT", sourceRef)
  end
  result = self~determineSettlement(request)
  if \result~ok then return .AccountingSettlementPostingResult~failure(result~errorCode, result~message)
  determination = result~determination
  tx = self~transact(determination~toAccountingEvent(accountingEventType))
  if \tx~ok then return .AccountingSettlementPostingResult~failure(tx~errorCode, tx~message, determination)
  return .AccountingSettlementPostingResult~success(tx~status, tx~entry, determination)

/* Low-level controlled posting path retained for accountant/manual/migration
 * use. Operational engines should normally call transact(). */
::method post
  expose nativeBook scopeRegistry
  use arg draft
  validation = scopeRegistry~validateDraft(draft)
  if \validation~ok then return .AccountingPostingResult~failure(validation~errorCode, validation~message)
  return nativeBook~post(draft)

::method postDraft
  use arg draft
  return self~post(draft)

::method reportingView
  expose nativeBook
  use arg boundary, startDate = "", endDate = ""
  books = .array~of(nativeBook)
  return .AccountingReportingService~buildView(boundary, books, startDate, endDate)

::method reportingSnapshot
  expose nativeBook
  use arg snapshotId, boundary, startDate = "", endDate = "", sealRef = "", evidenceRefs = .nil, metadata = .nil
  books = .array~of(nativeBook)
  return .AccountingReportingService~sealSnapshot(snapshotId, boundary, books, startDate, endDate, sealRef, evidenceRefs, metadata)

::method entriesByCorrelation
  expose nativeBook
  use arg correlationRef
  return nativeBook~entriesByCorrelation(correlationRef)

::method importExternalStatement
  expose assessmentBook
  use arg statement
  return assessmentBook~importStatement(statement)

::method importCivicCompaniesHouseProjection
  use arg projection
  statement = .AccountingCivicCompaniesHouseImport~fromProjection(projection)
  return self~importExternalStatement(statement)

::method validatePolicyDraft private
  use arg event, policy, draft
  if draft~sourceEventRef \= event~sourceEventRef then return "sourceEventRef"
  if draft~correlationRef \= event~correlationRef then return "correlationRef"
  if draft~policyRef \= policy~policyRef then return "policyRef"
  if draft~policyIdentity \= policy~policyIdentity then return "policyIdentity"
  if draft~sourceEventFingerprint \= event~fingerprint then return "sourceEventFingerprint"
  if draft~eventType \= event~eventType then return "eventType"
  if draft~counterpartyEntityId \= event~counterpartyEntityId then return "counterpartyEntityId"

  draftEvidence = draft~evidenceRefs
  do evidence over event~evidenceRefs
    if \self~containsText(draftEvidence, evidence) then return "evidenceRefs"
  end
  if event~sourceAuthorityRef \= "" then do
    m = draft~metadata
    if \m~hasIndex("accounting.sourceAuthorityRef") then return "sourceAuthorityRef"
    if m["accounting.sourceAuthorityRef"]~string \= event~sourceAuthorityRef then return "sourceAuthorityRef"
  end
  return ""

::method validateTaxDetermination private
  use arg request, registration, election, policy, determination
  if determination~sourceTaxEventRef \= request~sourceTaxEventRef then return "sourceTaxEventRef"
  if determination~legalEntityId \= request~legalEntityId then return "legalEntityId"
  if determination~taxPointDate \= request~taxPointDate then return "taxPointDate"
  if determination~currency \= request~currency then return "currency"
  if determination~currencyMinorExponent \= request~currencyMinorExponent then return "currencyMinorExponent"
  if determination~taxableBasisMinor \= request~taxableBasisMinor then return "taxableBasisMinor"
  if determination~taxRegistrationRef \= registration~taxRegistrationId then return "taxRegistrationRef"
  if determination~taxElectionRef \= election~taxElectionId then return "taxElectionRef"
  if determination~taxElectionIdentity \= election~taxElectionIdentity then return "taxElectionIdentity"
  if determination~rulesetRef \= election~rulesetRef then return "rulesetRef"
  if determination~rulesetIdentity \= election~rulesetIdentity then return "rulesetIdentity"
  if determination~roundingAlgorithmRef \= election~roundingAlgorithmRef then return "roundingAlgorithmRef"
  if determination~calculationGranularity \= election~calculationGranularity then return "calculationGranularity"
  if determination~taxPolicyRef \= policy~taxPolicyRef then return "taxPolicyRef"
  if determination~taxPolicyIdentity \= policy~taxPolicyIdentity then return "taxPolicyIdentity"
  if determination~jurisdiction \= registration~jurisdiction then return "jurisdiction"
  if determination~taxType \= registration~taxType then return "taxType"
  if determination~requestFingerprint \= request~fingerprint then return "requestFingerprint"
  if determination~correlationRef \= request~correlationRef then return "correlationRef"
  if determination~counterpartyEntityId \= request~counterpartyEntityId then return "counterpartyEntityId"
  return ""


::method validateSettlementDetermination private
  use arg request, election, policy, determination
  numeric digits 50
  if determination~sourceSettlementEventRef \= request~sourceSettlementEventRef then return "sourceSettlementEventRef"
  if determination~legalEntityId \= request~legalEntityId then return "legalEntityId"
  if determination~settlementDate \= request~settlementDate then return "settlementDate"
  if determination~currency \= request~currency then return "currency"
  if determination~currencyMinorExponent \= request~currencyMinorExponent then return "currencyMinorExponent"
  if determination~accountedAmountMinor \= request~accountedAmountMinor then return "accountedAmountMinor"
  if determination~settlementElectionRef \= election~settlementElectionId then return "settlementElectionRef"
  if determination~settlementElectionIdentity \= election~settlementElectionIdentity then return "settlementElectionIdentity"
  if determination~rulesetRef \= election~rulesetRef then return "rulesetRef"
  if determination~rulesetIdentity \= election~rulesetIdentity then return "rulesetIdentity"
  if determination~roundingAlgorithmRef \= election~roundingAlgorithmRef then return "roundingAlgorithmRef"
  if determination~roundingQuantumMinor \= election~roundingQuantumMinor then return "roundingQuantumMinor"
  if determination~tenderClass \= request~tenderClass then return "tenderClass"
  if determination~jurisdiction \= election~jurisdiction then return "jurisdiction"
  if determination~settlementPolicyRef \= policy~settlementPolicyRef then return "settlementPolicyRef"
  if determination~settlementPolicyIdentity \= policy~settlementPolicyIdentity then return "settlementPolicyIdentity"
  if determination~requestFingerprint \= request~fingerprint then return "requestFingerprint"
  if determination~settledAmountMinor - determination~accountedAmountMinor \= determination~roundingDifferenceMinor then return "roundingDifferenceMinor"
  return ""

::method containsText private
  use arg values, target
  text = target~string
  do value over values
    if value~string = text then return .true
  end
  return .false

::requires "AccountingTransactions.cls"
::requires "AccountingScopes.cls"
::requires "AccountingReportingEvidence.cls"
::requires "AccountingReportingLifecycle.cls"
::requires "AccountingTax.cls"
::requires "AccountingSettlement.cls"
::requires "AccountingCivicImport.cls"
