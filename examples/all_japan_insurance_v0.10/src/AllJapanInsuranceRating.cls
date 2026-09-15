/* AllJapanInsuranceRating.cls - deterministic quotation rating v0.6
 *
 * v0.6 retains the executable rating algorithm as a first-class immutable
 * identity and adds effective-dated/configuration-owned factor tables,
 * controlled schedule modifiers, minimum-premium guards and explicit
 * transaction proration.
 *
 * Existing v0.2 arithmetic remains the zero-configuration case:
 * fixed + proportionate up to step + proportionate over step +
 * underwriter fee/overage + sales cost + taxes.
 */

::class AllJapanInsuranceRatingBuild public
::constant API_VERSION "all.japan.insurance.rating/0.6"
::constant SALES_NONE "NONE"
::constant SALES_ADDITIVE "ADDITIVE"
::constant SALES_GROSS_UP "GROSS_UP"
::constant TAX_PRE_TAX_PREMIUM "PRE_TAX_PREMIUM"
::constant TAX_RISK_PREMIUM "RISK_PREMIUM"
::constant TAX_SALES_COST "SALES_COST"
::constant FACTOR_PROPORTIONATE "PROPORTIONATE"
::constant FACTOR_RISK_PREMIUM "RISK_PREMIUM"
::constant FACTOR_MATCH_EXACT "EXACT"
::constant FACTOR_MATCH_RANGE "RANGE"
::constant COST_FIXED "FIXED"
::constant COST_PROPORTIONATE_UP_TO_STEP "PROPORTIONATE_UP_TO_STEP"
::constant COST_PROPORTIONATE_OVER_STEP "PROPORTIONATE_OVER_STEP"
::constant COST_RATE_FACTOR "RATE_FACTOR_ADJUSTMENT"
::constant COST_SCHEDULE_MODIFIER "SCHEDULE_MODIFIER"
::constant COST_UNDERWRITER_FEE "UNDERWRITER_FEE"
::constant COST_OVERAGE "OVERAGE"
::constant COST_MINIMUM_PREMIUM "MINIMUM_PREMIUM_ADJUSTMENT"
::constant COST_PRORATION "PRORATION_ADJUSTMENT"
::constant COST_SALES "COMMISSION_OR_SALES_COST"
::constant FUNCTION_MIN_THEN_PRORATE "AJI.RATING.MIN_THEN_PRORATE/1"
::constant FUNCTION_PRORATE_THEN_MIN "AJI.RATING.PRORATE_THEN_MIN/1"

::class AllJapanInsuranceRatingMath public
::method nonNegativeWhole class
  use arg value
  if value == .nil then return .false
  signal on syntax name badNumber
  n = value + 0
  signal off syntax
  if n < 0 then return .false
  if n \= n~trunc then return .false
  return .true
badNumber:
  signal off syntax
  return .false
::method positiveWhole class
  use arg value
  if \self~nonNegativeWhole(value) then return .false
  return (value + 0) > 0
::method min class
  use arg a, b
  if a <= b then return a
  return b
::method max class
  use arg a, b
  if a >= b then return a
  return b
::method roundFraction class
  use arg numerator, denominator
  if denominator <= 0 then return .nil
  if numerator < 0 then return .nil
  return (2 * numerator + denominator) % (2 * denominator)
::method roundSignedFraction class
  use arg numerator, denominator
  if denominator <= 0 then return .nil
  if numerator >= 0 then return self~roundFraction(numerator, denominator)
  return -self~roundFraction(-numerator, denominator)
::method rateLessThan class
  use arg a, b
  return a~numerator * b~denominator < b~numerator * a~denominator
::method rateGreaterThan class
  use arg a, b
  return a~numerator * b~denominator > b~numerator * a~denominator

::class AllJapanInsuranceRationalRate public
::attribute numerator get
::attribute denominator get
::attribute label get
::method init
  expose numerator denominator label
  use arg numeratorArg, denominatorArg, labelArg = ""
  numerator = numeratorArg + 0
  denominator = denominatorArg + 0
  label = labelArg~string
::method valid
  expose numerator denominator
  return .AllJapanInsuranceRatingMath~nonNegativeWhole(numerator) & .AllJapanInsuranceRatingMath~positiveWhole(denominator)
::method positive
  return self~valid & self~numerator > 0
::method apply
  expose numerator denominator
  use arg basisUnits
  if \self~valid then return .nil
  if \.AllJapanInsuranceRatingMath~nonNegativeWhole(basisUnits) then return .nil
  return .AllJapanInsuranceRatingMath~roundFraction((basisUnits + 0) * numerator, denominator)
::method canonicalText
  expose numerator denominator label
  return numerator || "/" || denominator || ":" || label

::class AllJapanInsuranceTieredRiskPrice public
::attribute basisCode get
::attribute fixedMinor get
::attribute stepUnits get
::attribute upToStepRate get
::attribute overStepRate get
::method init
  expose basisCode fixedMinor stepUnits upToStepRate overStepRate
  use arg basisCodeArg, fixedMinorArg, stepUnitsArg, upToStepRateArg, overStepRateArg
  basisCode = .AllJapanInsuranceCanonical~token(basisCodeArg)
  fixedMinor = fixedMinorArg + 0
  stepUnits = stepUnitsArg + 0
  upToStepRate = upToStepRateArg
  overStepRate = overStepRateArg
::method validate
  expose basisCode fixedMinor stepUnits upToStepRate overStepRate
  if basisCode = "" then return .AllJapanInsuranceResult~failure("RATING_BASIS_CODE_REQUIRED")
  if \.AllJapanInsuranceRatingMath~nonNegativeWhole(fixedMinor) then return .AllJapanInsuranceResult~failure("RATING_FIXED_INVALID")
  if \.AllJapanInsuranceRatingMath~nonNegativeWhole(stepUnits) then return .AllJapanInsuranceResult~failure("RATING_STEP_INVALID")
  if upToStepRate == .nil | \upToStepRate~valid then return .AllJapanInsuranceResult~failure("RATING_UP_TO_STEP_RATE_INVALID")
  if overStepRate == .nil | \overStepRate~valid then return .AllJapanInsuranceResult~failure("RATING_OVER_STEP_RATE_INVALID")
  return .AllJapanInsuranceResult~success
::method canonicalText
  expose basisCode fixedMinor stepUnits upToStepRate overStepRate
  return "TIER|" || basisCode || "|" || fixedMinor || "|" || stepUnits || "|" || upToStepRate~canonicalText || "|" || overStepRate~canonicalText

::class AllJapanInsuranceUnderwritingPrice public
::attribute basisCode get
::attribute enabled get
::attribute riskLimitUnits get
::attribute underwriterFeeMinor get
::attribute overageRate get
::method init
  expose basisCode enabled riskLimitUnits underwriterFeeMinor overageRate
  use arg basisCodeArg, enabledArg, riskLimitUnitsArg, underwriterFeeMinorArg, overageRateArg
  basisCode = .AllJapanInsuranceCanonical~token(basisCodeArg)
  enabled = enabledArg
  riskLimitUnits = riskLimitUnitsArg + 0
  underwriterFeeMinor = underwriterFeeMinorArg + 0
  overageRate = overageRateArg
::method validate
  expose basisCode enabled riskLimitUnits underwriterFeeMinor overageRate
  if enabled then do
    if basisCode = "" then return .AllJapanInsuranceResult~failure("UNDERWRITING_BASIS_CODE_REQUIRED")
    if \.AllJapanInsuranceRatingMath~nonNegativeWhole(riskLimitUnits) then return .AllJapanInsuranceResult~failure("UNDERWRITING_LIMIT_INVALID")
    if \.AllJapanInsuranceRatingMath~nonNegativeWhole(underwriterFeeMinor) then return .AllJapanInsuranceResult~failure("UNDERWRITER_FEE_INVALID")
    if overageRate == .nil | \overageRate~valid then return .AllJapanInsuranceResult~failure("OVERAGE_RATE_INVALID")
  end
  return .AllJapanInsuranceResult~success
::method canonicalText
  expose basisCode enabled riskLimitUnits underwriterFeeMinor overageRate
  return "UW|" || basisCode || "|" || enabled || "|" || riskLimitUnits || "|" || underwriterFeeMinor || "|" || overageRate~canonicalText

::class AllJapanInsuranceSalesCostRule public
::attribute mode get
::attribute fixedMinor get
::attribute rate get
::method init
  expose mode fixedMinor rate
  use arg modeArg = "NONE", fixedMinorArg = 0, rateArg = .nil
  mode = .AllJapanInsuranceCanonical~token(modeArg)
  fixedMinor = fixedMinorArg + 0
  if rateArg == .nil then rate = .AllJapanInsuranceRationalRate~new(0, 1, "none")
  else rate = rateArg
::method validate
  expose mode fixedMinor rate
  if mode \= .AllJapanInsuranceRatingBuild~SALES_NONE, mode \= .AllJapanInsuranceRatingBuild~SALES_ADDITIVE, mode \= .AllJapanInsuranceRatingBuild~SALES_GROSS_UP then return .AllJapanInsuranceResult~failure("SALES_COST_MODE_INVALID", mode)
  if \.AllJapanInsuranceRatingMath~nonNegativeWhole(fixedMinor) then return .AllJapanInsuranceResult~failure("SALES_COST_FIXED_INVALID")
  if rate == .nil | \rate~valid then return .AllJapanInsuranceResult~failure("SALES_COST_RATE_INVALID")
  if mode = .AllJapanInsuranceRatingBuild~SALES_GROSS_UP then do
    if rate~numerator >= rate~denominator then return .AllJapanInsuranceResult~failure("SALES_GROSS_UP_RATE_INVALID")
  end
  return .AllJapanInsuranceResult~success
::method amount
  expose mode fixedMinor rate
  use arg riskPremiumMinor
  if mode = .AllJapanInsuranceRatingBuild~SALES_NONE then return 0
  if mode = .AllJapanInsuranceRatingBuild~SALES_ADDITIVE then return fixedMinor + rate~apply(riskPremiumMinor)
  base = riskPremiumMinor + fixedMinor
  gross = .AllJapanInsuranceRatingMath~roundFraction(base * rate~denominator, rate~denominator - rate~numerator)
  return gross - riskPremiumMinor
::method canonicalText
  expose mode fixedMinor rate
  return "SALES|" || mode || "|" || fixedMinor || "|" || rate~canonicalText

::class AllJapanInsuranceTaxRule public
::attribute code get
::attribute basisMode get
::attribute rate get
::method init
  expose code basisMode rate
  use arg codeArg, basisModeArg, rateArg
  code = .AllJapanInsuranceCanonical~token(codeArg)
  basisMode = .AllJapanInsuranceCanonical~token(basisModeArg)
  rate = rateArg
::method validate
  expose code basisMode rate
  if code = "" then return .AllJapanInsuranceResult~failure("TAX_CODE_REQUIRED")
  if basisMode \= .AllJapanInsuranceRatingBuild~TAX_PRE_TAX_PREMIUM, basisMode \= .AllJapanInsuranceRatingBuild~TAX_RISK_PREMIUM, basisMode \= .AllJapanInsuranceRatingBuild~TAX_SALES_COST then return .AllJapanInsuranceResult~failure("TAX_BASIS_INVALID", basisMode)
  if rate == .nil | \rate~valid then return .AllJapanInsuranceResult~failure("TAX_RATE_INVALID", code)
  return .AllJapanInsuranceResult~success
::method canonicalText
  expose code basisMode rate
  return "TAX|" || code || "|" || basisMode || "|" || rate~canonicalText

/* Exact versioned lookup table. A table belongs to a rate-plan release; its
 * tableRef is evidence, not a mutable database key that may be overwritten. */
::class AllJapanInsuranceFactorTable public
::attribute tableRef get
::attribute factCode get
::attribute targetMode get
::method init
  expose tableRef factCode targetMode rows
  use arg tableRefArg, factCodeArg, targetModeArg, rowsArg
  tableRef = tableRefArg~string
  factCode = .AllJapanInsuranceCanonical~token(factCodeArg)
  targetMode = .AllJapanInsuranceCanonical~token(targetModeArg)
  rows = .table~new
  if rowsArg \== .nil then do key over rowsArg~allIndexes
    rows[.AllJapanInsuranceCanonical~token(key)] = rowsArg[key]
  end
::method validate
  expose tableRef factCode targetMode rows
  if tableRef = "" | factCode = "" then return .AllJapanInsuranceResult~failure("FACTOR_TABLE_IDENTITY_REQUIRED")
  if targetMode \= .AllJapanInsuranceRatingBuild~FACTOR_PROPORTIONATE, targetMode \= .AllJapanInsuranceRatingBuild~FACTOR_RISK_PREMIUM then return .AllJapanInsuranceResult~failure("FACTOR_TARGET_INVALID", targetMode)
  if rows~items = 0 then return .AllJapanInsuranceResult~failure("FACTOR_TABLE_EMPTY", tableRef)
  do key over rows~allIndexes
    rate = rows[key]
    if rate == .nil | \rate~positive then return .AllJapanInsuranceResult~failure("FACTOR_RATE_INVALID", tableRef || ":" || key)
  end
  return .AllJapanInsuranceResult~success
::method factorFor
  expose rows tableRef
  use arg valueArg
  key = .AllJapanInsuranceCanonical~token(valueArg)
  if \rows~hasIndex(key) then return .AllJapanInsuranceResult~failure("FACTOR_ROW_NOT_FOUND", tableRef || ":" || key)
  return .AllJapanInsuranceResult~success(rows[key], key)
::method factorForRequest
  expose factCode
  use arg request
  fact=request~factorFact(factCode)
  if fact==.nil then return .AllJapanInsuranceResult~failure("FACTOR_FACT_REQUIRED",factCode)
  return self~factorFor(fact)
::method evidenceBasisCode
  expose factCode
  return factCode
::method canonicalText
  expose tableRef factCode targetMode rows
  keys = .array~new
  do key over rows~allIndexes
    keys~append(key)
  end
  keys~sort
  out = "FACTOR_TABLE|" || tableRef || "|" || factCode || "|" || targetMode
  do key over keys
    out ||= "|" || key || "=" || rows[key]~canonicalText
  end
  return out


/* Multi-dimensional factor rows support exact categorical conditions and
 * inclusive/exclusive numeric bands.  A lookup must match exactly one row:
 * zero or multiple matches fail closed rather than choosing by row order. */
::class AllJapanInsuranceFactorCondition public
::attribute factCode get
::attribute mode get
::attribute exactValue get
::attribute minUnits get
::attribute maxUnits get
::method init
  expose factCode mode exactValue minUnits maxUnits
  use arg factCodeArg, modeArg, exactValueArg = "", minUnitsArg = 0, maxUnitsArg = 0
  factCode=.AllJapanInsuranceCanonical~token(factCodeArg)
  mode=.AllJapanInsuranceCanonical~token(modeArg)
  exactValue=.AllJapanInsuranceCanonical~token(exactValueArg)
  minUnits=minUnitsArg + 0
  maxUnits=maxUnitsArg + 0
::method validate
  expose factCode mode exactValue minUnits maxUnits
  if factCode="" then return .AllJapanInsuranceResult~failure("FACTOR_CONDITION_FACT_REQUIRED")
  if mode=.AllJapanInsuranceRatingBuild~FACTOR_MATCH_EXACT then do
    if exactValue="" then return .AllJapanInsuranceResult~failure("FACTOR_CONDITION_EXACT_REQUIRED",factCode)
    return .AllJapanInsuranceResult~success
  end
  if mode=.AllJapanInsuranceRatingBuild~FACTOR_MATCH_RANGE then do
    if \.AllJapanInsuranceRatingMath~nonNegativeWhole(minUnits) | \.AllJapanInsuranceRatingMath~positiveWhole(maxUnits) then return .AllJapanInsuranceResult~failure("FACTOR_CONDITION_RANGE_INVALID",factCode)
    if maxUnits<=minUnits then return .AllJapanInsuranceResult~failure("FACTOR_CONDITION_RANGE_INVALID",factCode)
    return .AllJapanInsuranceResult~success
  end
  return .AllJapanInsuranceResult~failure("FACTOR_CONDITION_MODE_INVALID",mode)
::method matches
  expose mode exactValue minUnits maxUnits
  use arg value
  if mode=.AllJapanInsuranceRatingBuild~FACTOR_MATCH_EXACT then return .AllJapanInsuranceCanonical~token(value)=exactValue
  signal on syntax name notNumeric
  n=value + 0
  signal off syntax
  if n \= n~trunc then return .false
  return n>=minUnits & n<maxUnits
notNumeric:
  signal off syntax
  return .false
::method canonicalText
  expose factCode mode exactValue minUnits maxUnits
  if mode=.AllJapanInsuranceRatingBuild~FACTOR_MATCH_EXACT then return factCode || "=EXACT:" || exactValue
  return factCode || "=RANGE:[" || minUnits || "," || maxUnits || ")"

::class AllJapanInsuranceMultiFactorRow public
::attribute rowRef get
::attribute factor get
::attribute conditions get
::method init
  expose rowRef factor conditions
  use arg rowRefArg, conditionsArg, factorArg
  rowRef=rowRefArg~string
  if conditionsArg==.nil then conditions=.array~new
  else conditions=conditionsArg
  factor=factorArg
::method validate
  expose rowRef factor conditions
  if rowRef="" then return .AllJapanInsuranceResult~failure("FACTOR_ROW_REF_REQUIRED")
  if factor==.nil | \factor~positive then return .AllJapanInsuranceResult~failure("FACTOR_RATE_INVALID",rowRef)
  if conditions~items=0 then return .AllJapanInsuranceResult~failure("FACTOR_ROW_CONDITIONS_REQUIRED",rowRef)
  seen=.set~new
  do condition over conditions
    if condition==.nil then return .AllJapanInsuranceResult~failure("FACTOR_CONDITION_REQUIRED",rowRef)
    r=condition~validate
    if \r~ok then return r
    if seen~hasIndex(condition~factCode) then return .AllJapanInsuranceResult~failure("FACTOR_CONDITION_DUPLICATE",rowRef || ":" || condition~factCode)
    seen~put(condition~factCode)
  end
  return .AllJapanInsuranceResult~success
::method matchesRequest
  expose conditions
  use arg request
  do condition over conditions
    value=request~factorFact(condition~factCode)
    if value==.nil then return .AllJapanInsuranceResult~failure("FACTOR_FACT_REQUIRED",condition~factCode)
    if \condition~matches(value) then return .AllJapanInsuranceResult~success(.false)
  end
  return .AllJapanInsuranceResult~success(.true)
::method canonicalText
  expose rowRef factor conditions
  out="ROW|" || rowRef
  do condition over conditions
    out||="|" || condition~canonicalText
  end
  out||="|FACTOR=" || factor~canonicalText
  return out

::class AllJapanInsuranceMultiFactorTable public
::attribute tableRef get
::attribute targetMode get
::attribute rows get
::method init
  expose tableRef targetMode rows
  use arg tableRefArg, targetModeArg, rowsArg
  tableRef=tableRefArg~string
  targetMode=.AllJapanInsuranceCanonical~token(targetModeArg)
  if rowsArg==.nil then rows=.array~new
  else rows=rowsArg
::method validate
  expose tableRef targetMode rows
  if tableRef="" then return .AllJapanInsuranceResult~failure("FACTOR_TABLE_IDENTITY_REQUIRED")
  if targetMode \= .AllJapanInsuranceRatingBuild~FACTOR_PROPORTIONATE, targetMode \= .AllJapanInsuranceRatingBuild~FACTOR_RISK_PREMIUM then return .AllJapanInsuranceResult~failure("FACTOR_TARGET_INVALID",targetMode)
  if rows~items=0 then return .AllJapanInsuranceResult~failure("FACTOR_TABLE_EMPTY",tableRef)
  seen=.set~new
  do row over rows
    if row==.nil then return .AllJapanInsuranceResult~failure("FACTOR_ROW_REQUIRED",tableRef)
    r=row~validate
    if \r~ok then return r
    if seen~hasIndex(row~rowRef) then return .AllJapanInsuranceResult~failure("FACTOR_ROW_DUPLICATE",tableRef || ":" || row~rowRef)
    seen~put(row~rowRef)
  end
  return .AllJapanInsuranceResult~success
::method factorForRequest
  expose rows tableRef
  use arg request
  matched=.array~new
  do row over rows
    r=row~matchesRequest(request)
    if \r~ok then return r
    if r~value then matched~append(row)
  end
  if matched~items=0 then return .AllJapanInsuranceResult~failure("FACTOR_ROW_NOT_FOUND",tableRef)
  if matched~items>1 then return .AllJapanInsuranceResult~failure("FACTOR_ROW_AMBIGUOUS",tableRef)
  row=matched[1]
  return .AllJapanInsuranceResult~success(row~factor,row~rowRef)
::method evidenceBasisCode
  return "MULTI_DIMENSION"
::method canonicalText
  expose tableRef targetMode rows
  out="MULTI_FACTOR_TABLE|" || tableRef || "|" || targetMode
  do row over rows
    out||="|" || row~canonicalText
  end
  return out

/* Underwriter-selected schedule modifier / IRPM-style control. The rate plan
 * sets the permitted factor interval. Non-unity selections require evidence. */
::class AllJapanInsuranceScheduleModifierRule public
::attribute code get
::attribute minFactor get
::attribute maxFactor get
::attribute requiresJustification get
::method init
  expose code minFactor maxFactor requiresJustification
  use arg codeArg, minFactorArg, maxFactorArg, requiresJustificationArg = .true
  code = .AllJapanInsuranceCanonical~token(codeArg)
  minFactor = minFactorArg
  maxFactor = maxFactorArg
  requiresJustification = requiresJustificationArg
::method validate
  expose code minFactor maxFactor
  if code = "" then return .AllJapanInsuranceResult~failure("MODIFIER_CODE_REQUIRED")
  if minFactor == .nil | maxFactor == .nil | \minFactor~positive | \maxFactor~positive then return .AllJapanInsuranceResult~failure("MODIFIER_RANGE_INVALID", code)
  if .AllJapanInsuranceRatingMath~rateGreaterThan(minFactor, maxFactor) then return .AllJapanInsuranceResult~failure("MODIFIER_RANGE_REVERSED", code)
  return .AllJapanInsuranceResult~success
::method permits
  expose minFactor maxFactor
  use arg factor
  if factor == .nil | \factor~positive then return .false
  if .AllJapanInsuranceRatingMath~rateLessThan(factor, minFactor) then return .false
  if .AllJapanInsuranceRatingMath~rateGreaterThan(factor, maxFactor) then return .false
  return .true
::method canonicalText
  expose code minFactor maxFactor requiresJustification
  return "MODIFIER_RULE|" || code || "|" || minFactor~canonicalText || "|" || maxFactor~canonicalText || "|" || requiresJustification

::class AllJapanInsuranceSelectedModifier public
::attribute code get
::attribute factor get
::attribute justification get
::attribute authorizedBy get
::method init
  expose code factor justification authorizedBy
  use arg codeArg, factorArg, justificationArg = "", authorizedByArg = ""
  code = .AllJapanInsuranceCanonical~token(codeArg)
  factor = factorArg
  justification = justificationArg~string
  authorizedBy = authorizedByArg~string

/* Proration is explicit evidence supplied to rating. Date/day-count semantics
 * are therefore not silently hidden inside the calculation. */
::class AllJapanInsuranceProration public
::attribute numerator get
::attribute denominator get
::attribute basisRef get
::method init
  expose numerator denominator basisRef
  use arg numeratorArg = 1, denominatorArg = 1, basisRefArg = "FULL_TERM"
  numerator = numeratorArg + 0
  denominator = denominatorArg + 0
  basisRef = basisRefArg~string
::method validate
  expose numerator denominator basisRef
  if \.AllJapanInsuranceRatingMath~nonNegativeWhole(numerator) | \.AllJapanInsuranceRatingMath~positiveWhole(denominator) then return .AllJapanInsuranceResult~failure("PRORATION_FRACTION_INVALID")
  if numerator > denominator then return .AllJapanInsuranceResult~failure("PRORATION_OVER_FULL_TERM")
  if basisRef = "" then return .AllJapanInsuranceResult~failure("PRORATION_BASIS_REQUIRED")
  return .AllJapanInsuranceResult~success
::method isFullTerm
  expose numerator denominator
  return numerator = denominator
::method applySigned
  expose numerator denominator
  use arg amount
  return .AllJapanInsuranceRatingMath~roundSignedFraction((amount + 0) * numerator, denominator)
::method canonicalText
  expose numerator denominator basisRef
  return numerator || "/" || denominator || ":" || basisRef

/* Rate-plan policy says which full-term cost lines are non-proratable. */
::class AllJapanInsuranceProrationPolicy public
::method init
  expose nonProratable
  use arg nonProratableCodesArg = .nil
  nonProratable = .set~new
  if nonProratableCodesArg \== .nil then do code over nonProratableCodesArg
    nonProratable~put(.AllJapanInsuranceCanonical~token(code))
  end
::method isProratable
  expose nonProratable
  use arg codeArg
  return \nonProratable~hasIndex(.AllJapanInsuranceCanonical~token(codeArg))
::method canonicalText
  expose nonProratable
  keys=.array~new
  do key over nonProratable~allIndexes
    keys~append(key)
  end
  keys~sort
  out="PRORATION_POLICY"
  do key over keys
    out ||= "|NON=" || key
  end
  return out

::class AllJapanInsuranceRatingPlan public
::attribute planRef get
::attribute productCode get
::attribute jurisdiction get
::attribute currency get
::attribute effectiveFrom get
::attribute effectiveTo get
::attribute tieredRiskPrice get
::attribute underwritingPrice get
::attribute salesCostRule get
::attribute taxRules get
::attribute functionRef get
::attribute factorTables get
::attribute modifierRules get
::attribute minimumPremiumMinor get
::attribute prorationPolicy get
::attribute coverageCode get
::method init
  expose planRef productCode jurisdiction currency effectiveFrom effectiveTo tieredRiskPrice underwritingPrice salesCostRule taxRules functionRef factorTables modifierRules minimumPremiumMinor prorationPolicy coverageCode
  use arg planRefArg, productCodeArg, jurisdictionArg, currencyArg, effectiveFromArg, effectiveToArg, tieredRiskPriceArg, underwritingPriceArg, salesCostRuleArg, taxRulesArg = .nil, functionRefArg = "AJI.RATING.MIN_THEN_PRORATE/1", factorTablesArg = .nil, modifierRulesArg = .nil, minimumPremiumMinorArg = 0, prorationPolicyArg = .nil, coverageCodeArg = "POLICY"
  planRef = planRefArg~string
  productCode = .AllJapanInsuranceCanonical~token(productCodeArg)
  jurisdiction = .AllJapanInsuranceCanonical~token(jurisdictionArg)
  currency = .AllJapanInsuranceCanonical~token(currencyArg)
  effectiveFrom = effectiveFromArg~string
  effectiveTo = effectiveToArg~string
  tieredRiskPrice = tieredRiskPriceArg
  underwritingPrice = underwritingPriceArg
  salesCostRule = salesCostRuleArg
  if taxRulesArg == .nil then taxRules = .array~new
  else taxRules = taxRulesArg
  functionRef = functionRefArg~string
  if factorTablesArg == .nil then factorTables = .array~new
  else factorTables = factorTablesArg
  if modifierRulesArg == .nil then modifierRules = .array~new
  else modifierRules = modifierRulesArg
  minimumPremiumMinor = minimumPremiumMinorArg + 0
  if prorationPolicyArg == .nil then prorationPolicy = .AllJapanInsuranceProrationPolicy~new
  else prorationPolicy = prorationPolicyArg
  coverageCode=.AllJapanInsuranceCanonical~token(coverageCodeArg)
::method validate
  expose planRef productCode jurisdiction currency effectiveFrom effectiveTo tieredRiskPrice underwritingPrice salesCostRule taxRules functionRef factorTables modifierRules minimumPremiumMinor prorationPolicy coverageCode
  if planRef = "" | productCode = "" | jurisdiction = "" | currency = "" | effectiveFrom = "" | functionRef = "" | coverageCode = "" then return .AllJapanInsuranceResult~failure("RATE_PLAN_IDENTITY_REQUIRED")
  if \.AllJapanInsuranceCurrency~supported(currency) then return .AllJapanInsuranceResult~failure("CURRENCY_UNSUPPORTED",currency)
  if effectiveTo \= "" & effectiveTo <= effectiveFrom then return .AllJapanInsuranceResult~failure("RATE_PLAN_PERIOD_INVALID")
  if tieredRiskPrice == .nil then return .AllJapanInsuranceResult~failure("TIERED_RISK_PRICE_REQUIRED")
  r = tieredRiskPrice~validate
  if \r~ok then return r
  if underwritingPrice == .nil then return .AllJapanInsuranceResult~failure("UNDERWRITING_PRICE_REQUIRED")
  r = underwritingPrice~validate
  if \r~ok then return r
  if salesCostRule == .nil then return .AllJapanInsuranceResult~failure("SALES_COST_RULE_REQUIRED")
  r = salesCostRule~validate
  if \r~ok then return r
  do tax over taxRules
    r = tax~validate
    if \r~ok then return r
  end
  seen=.set~new
  do table over factorTables
    if table == .nil then return .AllJapanInsuranceResult~failure("FACTOR_TABLE_REQUIRED")
    r=table~validate
    if \r~ok then return r
    if seen~hasIndex(table~tableRef) then return .AllJapanInsuranceResult~failure("FACTOR_TABLE_DUPLICATE",table~tableRef)
    seen~put(table~tableRef)
  end
  seen=.set~new
  do rule over modifierRules
    if rule == .nil then return .AllJapanInsuranceResult~failure("MODIFIER_RULE_REQUIRED")
    r=rule~validate
    if \r~ok then return r
    if seen~hasIndex(rule~code) then return .AllJapanInsuranceResult~failure("MODIFIER_RULE_DUPLICATE",rule~code)
    seen~put(rule~code)
  end
  if \.AllJapanInsuranceRatingMath~nonNegativeWhole(minimumPremiumMinor) then return .AllJapanInsuranceResult~failure("MINIMUM_PREMIUM_INVALID")
  if prorationPolicy == .nil then return .AllJapanInsuranceResult~failure("PRORATION_POLICY_REQUIRED")
  return .AllJapanInsuranceResult~success
::method modifierRule
  expose modifierRules
  use arg codeArg
  code=.AllJapanInsuranceCanonical~token(codeArg)
  do rule over modifierRules
    if rule~code=code then return rule
  end
  return .nil
::method appliesAsOf
  expose effectiveFrom effectiveTo
  use arg asOf
  d = asOf~string
  if d < effectiveFrom then return .false
  if effectiveTo \= "" & d >= effectiveTo then return .false
  return .true
::method canonicalText
  expose planRef productCode jurisdiction currency effectiveFrom effectiveTo tieredRiskPrice underwritingPrice salesCostRule taxRules functionRef factorTables modifierRules minimumPremiumMinor prorationPolicy coverageCode
  out="AJI-RATE-PLAN/0.5" || '0a'x
  out||="PLAN_REF=" || planRef || '0a'x
  out||="PRODUCT=" || productCode || '0a'x
  out||="JURISDICTION=" || jurisdiction || '0a'x
  out||="CURRENCY=" || currency || '0a'x
  out||="EFFECTIVE_FROM=" || effectiveFrom || '0a'x
  out||="EFFECTIVE_TO=" || effectiveTo || '0a'x
  out||="FUNCTION_REF=" || functionRef || '0a'x
  out||="COVERAGE_CODE=" || coverageCode || '0a'x
  out||="MINIMUM_PREMIUM_MINOR=" || minimumPremiumMinor || '0a'x
  out||=tieredRiskPrice~canonicalText || '0a'x
  out||=underwritingPrice~canonicalText || '0a'x
  out||=salesCostRule~canonicalText || '0a'x
  do table over factorTables
    out||=table~canonicalText || '0a'x
  end
  do rule over modifierRules
    out||=rule~canonicalText || '0a'x
  end
  do tax over taxRules
    out||=tax~canonicalText || '0a'x
  end
  out||=prorationPolicy~canonicalText || '0a'x
  return out
::method semanticIdentity
  return self~canonicalText

::class AllJapanInsuranceRatingRequest public
::attribute submissionId get
::attribute productCode get
::attribute jurisdiction get
::attribute currency get
::attribute rateAsOf get
::attribute ratingBasisCode get
::attribute ratingBasisUnits get
::attribute underwritingBasisCode get
::attribute underwritingRiskUnits get
::attribute factorFacts get
::attribute selectedModifiers get
::attribute proration get
::attribute riskRef get
::attribute coverageCode get
::method init
  expose submissionId productCode jurisdiction currency rateAsOf ratingBasisCode ratingBasisUnits underwritingBasisCode underwritingRiskUnits factorFacts selectedModifiers proration riskRef coverageCode
  use arg submissionIdArg, productCodeArg, jurisdictionArg, currencyArg, rateAsOfArg, ratingBasisCodeArg, ratingBasisUnitsArg, underwritingBasisCodeArg, underwritingRiskUnitsArg, factorFactsArg = .nil, selectedModifiersArg = .nil, prorationArg = .nil, riskRefArg = "", coverageCodeArg = "POLICY"
  submissionId = submissionIdArg~string
  productCode = .AllJapanInsuranceCanonical~token(productCodeArg)
  jurisdiction = .AllJapanInsuranceCanonical~token(jurisdictionArg)
  currency = .AllJapanInsuranceCanonical~token(currencyArg)
  rateAsOf = rateAsOfArg~string
  ratingBasisCode = .AllJapanInsuranceCanonical~token(ratingBasisCodeArg)
  ratingBasisUnits = ratingBasisUnitsArg + 0
  underwritingBasisCode = .AllJapanInsuranceCanonical~token(underwritingBasisCodeArg)
  underwritingRiskUnits = underwritingRiskUnitsArg + 0
  factorFacts=.table~new
  if factorFactsArg \== .nil then do key over factorFactsArg~allIndexes
    factorFacts[.AllJapanInsuranceCanonical~token(key)] = factorFactsArg[key]
  end
  if selectedModifiersArg == .nil then selectedModifiers=.array~new
  else selectedModifiers=selectedModifiersArg
  if prorationArg == .nil then proration=.AllJapanInsuranceProration~new
  else proration=prorationArg
  riskRef=riskRefArg~string
  coverageCode=.AllJapanInsuranceCanonical~token(coverageCodeArg)
::method validate
  expose submissionId productCode jurisdiction currency rateAsOf ratingBasisCode ratingBasisUnits underwritingBasisCode underwritingRiskUnits selectedModifiers proration coverageCode
  if submissionId = "" | productCode = "" | jurisdiction = "" | currency = "" | rateAsOf = "" | coverageCode = "" then return .AllJapanInsuranceResult~failure("RATING_REQUEST_IDENTITY_REQUIRED")
  if \.AllJapanInsuranceCurrency~supported(currency) then return .AllJapanInsuranceResult~failure("CURRENCY_UNSUPPORTED",currency)
  if ratingBasisCode = "" | underwritingBasisCode = "" then return .AllJapanInsuranceResult~failure("RATING_REQUEST_BASIS_REQUIRED")
  if \.AllJapanInsuranceRatingMath~nonNegativeWhole(ratingBasisUnits) | \.AllJapanInsuranceRatingMath~nonNegativeWhole(underwritingRiskUnits) then return .AllJapanInsuranceResult~failure("RATING_REQUEST_UNITS_INVALID")
  if proration == .nil then return .AllJapanInsuranceResult~failure("PRORATION_REQUIRED")
  r=proration~validate
  if \r~ok then return r
  seen=.set~new
  do selection over selectedModifiers
    if selection == .nil | selection~code="" | selection~factor==.nil | \selection~factor~positive then return .AllJapanInsuranceResult~failure("MODIFIER_SELECTION_INVALID")
    if seen~hasIndex(selection~code) then return .AllJapanInsuranceResult~failure("MODIFIER_SELECTION_DUPLICATE",selection~code)
    seen~put(selection~code)
  end
  return .AllJapanInsuranceResult~success
::method factorFact
  expose factorFacts
  use arg codeArg
  code=.AllJapanInsuranceCanonical~token(codeArg)
  if \factorFacts~hasIndex(code) then return .nil
  return factorFacts[code]

::class AllJapanInsuranceRatedCost public
::attribute sequence get
::attribute code get
::attribute basisCode get
::attribute basisUnits get
::attribute rateNumerator get
::attribute rateDenominator get
::attribute amountMinor get
::attribute trigger get
::attribute ruleRef get
::attribute currency get
::method init
  expose sequence code basisCode basisUnits rateNumerator rateDenominator amountMinor trigger ruleRef currency
  use arg sequenceArg, codeArg, basisCodeArg, basisUnitsArg, rateNumeratorArg, rateDenominatorArg, amountMinorArg, triggerArg = "", ruleRefArg = "", currencyArg = ""
  sequence = sequenceArg + 0
  code = .AllJapanInsuranceCanonical~token(codeArg)
  basisCode = .AllJapanInsuranceCanonical~token(basisCodeArg)
  basisUnits = basisUnitsArg + 0
  rateNumerator = rateNumeratorArg + 0
  rateDenominator = rateDenominatorArg + 0
  amountMinor = amountMinorArg + 0
  trigger = triggerArg~string
  ruleRef = ruleRefArg~string
  currency = .AllJapanInsuranceCanonical~token(currencyArg)
::method canonicalText
  expose sequence code basisCode basisUnits rateNumerator rateDenominator amountMinor trigger ruleRef currency
  return sequence || "|" || code || "|" || basisCode || "|" || basisUnits || "|" || rateNumerator || "/" || rateDenominator || "|" || amountMinor || "|" || currency || "|" || trigger || "|" || ruleRef

::class AllJapanInsuranceRatingResult public
::attribute ratingId get
::attribute submissionId get
::attribute productCode get
::attribute currency get
::attribute planRef get
::attribute ratingFunctionRef get
::attribute ratedAt get
::attribute rateAsOf get
::attribute costs get
::attribute fullTermRiskPremiumMinor get
::attribute riskPremiumMinor get
::attribute salesCostMinor get
::attribute preTaxPremiumMinor get
::attribute taxMinor get
::attribute totalPremiumMinor get
::attribute requiresUnderwriter get
::attribute underwritingOverageUnits get
::attribute proration get
::attribute riskRef get
::attribute coverageCode get
::method init
  expose ratingId submissionId productCode currency planRef ratingFunctionRef ratedAt rateAsOf costs fullTermRiskPremiumMinor riskPremiumMinor salesCostMinor preTaxPremiumMinor taxMinor totalPremiumMinor requiresUnderwriter underwritingOverageUnits proration riskRef coverageCode
  use arg ratingIdArg, submissionIdArg, productCodeArg, currencyArg, planRefArg, ratingFunctionRefArg, ratedAtArg, rateAsOfArg, costsArg, fullTermRiskPremiumMinorArg, riskPremiumMinorArg, salesCostMinorArg, preTaxPremiumMinorArg, taxMinorArg, totalPremiumMinorArg, requiresUnderwriterArg, underwritingOverageUnitsArg, prorationArg, riskRefArg = "", coverageCodeArg = "POLICY"
  ratingId = ratingIdArg~string
  submissionId = submissionIdArg~string
  productCode = .AllJapanInsuranceCanonical~token(productCodeArg)
  currency = .AllJapanInsuranceCanonical~token(currencyArg)
  planRef = planRefArg~string
  ratingFunctionRef = ratingFunctionRefArg~string
  ratedAt = ratedAtArg~string
  rateAsOf = rateAsOfArg~string
  costs = costsArg
  fullTermRiskPremiumMinor = fullTermRiskPremiumMinorArg + 0
  riskPremiumMinor = riskPremiumMinorArg + 0
  salesCostMinor = salesCostMinorArg + 0
  preTaxPremiumMinor = preTaxPremiumMinorArg + 0
  taxMinor = taxMinorArg + 0
  totalPremiumMinor = totalPremiumMinorArg + 0
  requiresUnderwriter = requiresUnderwriterArg
  underwritingOverageUnits = underwritingOverageUnitsArg + 0
  proration = prorationArg
  riskRef=riskRefArg~string
  coverageCode=.AllJapanInsuranceCanonical~token(coverageCodeArg)
::method componentAmount
  expose costs
  use arg codeArg
  code = .AllJapanInsuranceCanonical~token(codeArg)
  total = 0
  do c over costs
    if c~code = code then total += c~amountMinor
  end
  return total
::method balanced
  expose costs totalPremiumMinor
  total = 0
  do c over costs
    total += c~amountMinor
  end
  return total = totalPremiumMinor
::method canonicalText
  expose ratingId submissionId productCode currency planRef ratingFunctionRef ratedAt rateAsOf costs fullTermRiskPremiumMinor totalPremiumMinor requiresUnderwriter underwritingOverageUnits proration riskRef coverageCode
  out = "AJI-RATING/0.6" || '0a'x
  out ||= "RATING_ID=" || ratingId || '0a'x
  out ||= "SUBMISSION_ID=" || submissionId || '0a'x
  out ||= "PRODUCT=" || productCode || '0a'x
  out ||= "CURRENCY=" || currency || '0a'x
  out ||= "PLAN_REF=" || planRef || '0a'x
  out ||= "RATING_FUNCTION_REF=" || ratingFunctionRef || '0a'x
  out ||= "RISK_REF=" || riskRef || '0a'x
  out ||= "COVERAGE_CODE=" || coverageCode || '0a'x
  out ||= "RATE_AS_OF=" || rateAsOf || '0a'x
  out ||= "RATED_AT=" || ratedAt || '0a'x
  out ||= "PRORATION=" || proration~canonicalText || '0a'x
  out ||= "FULL_TERM_RISK_PREMIUM_MINOR=" || fullTermRiskPremiumMinor || '0a'x
  out ||= "REQUIRES_UNDERWRITER=" || requiresUnderwriter || '0a'x
  out ||= "UNDERWRITING_OVERAGE_UNITS=" || underwritingOverageUnits || '0a'x
  do c over costs
    out ||= "COST=" || c~canonicalText || '0a'x
  end
  out ||= "TOTAL_MINOR=" || totalPremiumMinor || '0a'x
  return out

::class AllJapanInsuranceRatingFunctionMinThenProrateV1 public
::method functionRef
  return .AllJapanInsuranceRatingBuild~FUNCTION_MIN_THEN_PRORATE
::method canonicalText
  return "AJI-RATING-FUNCTION/1|BASE_FACTOR_MODIFIER_UW_MIN_PRORATE_SALES_TAX"
::method execute
  use arg ratingId, request, plan, ratedAt
  return .AllJapanInsuranceRatingCalculator~calculate(ratingId,request,plan,ratedAt,self~functionRef,.true)

::class AllJapanInsuranceRatingFunctionProrateThenMinV1 public
::method functionRef
  return .AllJapanInsuranceRatingBuild~FUNCTION_PRORATE_THEN_MIN
::method canonicalText
  return "AJI-RATING-FUNCTION/1|BASE_FACTOR_MODIFIER_UW_PRORATE_MIN_SALES_TAX"
::method execute
  use arg ratingId, request, plan, ratedAt
  return .AllJapanInsuranceRatingCalculator~calculate(ratingId,request,plan,ratedAt,self~functionRef,.false)

::class AllJapanInsuranceRatingFunctionRegistry public
::method init
  expose functions
  functions=.table~new
::method register
  expose functions
  use arg function
  if function == .nil then return .AllJapanInsuranceResult~failure("RATING_FUNCTION_REQUIRED")
  ref=function~functionRef
  if ref="" then return .AllJapanInsuranceResult~failure("RATING_FUNCTION_REF_REQUIRED")
  if functions~hasIndex(ref) then return .AllJapanInsuranceResult~failure("RATING_FUNCTION_DUPLICATE",ref)
  functions[ref]=function
  return .AllJapanInsuranceResult~success(function)
::method function
  expose functions
  use arg functionRef
  return functions[functionRef~string]
::method execute
  expose functions
  use arg ratingId,request,plan,ratedAt
  function=functions[plan~functionRef]
  if function==.nil then return .AllJapanInsuranceResult~failure("RATING_FUNCTION_NOT_FOUND",plan~functionRef)
  return function~execute(ratingId,request,plan,ratedAt)
::method count
  expose functions
  return functions~items

::class AllJapanInsuranceRateBook public
::method init
  expose plans byRef functionRegistry
  use arg functionRegistryArg=.nil
  plans = .array~new
  byRef=.table~new
  if functionRegistryArg==.nil then do
    functionRegistry=.AllJapanInsuranceRatingFunctionRegistry~new
    ignored=functionRegistry~register(.AllJapanInsuranceRatingFunctionMinThenProrateV1~new)
    ignored=functionRegistry~register(.AllJapanInsuranceRatingFunctionProrateThenMinV1~new)
  end
  else functionRegistry=functionRegistryArg
::method functionRegistry
  expose functionRegistry
  return functionRegistry
::method addPlan
  expose plans byRef functionRegistry
  use arg plan
  if plan == .nil then return .AllJapanInsuranceResult~failure("RATE_PLAN_REQUIRED")
  r = plan~validate
  if \r~ok then return r
  if functionRegistry~function(plan~functionRef)==.nil then return .AllJapanInsuranceResult~failure("RATING_FUNCTION_NOT_FOUND",plan~functionRef)
  if byRef~hasIndex(plan~planRef) then return .AllJapanInsuranceResult~failure("RATE_PLAN_DUPLICATE",plan~planRef)
  plans~append(plan)
  byRef[plan~planRef]=plan
  return .AllJapanInsuranceResult~success(plan)
::method plan
  expose byRef
  use arg planRef
  return byRef[planRef~string]
::method resolve
  expose plans
  use arg request
  if request == .nil then return .AllJapanInsuranceResult~failure("RATING_REQUEST_REQUIRED")
  r = request~validate
  if \r~ok then return r
  matches = .array~new
  do plan over plans
    if plan~productCode \= request~productCode then iterate
    if plan~jurisdiction \= request~jurisdiction then iterate
    if plan~currency \= request~currency then iterate
    if plan~coverageCode \= request~coverageCode then iterate
    if plan~tieredRiskPrice~basisCode \= request~ratingBasisCode then iterate
    if plan~underwritingPrice~enabled & plan~underwritingPrice~basisCode \= request~underwritingBasisCode then iterate
    if \plan~appliesAsOf(request~rateAsOf) then iterate
    matches~append(plan)
  end
  if matches~items = 0 then return .AllJapanInsuranceResult~failure("RATE_PLAN_NOT_FOUND")
  if matches~items > 1 then return .AllJapanInsuranceResult~failure("RATE_PLAN_AMBIGUOUS")
  return .AllJapanInsuranceResult~success(matches[1])
::method rate
  expose functionRegistry
  use arg ratingId, request, ratedAt
  r=self~resolve(request)
  if \r~ok then return r
  return .AllJapanInsuranceRatingEngine~new(functionRegistry)~rate(ratingId,request,r~value,ratedAt)
::method count
  expose plans
  return plans~items

::class AllJapanInsuranceRatingEngine public
::method init
  expose functionRegistry
  use arg functionRegistryArg=.nil
  if functionRegistryArg==.nil then do
    functionRegistry=.AllJapanInsuranceRatingFunctionRegistry~new
    ignored=functionRegistry~register(.AllJapanInsuranceRatingFunctionMinThenProrateV1~new)
    ignored=functionRegistry~register(.AllJapanInsuranceRatingFunctionProrateThenMinV1~new)
  end
  else functionRegistry=functionRegistryArg
::method functionRegistry
  expose functionRegistry
  return functionRegistry
::method rate
  expose functionRegistry
  use arg ratingId, request, plan, ratedAt
  if ratingId~string = "" | ratedAt~string = "" then return .AllJapanInsuranceResult~failure("RATING_IDENTITY_REQUIRED")
  if request == .nil then return .AllJapanInsuranceResult~failure("RATING_REQUEST_REQUIRED")
  r = request~validate
  if \r~ok then return r
  if plan == .nil then return .AllJapanInsuranceResult~failure("RATE_PLAN_REQUIRED")
  r = plan~validate
  if \r~ok then return r
  if functionRegistry~function(plan~functionRef)==.nil then return .AllJapanInsuranceResult~failure("RATING_FUNCTION_NOT_FOUND",plan~functionRef)
  if plan~productCode \= request~productCode | plan~jurisdiction \= request~jurisdiction | plan~currency \= request~currency | plan~coverageCode \= request~coverageCode then return .AllJapanInsuranceResult~failure("RATE_PLAN_REQUEST_MISMATCH")
  if plan~tieredRiskPrice~basisCode \= request~ratingBasisCode then return .AllJapanInsuranceResult~failure("RATING_BASIS_MISMATCH")
  if plan~underwritingPrice~enabled & plan~underwritingPrice~basisCode \= request~underwritingBasisCode then return .AllJapanInsuranceResult~failure("UNDERWRITING_BASIS_MISMATCH")
  if \plan~appliesAsOf(request~rateAsOf) then return .AllJapanInsuranceResult~failure("RATE_PLAN_NOT_EFFECTIVE")
  return functionRegistry~execute(ratingId,request,plan,ratedAt)

::class AllJapanInsuranceRatingCalculator public
::method factorAdjusted class
  use arg amount, factor
  return factor~apply(amount)
::method calculate class
  use arg ratingId, request, plan, ratedAt, functionRef, minimumBeforeProration
  costs=.array~new
  seq=0
  tier=plan~tieredRiskPrice

  seq+=1
  costs~append(.AllJapanInsuranceRatedCost~new(seq,.AllJapanInsuranceRatingBuild~COST_FIXED,"FIXED",1,tier~fixedMinor,1,tier~fixedMinor,"always",plan~planRef,request~currency))

  upToBasis=.AllJapanInsuranceRatingMath~min(request~ratingBasisUnits,tier~stepUnits)
  upToAmount=tier~upToStepRate~apply(upToBasis)
  seq+=1
  costs~append(.AllJapanInsuranceRatedCost~new(seq,.AllJapanInsuranceRatingBuild~COST_PROPORTIONATE_UP_TO_STEP,request~ratingBasisCode,upToBasis,tier~upToStepRate~numerator,tier~upToStepRate~denominator,upToAmount,"basis<=step slice",plan~planRef,request~currency))

  overBasis=.AllJapanInsuranceRatingMath~max(request~ratingBasisUnits-tier~stepUnits,0)
  overAmount=tier~overStepRate~apply(overBasis)
  seq+=1
  costs~append(.AllJapanInsuranceRatedCost~new(seq,.AllJapanInsuranceRatingBuild~COST_PROPORTIONATE_OVER_STEP,request~ratingBasisCode,overBasis,tier~overStepRate~numerator,tier~overStepRate~denominator,overAmount,"basis>step slice",plan~planRef,request~currency))

  proportionate=upToAmount+overAmount
  riskPremium=tier~fixedMinor+proportionate

  /* Deterministic factor chain in rate-plan order. */
  do table over plan~factorTables
    lookup=table~factorForRequest(request)
    if \lookup~ok then return lookup
    factor=lookup~value
    if table~targetMode=.AllJapanInsuranceRatingBuild~FACTOR_PROPORTIONATE then basis=proportionate
    else basis=riskPremium
    adjusted=factor~apply(basis)
    delta=adjusted-basis
    if table~targetMode=.AllJapanInsuranceRatingBuild~FACTOR_PROPORTIONATE then proportionate=adjusted
    riskPremium+=delta
    seq+=1
    costs~append(.AllJapanInsuranceRatedCost~new(seq,.AllJapanInsuranceRatingBuild~COST_RATE_FACTOR,table~evidenceBasisCode,basis,factor~numerator,factor~denominator,delta,"row=" || lookup~detail,table~tableRef,request~currency))
  end

  /* Schedule modifiers are underwriter-selected, bounded by the deployed
   * rule and always applied in request order to current risk premium. */
  do selection over request~selectedModifiers
    rule=plan~modifierRule(selection~code)
    if rule==.nil then return .AllJapanInsuranceResult~failure("MODIFIER_RULE_NOT_FOUND",selection~code)
    if \rule~permits(selection~factor) then return .AllJapanInsuranceResult~failure("MODIFIER_OUTSIDE_AUTHORITY",selection~code)
    unity=(selection~factor~numerator=selection~factor~denominator)
    if \unity & rule~requiresJustification then do
      if selection~justification="" | selection~authorizedBy="" then return .AllJapanInsuranceResult~failure("MODIFIER_EVIDENCE_REQUIRED",selection~code)
    end
    basis=riskPremium
    adjusted=selection~factor~apply(basis)
    delta=adjusted-basis
    riskPremium=adjusted
    seq+=1
    costs~append(.AllJapanInsuranceRatedCost~new(seq,.AllJapanInsuranceRatingBuild~COST_SCHEDULE_MODIFIER,selection~code,basis,selection~factor~numerator,selection~factor~denominator,delta,selection~justification,selection~authorizedBy,request~currency))
  end

  requiresUnderwriter=.false
  underwritingOverage=0
  uw=plan~underwritingPrice
  if uw~enabled then do
    if request~underwritingRiskUnits>uw~riskLimitUnits then do
      requiresUnderwriter=.true
      underwritingOverage=request~underwritingRiskUnits-uw~riskLimitUnits
      seq+=1
      costs~append(.AllJapanInsuranceRatedCost~new(seq,.AllJapanInsuranceRatingBuild~COST_UNDERWRITER_FEE,request~underwritingBasisCode,request~underwritingRiskUnits,uw~underwriterFeeMinor,1,uw~underwriterFeeMinor,"risk above underwriting limit",plan~planRef,request~currency))
      riskPremium+=uw~underwriterFeeMinor
      overageAmount=uw~overageRate~apply(underwritingOverage)
      seq+=1
      costs~append(.AllJapanInsuranceRatedCost~new(seq,.AllJapanInsuranceRatingBuild~COST_OVERAGE,request~underwritingBasisCode,underwritingOverage,uw~overageRate~numerator,uw~overageRate~denominator,overageAmount,"excess over underwriting limit",plan~planRef,request~currency))
      riskPremium+=overageAmount
    end
  end

  /* Two executable function identities intentionally differ here. This is
   * precisely why a policy/quote must retain functionRef, not just inputs. */
  if minimumBeforeProration then do
    if riskPremium<plan~minimumPremiumMinor then do
      delta=plan~minimumPremiumMinor-riskPremium
      seq+=1
      costs~append(.AllJapanInsuranceRatedCost~new(seq,.AllJapanInsuranceRatingBuild~COST_MINIMUM_PREMIUM,"RISK_PREMIUM",riskPremium,1,1,delta,"full-term minimum",plan~planRef,request~currency))
      riskPremium=plan~minimumPremiumMinor
    end
    fullTermRisk=riskPremium
    if \request~proration~isFullTerm then do
      prorated=self~proratedRisk(costs,request~proration,plan~prorationPolicy)
      delta=prorated-riskPremium
      seq+=1
      costs~append(.AllJapanInsuranceRatedCost~new(seq,.AllJapanInsuranceRatingBuild~COST_PRORATION,"RISK_PREMIUM",riskPremium,request~proration~numerator,request~proration~denominator,delta,request~proration~basisRef,plan~prorationPolicy~canonicalText,request~currency))
      riskPremium=prorated
    end
  end
  else do
    fullTermRisk=riskPremium
    if \request~proration~isFullTerm then do
      prorated=self~proratedRisk(costs,request~proration,plan~prorationPolicy)
      delta=prorated-riskPremium
      seq+=1
      costs~append(.AllJapanInsuranceRatedCost~new(seq,.AllJapanInsuranceRatingBuild~COST_PRORATION,"RISK_PREMIUM",riskPremium,request~proration~numerator,request~proration~denominator,delta,request~proration~basisRef,plan~prorationPolicy~canonicalText,request~currency))
      riskPremium=prorated
    end
    if riskPremium<plan~minimumPremiumMinor then do
      delta=plan~minimumPremiumMinor-riskPremium
      seq+=1
      costs~append(.AllJapanInsuranceRatedCost~new(seq,.AllJapanInsuranceRatingBuild~COST_MINIMUM_PREMIUM,"RISK_PREMIUM",riskPremium,1,1,delta,"transaction minimum",plan~planRef,request~currency))
      riskPremium=plan~minimumPremiumMinor
    end
  end

  sales=plan~salesCostRule~amount(riskPremium)
  if sales>0 then do
    seq+=1
    costs~append(.AllJapanInsuranceRatedCost~new(seq,.AllJapanInsuranceRatingBuild~COST_SALES,"RISK_PREMIUM",riskPremium,plan~salesCostRule~rate~numerator,plan~salesCostRule~rate~denominator,sales,plan~salesCostRule~mode,plan~planRef,request~currency))
  end
  preTax=riskPremium+sales

  taxTotal=0
  do tax over plan~taxRules
    select
      when tax~basisMode=.AllJapanInsuranceRatingBuild~TAX_PRE_TAX_PREMIUM then taxBasis=preTax
      when tax~basisMode=.AllJapanInsuranceRatingBuild~TAX_RISK_PREMIUM then taxBasis=riskPremium
      when tax~basisMode=.AllJapanInsuranceRatingBuild~TAX_SALES_COST then taxBasis=sales
      otherwise return .AllJapanInsuranceResult~failure("TAX_BASIS_INVALID",tax~basisMode)
    end
    taxAmount=tax~rate~apply(taxBasis)
    seq+=1
    costs~append(.AllJapanInsuranceRatedCost~new(seq,"TAX_" || tax~code,tax~basisMode,taxBasis,tax~rate~numerator,tax~rate~denominator,taxAmount,"tax",tax~code,request~currency))
    taxTotal+=taxAmount
  end

  total=preTax+taxTotal
  result=.AllJapanInsuranceRatingResult~new(ratingId,request~submissionId,request~productCode,request~currency,plan~planRef,functionRef,ratedAt,request~rateAsOf,costs,fullTermRisk,riskPremium,sales,preTax,taxTotal,total,requiresUnderwriter,underwritingOverage,request~proration,request~riskRef,request~coverageCode)
  if \result~balanced then return .AllJapanInsuranceResult~failure("RATING_COMPONENTS_UNBALANCED")
  return .AllJapanInsuranceResult~success(result)
::method proratedRisk class
  use arg costs,proration,prorationPolicy
  total=0
  do c over costs
    if prorationPolicy~isProratable(c~code) then total+=proration~applySigned(c~amountMinor)
    else total+=c~amountMinor
  end
  return total

::requires "AllJapanInsurance.cls"
