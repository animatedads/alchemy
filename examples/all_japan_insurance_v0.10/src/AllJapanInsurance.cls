/* AllJapanInsurance.cls - All Japan Insurance direct insurance authority v0.10
 *
 * Acquisition invariant:
 * Federation group ownership does not imply underwriting, policy, claims,
 * customer-balance or VMM authority inheritance.
 */

::options digits 50

::class AllJapanInsuranceBuild public
::constant RELEASE "0.10"
::constant API_VERSION "all.japan.insurance/0.10"
::constant OWNER_GROUP "FEDERATION"
::constant INSURER "ALL_JAPAN_INSURANCE"
::constant LEGAL_ENTITY_ID "ALL_JAPAN_INSURANCE_CO_LTD"
::constant FUNCTIONAL_CURRENCY "JPY"
::constant PRODUCT_PI "PI"
::constant PRODUCT_HOME "HOME"
::constant PRODUCT_CAR "CAR"
::constant DECISION_ACCEPT "ACCEPT"
::constant DECISION_DECLINE "DECLINE"
::constant DECISION_REFER "REFER"
::constant POLICY_ACTIVE "ACTIVE"
::constant CLAIM_OPEN "OPEN"
::constant ROLE_DISTRIBUTION "DISTRIBUTION_CHANNEL"
::constant ROLE_UNDERWRITER "UNDERWRITER"
::constant ROLE_RATING_ENGINE "RATING_ENGINE"
::constant ROLE_RATE_OVERRIDE "RATE_OVERRIDE"
::constant ROLE_POLICY "POLICY_AUTHORITY"
::constant ROLE_CLAIMS_INTAKE "CLAIMS_INTAKE"
::constant ROLE_CLAIMS_ASSESSOR "CLAIMS_ASSESSOR"
::constant ROLE_CLAIMS_PAYMENT "CLAIMS_PAYMENT_AUTHORITY"
::constant ROLE_POLICY_TRANSACTION "POLICY_TRANSACTION_AUTHORITY"
::constant ROLE_PREMIUM_BILLING "PREMIUM_BILLING_AUTHORITY"
::constant ROLE_COMMISSION_SETTLEMENT "COMMISSION_SETTLEMENT_AUTHORITY"
::constant ROLE_CREDIT_CONTROL "PREMIUM_CREDIT_CONTROL_AUTHORITY"
::constant ROLE_TAX_SETTLEMENT "PREMIUM_TAX_SETTLEMENT_AUTHORITY"
::constant TRANSACTION_NEW_BUSINESS "NEW_BUSINESS"
::constant TRANSACTION_RENEWAL "RENEWAL"

::class AllJapanInsuranceResult public
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

::class AllJapanInsuranceCanonical public
::method token class
  use arg value
  if value == .nil then return ""
  return value~string~strip~upper
::method positiveWhole class
  use arg value
  if value == .nil then return .false
  signal on syntax name badNumber
  n = value + 0
  signal off syntax
  if n <= 0 then return .false
  if n \= n~trunc then return .false
  return .true
badNumber:
  signal off syntax
  return .false

::class AllJapanInsuranceCurrency public
/* Monetary amounts throughout AJI are exact integer minor units.  Currency
 * exponent is metadata, never inferred from decimal arithmetic.  For JPY the
 * minor unit is one yen (exponent 0). */
::method minorUnitDigits class
  use arg codeArg
  code=.AllJapanInsuranceCanonical~token(codeArg)
  select
    when code="JPY" then return 0
    when code="GBP" | code="USD" | code="EUR" | code="AUD" then return 2
    otherwise return -1
  end
::method supported class
  use arg codeArg
  return self~minorUnitDigits(codeArg)>=0
::method denominator class
  use arg codeArg
  digits=self~minorUnitDigits(codeArg)
  if digits<0 then return 0
  if digits=0 then return 1
  if digits=1 then return 10
  if digits=2 then return 100
  return 10**digits
::method validateMinorAmount class
  use arg codeArg, amountArg
  code=.AllJapanInsuranceCanonical~token(codeArg)
  if \self~supported(code) then return .AllJapanInsuranceResult~failure("CURRENCY_UNSUPPORTED",code)
  if amountArg==.nil then return .AllJapanInsuranceResult~failure("MONEY_MINOR_AMOUNT_INVALID",code)
  signal on syntax name badMoney
  n=amountArg+0
  signal off syntax
  if n<0 | n\=n~trunc then return .AllJapanInsuranceResult~failure("MONEY_MINOR_AMOUNT_INVALID",code)
  return .AllJapanInsuranceResult~success
badMoney:
  signal off syntax
  return .AllJapanInsuranceResult~failure("MONEY_MINOR_AMOUNT_INVALID",code)
::method canonicalText class
  use arg codeArg
  code=.AllJapanInsuranceCanonical~token(codeArg)
  digits=self~minorUnitDigits(code)
  if digits<0 then return ""
  return "AJI-CURRENCY/0.7|" || code || "|MINOR_DIGITS=" || digits

::class AllJapanInsuranceActor public
::attribute principalId get
::method init
  expose principalId roles
  use arg principalIdArg, rolesArg = .nil
  principalId = principalIdArg~string
  roles = .set~new
  if rolesArg <> .nil then do role over rolesArg
    roles~put(.AllJapanInsuranceCanonical~token(role))
  end
::method hasRole
  expose roles
  use arg role
  return roles~hasIndex(.AllJapanInsuranceCanonical~token(role))

::class AllJapanInsuranceProduct public
::attribute code get
::attribute policyRef get
::method init
  expose code policyRef
  use arg codeArg, policyRefArg
  code = .AllJapanInsuranceCanonical~token(codeArg)
  policyRef = policyRefArg~string
::method canonicalText
  expose code policyRef
  return "AJI-PRODUCT/1" || '0a'x || "CODE=" || code || '0a'x || "POLICY_REF=" || policyRef || '0a'x
::method semanticIdentity
  return self~canonicalText

::class AllJapanInsuranceCatalogue public
::method init
  expose products
  products = .table~new
  products[.AllJapanInsuranceBuild~PRODUCT_PI] = .AllJapanInsuranceProduct~new("PI", "AJI-PRODUCT-PI/0.1")
  products[.AllJapanInsuranceBuild~PRODUCT_HOME] = .AllJapanInsuranceProduct~new("HOME", "AJI-PRODUCT-HOME/0.1")
  products[.AllJapanInsuranceBuild~PRODUCT_CAR] = .AllJapanInsuranceProduct~new("CAR", "AJI-PRODUCT-CAR/0.1")
::method product
  expose products
  use arg code
  return products[.AllJapanInsuranceCanonical~token(code)]
::method contains
  expose products
  use arg code
  return products~hasIndex(.AllJapanInsuranceCanonical~token(code))
::method productCodes
  expose products
  out = .array~new
  do code over products~allIndexes
    out~append(code)
  end
  out~sort
  return out

::class AllJapanInsuranceRiskSubmission public
::attribute submissionId get
::attribute productCode get
::attribute partyRef get
::attribute riskRef get
::attribute jurisdiction get
::attribute submittedAt get
::attribute facts get
::method init
  expose submissionId productCode partyRef riskRef jurisdiction submittedAt facts
  use arg submissionIdArg, productCodeArg, partyRefArg, riskRefArg, jurisdictionArg, submittedAtArg, factsArg = .nil
  submissionId = submissionIdArg~string
  productCode = .AllJapanInsuranceCanonical~token(productCodeArg)
  partyRef = partyRefArg~string
  riskRef = riskRefArg~string
  jurisdiction = .AllJapanInsuranceCanonical~token(jurisdictionArg)
  submittedAt = submittedAtArg~string
  if factsArg == .nil then facts = .table~new
  else facts = factsArg

::class AllJapanInsuranceUnderwritingDecision public
::attribute decisionId get
::attribute submissionId get
::attribute productCode get
::attribute outcome get
::attribute policyRef get
::attribute decidedBy get
::attribute decidedAt get
::attribute evidenceRef get
::method init
  expose decisionId submissionId productCode outcome policyRef decidedBy decidedAt evidenceRef
  use arg decisionIdArg, submissionIdArg, productCodeArg, outcomeArg, policyRefArg, decidedByArg, decidedAtArg, evidenceRefArg = ""
  decisionId = decisionIdArg~string
  submissionId = submissionIdArg~string
  productCode = .AllJapanInsuranceCanonical~token(productCodeArg)
  outcome = .AllJapanInsuranceCanonical~token(outcomeArg)
  policyRef = policyRefArg~string
  decidedBy = decidedByArg~string
  decidedAt = decidedAtArg~string
  evidenceRef = evidenceRefArg~string

::class AllJapanInsuranceQuote public
::attribute quoteId get
::attribute decisionId get
::attribute submissionId get
::attribute productCode get
::attribute premiumMinor get
::attribute currency get
::attribute validUntil get
::attribute issuedAt get
::attribute ratingId get
::attribute ratingPlanRef get
::attribute ratingFunctionRef get
::attribute priceSource get
::attribute overrideReason get
::method init
  expose quoteId decisionId submissionId productCode premiumMinor currency validUntil issuedAt ratingId ratingPlanRef ratingFunctionRef priceSource overrideReason
  use arg quoteIdArg, decisionIdArg, submissionIdArg, productCodeArg, premiumMinorArg, currencyArg, validUntilArg, issuedAtArg, ratingIdArg = "", ratingPlanRefArg = "", priceSourceArg = "RATED", overrideReasonArg = "", ratingFunctionRefArg = ""
  quoteId = quoteIdArg~string
  decisionId = decisionIdArg~string
  submissionId = submissionIdArg~string
  productCode = .AllJapanInsuranceCanonical~token(productCodeArg)
  premiumMinor = premiumMinorArg + 0
  currency = .AllJapanInsuranceCanonical~token(currencyArg)
  validUntil = validUntilArg~string
  issuedAt = issuedAtArg~string
  ratingId = ratingIdArg~string
  ratingPlanRef = ratingPlanRefArg~string
  ratingFunctionRef = ratingFunctionRefArg~string
  priceSource = .AllJapanInsuranceCanonical~token(priceSourceArg)
  overrideReason = overrideReasonArg~string

::class AllJapanInsurancePolicy public
::attribute policyId get
::attribute quoteId get
::attribute partyRef get
::attribute productCode get
::attribute riskRef get
::attribute inceptionDate get
::attribute expiryDate get
::attribute status get
::attribute boundAt get
::attribute policyNumber get
::attribute termNumber get
::attribute transactionType get
::attribute priorPolicyId get
::method init
  expose policyId quoteId partyRef productCode riskRef inceptionDate expiryDate status boundAt policyNumber termNumber transactionType priorPolicyId
  use arg policyIdArg, quoteIdArg, partyRefArg, productCodeArg, riskRefArg, inceptionDateArg, expiryDateArg, boundAtArg, policyNumberArg = "", termNumberArg = 1, transactionTypeArg = "NEW_BUSINESS", priorPolicyIdArg = ""
  policyId = policyIdArg~string
  quoteId = quoteIdArg~string
  partyRef = partyRefArg~string
  productCode = .AllJapanInsuranceCanonical~token(productCodeArg)
  riskRef = riskRefArg~string
  inceptionDate = inceptionDateArg~string
  expiryDate = expiryDateArg~string
  status = .AllJapanInsuranceBuild~POLICY_ACTIVE
  boundAt = boundAtArg~string
  policyNumber = policyNumberArg~string
  if policyNumber = "" then policyNumber = policyId
  termNumber = termNumberArg + 0
  transactionType = .AllJapanInsuranceCanonical~token(transactionTypeArg)
  priorPolicyId = priorPolicyIdArg~string

::class AllJapanInsuranceClaim public
::attribute claimId get
::attribute policyId get
::attribute claimantRef get
::attribute lossDate get
::attribute notifiedAt get
::attribute lossRef get
::attribute status get
::method init
  expose claimId policyId claimantRef lossDate notifiedAt lossRef status
  use arg claimIdArg, policyIdArg, claimantRefArg, lossDateArg, notifiedAtArg, lossRefArg = ""
  claimId = claimIdArg~string
  policyId = policyIdArg~string
  claimantRef = claimantRefArg~string
  lossDate = lossDateArg~string
  notifiedAt = notifiedAtArg~string
  lossRef = lossRefArg~string
  status = .AllJapanInsuranceBuild~CLAIM_OPEN

::class AllJapanInsuranceClaimPayment public
::attribute paymentId get
::attribute claimId get
::attribute policyId get
::attribute assessmentId get
::attribute payeeRef get
::attribute amountMinor get
::attribute currency get
::attribute paidAt get
::attribute paymentRef get
::attribute evidenceRef get
::method init
  expose paymentId claimId policyId assessmentId payeeRef amountMinor currency paidAt paymentRef evidenceRef
  use arg paymentIdArg, claimIdArg, policyIdArg, assessmentIdArg, payeeRefArg, amountMinorArg, currencyArg, paidAtArg, paymentRefArg, evidenceRefArg = ""
  paymentId = paymentIdArg~string
  claimId = claimIdArg~string
  policyId = policyIdArg~string
  assessmentId = assessmentIdArg~string
  payeeRef = payeeRefArg~string
  amountMinor = amountMinorArg + 0
  currency = .AllJapanInsuranceCanonical~token(currencyArg)
  paidAt = paidAtArg~string
  paymentRef = paymentRefArg~string
  evidenceRef = evidenceRefArg~string
::method canonicalText
  expose paymentId claimId policyId assessmentId payeeRef amountMinor currency paidAt paymentRef evidenceRef
  return "AJI-CLAIM-PAYMENT/0.7" || '0a'x || -
         "PAYMENT_ID=" || paymentId || '0a'x || -
         "CLAIM_ID=" || claimId || '0a'x || -
         "POLICY_ID=" || policyId || '0a'x || -
         "ASSESSMENT_ID=" || assessmentId || '0a'x || -
         "PAYEE_REF=" || payeeRef || '0a'x || -
         "AMOUNT_MINOR=" || amountMinor || '0a'x || -
         "CURRENCY=" || currency || '0a'x || -
         "PAID_AT=" || paidAt || '0a'x || -
         "PAYMENT_REF=" || paymentRef || '0a'x || -
         "EVIDENCE_REF=" || evidenceRef || '0a'x
::method semanticIdentity
  return self~canonicalText


::class AllJapanInsurancePolicyCancellation public
::attribute cancellationId get
::attribute policyId get
::attribute effectiveDate get
::attribute reasonCode get
::attribute calculationRef get
::attribute authorizedBy get
::attribute authorizedAt get
::attribute evidenceRef get
::method init
  expose cancellationId policyId effectiveDate reasonCode calculationRef authorizedBy authorizedAt evidenceRef
  use arg cancellationIdArg, policyIdArg, effectiveDateArg, reasonCodeArg, calculationRefArg, authorizedByArg, authorizedAtArg, evidenceRefArg = ""
  cancellationId=cancellationIdArg~string
  policyId=policyIdArg~string
  effectiveDate=effectiveDateArg~string
  reasonCode=.AllJapanInsuranceCanonical~token(reasonCodeArg)
  calculationRef=calculationRefArg~string
  authorizedBy=authorizedByArg~string
  authorizedAt=authorizedAtArg~string
  evidenceRef=evidenceRefArg~string
::method canonicalText
  expose cancellationId policyId effectiveDate reasonCode calculationRef authorizedBy authorizedAt evidenceRef
  return "AJI-POLICY-CANCELLATION/0.8" || '0a'x || -
         "CANCELLATION_ID=" || cancellationId || '0a'x || -
         "POLICY_ID=" || policyId || '0a'x || -
         "EFFECTIVE_DATE=" || effectiveDate || '0a'x || -
         "REASON_CODE=" || reasonCode || '0a'x || -
         "CALCULATION_REF=" || calculationRef || '0a'x || -
         "AUTHORIZED_BY=" || authorizedBy || '0a'x || -
         "AUTHORIZED_AT=" || authorizedAt || '0a'x || -
         "EVIDENCE_REF=" || evidenceRef || '0a'x
::method semanticIdentity
  return self~canonicalText

::class AllJapanInsurancePolicyReinstatement public
::attribute reinstatementId get
::attribute policyId get
::attribute cancellationId get
::attribute effectiveDate get
::attribute coverageRestoredFromDate get
::attribute premiumAdjustmentRef get
::attribute authorizedBy get
::attribute authorizedAt get
::attribute evidenceRef get
::method init
  expose reinstatementId policyId cancellationId effectiveDate coverageRestoredFromDate premiumAdjustmentRef authorizedBy authorizedAt evidenceRef
  use arg reinstatementIdArg,policyIdArg,cancellationIdArg,effectiveDateArg,coverageRestoredFromDateArg,premiumAdjustmentRefArg,authorizedByArg,authorizedAtArg,evidenceRefArg=""
  reinstatementId=reinstatementIdArg~string
  policyId=policyIdArg~string
  cancellationId=cancellationIdArg~string
  effectiveDate=effectiveDateArg~string
  coverageRestoredFromDate=coverageRestoredFromDateArg~string
  premiumAdjustmentRef=premiumAdjustmentRefArg~string
  authorizedBy=authorizedByArg~string
  authorizedAt=authorizedAtArg~string
  evidenceRef=evidenceRefArg~string
::method canonicalText
  expose reinstatementId policyId cancellationId effectiveDate coverageRestoredFromDate premiumAdjustmentRef authorizedBy authorizedAt evidenceRef
  return "AJI-POLICY-REINSTATEMENT/0.9" || '0a'x || -
         "REINSTATEMENT_ID=" || reinstatementId || '0a'x || -
         "POLICY_ID=" || policyId || '0a'x || -
         "CANCELLATION_ID=" || cancellationId || '0a'x || -
         "EFFECTIVE_DATE=" || effectiveDate || '0a'x || -
         "COVERAGE_RESTORED_FROM_DATE=" || coverageRestoredFromDate || '0a'x || -
         "PREMIUM_ADJUSTMENT_REF=" || premiumAdjustmentRef || '0a'x || -
         "AUTHORIZED_BY=" || authorizedBy || '0a'x || -
         "AUTHORIZED_AT=" || authorizedAt || '0a'x || -
         "EVIDENCE_REF=" || evidenceRef || '0a'x
::method semanticIdentity
  return self~canonicalText

::class AllJapanInsuranceAuthority public
::method init
  expose catalogue contractBook submissions decisions ratings quotes policies policyLocks claims assessments claimPayments cancellations reinstatements
  use arg catalogueArg = .nil, contractBookArg = .nil
  if catalogueArg == .nil then catalogue = .AllJapanInsuranceCatalogue~new
  else catalogue = catalogueArg
  contractBook = contractBookArg
  submissions = .table~new
  decisions = .table~new
  ratings = .table~new
  quotes = .table~new
  policies = .table~new
  policyLocks = .table~new
  claims = .table~new
  assessments = .table~new
  claimPayments = .table~new
  cancellations = .table~new
  reinstatements = .table~new
::method catalogue
  expose catalogue
  return catalogue
::method contractBook
  expose contractBook
  return contractBook
::method submission
  expose submissions
  use arg id
  return submissions[id~string]
::method decision
  expose decisions
  use arg id
  return decisions[id~string]
::method rating
  expose ratings
  use arg id
  return ratings[id~string]
::method quote
  expose quotes
  use arg id
  return quotes[id~string]
::method policy
  expose policies
  use arg id
  return policies[id~string]
::method policyContractLock
  expose policyLocks
  use arg id
  return policyLocks[id~string]
::method claim
  expose claims
  use arg id
  return claims[id~string]
::method assessment
  expose assessments
  use arg id
  return assessments[id~string]
::method claimPayment
  expose claimPayments
  use arg id
  return claimPayments[id~string]
::method policyCancellation
  expose cancellations
  use arg policyIdArg
  return cancellations[policyIdArg~string]
::method policyReinstatement
  expose reinstatements
  use arg policyIdArg
  return reinstatements[policyIdArg~string]
::method coverageActiveOn
  expose policies cancellations reinstatements
  use arg policyIdArg,dateArg
  policy=policies[policyIdArg~string]
  if policy==.nil then return .false
  date=dateArg~string
  if date<policy~inceptionDate | date>=policy~expiryDate then return .false
  cancellation=cancellations[policy~policyId]
  if cancellation==.nil then return .true
  if date<cancellation~effectiveDate then return .true
  reinstatement=reinstatements[policy~policyId]
  if reinstatement==.nil then return .false
  return date>=reinstatement~coverageRestoredFromDate
::method claimPaidTotal
  expose claimPayments
  use arg claimIdArg
  numeric digits 50
  total = 0
  do payment over claimPayments~allItems
    if payment~claimId = claimIdArg~string then total += payment~amountMinor
  end
  return total
::method latestAssessmentForClaim
  expose assessments
  use arg claimIdArg
  latest = .nil
  ambiguous = .false
  do assessment over assessments~allItems
    if assessment~claimId \= claimIdArg~string then iterate
    if latest == .nil then do
      latest = assessment
      ambiguous = .false
      iterate
    end
    if assessment~assessedAt > latest~assessedAt then do
      latest = assessment
      ambiguous = .false
    end
    else if assessment~assessedAt = latest~assessedAt & assessment~assessmentId \= latest~assessmentId then ambiguous = .true
  end
  if ambiguous then return .nil
  return latest
::method requireRole private
  use arg actor, role
  if actor == .nil then return .AllJapanInsuranceResult~failure("AUTHORITY_REQUIRED", role)
  if \actor~hasRole(role) then return .AllJapanInsuranceResult~failure("AUTHORITY_DENIED", role)
  return .AllJapanInsuranceResult~success
::method submitRisk
  expose catalogue submissions
  use arg actor, submission
  auth = self~requireRole(actor, .AllJapanInsuranceBuild~ROLE_DISTRIBUTION)
  if \auth~ok then return auth
  if submission == .nil then return .AllJapanInsuranceResult~failure("SUBMISSION_REQUIRED")
  if submission~submissionId = "" | submission~partyRef = "" | submission~riskRef = "" then return .AllJapanInsuranceResult~failure("SUBMISSION_IDENTITY_REQUIRED")
  if submission~jurisdiction = "" | submission~submittedAt = "" then return .AllJapanInsuranceResult~failure("SUBMISSION_CONTEXT_REQUIRED")
  if \catalogue~contains(submission~productCode) then return .AllJapanInsuranceResult~failure("UNKNOWN_PRODUCT", submission~productCode)
  if submissions~hasIndex(submission~submissionId) then return .AllJapanInsuranceResult~failure("SUBMISSION_DUPLICATE", submission~submissionId)
  submissions[submission~submissionId] = submission
  return .AllJapanInsuranceResult~success(submission)
::method recordDecision
  expose catalogue submissions decisions
  use arg actor, decision
  auth = self~requireRole(actor, .AllJapanInsuranceBuild~ROLE_UNDERWRITER)
  if \auth~ok then return auth
  if decision == .nil then return .AllJapanInsuranceResult~failure("DECISION_REQUIRED")
  if decisions~hasIndex(decision~decisionId) then return .AllJapanInsuranceResult~failure("DECISION_DUPLICATE", decision~decisionId)
  submission = submissions[decision~submissionId]
  if submission == .nil then return .AllJapanInsuranceResult~failure("SUBMISSION_NOT_FOUND", decision~submissionId)
  if decision~productCode \= submission~productCode then return .AllJapanInsuranceResult~failure("PRODUCT_MISMATCH")
  if decision~policyRef \= catalogue~product(decision~productCode)~policyRef then return .AllJapanInsuranceResult~failure("PRODUCT_POLICY_REF_MISMATCH")
  if decision~outcome \= .AllJapanInsuranceBuild~DECISION_ACCEPT, decision~outcome \= .AllJapanInsuranceBuild~DECISION_DECLINE, decision~outcome \= .AllJapanInsuranceBuild~DECISION_REFER then return .AllJapanInsuranceResult~failure("DECISION_OUTCOME_INVALID", decision~outcome)
  if decision~decidedBy = "" | decision~decidedAt = "" then return .AllJapanInsuranceResult~failure("DECISION_EVIDENCE_REQUIRED")
  decisions[decision~decisionId] = decision
  return .AllJapanInsuranceResult~success(decision)
::method recordRating
  expose submissions ratings
  use arg actor, rating
  auth = self~requireRole(actor, .AllJapanInsuranceBuild~ROLE_RATING_ENGINE)
  if \auth~ok then return auth
  if rating == .nil then return .AllJapanInsuranceResult~failure("RATING_REQUIRED")
  if ratings~hasIndex(rating~ratingId) then return .AllJapanInsuranceResult~failure("RATING_DUPLICATE", rating~ratingId)
  submission = submissions[rating~submissionId]
  if submission == .nil then return .AllJapanInsuranceResult~failure("SUBMISSION_NOT_FOUND", rating~submissionId)
  if rating~productCode \= submission~productCode then return .AllJapanInsuranceResult~failure("RATING_PRODUCT_MISMATCH")
  if rating~currency = "" | rating~planRef = "" | rating~ratingFunctionRef = "" then return .AllJapanInsuranceResult~failure("RATING_CONTEXT_REQUIRED")
  if \.AllJapanInsuranceCurrency~supported(rating~currency) then return .AllJapanInsuranceResult~failure("CURRENCY_UNSUPPORTED",rating~currency)
  if \rating~balanced then return .AllJapanInsuranceResult~failure("RATING_COMPONENTS_UNBALANCED")
  ratings[rating~ratingId] = rating
  return .AllJapanInsuranceResult~success(rating)
::method issueRatedQuote
  expose decisions ratings quotes
  use arg actor, quoteId, decisionId, ratingId, validUntil, issuedAt
  auth = self~requireRole(actor, .AllJapanInsuranceBuild~ROLE_UNDERWRITER)
  if \auth~ok then return auth
  decision = decisions[decisionId~string]
  if decision == .nil then return .AllJapanInsuranceResult~failure("DECISION_NOT_FOUND", decisionId)
  if decision~outcome \= .AllJapanInsuranceBuild~DECISION_ACCEPT then return .AllJapanInsuranceResult~failure("DECISION_NOT_ACCEPTED", decision~outcome)
  rating = ratings[ratingId~string]
  if rating == .nil then return .AllJapanInsuranceResult~failure("RATING_NOT_FOUND", ratingId)
  if rating~submissionId \= decision~submissionId | rating~productCode \= decision~productCode then return .AllJapanInsuranceResult~failure("RATING_DECISION_MISMATCH")
  quote = .AllJapanInsuranceQuote~new(quoteId, decision~decisionId, decision~submissionId, decision~productCode, rating~totalPremiumMinor, rating~currency, validUntil, issuedAt, rating~ratingId, rating~planRef, "RATED", "", rating~ratingFunctionRef)
  return self~issueQuote(actor, quote)
::method issueQuote
  expose decisions ratings quotes
  use arg actor, quote
  auth = self~requireRole(actor, .AllJapanInsuranceBuild~ROLE_UNDERWRITER)
  if \auth~ok then return auth
  if quote == .nil then return .AllJapanInsuranceResult~failure("QUOTE_REQUIRED")
  if quotes~hasIndex(quote~quoteId) then return .AllJapanInsuranceResult~failure("QUOTE_DUPLICATE", quote~quoteId)
  decision = decisions[quote~decisionId]
  if decision == .nil then return .AllJapanInsuranceResult~failure("DECISION_NOT_FOUND", quote~decisionId)
  if decision~outcome \= .AllJapanInsuranceBuild~DECISION_ACCEPT then return .AllJapanInsuranceResult~failure("DECISION_NOT_ACCEPTED", decision~outcome)
  if quote~submissionId \= decision~submissionId | quote~productCode \= decision~productCode then return .AllJapanInsuranceResult~failure("QUOTE_DECISION_MISMATCH")
  if quote~premiumMinor < 0 then return .AllJapanInsuranceResult~failure("QUOTE_PREMIUM_INVALID")
  if quote~currency = "" | quote~validUntil = "" | quote~issuedAt = "" then return .AllJapanInsuranceResult~failure("QUOTE_CONTEXT_REQUIRED")
  if \.AllJapanInsuranceCurrency~supported(quote~currency) then return .AllJapanInsuranceResult~failure("CURRENCY_UNSUPPORTED",quote~currency)
  if quote~ratingId = "" then do
    overrideAuth = self~requireRole(actor, .AllJapanInsuranceBuild~ROLE_RATE_OVERRIDE)
    if \overrideAuth~ok then return .AllJapanInsuranceResult~failure("RATING_REQUIRED", "manual price requires RATE_OVERRIDE")
    if quote~priceSource \= "MANUAL_OVERRIDE" | quote~overrideReason = "" then return .AllJapanInsuranceResult~failure("RATE_OVERRIDE_EVIDENCE_REQUIRED")
  end
  else do
    rating = ratings[quote~ratingId]
    if rating == .nil then return .AllJapanInsuranceResult~failure("RATING_NOT_FOUND", quote~ratingId)
    if rating~submissionId \= quote~submissionId | rating~productCode \= quote~productCode then return .AllJapanInsuranceResult~failure("QUOTE_RATING_MISMATCH")
    if rating~currency \= quote~currency | rating~totalPremiumMinor \= quote~premiumMinor then return .AllJapanInsuranceResult~failure("QUOTE_RATING_AMOUNT_MISMATCH")
    if rating~planRef \= quote~ratingPlanRef then return .AllJapanInsuranceResult~failure("QUOTE_RATING_PLAN_MISMATCH")
    if quote~ratingFunctionRef = "" | rating~ratingFunctionRef \= quote~ratingFunctionRef then return .AllJapanInsuranceResult~failure("QUOTE_RATING_FUNCTION_MISMATCH")
  end
  quotes[quote~quoteId] = quote
  return .AllJapanInsuranceResult~success(quote)
::method bindPolicy
  expose submissions quotes policies policyLocks contractBook
  use arg actor, policy
  auth = self~requireRole(actor, .AllJapanInsuranceBuild~ROLE_POLICY)
  if \auth~ok then return auth
  if policy == .nil then return .AllJapanInsuranceResult~failure("POLICY_REQUIRED")
  if policies~hasIndex(policy~policyId) then return .AllJapanInsuranceResult~failure("POLICY_DUPLICATE", policy~policyId)
  quote = quotes[policy~quoteId]
  if quote == .nil then return .AllJapanInsuranceResult~failure("QUOTE_NOT_FOUND", policy~quoteId)
  submission = submissions[quote~submissionId]
  if submission == .nil then return .AllJapanInsuranceResult~failure("SUBMISSION_NOT_FOUND", quote~submissionId)
  if policy~productCode \= quote~productCode then return .AllJapanInsuranceResult~failure("POLICY_PRODUCT_MISMATCH")
  if policy~partyRef \= submission~partyRef | policy~riskRef \= submission~riskRef then return .AllJapanInsuranceResult~failure("POLICY_RISK_MISMATCH")
  if policy~inceptionDate = "" | policy~expiryDate = "" | policy~boundAt = "" then return .AllJapanInsuranceResult~failure("POLICY_CONTEXT_REQUIRED")
  if policy~expiryDate <= policy~inceptionDate then return .AllJapanInsuranceResult~failure("POLICY_PERIOD_INVALID")
  if quote~validUntil < policy~boundAt then return .AllJapanInsuranceResult~failure("QUOTE_EXPIRED")
  if policy~termNumber < 1 | policy~termNumber \= policy~termNumber~trunc then return .AllJapanInsuranceResult~failure("POLICY_TERM_NUMBER_INVALID")
  if policy~transactionType = .AllJapanInsuranceBuild~TRANSACTION_NEW_BUSINESS then do
    if policy~priorPolicyId \= "" then return .AllJapanInsuranceResult~failure("NEW_BUSINESS_PRIOR_POLICY_INVALID")
    if policy~termNumber \= 1 then return .AllJapanInsuranceResult~failure("NEW_BUSINESS_TERM_INVALID")
  end
  else if policy~transactionType = .AllJapanInsuranceBuild~TRANSACTION_RENEWAL then do
    if policy~priorPolicyId = "" then return .AllJapanInsuranceResult~failure("RENEWAL_PRIOR_POLICY_REQUIRED")
    prior = policies[policy~priorPolicyId]
    if prior == .nil then return .AllJapanInsuranceResult~failure("PRIOR_POLICY_NOT_FOUND", policy~priorPolicyId)
    if prior~policyNumber \= policy~policyNumber then return .AllJapanInsuranceResult~failure("RENEWAL_POLICY_NUMBER_MISMATCH")
    if prior~productCode \= policy~productCode | prior~partyRef \= policy~partyRef | prior~riskRef \= policy~riskRef then return .AllJapanInsuranceResult~failure("RENEWAL_RISK_MISMATCH")
    if policy~termNumber \= prior~termNumber + 1 then return .AllJapanInsuranceResult~failure("RENEWAL_TERM_NUMBER_INVALID")
    if policy~inceptionDate \= prior~expiryDate then return .AllJapanInsuranceResult~failure("RENEWAL_PERIOD_NOT_CONTIGUOUS")
  end
  else return .AllJapanInsuranceResult~failure("POLICY_TRANSACTION_TYPE_INVALID", policy~transactionType)

  if contractBook == .nil then return .AllJapanInsuranceResult~failure("CONTRACT_BOOK_REQUIRED")
  resolution = contractBook~resolve(policy~productCode, submission~jurisdiction, policy~inceptionDate)
  if \resolution~ok then return resolution
  contractVersion = resolution~value
  if contractVersion~ratingPlanRef \= "" & quote~ratingPlanRef \= contractVersion~ratingPlanRef then return .AllJapanInsuranceResult~failure("CONTRACT_RATING_PLAN_MISMATCH", contractVersion~ratingPlanRef)
  if contractVersion~ratingFunctionRef \= "" & quote~ratingFunctionRef \= contractVersion~ratingFunctionRef then return .AllJapanInsuranceResult~failure("CONTRACT_RATING_FUNCTION_MISMATCH", contractVersion~ratingFunctionRef)

  lock = contractBook~makePolicyLock(policy~policyId, policy~policyNumber, policy~termNumber, policy~transactionType, policy~priorPolicyId, contractVersion~versionRef, quote~ratingId, quote~ratingPlanRef, quote~ratingFunctionRef, policy~boundAt)
  policies[policy~policyId] = policy
  policyLocks[policy~policyId] = lock
  return .AllJapanInsuranceResult~success(policy, contractVersion~versionRef)
::method renewPolicy
  use arg actor, policy
  if policy == .nil then return .AllJapanInsuranceResult~failure("POLICY_REQUIRED")
  if policy~transactionType \= .AllJapanInsuranceBuild~TRANSACTION_RENEWAL then return .AllJapanInsuranceResult~failure("RENEWAL_TRANSACTION_REQUIRED")
  return self~bindPolicy(actor, policy)
::method recordCancellation
  expose policies cancellations
  use arg actor, cancellation
  auth=self~requireRole(actor,.AllJapanInsuranceBuild~ROLE_POLICY_TRANSACTION)
  if \auth~ok then return auth
  if cancellation==.nil then return .AllJapanInsuranceResult~failure("POLICY_CANCELLATION_REQUIRED")
  if cancellation~cancellationId="" | cancellation~policyId="" | cancellation~effectiveDate="" then return .AllJapanInsuranceResult~failure("POLICY_CANCELLATION_IDENTITY_REQUIRED")
  if cancellation~reasonCode="" | cancellation~calculationRef="" | cancellation~authorizedBy="" | cancellation~authorizedAt="" | cancellation~evidenceRef="" then return .AllJapanInsuranceResult~failure("POLICY_CANCELLATION_EVIDENCE_REQUIRED")
  if cancellations~hasIndex(cancellation~policyId) then return .AllJapanInsuranceResult~failure("POLICY_ALREADY_CANCELLED",cancellation~policyId)
  policy=policies[cancellation~policyId]
  if policy==.nil then return .AllJapanInsuranceResult~failure("POLICY_NOT_FOUND",cancellation~policyId)
  if cancellation~effectiveDate < policy~inceptionDate | cancellation~effectiveDate >= policy~expiryDate then return .AllJapanInsuranceResult~failure("POLICY_CANCELLATION_EFFECTIVE_DATE_INVALID",cancellation~effectiveDate)
  if cancellation~authorizedBy \= actor~principalId then return .AllJapanInsuranceResult~failure("POLICY_CANCELLATION_AUTHORITY_MISMATCH",cancellation~authorizedBy)
  cancellations[cancellation~policyId]=cancellation
  return .AllJapanInsuranceResult~success(cancellation)
::method recordReinstatement
  expose policies cancellations reinstatements
  use arg actor,reinstatement
  auth=self~requireRole(actor,.AllJapanInsuranceBuild~ROLE_POLICY_TRANSACTION)
  if \auth~ok then return auth
  if reinstatement==.nil then return .AllJapanInsuranceResult~failure("POLICY_REINSTATEMENT_REQUIRED")
  if reinstatement~reinstatementId="" | reinstatement~policyId="" | reinstatement~cancellationId="" | reinstatement~effectiveDate="" | reinstatement~coverageRestoredFromDate="" then return .AllJapanInsuranceResult~failure("POLICY_REINSTATEMENT_IDENTITY_REQUIRED")
  if reinstatement~premiumAdjustmentRef="" | reinstatement~authorizedBy="" | reinstatement~authorizedAt="" | reinstatement~evidenceRef="" then return .AllJapanInsuranceResult~failure("POLICY_REINSTATEMENT_EVIDENCE_REQUIRED")
  if reinstatements~hasIndex(reinstatement~policyId) then return .AllJapanInsuranceResult~failure("POLICY_ALREADY_REINSTATED",reinstatement~policyId)
  policy=policies[reinstatement~policyId]
  if policy==.nil then return .AllJapanInsuranceResult~failure("POLICY_NOT_FOUND",reinstatement~policyId)
  cancellation=cancellations[reinstatement~policyId]
  if cancellation==.nil then return .AllJapanInsuranceResult~failure("POLICY_CANCELLATION_NOT_FOUND",reinstatement~policyId)
  if cancellation~cancellationId\=reinstatement~cancellationId then return .AllJapanInsuranceResult~failure("POLICY_REINSTATEMENT_CANCELLATION_MISMATCH",reinstatement~cancellationId)
  if reinstatement~effectiveDate<cancellation~effectiveDate | reinstatement~effectiveDate>=policy~expiryDate then return .AllJapanInsuranceResult~failure("POLICY_REINSTATEMENT_EFFECTIVE_DATE_INVALID",reinstatement~effectiveDate)
  if reinstatement~coverageRestoredFromDate\=cancellation~effectiveDate then return .AllJapanInsuranceResult~failure("POLICY_REINSTATEMENT_GAP_MODE_UNSUPPORTED",reinstatement~coverageRestoredFromDate)
  if reinstatement~authorizedBy\=actor~principalId then return .AllJapanInsuranceResult~failure("POLICY_REINSTATEMENT_AUTHORITY_MISMATCH",reinstatement~authorizedBy)
  reinstatements[reinstatement~policyId]=reinstatement
  return .AllJapanInsuranceResult~success(reinstatement)
::method openClaim
  expose policies claims cancellations
  use arg actor, claim
  auth = self~requireRole(actor, .AllJapanInsuranceBuild~ROLE_CLAIMS_INTAKE)
  if \auth~ok then return auth
  if claim == .nil then return .AllJapanInsuranceResult~failure("CLAIM_REQUIRED")
  if claims~hasIndex(claim~claimId) then return .AllJapanInsuranceResult~failure("CLAIM_DUPLICATE", claim~claimId)
  policy = policies[claim~policyId]
  if policy == .nil then return .AllJapanInsuranceResult~failure("POLICY_NOT_FOUND", claim~policyId)
  if policy~status \= .AllJapanInsuranceBuild~POLICY_ACTIVE then return .AllJapanInsuranceResult~failure("POLICY_NOT_ACTIVE")
  if claim~claimantRef = "" | claim~lossDate = "" | claim~notifiedAt = "" then return .AllJapanInsuranceResult~failure("CLAIM_CONTEXT_REQUIRED")
  if claim~lossDate < policy~inceptionDate | claim~lossDate >= policy~expiryDate then return .AllJapanInsuranceResult~failure("LOSS_OUTSIDE_COVERAGE")
  if \self~coverageActiveOn(policy~policyId,claim~lossDate) then do
    cancellation=cancellations[policy~policyId]
    if cancellation\==.nil then return .AllJapanInsuranceResult~failure("LOSS_AFTER_POLICY_CANCELLATION",cancellation~effectiveDate)
    return .AllJapanInsuranceResult~failure("LOSS_OUTSIDE_COVERAGE")
  end
  claims[claim~claimId] = claim
  return .AllJapanInsuranceResult~success(claim)
::method assessClaim
  expose claims policies policyLocks contractBook assessments claimPayments
  use arg actor, assessmentId, claimId, assessedCoveredLossMinor, assessedAt, evidenceRef = ""
  auth = self~requireRole(actor, .AllJapanInsuranceBuild~ROLE_CLAIMS_ASSESSOR)
  if \auth~ok then return auth
  if assessments~hasIndex(assessmentId~string) then return .AllJapanInsuranceResult~failure("CLAIM_ASSESSMENT_DUPLICATE", assessmentId)
  claim = claims[claimId~string]
  if claim == .nil then return .AllJapanInsuranceResult~failure("CLAIM_NOT_FOUND", claimId)
  policy = policies[claim~policyId]
  if policy == .nil then return .AllJapanInsuranceResult~failure("POLICY_NOT_FOUND", claim~policyId)
  lock = policyLocks[policy~policyId]
  if lock == .nil then return .AllJapanInsuranceResult~failure("POLICY_CONTRACT_LOCK_NOT_FOUND", policy~policyId)
  if contractBook == .nil then return .AllJapanInsuranceResult~failure("CONTRACT_BOOK_REQUIRED")
  r = contractBook~assessLockedClaim(assessmentId, claim, policy, lock, assessedCoveredLossMinor, assessedAt, evidenceRef)
  if \r~ok then return r
  paidToDate = self~claimPaidTotal(claim~claimId)
  if r~value~payableMinor < paidToDate then return .AllJapanInsuranceResult~failure("CLAIM_ASSESSMENT_BELOW_PAID_AMOUNT", paidToDate)
  assessments[assessmentId~string] = r~value
  return r
::method recordClaimPayment
  expose claims policies quotes assessments claimPayments
  use arg actor, payment
  numeric digits 50
  auth = self~requireRole(actor, .AllJapanInsuranceBuild~ROLE_CLAIMS_PAYMENT)
  if \auth~ok then return auth
  if payment == .nil then return .AllJapanInsuranceResult~failure("CLAIM_PAYMENT_REQUIRED")
  if payment~paymentId = "" | payment~claimId = "" | payment~policyId = "" | payment~assessmentId = "" then return .AllJapanInsuranceResult~failure("CLAIM_PAYMENT_IDENTITY_REQUIRED")
  if payment~payeeRef = "" | payment~paidAt = "" | payment~paymentRef = "" then return .AllJapanInsuranceResult~failure("CLAIM_PAYMENT_EVIDENCE_REQUIRED")
  if claimPayments~hasIndex(payment~paymentId) then return .AllJapanInsuranceResult~failure("CLAIM_PAYMENT_DUPLICATE", payment~paymentId)
  money = .AllJapanInsuranceCurrency~validateMinorAmount(payment~currency, payment~amountMinor)
  if \money~ok | payment~amountMinor = 0 then return .AllJapanInsuranceResult~failure("CLAIM_PAYMENT_AMOUNT_INVALID", payment~currency)
  claim = claims[payment~claimId]
  if claim == .nil then return .AllJapanInsuranceResult~failure("CLAIM_NOT_FOUND", payment~claimId)
  if claim~policyId \= payment~policyId then return .AllJapanInsuranceResult~failure("CLAIM_PAYMENT_POLICY_MISMATCH")
  policy = policies[payment~policyId]
  if policy == .nil then return .AllJapanInsuranceResult~failure("POLICY_NOT_FOUND", payment~policyId)
  quote = quotes[policy~quoteId]
  if quote == .nil then return .AllJapanInsuranceResult~failure("QUOTE_NOT_FOUND", policy~quoteId)
  if payment~currency \= quote~currency then return .AllJapanInsuranceResult~failure("CLAIM_PAYMENT_CURRENCY_MISMATCH", payment~currency)
  assessment = assessments[payment~assessmentId]
  if assessment == .nil then return .AllJapanInsuranceResult~failure("CLAIM_ASSESSMENT_NOT_FOUND", payment~assessmentId)
  if assessment~claimId \= claim~claimId | assessment~policyId \= policy~policyId then return .AllJapanInsuranceResult~failure("CLAIM_PAYMENT_ASSESSMENT_MISMATCH")
  latest = self~latestAssessmentForClaim(claim~claimId)
  if latest == .nil then return .AllJapanInsuranceResult~failure("CLAIM_CURRENT_ASSESSMENT_AMBIGUOUS", claim~claimId)
  if latest~assessmentId \= assessment~assessmentId then return .AllJapanInsuranceResult~failure("CLAIM_PAYMENT_ASSESSMENT_STALE", assessment~assessmentId)
  paidBefore = self~claimPaidTotal(claim~claimId)
  if paidBefore + payment~amountMinor > assessment~payableMinor then return .AllJapanInsuranceResult~failure("CLAIM_PAYMENT_EXCEEDS_CURRENT_ASSESSMENT", assessment~payableMinor)
  claimPayments[payment~paymentId] = payment
  return .AllJapanInsuranceResult~success(payment, (paidBefore + payment~amountMinor)~string)
::method snapshot
  expose contractBook submissions decisions ratings quotes policies policyLocks claims assessments claimPayments cancellations reinstatements
  out = .table~new
  out["schema"] = "all.japan.insurance.snapshot/0.10"
  out["insurer"] = .AllJapanInsuranceBuild~INSURER
  out["ownerGroup"] = .AllJapanInsuranceBuild~OWNER_GROUP
  out["legalEntityId"] = .AllJapanInsuranceBuild~LEGAL_ENTITY_ID
  out["functionalCurrency"] = .AllJapanInsuranceBuild~FUNCTIONAL_CURRENCY
  if contractBook == .nil then out["contractVersionCount"] = 0
  else out["contractVersionCount"] = contractBook~count
  out["submissionCount"] = submissions~items
  out["decisionCount"] = decisions~items
  out["ratingCount"] = ratings~items
  out["quoteCount"] = quotes~items
  out["policyCount"] = policies~items
  out["policyContractLockCount"] = policyLocks~items
  out["claimCount"] = claims~items
  out["claimAssessmentCount"] = assessments~items
  out["claimPaymentCount"] = claimPayments~items
  out["policyCancellationCount"] = cancellations~items
  out["policyReinstatementCount"] = reinstatements~items
  return out
