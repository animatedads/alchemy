::class AJIProductTestSupport public
::method simplePlan class
  use arg planRef, productCode, coverageCode, basisCode, underwritingBasisCode, factorTables=.nil, effectiveFrom="2026-01-01", effectiveTo=""
  tier=.AllJapanInsuranceTieredRiskPrice~new(basisCode,1000,1000000000,.AllJapanInsuranceRationalRate~new(1,1000,"0.1%"),.AllJapanInsuranceRationalRate~new(1,1000,"0.1%"))
  uw=.AllJapanInsuranceUnderwritingPrice~new(underwritingBasisCode,.false,0,0,.AllJapanInsuranceRationalRate~new(0,1,"none"))
  sales=.AllJapanInsuranceSalesCostRule~new("NONE",0,.AllJapanInsuranceRationalRate~new(0,1,"none"))
  if factorTables==.nil then factorTables=.array~new
  return .AllJapanInsuranceRatingPlan~new(planRef,productCode,"GB","GBP",effectiveFrom,effectiveTo,tier,uw,sales,.array~new,.AllJapanInsuranceRatingBuild~FUNCTION_MIN_THEN_PRORATE,factorTables,.array~new,0,.AllJapanInsuranceProrationPolicy~new,coverageCode)
::method exactCondition class
  use arg factCode,value
  return .AllJapanInsuranceFactorCondition~new(factCode,"EXACT",value)
::method rangeCondition class
  use arg factCode,minUnits,maxUnits
  return .AllJapanInsuranceFactorCondition~new(factCode,"RANGE","",minUnits,maxUnits)
::method multiRow class
  use arg rowRef,conditions,numerator,denominator
  return .AllJapanInsuranceMultiFactorRow~new(rowRef,conditions,.AllJapanInsuranceRationalRate~new(numerator,denominator,rowRef))
::method program class
  use arg programRef,definitionRef,productCode,planRefs,effectiveFrom="2026-01-01",effectiveTo=""
  return .AllJapanInsuranceProductRatingProgram~new(programRef,definitionRef,productCode,"GB","GBP",effectiveFrom,effectiveTo,planRefs)
::requires "AllJapanInsuranceProductRating.cls"
