/* Accounting Core v0.7 settlement-rounding contract. */
::options digits 50

::class AccountingSettlementRequest public
::attribute sourceSettlementEventRef get
::attribute legalEntityId get
::attribute settlementDate get
::attribute currency get
::attribute currencyMinorExponent get
::attribute accountedAmountMinor get
::attribute settlementElectionRef get
::attribute tenderClass get
::attribute correlationRef get
::attribute counterpartyEntityId get
::attribute sourceAuthorityRef get
::method init
  expose sourceSettlementEventRef legalEntityId settlementDate currency currencyMinorExponent accountedAmountMinor settlementElectionRef tenderClass correlationRef counterpartyEntityId sourceAuthorityRef evidenceRefs dimensions metadata
  use arg sourceArg, entityArg, dateArg, currencyArg, minorExponentArg, amountArg, electionArg, tenderArg, correlationArg = "", counterpartyArg = "", authorityArg = "", evidenceArg = .nil, dimensionsArg = .nil, metadataArg = .nil
  sourceSettlementEventRef = .AccountingUtil~requireText(sourceArg, "sourceSettlementEventRef")
  legalEntityId = .AccountingUtil~requireText(entityArg, "settlement legalEntityId")
  settlementDate = .AccountingUtil~requireDate(dateArg, "settlementDate")
  currency = .AccountingUtil~requireText(currencyArg, "settlement currency")~upper
  currencyMinorExponent = .AccountingUtil~requireWholeNonNegative(minorExponentArg, "currency minor exponent")
  accountedAmountMinor = .AccountingUtil~requireWholeSigned(amountArg, "accountedAmountMinor")
  settlementElectionRef = .AccountingUtil~requireText(electionArg, "settlementElectionRef")
  tenderClass = .AccountingUtil~requireText(tenderArg, "tenderClass")~upper
  correlationRef = correlationArg~string~strip
  counterpartyEntityId = counterpartyArg~string~strip
  sourceAuthorityRef = authorityArg~string~strip
  evidenceRefs = .AccountingUtil~copyArray(evidenceArg)
  dimensions = .AccountingUtil~copyDirectory(dimensionsArg)
  metadata = .AccountingUtil~copyDirectory(metadataArg)
::method evidenceRefs
  expose evidenceRefs
  return .AccountingUtil~copyArray(evidenceRefs)
::method dimensions
  expose dimensions
  return .AccountingUtil~copyDirectory(dimensions)
::method metadata
  expose metadata
  return .AccountingUtil~copyDirectory(metadata)
::method fingerprint
  expose sourceSettlementEventRef legalEntityId settlementDate currency currencyMinorExponent accountedAmountMinor settlementElectionRef tenderClass correlationRef counterpartyEntityId sourceAuthorityRef evidenceRefs dimensions metadata
  return sourceSettlementEventRef || "|" || legalEntityId || "|" || settlementDate || "|" || currency || "|" || currencyMinorExponent || "|" || accountedAmountMinor || "|" || settlementElectionRef || "|" || tenderClass || "|" || correlationRef || "|" || counterpartyEntityId || "|" || sourceAuthorityRef || "|" || .AccountingUtil~canonicalArray(evidenceRefs) || "|" || .AccountingUtil~canonicalDirectory(dimensions) || "|" || .AccountingUtil~canonicalDirectory(metadata)
::method accountingSourceEventRef
  expose settlementElectionRef sourceSettlementEventRef
  return "SETTLE:" || settlementElectionRef || ":" || sourceSettlementEventRef


::class AccountingSettlementRequestCodec public
::constant CONTRACT "accounting.settlement.request/0.1"
::method toProjection class
  use arg r
  if r == .nil | \r~isA(.AccountingSettlementRequest) then raise syntax 93.900 additional("AccountingSettlementRequest required")
  p=.directory~new
  p["contract_generation"]=self~CONTRACT
  p["source_settlement_event_ref"]=r~sourceSettlementEventRef
  p["legal_entity_id"]=r~legalEntityId
  p["settlement_date"]=r~settlementDate
  p["currency"]=r~currency
  p["currency_minor_exponent"]=r~currencyMinorExponent
  p["accounted_amount_minor"]=r~accountedAmountMinor
  p["settlement_election_ref"]=r~settlementElectionRef
  p["tender_class"]=r~tenderClass
  p["correlation_ref"]=r~correlationRef
  p["counterparty_entity_id"]=r~counterpartyEntityId
  p["source_authority_ref"]=r~sourceAuthorityRef
  p["evidence_refs"]=r~evidenceRefs
  p["dimensions"]=r~dimensions
  p["metadata"]=r~metadata
  p["request_fingerprint"]=r~fingerprint
  return p
::method fromProjection class
  use arg p
  if p == .nil | \p~isA(.Directory) then raise syntax 93.900 additional("Settlement request projection Directory required")
  if self~required(p,"contract_generation") \= self~CONTRACT then raise syntax 93.900 additional("Unsupported settlement request contract")
  r=.AccountingSettlementRequest~new(self~required(p,"source_settlement_event_ref"),self~required(p,"legal_entity_id"),self~required(p,"settlement_date"),self~required(p,"currency"),self~required(p,"currency_minor_exponent"),self~required(p,"accounted_amount_minor"),self~required(p,"settlement_election_ref"),self~required(p,"tender_class"),self~optional(p,"correlation_ref"),self~optional(p,"counterparty_entity_id"),self~optional(p,"source_authority_ref"),self~arrayValue(p,"evidence_refs"),self~directoryValue(p,"dimensions"),self~directoryValue(p,"metadata"))
  if p~hasIndex("request_fingerprint") then if p["request_fingerprint"]~string \= r~fingerprint then raise syntax 93.900 additional("Settlement request projection fingerprint mismatch")
  return r
::method required class private
  use arg p,key
  if \p~hasIndex(key) | p[key] == .nil then raise syntax 93.900 additional("Missing settlement request field: " || key)
  return p[key]~string
::method optional class private
  use arg p,key
  if \p~hasIndex(key) | p[key] == .nil then return ""
  return p[key]~string
::method arrayValue class private
  use arg p,key
  if \p~hasIndex(key) | p[key] == .nil then return .array~new
  if \p[key]~isA(.Array) then raise syntax 93.900 additional(key || " must be an Array")
  return p[key]
::method directoryValue class private
  use arg p,key
  if \p~hasIndex(key) | p[key] == .nil then return .directory~new
  if \p[key]~isA(.Directory) then raise syntax 93.900 additional(key || " must be a Directory")
  return p[key]

::class AccountingSettlementMath public
::method roundToQuantum class
  use arg amountArg, quantumArg, modeArg
  numeric digits 50
  amount = .AccountingUtil~requireWholeSigned(amountArg, "settlement amount")
  quantum = .AccountingTaxMath~requirePositiveWhole(quantumArg, "settlement quantum")
  units = .AccountingTaxMath~roundRatio(amount, quantum, modeArg)
  return .AccountingTaxMath~safeMultiply(units, quantum, "settlement quantum multiplication")

::class AccountingSettlementDetermination public
::attribute sourceSettlementEventRef get
::attribute legalEntityId get
::attribute settlementDate get
::attribute currency get
::attribute currencyMinorExponent get
::attribute accountedAmountMinor get
::attribute settledAmountMinor get
::attribute roundingDifferenceMinor get
::attribute settlementElectionRef get
::attribute settlementElectionIdentity get
::attribute settlementPolicyRef get
::attribute settlementPolicyIdentity get
::attribute rulesetRef get
::attribute rulesetIdentity get
::attribute roundingAlgorithmRef get
::attribute roundingQuantumMinor get
::attribute tenderClass get
::attribute jurisdiction get
::attribute requestFingerprint get
::attribute correlationRef get
::attribute counterpartyEntityId get
::method init
  expose sourceSettlementEventRef legalEntityId settlementDate currency currencyMinorExponent accountedAmountMinor settledAmountMinor roundingDifferenceMinor settlementElectionRef settlementElectionIdentity settlementPolicyRef settlementPolicyIdentity rulesetRef rulesetIdentity roundingAlgorithmRef roundingQuantumMinor tenderClass jurisdiction requestFingerprint correlationRef counterpartyEntityId evidenceRefs dimensions metadata
  use arg sourceArg, entityArg, dateArg, currencyArg, minorExponentArg, accountedArg, settledArg, differenceArg, electionArg, electionIdentityArg, policyRefArg, policyIdentityArg, rulesetRefArg, rulesetIdentityArg, roundingArg, quantumArg, tenderArg, jurisdictionArg, requestFingerprintArg, correlationArg = "", counterpartyArg = "", evidenceArg = .nil, dimensionsArg = .nil, metadataArg = .nil
  sourceSettlementEventRef = .AccountingUtil~requireText(sourceArg, "sourceSettlementEventRef")
  legalEntityId = .AccountingUtil~requireText(entityArg, "settlement determination legalEntityId")
  settlementDate = .AccountingUtil~requireDate(dateArg, "settlementDate")
  currency = .AccountingUtil~requireText(currencyArg, "currency")~upper
  currencyMinorExponent = .AccountingUtil~requireWholeNonNegative(minorExponentArg, "currency minor exponent")
  accountedAmountMinor = .AccountingUtil~requireWholeSigned(accountedArg, "accountedAmountMinor")
  settledAmountMinor = .AccountingUtil~requireWholeSigned(settledArg, "settledAmountMinor")
  roundingDifferenceMinor = .AccountingUtil~requireWholeSigned(differenceArg, "roundingDifferenceMinor")
  settlementElectionRef = .AccountingUtil~requireText(electionArg, "settlementElectionRef")
  settlementElectionIdentity = .AccountingUtil~requireText(electionIdentityArg, "settlementElectionIdentity")
  settlementPolicyRef = .AccountingUtil~requireText(policyRefArg, "settlementPolicyRef")
  settlementPolicyIdentity = .AccountingUtil~requireText(policyIdentityArg, "settlementPolicyIdentity")
  rulesetRef = .AccountingUtil~requireText(rulesetRefArg, "rulesetRef")
  rulesetIdentity = .AccountingUtil~requireText(rulesetIdentityArg, "rulesetIdentity")
  roundingAlgorithmRef = .AccountingUtil~requireText(roundingArg, "roundingAlgorithmRef")
  roundingQuantumMinor = .AccountingTaxMath~requirePositiveWhole(quantumArg, "roundingQuantumMinor")
  tenderClass = .AccountingUtil~requireText(tenderArg, "tenderClass")~upper
  jurisdiction = .AccountingUtil~requireText(jurisdictionArg, "jurisdiction")~upper
  requestFingerprint = .AccountingUtil~requireText(requestFingerprintArg, "requestFingerprint")
  correlationRef = correlationArg~string~strip
  counterpartyEntityId = counterpartyArg~string~strip
  evidenceRefs = .AccountingUtil~copyArray(evidenceArg)
  dimensions = .AccountingUtil~copyDirectory(dimensionsArg)
  metadata = .AccountingUtil~copyDirectory(metadataArg)
::method evidenceRefs
  expose evidenceRefs
  return .AccountingUtil~copyArray(evidenceRefs)
::method dimensions
  expose dimensions
  return .AccountingUtil~copyDirectory(dimensions)
::method metadata
  expose metadata
  return .AccountingUtil~copyDirectory(metadata)
::method fingerprint
  expose sourceSettlementEventRef legalEntityId settlementDate currency currencyMinorExponent accountedAmountMinor settledAmountMinor roundingDifferenceMinor settlementElectionRef settlementElectionIdentity settlementPolicyRef settlementPolicyIdentity rulesetRef rulesetIdentity roundingAlgorithmRef roundingQuantumMinor tenderClass jurisdiction requestFingerprint correlationRef counterpartyEntityId evidenceRefs dimensions metadata
  return sourceSettlementEventRef || "|" || legalEntityId || "|" || settlementDate || "|" || currency || "|" || currencyMinorExponent || "|" || accountedAmountMinor || "|" || settledAmountMinor || "|" || roundingDifferenceMinor || "|" || settlementElectionRef || "|" || settlementElectionIdentity || "|" || settlementPolicyRef || "|" || settlementPolicyIdentity || "|" || rulesetRef || "|" || rulesetIdentity || "|" || roundingAlgorithmRef || "|" || roundingQuantumMinor || "|" || tenderClass || "|" || jurisdiction || "|" || requestFingerprint || "|" || correlationRef || "|" || counterpartyEntityId || "|" || .AccountingUtil~canonicalArray(evidenceRefs) || "|" || .AccountingUtil~canonicalDirectory(dimensions) || "|" || .AccountingUtil~canonicalDirectory(metadata)
::method toAccountingEvent
  expose sourceSettlementEventRef legalEntityId settlementDate currency currencyMinorExponent accountedAmountMinor settledAmountMinor roundingDifferenceMinor settlementElectionRef settlementElectionIdentity settlementPolicyRef settlementPolicyIdentity rulesetRef rulesetIdentity roundingAlgorithmRef roundingQuantumMinor tenderClass jurisdiction requestFingerprint correlationRef counterpartyEntityId evidenceRefs dimensions metadata
  use arg eventTypeArg = "SETTLEMENT_ROUNDING_DETERMINED", sourceAuthorityArg = "ACCOUNTING.SETTLEMENT.DETERMINATION"
  payload = .directory~new
  payload["currency"] = currency
  payload["currencyMinorExponent"] = currencyMinorExponent
  payload["accountedAmountMinor"] = accountedAmountMinor
  payload["settledAmountMinor"] = settledAmountMinor
  payload["roundingDifferenceMinor"] = roundingDifferenceMinor
  payload["settlementElectionRef"] = settlementElectionRef
  payload["settlementElectionIdentity"] = settlementElectionIdentity
  payload["settlementPolicyRef"] = settlementPolicyRef
  payload["settlementPolicyIdentity"] = settlementPolicyIdentity
  payload["rulesetRef"] = rulesetRef
  payload["rulesetIdentity"] = rulesetIdentity
  payload["roundingAlgorithmRef"] = roundingAlgorithmRef
  payload["roundingQuantumMinor"] = roundingQuantumMinor
  payload["tenderClass"] = tenderClass
  payload["jurisdiction"] = jurisdiction
  journalDimensions = .AccountingUtil~copyDirectory(dimensions)
  journalDimensions[.AccountingDimensionKeys~SETTLEMENT_ELECTION_REF] = settlementElectionRef
  journalDimensions[.AccountingDimensionKeys~SETTLEMENT_ELECTION_IDENTITY] = settlementElectionIdentity
  payload["accountingDimensions"] = journalDimensions
  eventMetadata = .AccountingUtil~copyDirectory(metadata)
  eventMetadata["accounting.settlementRequestFingerprint"] = requestFingerprint
  eventMetadata["accounting.settlementDeterminationFingerprint"] = self~fingerprint
  eventMetadata["accounting.settlementPolicyIdentity"] = settlementPolicyIdentity
  eventMetadata["accounting.settlementRulesetIdentity"] = rulesetIdentity
  return .AccountingEvent~new("SETTLE:" || settlementElectionRef || ":" || sourceSettlementEventRef, legalEntityId, eventTypeArg, settlementDate, correlationRef, counterpartyEntityId, sourceAuthorityArg, payload, evidenceRefs, eventMetadata)


::class AccountingSettlementDeterminationCodec public
::constant CONTRACT "accounting.settlement.determination/0.1"
::method toProjection class
  use arg d
  if d == .nil | \d~isA(.AccountingSettlementDetermination) then raise syntax 93.900 additional("AccountingSettlementDetermination required")
  p=.directory~new
  p["contract_generation"]=self~CONTRACT
  p["source_settlement_event_ref"]=d~sourceSettlementEventRef
  p["legal_entity_id"]=d~legalEntityId
  p["settlement_date"]=d~settlementDate
  p["currency"]=d~currency
  p["currency_minor_exponent"]=d~currencyMinorExponent
  p["accounted_amount_minor"]=d~accountedAmountMinor
  p["settled_amount_minor"]=d~settledAmountMinor
  p["rounding_difference_minor"]=d~roundingDifferenceMinor
  p["settlement_election_ref"]=d~settlementElectionRef
  p["settlement_election_identity"]=d~settlementElectionIdentity
  p["settlement_policy_ref"]=d~settlementPolicyRef
  p["settlement_policy_identity"]=d~settlementPolicyIdentity
  p["ruleset_ref"]=d~rulesetRef
  p["ruleset_identity"]=d~rulesetIdentity
  p["rounding_algorithm_ref"]=d~roundingAlgorithmRef
  p["rounding_quantum_minor"]=d~roundingQuantumMinor
  p["tender_class"]=d~tenderClass
  p["jurisdiction"]=d~jurisdiction
  p["request_fingerprint"]=d~requestFingerprint
  p["correlation_ref"]=d~correlationRef
  p["counterparty_entity_id"]=d~counterpartyEntityId
  p["evidence_refs"]=d~evidenceRefs
  p["dimensions"]=d~dimensions
  p["metadata"]=d~metadata
  p["determination_fingerprint"]=d~fingerprint
  return p
::method fromProjection class
  use arg p
  if p == .nil | \p~isA(.Directory) then raise syntax 93.900 additional("Settlement determination projection Directory required")
  if self~required(p,"contract_generation") \= self~CONTRACT then raise syntax 93.900 additional("Unsupported settlement determination contract")
  d=.AccountingSettlementDetermination~new(self~required(p,"source_settlement_event_ref"),self~required(p,"legal_entity_id"),self~required(p,"settlement_date"),self~required(p,"currency"),self~required(p,"currency_minor_exponent"),self~required(p,"accounted_amount_minor"),self~required(p,"settled_amount_minor"),self~required(p,"rounding_difference_minor"),self~required(p,"settlement_election_ref"),self~required(p,"settlement_election_identity"),self~required(p,"settlement_policy_ref"),self~required(p,"settlement_policy_identity"),self~required(p,"ruleset_ref"),self~required(p,"ruleset_identity"),self~required(p,"rounding_algorithm_ref"),self~required(p,"rounding_quantum_minor"),self~required(p,"tender_class"),self~required(p,"jurisdiction"),self~required(p,"request_fingerprint"),self~optional(p,"correlation_ref"),self~optional(p,"counterparty_entity_id"),self~arrayValue(p,"evidence_refs"),self~directoryValue(p,"dimensions"),self~directoryValue(p,"metadata"))
  if p~hasIndex("determination_fingerprint") then if p["determination_fingerprint"]~string \= d~fingerprint then raise syntax 93.900 additional("Settlement determination projection fingerprint mismatch")
  return d
::method required class private
  use arg p,key
  if \p~hasIndex(key) | p[key] == .nil then raise syntax 93.900 additional("Missing settlement determination field: " || key)
  return p[key]~string
::method optional class private
  use arg p,key
  if \p~hasIndex(key) | p[key] == .nil then return ""
  return p[key]~string
::method arrayValue class private
  use arg p,key
  if \p~hasIndex(key) | p[key] == .nil then return .array~new
  if \p[key]~isA(.Array) then raise syntax 93.900 additional(key || " must be an Array")
  return p[key]
::method directoryValue class private
  use arg p,key
  if \p~hasIndex(key) | p[key] == .nil then return .directory~new
  if \p[key]~isA(.Directory) then raise syntax 93.900 additional(key || " must be a Directory")
  return p[key]

::class AccountingSettlementPolicyDecision public
::attribute ok get
::attribute code get
::attribute detail get
::attribute determination get
::method accept class
  use arg determinationArg
  return self~new(.true, "ACCEPT", "", determinationArg)
::method reject class
  use arg codeArg, detailArg = ""
  return self~new(.false, codeArg, detailArg, .nil)
::method init
  expose ok code detail determination
  use arg okArg, codeArg, detailArg, determinationArg
  ok = okArg; code = codeArg~string; detail = detailArg~string; determination = determinationArg

::class AccountingSettlementPolicy public
::attribute settlementPolicyRef get
::attribute settlementPolicyIdentity get
::attribute rulesetRef get
::attribute rulesetIdentity get
::method init
  expose settlementPolicyRef settlementPolicyIdentity rulesetRef rulesetIdentity
  use arg policyRefArg, policyIdentityArg, rulesetRefArg, rulesetIdentityArg
  settlementPolicyRef = .AccountingUtil~requireText(policyRefArg, "settlementPolicyRef")
  settlementPolicyIdentity = .AccountingUtil~requireText(policyIdentityArg, "settlementPolicyIdentity")
  rulesetRef = .AccountingUtil~requireText(rulesetRefArg, "settlement rulesetRef")
  rulesetIdentity = .AccountingUtil~requireText(rulesetIdentityArg, "settlement rulesetIdentity")
::method determine
  use arg request, election
  return .AccountingSettlementPolicyDecision~reject("SETTLEMENT_POLICY_NOT_IMPLEMENTED", self~settlementPolicyRef)
::method newDetermination
  expose settlementPolicyRef settlementPolicyIdentity rulesetRef rulesetIdentity
  use arg request, election, settledAmountArg, evidenceArg = .nil, dimensionsArg = .nil, metadataArg = .nil
  numeric digits 50
  settled = .AccountingUtil~requireWholeSigned(settledAmountArg, "settledAmountMinor")
  difference = settled - request~accountedAmountMinor
  evidence = request~evidenceRefs
  if evidenceArg \== .nil then do item over evidenceArg; evidence~append(item); end
  dimensions = request~dimensions
  if dimensionsArg \== .nil then do key over dimensionsArg; dimensions[key] = dimensionsArg[key]; end
  metadata = request~metadata
  if metadataArg \== .nil then do key over metadataArg; metadata[key] = metadataArg[key]; end
  return .AccountingSettlementDetermination~new(request~sourceSettlementEventRef, request~legalEntityId, request~settlementDate, request~currency, request~currencyMinorExponent, request~accountedAmountMinor, settled, difference, election~settlementElectionId, election~settlementElectionIdentity, settlementPolicyRef, settlementPolicyIdentity, rulesetRef, rulesetIdentity, election~roundingAlgorithmRef, election~roundingQuantumMinor, request~tenderClass, election~jurisdiction, request~fingerprint, request~correlationRef, request~counterpartyEntityId, evidence, dimensions, metadata)

::class AccountingSettlementPolicyCatalog public
::method init
  expose byRuleset identities
  byRuleset = .directory~new; identities = .directory~new
::method register
  expose byRuleset identities
  use arg policy
  if policy == .nil | \policy~isA(.AccountingSettlementPolicy) then raise syntax 93.900 additional("AccountingSettlementPolicy required")
  if policy~class~package~digits < .AccountingBuild~NUMERIC_DIGITS then raise syntax 93.900 additional("Settlement policy package must declare ::OPTIONS DIGITS 50")
  if byRuleset~hasIndex(policy~rulesetIdentity) then raise syntax 93.900 additional("Duplicate settlement ruleset identity: " || policy~rulesetIdentity)
  if identities~hasIndex(policy~settlementPolicyIdentity) then raise syntax 93.900 additional("Duplicate settlement policy identity: " || policy~settlementPolicyIdentity)
  byRuleset[policy~rulesetIdentity] = policy; identities[policy~settlementPolicyIdentity] = policy
  return policy
::method resolve
  expose byRuleset
  use arg identityArg
  return byRuleset[identityArg~string]

::class AccountingSettlementResult public
::attribute ok get
::attribute status get
::attribute determination get
::attribute errorCode get
::attribute message get
::method success class
  use arg determinationArg
  return self~new(.true, "DETERMINED", determinationArg, "", "")
::method failure class
  use arg codeArg, messageArg = ""
  return self~new(.false, "REJECTED", .nil, codeArg, messageArg)
::method init
  expose ok status determination errorCode message
  use arg okArg, statusArg, determinationArg, codeArg, messageArg
  ok = okArg; status = statusArg~string; determination = determinationArg; errorCode = codeArg~string; message = messageArg~string

::class AccountingSettlementPostingResult public
::attribute ok get
::attribute status get
::attribute entry get
::attribute determination get
::attribute errorCode get
::attribute message get
::method success class
  use arg statusArg, entryArg, determinationArg = .nil
  return self~new(.true, statusArg, entryArg, determinationArg, "", "")
::method failure class
  use arg codeArg, messageArg = "", determinationArg = .nil
  return self~new(.false, "REJECTED", .nil, determinationArg, codeArg, messageArg)
::method init
  expose ok status entry determination errorCode message
  use arg okArg, statusArg, entryArg, determinationArg, codeArg, messageArg
  ok=okArg; status=statusArg~string; entry=entryArg; determination=determinationArg; errorCode=codeArg~string; message=messageArg~string

::requires "AccountingTax.cls"
::requires "AccountingScopes.cls"
