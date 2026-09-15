/* AllJapanInsuranceContract.cls - immutable contract/ruleset releases v0.5
 *
 * A bound policy term locks the exact contract version that governs it.
 * Publishing a later product/claims ruleset affects new business and later
 * renewals according to its effective period; it does not rewrite an
 * already-bound term.
 */

::class AllJapanInsuranceContractBuild public
::constant API_VERSION "all.japan.insurance.contract/0.5"
::constant TRANSACTION_NEW_BUSINESS "NEW_BUSINESS"
::constant TRANSACTION_RENEWAL "RENEWAL"

::class AllJapanInsuranceClaimPayoutRule public
::attribute ruleRef get
::attribute basisCode get
::attribute deductibleMinor get
::attribute payableRate get
::attribute hasLimit get
::attribute limitMinor get
::attribute functionRef get
::method init
  expose ruleRef basisCode deductibleMinor payableRate hasLimit limitMinor functionRef
  use arg ruleRefArg, basisCodeArg, deductibleMinorArg, payableRateArg, hasLimitArg = .false, limitMinorArg = 0, functionRefArg = "AJI.PAYOUT.DEDUCT_RATE_CAP/1"
  ruleRef = ruleRefArg~string
  basisCode = .AllJapanInsuranceCanonical~token(basisCodeArg)
  deductibleMinor = deductibleMinorArg + 0
  payableRate = payableRateArg
  hasLimit = hasLimitArg
  limitMinor = limitMinorArg + 0
  functionRef = functionRefArg~string
::method validate
  expose ruleRef basisCode deductibleMinor payableRate hasLimit limitMinor functionRef
  if ruleRef = "" | basisCode = "" | functionRef = "" then return .AllJapanInsuranceResult~failure("CLAIM_PAYOUT_RULE_IDENTITY_REQUIRED")
  if \.AllJapanInsuranceRatingMath~nonNegativeWhole(deductibleMinor) then return .AllJapanInsuranceResult~failure("CLAIM_DEDUCTIBLE_INVALID")
  if payableRate == .nil | \payableRate~valid then return .AllJapanInsuranceResult~failure("CLAIM_PAYABLE_RATE_INVALID")
  if payableRate~numerator > payableRate~denominator then return .AllJapanInsuranceResult~failure("CLAIM_PAYABLE_RATE_OVER_100_PERCENT")
  if hasLimit & \.AllJapanInsuranceRatingMath~nonNegativeWhole(limitMinor) then return .AllJapanInsuranceResult~failure("CLAIM_LIMIT_INVALID")
  return .AllJapanInsuranceResult~success
::method payableFor
  expose deductibleMinor payableRate hasLimit limitMinor
  use arg assessedCoveredLossMinor
  if \.AllJapanInsuranceRatingMath~nonNegativeWhole(assessedCoveredLossMinor) then return .nil
  net = .AllJapanInsuranceRatingMath~max((assessedCoveredLossMinor + 0) - deductibleMinor, 0)
  payable = payableRate~apply(net)
  if hasLimit then payable = .AllJapanInsuranceRatingMath~min(payable, limitMinor)
  return payable
::method canonicalText
  expose ruleRef basisCode deductibleMinor payableRate hasLimit limitMinor functionRef
  return "AJI-CLAIM-PAYOUT-RULE/0.5" || '0a'x || -
         "RULE_REF=" || ruleRef || '0a'x || -
         "BASIS=" || basisCode || '0a'x || -
         "DEDUCTIBLE_MINOR=" || deductibleMinor || '0a'x || -
         "PAYABLE_RATE=" || payableRate~canonicalText || '0a'x || -
         "HAS_LIMIT=" || hasLimit || '0a'x || -
         "LIMIT_MINOR=" || limitMinor || '0a'x || -
         "FUNCTION_REF=" || functionRef || '0a'x

::class AllJapanInsurancePayoutFunctionDeductRateCapV1 public
::method functionRef
  return "AJI.PAYOUT.DEDUCT_RATE_CAP/1"
::method execute
  use arg rule, assessedCoveredLossMinor
  net = .AllJapanInsuranceRatingMath~max((assessedCoveredLossMinor + 0) - rule~deductibleMinor, 0)
  payable = rule~payableRate~apply(net)
  if rule~hasLimit then payable = .AllJapanInsuranceRatingMath~min(payable, rule~limitMinor)
  return payable
::method canonicalText
  return "AJI-PAYOUT-FUNCTION/1|DEDUCT_THEN_RATE_THEN_CAP"

::class AllJapanInsurancePayoutFunctionRateDeductCapV1 public
::method functionRef
  return "AJI.PAYOUT.RATE_DEDUCT_CAP/1"
::method execute
  use arg rule, assessedCoveredLossMinor
  rated = rule~payableRate~apply(assessedCoveredLossMinor + 0)
  payable = .AllJapanInsuranceRatingMath~max(rated - rule~deductibleMinor, 0)
  if rule~hasLimit then payable = .AllJapanInsuranceRatingMath~min(payable, rule~limitMinor)
  return payable
::method canonicalText
  return "AJI-PAYOUT-FUNCTION/1|RATE_THEN_DEDUCT_THEN_CAP"

::class AllJapanInsurancePayoutFunctionRegistry public
::method init
  expose functions
  functions=.table~new
::method register
  expose functions
  use arg function
  if function == .nil then return .AllJapanInsuranceResult~failure("PAYOUT_FUNCTION_REQUIRED")
  ref=function~functionRef
  if ref = "" then return .AllJapanInsuranceResult~failure("PAYOUT_FUNCTION_REF_REQUIRED")
  if functions~hasIndex(ref) then return .AllJapanInsuranceResult~failure("PAYOUT_FUNCTION_DUPLICATE",ref)
  functions[ref]=function
  return .AllJapanInsuranceResult~success(function)
::method function
  expose functions
  use arg functionRef
  return functions[functionRef~string]
::method execute
  expose functions
  use arg rule, assessedCoveredLossMinor
  function=functions[rule~functionRef]
  if function == .nil then return .AllJapanInsuranceResult~failure("PAYOUT_FUNCTION_NOT_FOUND",rule~functionRef)
  amount=function~execute(rule,assessedCoveredLossMinor)
  if amount == .nil then return .AllJapanInsuranceResult~failure("CLAIM_PAYOUT_CALCULATION_FAILED")
  return .AllJapanInsuranceResult~success(amount)
::method count
  expose functions
  return functions~items

::class AllJapanInsuranceContractVersion public
::attribute versionRef get
::attribute productCode get
::attribute jurisdiction get
::attribute effectiveFrom get
::attribute effectiveTo get
::attribute wordingRef get
::attribute claimPayoutRule get
::attribute ratingPlanRef get
::attribute ratingFunctionRef get
::attribute approvedAt get
::attribute approvedBy get
::method init
  expose versionRef productCode jurisdiction effectiveFrom effectiveTo wordingRef claimPayoutRule ratingPlanRef ratingFunctionRef approvedAt approvedBy
  use arg versionRefArg, productCodeArg, jurisdictionArg, effectiveFromArg, effectiveToArg, wordingRefArg, claimPayoutRuleArg, ratingPlanRefArg = "", approvedAtArg = "", approvedByArg = "", ratingFunctionRefArg = ""
  versionRef = versionRefArg~string
  productCode = .AllJapanInsuranceCanonical~token(productCodeArg)
  jurisdiction = .AllJapanInsuranceCanonical~token(jurisdictionArg)
  effectiveFrom = effectiveFromArg~string
  effectiveTo = effectiveToArg~string
  wordingRef = wordingRefArg~string
  claimPayoutRule = claimPayoutRuleArg
  ratingPlanRef = ratingPlanRefArg~string
  ratingFunctionRef = ratingFunctionRefArg~string
  approvedAt = approvedAtArg~string
  approvedBy = approvedByArg~string
::method validate
  expose versionRef productCode jurisdiction effectiveFrom effectiveTo wordingRef claimPayoutRule approvedAt approvedBy
  if versionRef = "" | productCode = "" | jurisdiction = "" | effectiveFrom = "" | wordingRef = "" then return .AllJapanInsuranceResult~failure("CONTRACT_VERSION_IDENTITY_REQUIRED")
  if effectiveTo \= "" & effectiveTo <= effectiveFrom then return .AllJapanInsuranceResult~failure("CONTRACT_VERSION_PERIOD_INVALID")
  if approvedAt = "" | approvedBy = "" then return .AllJapanInsuranceResult~failure("CONTRACT_VERSION_APPROVAL_REQUIRED")
  if claimPayoutRule == .nil then return .AllJapanInsuranceResult~failure("CLAIM_PAYOUT_RULE_REQUIRED")
  r = claimPayoutRule~validate
  if \r~ok then return r
  return .AllJapanInsuranceResult~success
::method appliesAsOf
  expose effectiveFrom effectiveTo
  use arg asOf
  d = asOf~string
  if d < effectiveFrom then return .false
  if effectiveTo \= "" & d >= effectiveTo then return .false
  return .true
::method canonicalText
  expose versionRef productCode jurisdiction effectiveFrom effectiveTo wordingRef claimPayoutRule ratingPlanRef ratingFunctionRef approvedAt approvedBy
  return "AJI-CONTRACT-VERSION/0.5" || '0a'x || -
         "VERSION_REF=" || versionRef || '0a'x || -
         "PRODUCT=" || productCode || '0a'x || -
         "JURISDICTION=" || jurisdiction || '0a'x || -
         "EFFECTIVE_FROM=" || effectiveFrom || '0a'x || -
         "EFFECTIVE_TO=" || effectiveTo || '0a'x || -
         "WORDING_REF=" || wordingRef || '0a'x || -
         "RATING_PLAN_REF=" || ratingPlanRef || '0a'x || -
         "RATING_FUNCTION_REF=" || ratingFunctionRef || '0a'x || -
         "APPROVED_AT=" || approvedAt || '0a'x || -
         "APPROVED_BY=" || approvedBy || '0a'x || -
         claimPayoutRule~canonicalText
::method semanticIdentity
  return self~canonicalText

::class AllJapanInsuranceContractBook public
::method init
  expose versions byRef functionRegistry
  use arg functionRegistryArg = .nil
  versions = .array~new
  byRef = .table~new
  if functionRegistryArg == .nil then do
    functionRegistry=.AllJapanInsurancePayoutFunctionRegistry~new
    ignored=functionRegistry~register(.AllJapanInsurancePayoutFunctionDeductRateCapV1~new)
    ignored=functionRegistry~register(.AllJapanInsurancePayoutFunctionRateDeductCapV1~new)
  end
  else functionRegistry=functionRegistryArg
::method functionRegistry
  expose functionRegistry
  return functionRegistry
::method addVersion
  expose versions byRef functionRegistry
  use arg version
  if version == .nil then return .AllJapanInsuranceResult~failure("CONTRACT_VERSION_REQUIRED")
  r = version~validate
  if \r~ok then return r
  if functionRegistry~function(version~claimPayoutRule~functionRef) == .nil then return .AllJapanInsuranceResult~failure("PAYOUT_FUNCTION_NOT_FOUND",version~claimPayoutRule~functionRef)
  if byRef~hasIndex(version~versionRef) then return .AllJapanInsuranceResult~failure("CONTRACT_VERSION_DUPLICATE", version~versionRef)
  versions~append(version)
  byRef[version~versionRef] = version
  return .AllJapanInsuranceResult~success(version)
::method version
  expose byRef
  use arg versionRef
  return byRef[versionRef~string]
::method resolve
  expose versions
  use arg productCodeArg, jurisdictionArg, asOfArg
  productCode = .AllJapanInsuranceCanonical~token(productCodeArg)
  jurisdiction = .AllJapanInsuranceCanonical~token(jurisdictionArg)
  asOf = asOfArg~string
  if productCode = "" | jurisdiction = "" | asOf = "" then return .AllJapanInsuranceResult~failure("CONTRACT_RESOLUTION_CONTEXT_REQUIRED")
  exact = .array~new
  fallback = .array~new
  do version over versions
    if version~productCode \= productCode then iterate
    if \version~appliesAsOf(asOf) then iterate
    if version~jurisdiction = jurisdiction then exact~append(version)
    else if version~jurisdiction = "*" then fallback~append(version)
  end
  if exact~items > 1 then return .AllJapanInsuranceResult~failure("CONTRACT_VERSION_AMBIGUOUS", productCode || "/" || jurisdiction || "/" || asOf)
  if exact~items = 1 then return .AllJapanInsuranceResult~success(exact[1])
  if fallback~items > 1 then return .AllJapanInsuranceResult~failure("CONTRACT_VERSION_AMBIGUOUS", productCode || "/*/" || asOf)
  if fallback~items = 1 then return .AllJapanInsuranceResult~success(fallback[1])
  return .AllJapanInsuranceResult~failure("CONTRACT_VERSION_NOT_FOUND", productCode || "/" || jurisdiction || "/" || asOf)
::method count
  expose versions
  return versions~items
::method makePolicyLock
  use arg policyId, policyNumber, termNumber, transactionType, priorPolicyId, contractVersionRef, ratingId, ratingPlanRef, ratingFunctionRef, lockedAt
  return .AllJapanInsurancePolicyContractLock~new(policyId, policyNumber, termNumber, transactionType, priorPolicyId, contractVersionRef, ratingId, ratingPlanRef, ratingFunctionRef, lockedAt)
::method assessLockedClaim
  expose byRef functionRegistry
  use arg assessmentId, claim, policy, lock, assessedCoveredLossMinor, assessedAt, evidenceRef = ""
  if lock == .nil then return .AllJapanInsuranceResult~failure("POLICY_CONTRACT_LOCK_NOT_FOUND")
  contractVersion = byRef[lock~contractVersionRef]
  if contractVersion == .nil then return .AllJapanInsuranceResult~failure("LOCKED_CONTRACT_VERSION_NOT_FOUND", lock~contractVersionRef)
  return .AllJapanInsuranceClaimsEngine~new~assess(assessmentId, claim, policy, lock, contractVersion, functionRegistry, assessedCoveredLossMinor, assessedAt, evidenceRef)

::class AllJapanInsurancePolicyContractLock public
::attribute policyId get
::attribute policyNumber get
::attribute termNumber get
::attribute transactionType get
::attribute priorPolicyId get
::attribute contractVersionRef get
::attribute ratingId get
::attribute ratingPlanRef get
::attribute ratingFunctionRef get
::attribute lockedAt get
::method init
  expose policyId policyNumber termNumber transactionType priorPolicyId contractVersionRef ratingId ratingPlanRef ratingFunctionRef lockedAt
  use arg policyIdArg, policyNumberArg, termNumberArg, transactionTypeArg, priorPolicyIdArg, contractVersionRefArg, ratingIdArg, ratingPlanRefArg, ratingFunctionRefArg, lockedAtArg
  policyId = policyIdArg~string
  policyNumber = policyNumberArg~string
  termNumber = termNumberArg + 0
  transactionType = .AllJapanInsuranceCanonical~token(transactionTypeArg)
  priorPolicyId = priorPolicyIdArg~string
  contractVersionRef = contractVersionRefArg~string
  ratingId = ratingIdArg~string
  ratingPlanRef = ratingPlanRefArg~string
  ratingFunctionRef = ratingFunctionRefArg~string
  lockedAt = lockedAtArg~string
::method canonicalText
  expose policyId policyNumber termNumber transactionType priorPolicyId contractVersionRef ratingId ratingPlanRef ratingFunctionRef lockedAt
  return "AJI-POLICY-CONTRACT-LOCK/0.5" || '0a'x || -
         "POLICY_ID=" || policyId || '0a'x || -
         "POLICY_NUMBER=" || policyNumber || '0a'x || -
         "TERM_NUMBER=" || termNumber || '0a'x || -
         "TRANSACTION_TYPE=" || transactionType || '0a'x || -
         "PRIOR_POLICY_ID=" || priorPolicyId || '0a'x || -
         "CONTRACT_VERSION_REF=" || contractVersionRef || '0a'x || -
         "RATING_ID=" || ratingId || '0a'x || -
         "RATING_PLAN_REF=" || ratingPlanRef || '0a'x || -
         "RATING_FUNCTION_REF=" || ratingFunctionRef || '0a'x || -
         "LOCKED_AT=" || lockedAt || '0a'x
::method semanticIdentity
  return self~canonicalText

::class AllJapanInsuranceClaimAssessment public
::attribute assessmentId get
::attribute claimId get
::attribute policyId get
::attribute contractVersionRef get
::attribute payoutRuleRef get
::attribute payoutFunctionRef get
::attribute assessedCoveredLossMinor get
::attribute payableMinor get
::attribute assessedAt get
::attribute evidenceRef get
::method init
  expose assessmentId claimId policyId contractVersionRef payoutRuleRef payoutFunctionRef assessedCoveredLossMinor payableMinor assessedAt evidenceRef
  use arg assessmentIdArg, claimIdArg, policyIdArg, contractVersionRefArg, payoutRuleRefArg, payoutFunctionRefArg, assessedCoveredLossMinorArg, payableMinorArg, assessedAtArg, evidenceRefArg = ""
  assessmentId = assessmentIdArg~string
  claimId = claimIdArg~string
  policyId = policyIdArg~string
  contractVersionRef = contractVersionRefArg~string
  payoutRuleRef = payoutRuleRefArg~string
  payoutFunctionRef = payoutFunctionRefArg~string
  assessedCoveredLossMinor = assessedCoveredLossMinorArg + 0
  payableMinor = payableMinorArg + 0
  assessedAt = assessedAtArg~string
  evidenceRef = evidenceRefArg~string
::method canonicalText
  expose assessmentId claimId policyId contractVersionRef payoutRuleRef payoutFunctionRef assessedCoveredLossMinor payableMinor assessedAt evidenceRef
  return "AJI-CLAIM-ASSESSMENT/0.5" || '0a'x || -
         "ASSESSMENT_ID=" || assessmentId || '0a'x || -
         "CLAIM_ID=" || claimId || '0a'x || -
         "POLICY_ID=" || policyId || '0a'x || -
         "CONTRACT_VERSION_REF=" || contractVersionRef || '0a'x || -
         "PAYOUT_RULE_REF=" || payoutRuleRef || '0a'x || -
         "PAYOUT_FUNCTION_REF=" || payoutFunctionRef || '0a'x || -
         "ASSESSED_COVERED_LOSS_MINOR=" || assessedCoveredLossMinor || '0a'x || -
         "PAYABLE_MINOR=" || payableMinor || '0a'x || -
         "ASSESSED_AT=" || assessedAt || '0a'x || -
         "EVIDENCE_REF=" || evidenceRef || '0a'x

::class AllJapanInsuranceClaimsEngine public
::method assess
  use arg assessmentId, claim, policy, lock, contractVersion, functionRegistry, assessedCoveredLossMinor, assessedAt, evidenceRef = ""
  if assessmentId~string = "" | assessedAt~string = "" then return .AllJapanInsuranceResult~failure("CLAIM_ASSESSMENT_IDENTITY_REQUIRED")
  if claim == .nil | policy == .nil | lock == .nil | contractVersion == .nil | functionRegistry == .nil then return .AllJapanInsuranceResult~failure("CLAIM_ASSESSMENT_CONTEXT_REQUIRED")
  if claim~policyId \= policy~policyId then return .AllJapanInsuranceResult~failure("CLAIM_POLICY_MISMATCH")
  if lock~policyId \= policy~policyId then return .AllJapanInsuranceResult~failure("POLICY_LOCK_MISMATCH")
  if contractVersion~versionRef \= lock~contractVersionRef then return .AllJapanInsuranceResult~failure("CONTRACT_LOCK_MISMATCH")
  if contractVersion~productCode \= policy~productCode then return .AllJapanInsuranceResult~failure("CONTRACT_PRODUCT_MISMATCH")
  if \.AllJapanInsuranceRatingMath~nonNegativeWhole(assessedCoveredLossMinor) then return .AllJapanInsuranceResult~failure("ASSESSED_COVERED_LOSS_INVALID")
  calc = functionRegistry~execute(contractVersion~claimPayoutRule,assessedCoveredLossMinor)
  if \calc~ok then return calc
  payable = calc~value
  a = .AllJapanInsuranceClaimAssessment~new(assessmentId, claim~claimId, policy~policyId, contractVersion~versionRef, contractVersion~claimPayoutRule~ruleRef, contractVersion~claimPayoutRule~functionRef, assessedCoveredLossMinor, payable, assessedAt, evidenceRef)
  return .AllJapanInsuranceResult~success(a)

::requires "AllJapanInsurance.cls"
::requires "AllJapanInsuranceRating.cls"
