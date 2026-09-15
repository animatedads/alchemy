::class AJITestSupport public
::method assert class
  use arg condition, label
  if \condition then do
    say "FAIL" label
    exit 1
  end
  return .true
::method must class
  use arg result, label
  if result == .nil then do
    say "FAIL" label "NIL_RESULT"
    exit 1
  end
  if \result~ok then do
    say "FAIL" label result~code result~detail
    exit 1
  end
  return result
::method actor class
  use arg id, role
  return .AllJapanInsuranceActor~new(id, .array~of(role))
::method actorRoles class
  use arg id, roles
  return .AllJapanInsuranceActor~new(id, roles)
::method samplePlan class
  use arg planRef = "AJI-RATE-PI-GB-2026A", effectiveFrom = "2026-01-01", effectiveTo = ""
  tier = .AllJapanInsuranceTieredRiskPrice~new("TURNOVER_MINOR", 10000, 10000000, .AllJapanInsuranceRationalRate~new(1,1000,"0.1%"), .AllJapanInsuranceRationalRate~new(2,1000,"0.2%"))
  uw = .AllJapanInsuranceUnderwritingPrice~new("INDEMNITY_LIMIT_MINOR", .true, 100000000, 5000, .AllJapanInsuranceRationalRate~new(1,10000,"0.01% excess"))
  sales = .AllJapanInsuranceSalesCostRule~new("ADDITIVE", 0, .AllJapanInsuranceRationalRate~new(1,10,"10%"))
  taxes = .array~of(.AllJapanInsuranceTaxRule~new("IPT_TEST", "PRE_TAX_PREMIUM", .AllJapanInsuranceRationalRate~new(12,100,"12%")))
  return .AllJapanInsuranceRatingPlan~new(planRef,"PI","GB","GBP",effectiveFrom,effectiveTo,tier,uw,sales,taxes)
::method payoutRule class
  use arg ruleRef = "AJI-CLAIM-TEST/1", deductibleMinor = 0, rateNumerator = 1, rateDenominator = 1, hasLimit = .false, limitMinor = 0, functionRef = "AJI.PAYOUT.DEDUCT_RATE_CAP/1"
  return .AllJapanInsuranceClaimPayoutRule~new(ruleRef,"ASSESSED_COVERED_LOSS_MINOR",deductibleMinor,.AllJapanInsuranceRationalRate~new(rateNumerator,rateDenominator,ruleRef),hasLimit,limitMinor,functionRef)
::method contractVersion class
  use arg versionRef = "AJI-CONTRACT-HOME-JP/1", productCode = "HOME", jurisdiction = "JP", effectiveFrom = "2026-01-01", effectiveTo = "", payoutRule = .nil, ratingPlanRef = "", ratingFunctionRef = ""
  if payoutRule == .nil then payoutRule = self~payoutRule(versionRef || "-PAYOUT")
  return .AllJapanInsuranceContractVersion~new(versionRef,productCode,jurisdiction,effectiveFrom,effectiveTo,versionRef || "-WORDING",payoutRule,ratingPlanRef,"2025-12-01T00:00:00","AJI-PRODUCT-GOVERNANCE",ratingFunctionRef)
::method contractBook class
  use arg versions
  book=.AllJapanInsuranceContractBook~new
  do v over versions
    ignored=self~must(book~addVersion(v),"add contract version")
  end
  return book
::requires "AllJapanInsurance.cls"
::requires "AllJapanInsuranceRating.cls"
::requires "AllJapanInsuranceContract.cls"
::requires "AllJapanInsuranceProductRating.cls"
