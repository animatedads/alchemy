/* All Japan Insurance v0.3 -> regulated intermediary provider-event adapter. */

::class RIDAllJapanInsuranceAdapter public
::constant PROVIDER_ENTITY "ALL_JAPAN_INSURANCE_CO_LTD"
::constant PROVIDER_SYSTEM "ALL_JAPAN_POLICY_ADMIN"

::method validateProduct private
  use arg ridProduct, ajiProductCode
  if ridProduct == .nil then return .RIDResult~failure("RID_PRODUCT_REQUIRED")
  if ridProduct~productFamily <> "INSURANCE" then return .RIDResult~failure("RID_PRODUCT_NOT_INSURANCE")
  if ridProduct~providerIdentity~legalEntityId <> self~PROVIDER_ENTITY then return .RIDResult~failure("AJI_PROVIDER_ENTITY_MISMATCH")
  if ridProduct~providerIdentity~providerSystem <> self~PROVIDER_SYSTEM then return .RIDResult~failure("AJI_PROVIDER_SYSTEM_MISMATCH")
  if .RIDCanonical~token(ridProduct~productId) <> .RIDCanonical~token(ajiProductCode) then return .RIDResult~failure("AJI_PRODUCT_CODE_MISMATCH")
  return .RIDResult~success(ridProduct)

::method fromDecision
  use arg decision, ridProduct, sequence, eventId = "", sourceRef = ""
  if decision == .nil then return .RIDResult~failure("AJI_DECISION_REQUIRED")
  vr = self~validateProduct(ridProduct, decision~productCode)
  if \vr~ok then return vr
  select
    when decision~outcome = .AllJapanInsuranceBuild~DECISION_ACCEPT then status = "APPROVED"
    when decision~outcome = .AllJapanInsuranceBuild~DECISION_DECLINE then status = "DECLINED"
    when decision~outcome = .AllJapanInsuranceBuild~DECISION_REFER then status = "UNDERWRITER_REVIEW"
    otherwise return .RIDResult~failure("AJI_DECISION_OUTCOME_UNMAPPED", decision~outcome)
  end
  if eventId~string = "" then eventId = "AJI-DECISION-" || decision~decisionId
  if sourceRef~string = "" then sourceRef = "AJI:DECISION:" || decision~decisionId || ":" || decision~evidenceRef
  e = .RIDProviderStatusEvidence~new(eventId, self~PROVIDER_ENTITY, self~PROVIDER_SYSTEM, decision~submissionId, ridProduct~productSemanticIdentity, sequence, status, decision~decidedAt, sourceRef)
  return .RIDResult~success(e)

::method fromQuote
  use arg quote, ridProduct, sequence, eventId = "", sourceRef = ""
  if quote == .nil then return .RIDResult~failure("AJI_QUOTE_REQUIRED")
  vr = self~validateProduct(ridProduct, quote~productCode)
  if \vr~ok then return vr
  if eventId~string = "" then eventId = "AJI-QUOTE-" || quote~quoteId
  if sourceRef~string = "" then sourceRef = "AJI:QUOTE:" || quote~quoteId
  e = .RIDProviderStatusEvidence~new(eventId, self~PROVIDER_ENTITY, self~PROVIDER_SYSTEM, quote~submissionId, ridProduct~productSemanticIdentity, sequence, "QUOTED", quote~issuedAt, sourceRef)
  return .RIDResult~success(e)

::method fromPolicy
  use arg policy, ridProduct, providerCaseRef, sequence, eventId = "", sourceRef = ""
  if policy == .nil then return .RIDResult~failure("AJI_POLICY_REQUIRED")
  vr = self~validateProduct(ridProduct, policy~productCode)
  if \vr~ok then return vr
  if eventId~string = "" then eventId = "AJI-POLICY-" || policy~policyId
  if sourceRef~string = "" then sourceRef = "AJI:POLICY:" || policy~policyId
  e = .RIDProviderStatusEvidence~new(eventId, self~PROVIDER_ENTITY, self~PROVIDER_SYSTEM, providerCaseRef, ridProduct~productSemanticIdentity, sequence, "BOUND", policy~boundAt, sourceRef)
  return .RIDResult~success(e)

::requires "RegulatedIntermediaryDistribution.cls"
::requires "AllJapanInsurance.cls"
