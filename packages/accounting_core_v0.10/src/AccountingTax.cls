/*
 * Accounting Core v0.6 generic tax-determination contract.
 *
 * This package deliberately does NOT contain UK VAT, Australian GST, US sales
 * tax or any other jurisdiction's substantive rules.  It provides exact
 * rational arithmetic, reusable quantization/rounding mechanics, tax request
 * and determination contracts, and dispatch through an exact tax ruleset
 * identity selected by the entity's effective TaxElection.
 */

::options digits 50

::class AccountingTaxMath public
::method requirePositiveWhole class
  use arg value, label
  text = .AccountingUtil~requireWholeNonNegative(value, label)
  if text = "0" then raise syntax 93.900 additional(label || " must be greater than zero")
  return text

::method safeMultiply class
  use arg leftArg, rightArg, label = "tax multiplication"
  numeric digits 50
  left = .AccountingUtil~requireWholeSigned(leftArg, label || " left")
  right = .AccountingUtil~requireWholeSigned(rightArg, label || " right")
  if left = "0" | right = "0" then return "0"
  if left = "1" then return right
  if right = "1" then return left
  if left = "-1" then return self~negate(right)
  if right = "-1" then return self~negate(left)
  leftDigits = self~digitCount(left)
  rightDigits = self~digitCount(right)
  /* Conservative guard: if the operand lengths could require more than the
   * module's 50-digit arithmetic profile, refuse rather than round. */
  if leftDigits + rightDigits > .AccountingBuild~NUMERIC_DIGITS then -
    raise syntax 93.900 additional(label || " exceeds accounting numeric digits 50 intermediate precision")
  return .AccountingUtil~requireWholeSigned(left * right, label || " result")

::method power10 class
  use arg exponentArg
  numeric digits 50
  exponent = .AccountingUtil~requireWholeNonNegative(exponentArg, "decimal exponent")
  if exponent > 49 then raise syntax 93.900 additional("decimal exponent exceeds digits 50")
  text = "1"
  do exponent
    text = text || "0"
  end
  return text

::method digitCount class
  use arg value
  text = value~string~strip
  if text~substr(1,1) = "-" | text~substr(1,1) = "+" then text = text~substr(2)
  do while text~length > 1 & text~substr(1,1) = "0"
    text = text~substr(2)
  end
  return text~length

::method negate class
  use arg value
  text = .AccountingUtil~requireWholeSigned(value, "integer")
  if text = "0" then return "0"
  if text~substr(1,1) = "-" then return text~substr(2)
  return "-" || text

::method roundRatio class
  use arg numeratorArg, denominatorArg, modeArg
  numeric digits 50
  numerator = .AccountingUtil~requireWholeSigned(numeratorArg, "rounding numerator")
  denominator = self~requirePositiveWhole(denominatorArg, "rounding denominator")
  mode = .AccountingUtil~requireText(modeArg, "rounding mode")~upper
  if wordpos(mode, "TRUNCATE HALF_UP HALF_EVEN FLOOR CEILING") = 0 then raise syntax 93.900 additional("Unsupported tax rounding mode: " || mode)

  negative = numerator~substr(1,1) = "-"
  if negative then magnitude = numerator~substr(2)
  else magnitude = numerator
  quotient = magnitude % denominator
  remainder = magnitude // denominator
  increment = 0

  select
    when mode = "TRUNCATE" then increment = 0
    when mode = "HALF_UP" then do
      threshold = denominator % 2
      if denominator // 2 > 0 then threshold += 1
      if remainder > 0 & remainder >= threshold then increment = 1
    end
    when mode = "HALF_EVEN" then do
      half = denominator % 2
      if denominator // 2 > 0 then do
        if remainder > half then increment = 1
      end
      else do
        if remainder > half then increment = 1
        else if remainder = half & quotient // 2 = 1 then increment = 1
      end
    end
    when mode = "FLOOR" then do
      if negative & remainder > 0 then increment = 1
    end
    when mode = "CEILING" then do
      if \negative & remainder > 0 then increment = 1
    end
  end

  roundedMagnitude = quotient + increment
  if roundedMagnitude = 0 then return "0"
  if negative then return "-" || roundedMagnitude
  return roundedMagnitude~string

::class AccountingTaxExactAmount public
::attribute numerator get
::attribute denominator get
::method init
  expose numerator denominator
  use arg numeratorArg, denominatorArg = 1
  numerator = .AccountingUtil~requireWholeSigned(numeratorArg, "tax exact numerator")
  denominator = .AccountingTaxMath~requirePositiveWhole(denominatorArg, "tax exact denominator")

::method fromBasisRate class
  use arg basisMinorArg, rateNumeratorArg, rateDenominatorArg
  numerator = .AccountingTaxMath~safeMultiply(.AccountingUtil~requireWholeSigned(basisMinorArg, "taxable basis minor"), .AccountingUtil~requireWholeSigned(rateNumeratorArg, "tax rate numerator"), "tax basis/rate multiplication")
  denominator = .AccountingTaxMath~requirePositiveWhole(rateDenominatorArg, "tax rate denominator")
  return self~new(numerator, denominator)

::method quantizeDenominator
  expose numerator denominator
  use arg targetDenominatorArg, modeArg
  target = .AccountingTaxMath~requirePositiveWhole(targetDenominatorArg, "target quantization denominator")
  scaledNumerator = .AccountingTaxMath~safeMultiply(numerator, target, "tax quantization")
  rounded = .AccountingTaxMath~roundRatio(scaledNumerator, denominator, modeArg)
  return .AccountingTaxExactAmount~new(rounded, target)

/* majorDecimalPlaces refers to digits after the major currency decimal point.
 * GBP/AUD normally use minorExponent=2; JPY normally uses 0.  For example,
 * quantizing GBP tax to 4 major decimal places means hundredths of a penny. */
::method quantizeMajor
  use arg currencyMinorExponentArg, majorDecimalPlacesArg, modeArg
  minorExponent = .AccountingUtil~requireWholeNonNegative(currencyMinorExponentArg, "currency minor exponent")
  majorPlaces = .AccountingUtil~requireWholeNonNegative(majorDecimalPlacesArg, "major decimal places")
  if majorPlaces < minorExponent then raise syntax 93.900 additional("major decimal places cannot be less than currency minor exponent")
  subMinorPlaces = majorPlaces - minorExponent
  return self~quantizeDenominator(.AccountingTaxMath~power10(subMinorPlaces), modeArg)

::method toMinorUnits
  expose numerator denominator
  use arg modeArg
  return .AccountingTaxMath~roundRatio(numerator, denominator, modeArg)

::method fingerprint
  expose numerator denominator
  return numerator || "/" || denominator

::class AccountingTaxRequest public
::attribute sourceTaxEventRef get
::attribute legalEntityId get
::attribute taxPointDate get
::attribute currency get
::attribute currencyMinorExponent get
::attribute taxableBasisMinor get
::attribute taxRegistrationRef get
::attribute calculationGranularity get
::attribute correlationRef get
::attribute counterpartyEntityId get
::attribute sourceAuthorityRef get
::method init
  expose sourceTaxEventRef legalEntityId taxPointDate currency currencyMinorExponent taxableBasisMinor taxRegistrationRef calculationGranularity correlationRef counterpartyEntityId sourceAuthorityRef evidenceRefs dimensions payload metadata
  use arg sourceArg, entityArg, dateArg, currencyArg, minorExponentArg, basisMinorArg, registrationArg, granularityArg, correlationArg = "", counterpartyArg = "", authorityArg = "", evidenceArg = .nil, dimensionsArg = .nil, payloadArg = .nil, metadataArg = .nil
  sourceTaxEventRef = .AccountingUtil~requireText(sourceArg, "sourceTaxEventRef")
  legalEntityId = .AccountingUtil~requireText(entityArg, "tax request legalEntityId")
  taxPointDate = .AccountingUtil~requireDate(dateArg, "taxPointDate")
  currency = .AccountingUtil~requireText(currencyArg, "tax currency")~upper
  currencyMinorExponent = .AccountingUtil~requireWholeNonNegative(minorExponentArg, "currency minor exponent")
  if currencyMinorExponent > 9 then raise syntax 93.900 additional("currency minor exponent is unreasonably large")
  taxableBasisMinor = .AccountingUtil~requireWholeSigned(basisMinorArg, "taxableBasisMinor")
  taxRegistrationRef = .AccountingUtil~requireText(registrationArg, "taxRegistrationRef")
  calculationGranularity = .AccountingUtil~requireText(granularityArg, "calculationGranularity")~upper
  correlationRef = correlationArg~string~strip
  counterpartyEntityId = counterpartyArg~string~strip
  sourceAuthorityRef = authorityArg~string~strip
  evidenceRefs = .AccountingUtil~copyArray(evidenceArg)
  dimensions = .AccountingUtil~copyDirectory(dimensionsArg)
  payload = .AccountingUtil~copyDirectory(payloadArg)
  metadata = .AccountingUtil~copyDirectory(metadataArg)

::method evidenceRefs
  expose evidenceRefs
  return .AccountingUtil~copyArray(evidenceRefs)
::method dimensions
  expose dimensions
  return .AccountingUtil~copyDirectory(dimensions)
::method payload
  expose payload
  return .AccountingUtil~copyDirectory(payload)
::method metadata
  expose metadata
  return .AccountingUtil~copyDirectory(metadata)
::method value
  expose payload
  use arg key, defaultValue = .nil
  if payload~hasIndex(key~string) then return payload[key~string]
  return defaultValue
::method fingerprint
  expose sourceTaxEventRef legalEntityId taxPointDate currency currencyMinorExponent taxableBasisMinor taxRegistrationRef calculationGranularity correlationRef counterpartyEntityId sourceAuthorityRef evidenceRefs dimensions payload metadata
  return sourceTaxEventRef || "|" || legalEntityId || "|" || taxPointDate || "|" || currency || "|" || currencyMinorExponent || "|" || taxableBasisMinor || "|" || taxRegistrationRef || "|" || calculationGranularity || "|" || correlationRef || "|" || counterpartyEntityId || "|" || sourceAuthorityRef || "|" || -
    .AccountingUtil~canonicalArray(evidenceRefs) || "|" || .AccountingUtil~canonicalDirectory(dimensions) || "|" || .AccountingUtil~canonicalDirectory(payload) || "|" || .AccountingUtil~canonicalDirectory(metadata)
::method accountingSourceEventRef
  expose sourceTaxEventRef taxRegistrationRef
  return "TAXDET:" || taxRegistrationRef || ":" || sourceTaxEventRef

::class AccountingTaxRequestCodec public
::constant CONTRACT "accounting.tax.request/0.1"
::method toProjection class
  use arg request
  if request == .nil | \request~isA(.AccountingTaxRequest) then raise syntax 93.900 additional("AccountingTaxRequest required")
  p = .directory~new
  p["contract_generation"] = self~CONTRACT
  p["source_tax_event_ref"] = request~sourceTaxEventRef
  p["legal_entity_id"] = request~legalEntityId
  p["tax_point_date"] = request~taxPointDate
  p["currency"] = request~currency
  p["currency_minor_exponent"] = request~currencyMinorExponent
  p["taxable_basis_minor"] = request~taxableBasisMinor
  p["tax_registration_ref"] = request~taxRegistrationRef
  p["calculation_granularity"] = request~calculationGranularity
  p["correlation_ref"] = request~correlationRef
  p["counterparty_entity_id"] = request~counterpartyEntityId
  p["source_authority_ref"] = request~sourceAuthorityRef
  p["evidence_refs"] = request~evidenceRefs
  p["dimensions"] = request~dimensions
  p["payload"] = request~payload
  p["metadata"] = request~metadata
  return p
::method fromProjection class
  use arg p
  if p == .nil | \p~isA(.Directory) then raise syntax 93.900 additional("Tax request projection Directory required")
  if self~required(p, "contract_generation") \= self~CONTRACT then raise syntax 93.900 additional("Unsupported tax request contract")
  return .AccountingTaxRequest~new(self~required(p,"source_tax_event_ref"), self~required(p,"legal_entity_id"), self~required(p,"tax_point_date"), self~required(p,"currency"), self~required(p,"currency_minor_exponent"), self~required(p,"taxable_basis_minor"), self~required(p,"tax_registration_ref"), self~required(p,"calculation_granularity"), -
    self~optional(p,"correlation_ref"), self~optional(p,"counterparty_entity_id"), self~optional(p,"source_authority_ref"), self~arrayValue(p,"evidence_refs"), self~directoryValue(p,"dimensions"), self~directoryValue(p,"payload"), self~directoryValue(p,"metadata"))
::method required class private
  use arg p, key
  if \p~hasIndex(key) | p[key] == .nil then raise syntax 93.900 additional("Missing tax request field: " || key)
  return p[key]~string
::method optional class private
  use arg p, key
  if \p~hasIndex(key) | p[key] == .nil then return ""
  return p[key]~string
::method arrayValue class private
  use arg p, key
  if \p~hasIndex(key) | p[key] == .nil then return .array~new
  if \p[key]~isA(.Array) then raise syntax 93.900 additional(key || " must be an Array")
  return p[key]
::method directoryValue class private
  use arg p, key
  if \p~hasIndex(key) | p[key] == .nil then return .directory~new
  if \p[key]~isA(.Directory) then raise syntax 93.900 additional(key || " must be a Directory")
  return p[key]

::class AccountingTaxDetermination public
::attribute sourceTaxEventRef get
::attribute legalEntityId get
::attribute taxPointDate get
::attribute currency get
::attribute currencyMinorExponent get
::attribute taxableBasisMinor get
::attribute taxMinor get
::attribute taxRegistrationRef get
::attribute taxElectionRef get
::attribute taxElectionIdentity get
::attribute taxPolicyRef get
::attribute taxPolicyIdentity get
::attribute rulesetRef get
::attribute rulesetIdentity get
::attribute roundingAlgorithmRef get
::attribute calculationGranularity get
::attribute taxCode get
::attribute calculationMethodRef get
::attribute jurisdiction get
::attribute taxType get
::attribute preRoundingNumerator get
::attribute preRoundingDenominator get
::attribute requestFingerprint get
::attribute correlationRef get
::attribute counterpartyEntityId get
::method init
  expose sourceTaxEventRef legalEntityId taxPointDate currency currencyMinorExponent taxableBasisMinor taxMinor taxRegistrationRef taxElectionRef taxElectionIdentity taxPolicyRef taxPolicyIdentity rulesetRef rulesetIdentity roundingAlgorithmRef calculationGranularity taxCode calculationMethodRef jurisdiction taxType preRoundingNumerator preRoundingDenominator requestFingerprint correlationRef counterpartyEntityId evidenceRefs dimensions metadata
  use arg sourceArg, entityArg, dateArg, currencyArg, minorExponentArg, basisArg, taxMinorArg, registrationArg, electionArg, electionIdentityArg, policyRefArg, policyIdentityArg, rulesetRefArg, rulesetIdentityArg, roundingArg, granularityArg, taxCodeArg, methodArg, jurisdictionArg, taxTypeArg, preNumeratorArg, preDenominatorArg, requestFingerprintArg, correlationArg = "", counterpartyArg = "", evidenceArg = .nil, dimensionsArg = .nil, metadataArg = .nil
  sourceTaxEventRef = .AccountingUtil~requireText(sourceArg, "determination sourceTaxEventRef")
  legalEntityId = .AccountingUtil~requireText(entityArg, "determination legalEntityId")
  taxPointDate = .AccountingUtil~requireDate(dateArg, "determination taxPointDate")
  currency = .AccountingUtil~requireText(currencyArg, "determination currency")~upper
  currencyMinorExponent = .AccountingUtil~requireWholeNonNegative(minorExponentArg, "determination currency minor exponent")
  taxableBasisMinor = .AccountingUtil~requireWholeSigned(basisArg, "determination taxableBasisMinor")
  taxMinor = .AccountingUtil~requireWholeSigned(taxMinorArg, "determination taxMinor")
  taxRegistrationRef = .AccountingUtil~requireText(registrationArg, "determination taxRegistrationRef")
  taxElectionRef = .AccountingUtil~requireText(electionArg, "determination taxElectionRef")
  taxElectionIdentity = .AccountingUtil~requireText(electionIdentityArg, "determination taxElectionIdentity")
  taxPolicyRef = .AccountingUtil~requireText(policyRefArg, "determination taxPolicyRef")
  taxPolicyIdentity = .AccountingUtil~requireText(policyIdentityArg, "determination taxPolicyIdentity")
  rulesetRef = .AccountingUtil~requireText(rulesetRefArg, "determination rulesetRef")
  rulesetIdentity = .AccountingUtil~requireText(rulesetIdentityArg, "determination rulesetIdentity")
  roundingAlgorithmRef = .AccountingUtil~requireText(roundingArg, "determination roundingAlgorithmRef")
  calculationGranularity = .AccountingUtil~requireText(granularityArg, "determination calculationGranularity")~upper
  taxCode = .AccountingUtil~requireText(taxCodeArg, "determination taxCode")
  calculationMethodRef = .AccountingUtil~requireText(methodArg, "determination calculationMethodRef")
  jurisdiction = .AccountingUtil~requireText(jurisdictionArg, "determination jurisdiction")~upper
  taxType = .AccountingUtil~requireText(taxTypeArg, "determination taxType")~upper
  preRoundingNumerator = .AccountingUtil~requireWholeSigned(preNumeratorArg, "determination pre-round numerator")
  preRoundingDenominator = .AccountingTaxMath~requirePositiveWhole(preDenominatorArg, "determination pre-round denominator")
  requestFingerprint = .AccountingUtil~requireText(requestFingerprintArg, "determination requestFingerprint")
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
::method exactPreRoundingAmount
  expose preRoundingNumerator preRoundingDenominator
  return .AccountingTaxExactAmount~new(preRoundingNumerator, preRoundingDenominator)
::method fingerprint
  expose sourceTaxEventRef legalEntityId taxPointDate currency currencyMinorExponent taxableBasisMinor taxMinor taxRegistrationRef taxElectionRef taxElectionIdentity taxPolicyRef taxPolicyIdentity rulesetRef rulesetIdentity roundingAlgorithmRef calculationGranularity taxCode calculationMethodRef jurisdiction taxType preRoundingNumerator preRoundingDenominator requestFingerprint correlationRef counterpartyEntityId evidenceRefs dimensions metadata
  return sourceTaxEventRef || "|" || legalEntityId || "|" || taxPointDate || "|" || currency || "|" || currencyMinorExponent || "|" || taxableBasisMinor || "|" || taxMinor || "|" || taxRegistrationRef || "|" || taxElectionRef || "|" || taxElectionIdentity || "|" || taxPolicyRef || "|" || taxPolicyIdentity || "|" || rulesetRef || "|" || rulesetIdentity || "|" || roundingAlgorithmRef || "|" || calculationGranularity || "|" || taxCode || "|" || calculationMethodRef || "|" || jurisdiction || "|" || taxType || "|" || preRoundingNumerator || "/" || preRoundingDenominator || "|" || requestFingerprint || "|" || correlationRef || "|" || counterpartyEntityId || "|" || .AccountingUtil~canonicalArray(evidenceRefs) || "|" || .AccountingUtil~canonicalDirectory(dimensions) || "|" || .AccountingUtil~canonicalDirectory(metadata)

::method toAccountingEvent
  expose sourceTaxEventRef legalEntityId taxPointDate currency currencyMinorExponent taxableBasisMinor taxMinor taxRegistrationRef taxElectionRef taxElectionIdentity taxPolicyRef taxPolicyIdentity rulesetRef rulesetIdentity roundingAlgorithmRef calculationGranularity taxCode calculationMethodRef jurisdiction taxType preRoundingNumerator preRoundingDenominator requestFingerprint correlationRef counterpartyEntityId evidenceRefs dimensions metadata
  use arg eventTypeArg = "TAX_DETERMINED", sourceAuthorityArg = "ACCOUNTING.TAX.DETERMINATION"
  payload = .directory~new
  payload["taxableBasisMinor"] = taxableBasisMinor
  payload["taxMinor"] = taxMinor
  payload["currency"] = currency
  payload["currencyMinorExponent"] = currencyMinorExponent
  payload["taxRegistrationRef"] = taxRegistrationRef
  payload["taxElectionRef"] = taxElectionRef
  payload["taxElectionIdentity"] = taxElectionIdentity
  payload["taxPolicyRef"] = taxPolicyRef
  payload["taxPolicyIdentity"] = taxPolicyIdentity
  payload["rulesetRef"] = rulesetRef
  payload["rulesetIdentity"] = rulesetIdentity
  payload["roundingAlgorithmRef"] = roundingAlgorithmRef
  payload["calculationGranularity"] = calculationGranularity
  payload["taxCode"] = taxCode
  payload["calculationMethodRef"] = calculationMethodRef
  payload["jurisdiction"] = jurisdiction
  payload["taxType"] = taxType
  payload["preRoundingNumerator"] = preRoundingNumerator
  payload["preRoundingDenominator"] = preRoundingDenominator
  journalDimensions = .AccountingUtil~copyDirectory(dimensions)
  journalDimensions[.AccountingDimensionKeys~TAX_REGISTRATION_REF] = taxRegistrationRef
  journalDimensions[.AccountingDimensionKeys~TAX_ELECTION_REF] = taxElectionRef
  journalDimensions[.AccountingDimensionKeys~TAX_ELECTION_IDENTITY] = taxElectionIdentity
  payload["accountingDimensions"] = journalDimensions

  eventMetadata = .AccountingUtil~copyDirectory(metadata)
  eventMetadata["accounting.taxRequestFingerprint"] = requestFingerprint
  eventMetadata["accounting.taxDeterminationFingerprint"] = self~fingerprint
  eventMetadata["accounting.taxPolicyIdentity"] = taxPolicyIdentity
  eventMetadata["accounting.taxRulesetIdentity"] = rulesetIdentity
  return .AccountingEvent~new("TAXDET:" || taxRegistrationRef || ":" || sourceTaxEventRef, legalEntityId, eventTypeArg, taxPointDate, correlationRef, counterpartyEntityId, sourceAuthorityArg, payload, evidenceRefs, eventMetadata)

::class AccountingTaxDeterminationCodec public
::constant CONTRACT "accounting.tax.determination/0.1"
::method toProjection class
  use arg d
  if d == .nil | \d~isA(.AccountingTaxDetermination) then raise syntax 93.900 additional("AccountingTaxDetermination required")
  p = .directory~new
  p["contract_generation"] = self~CONTRACT
  p["source_tax_event_ref"] = d~sourceTaxEventRef
  p["legal_entity_id"] = d~legalEntityId
  p["tax_point_date"] = d~taxPointDate
  p["currency"] = d~currency
  p["currency_minor_exponent"] = d~currencyMinorExponent
  p["taxable_basis_minor"] = d~taxableBasisMinor
  p["tax_minor"] = d~taxMinor
  p["tax_registration_ref"] = d~taxRegistrationRef
  p["tax_election_ref"] = d~taxElectionRef
  p["tax_election_identity"] = d~taxElectionIdentity
  p["tax_policy_ref"] = d~taxPolicyRef
  p["tax_policy_identity"] = d~taxPolicyIdentity
  p["ruleset_ref"] = d~rulesetRef
  p["ruleset_identity"] = d~rulesetIdentity
  p["rounding_algorithm_ref"] = d~roundingAlgorithmRef
  p["calculation_granularity"] = d~calculationGranularity
  p["tax_code"] = d~taxCode
  p["calculation_method_ref"] = d~calculationMethodRef
  p["jurisdiction"] = d~jurisdiction
  p["tax_type"] = d~taxType
  p["pre_rounding_numerator"] = d~preRoundingNumerator
  p["pre_rounding_denominator"] = d~preRoundingDenominator
  p["request_fingerprint"] = d~requestFingerprint
  p["correlation_ref"] = d~correlationRef
  p["counterparty_entity_id"] = d~counterpartyEntityId
  p["evidence_refs"] = d~evidenceRefs
  p["dimensions"] = d~dimensions
  p["metadata"] = d~metadata
  p["determination_fingerprint"] = d~fingerprint
  return p
::method fromProjection class
  use arg p
  if p == .nil | \p~isA(.Directory) then raise syntax 93.900 additional("Tax determination projection Directory required")
  if self~required(p,"contract_generation") \= self~CONTRACT then raise syntax 93.900 additional("Unsupported tax determination contract")
  d = .AccountingTaxDetermination~new(self~required(p,"source_tax_event_ref"), self~required(p,"legal_entity_id"), self~required(p,"tax_point_date"), self~required(p,"currency"), self~required(p,"currency_minor_exponent"), self~required(p,"taxable_basis_minor"), self~required(p,"tax_minor"), self~required(p,"tax_registration_ref"), self~required(p,"tax_election_ref"), self~required(p,"tax_election_identity"), self~required(p,"tax_policy_ref"), self~required(p,"tax_policy_identity"), self~required(p,"ruleset_ref"), self~required(p,"ruleset_identity"), self~required(p,"rounding_algorithm_ref"), self~required(p,"calculation_granularity"), self~required(p,"tax_code"), self~required(p,"calculation_method_ref"), self~required(p,"jurisdiction"), self~required(p,"tax_type"), self~required(p,"pre_rounding_numerator"), self~required(p,"pre_rounding_denominator"), self~required(p,"request_fingerprint"), self~optional(p,"correlation_ref"), self~optional(p,"counterparty_entity_id"), self~arrayValue(p,"evidence_refs"), self~directoryValue(p,"dimensions"), self~directoryValue(p,"metadata"))
  if p~hasIndex("determination_fingerprint") then do
    if p["determination_fingerprint"]~string \= d~fingerprint then raise syntax 93.900 additional("Tax determination projection fingerprint mismatch")
  end
  return d
::method required class private
  use arg p, key
  if \p~hasIndex(key) | p[key] == .nil then raise syntax 93.900 additional("Missing tax determination field: " || key)
  return p[key]~string
::method optional class private
  use arg p, key
  if \p~hasIndex(key) | p[key] == .nil then return ""
  return p[key]~string
::method arrayValue class private
  use arg p, key
  if \p~hasIndex(key) | p[key] == .nil then return .array~new
  if \p[key]~isA(.Array) then raise syntax 93.900 additional(key || " must be an Array")
  return p[key]
::method directoryValue class private
  use arg p, key
  if \p~hasIndex(key) | p[key] == .nil then return .directory~new
  if \p[key]~isA(.Directory) then raise syntax 93.900 additional(key || " must be a Directory")
  return p[key]

::class AccountingTaxPolicyDecision public
::attribute ok get
::attribute code get
::attribute detail get
::attribute determination get
::attribute rationale get
::method accept class
  use arg determinationArg, rationaleArg = ""
  return self~new(.true, "ACCEPT", "", determinationArg, rationaleArg)
::method reject class
  use arg codeArg, detailArg = "", rationaleArg = ""
  return self~new(.false, codeArg, detailArg, .nil, rationaleArg)
::method init
  expose ok code detail determination rationale
  use arg okArg, codeArg, detailArg, determinationArg, rationaleArg
  ok = okArg
  code = codeArg~string
  detail = detailArg~string
  determination = determinationArg
  rationale = rationaleArg~string

::class AccountingTaxPolicy public
::attribute taxPolicyRef get
::attribute taxPolicyIdentity get
::attribute rulesetRef get
::attribute rulesetIdentity get
::method init
  expose taxPolicyRef taxPolicyIdentity rulesetRef rulesetIdentity
  use arg policyRefArg, policyIdentityArg, rulesetRefArg, rulesetIdentityArg
  taxPolicyRef = .AccountingUtil~requireText(policyRefArg, "taxPolicyRef")
  taxPolicyIdentity = .AccountingUtil~requireText(policyIdentityArg, "taxPolicyIdentity")
  rulesetRef = .AccountingUtil~requireText(rulesetRefArg, "tax rulesetRef")
  rulesetIdentity = .AccountingUtil~requireText(rulesetIdentityArg, "tax rulesetIdentity")
::method determine
  use arg request, registration, election
  return .AccountingTaxPolicyDecision~reject("TAX_POLICY_NOT_IMPLEMENTED", self~taxPolicyRef)
::method newDetermination
  expose taxPolicyRef taxPolicyIdentity rulesetRef rulesetIdentity
  use arg request, registration, election, taxMinorArg, taxCodeArg, methodRefArg, exactAmount, evidenceArg = .nil, dimensionsArg = .nil, metadataArg = .nil
  if request == .nil | \request~isA(.AccountingTaxRequest) then raise syntax 93.900 additional("AccountingTaxRequest required")
  if registration == .nil | \registration~isA(.AccountingTaxRegistration) then raise syntax 93.900 additional("AccountingTaxRegistration required")
  if election == .nil | \election~isA(.AccountingTaxElection) then raise syntax 93.900 additional("AccountingTaxElection required")
  if exactAmount == .nil | \exactAmount~isA(.AccountingTaxExactAmount) then raise syntax 93.900 additional("AccountingTaxExactAmount required")
  evidence = request~evidenceRefs
  if evidenceArg \== .nil then do item over evidenceArg
    self~appendUnique(evidence, item)
  end
  dimensions = request~dimensions
  if dimensionsArg \== .nil then do key over dimensionsArg
    dimensions[key] = dimensionsArg[key]
  end
  metadata = request~metadata
  if metadataArg \== .nil then do key over metadataArg
    metadata[key] = metadataArg[key]
  end
  return .AccountingTaxDetermination~new(request~sourceTaxEventRef, request~legalEntityId, request~taxPointDate, request~currency, request~currencyMinorExponent, request~taxableBasisMinor, taxMinorArg, registration~taxRegistrationId, election~taxElectionId, election~taxElectionIdentity, taxPolicyRef, taxPolicyIdentity, rulesetRef, rulesetIdentity, election~roundingAlgorithmRef, election~calculationGranularity, taxCodeArg, methodRefArg, registration~jurisdiction, registration~taxType, exactAmount~numerator, exactAmount~denominator, request~fingerprint, request~correlationRef, request~counterpartyEntityId, evidence, dimensions, metadata)
::method appendUnique private
  use arg target, value
  text = value~string
  do existing over target
    if existing~string = text then return
  end
  target~append(value)

::class AccountingTaxPolicyCatalog public
::method init
  expose byRuleset policyIdentities
  byRuleset = .directory~new
  policyIdentities = .directory~new
::method register
  expose byRuleset policyIdentities
  use arg policy
  if policy == .nil | \policy~isA(.AccountingTaxPolicy) then raise syntax 93.900 additional("AccountingTaxPolicy required")
  packageDigits = policy~class~package~digits
  if packageDigits < .AccountingBuild~NUMERIC_DIGITS then raise syntax 93.900 additional("Tax policy package must declare ::OPTIONS DIGITS 50; actual=" || packageDigits)
  if byRuleset~hasIndex(policy~rulesetIdentity) then raise syntax 93.900 additional("Duplicate tax ruleset identity: " || policy~rulesetIdentity)
  if policyIdentities~hasIndex(policy~taxPolicyIdentity) then raise syntax 93.900 additional("Duplicate tax policy identity: " || policy~taxPolicyIdentity)
  byRuleset[policy~rulesetIdentity] = policy
  policyIdentities[policy~taxPolicyIdentity] = policy
  return policy
::method resolve
  expose byRuleset
  use arg rulesetIdentityArg
  return byRuleset[rulesetIdentityArg~string]

::class AccountingTaxResult public
::attribute ok get
::attribute status get
::attribute determination get
::attribute errorCode get
::attribute message get
::attribute taxElectionRef get
::attribute taxElectionIdentity get
::attribute taxPolicyRef get
::attribute taxPolicyIdentity get
::method success class
  use arg determinationArg, electionArg, policyArg
  return self~new(.true, "DETERMINED", determinationArg, "", "", electionArg~taxElectionId, electionArg~taxElectionIdentity, policyArg~taxPolicyRef, policyArg~taxPolicyIdentity)
::method failure class
  use arg codeArg, messageArg = "", electionRefArg = "", electionIdentityArg = "", policyRefArg = "", policyIdentityArg = ""
  return self~new(.false, "REJECTED", .nil, codeArg, messageArg, electionRefArg, electionIdentityArg, policyRefArg, policyIdentityArg)
::method init
  expose ok status determination errorCode message taxElectionRef taxElectionIdentity taxPolicyRef taxPolicyIdentity
  use arg okArg, statusArg, determinationArg, codeArg, messageArg, electionRefArg, electionIdentityArg, policyRefArg, policyIdentityArg
  ok = okArg; status = statusArg~string; determination = determinationArg; errorCode = codeArg~string; message = messageArg~string
  taxElectionRef = electionRefArg~string; taxElectionIdentity = electionIdentityArg~string; taxPolicyRef = policyRefArg~string; taxPolicyIdentity = policyIdentityArg~string

::class AccountingTaxPostingResult public
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
  ok = okArg; status = statusArg~string; entry = entryArg; determination = determinationArg; errorCode = codeArg~string; message = messageArg~string

::requires "AccountingTransactions.cls"
::requires "AccountingScopes.cls"
