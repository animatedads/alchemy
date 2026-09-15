/* AllJapanInsuranceProductRating.cls - product/risk/coverage rating v0.7
 *
 * Builds policy -> risk object -> coverage rating over the deterministic
 * v0.4 rating kernel.  Product programs pin exact immutable coverage rate
 * plans and an executable composite-function identity.  The examples and
 * built-in schemas are structural; they are not production actuarial rates.
 */

::class AllJapanInsuranceProductRatingBuild public
::constant API_VERSION "all.japan.insurance.product.rating/0.7"
::constant FUNCTION_COMPOSITE "AJI.PRODUCT.RATING.COMPOSITE/1"
::constant RISK_PI "PROFESSIONAL_PRACTICE"
::constant RISK_HOME "PROPERTY"
::constant RISK_CAR "VEHICLE"
::constant COVERAGE_PI "PROFESSIONAL_INDEMNITY"
::constant COVERAGE_HOME_BUILDINGS "BUILDINGS"
::constant COVERAGE_HOME_CONTENTS "CONTENTS"
::constant COVERAGE_CAR "MOTOR"

::class AllJapanInsuranceCoverageSelection public
::attribute coverageCode get
::attribute selectedModifiers get
::attribute proration get
::method init
  expose coverageCode selectedModifiers proration
  use arg coverageCodeArg, selectedModifiersArg=.nil, prorationArg=.nil
  coverageCode=.AllJapanInsuranceCanonical~token(coverageCodeArg)
  if selectedModifiersArg==.nil then selectedModifiers=.array~new
  else selectedModifiers=selectedModifiersArg
  if prorationArg==.nil then proration=.AllJapanInsuranceProration~new
  else proration=prorationArg

::class AllJapanInsuranceRiskObject public
::attribute riskRef get
::attribute productCode get
::attribute riskType get
::attribute facts get
::attribute coverages get
::method init
  expose riskRef productCode riskType facts coverages
  use arg riskRefArg, productCodeArg, riskTypeArg, factsArg=.nil, coveragesArg=.nil
  riskRef=riskRefArg~string
  productCode=.AllJapanInsuranceCanonical~token(productCodeArg)
  riskType=.AllJapanInsuranceCanonical~token(riskTypeArg)
  facts=.table~new
  if factsArg\==.nil then do key over factsArg~allIndexes
    facts[.AllJapanInsuranceCanonical~token(key)]=factsArg[key]
  end
  if coveragesArg==.nil then coverages=.array~new
  else coverages=coveragesArg
::method fact
  expose facts
  use arg codeArg
  code=.AllJapanInsuranceCanonical~token(codeArg)
  if \facts~hasIndex(code) then return .nil
  return facts[code]
::method hasFact
  expose facts
  use arg codeArg
  return facts~hasIndex(.AllJapanInsuranceCanonical~token(codeArg))
::method canonicalFacts
  expose facts
  keys=.array~new
  do key over facts~allIndexes
    keys~append(key)
  end
  keys~sort
  out=""
  do key over keys
    out||="|" || key || "=" || facts[key]
  end
  return out

::class AllJapanInsuranceCoverageDefinition public
::attribute coverageCode get
::attribute ratingBasisFactCode get
::attribute underwritingBasisFactCode get
::attribute requiredFacts get
::method init
  expose coverageCode ratingBasisFactCode underwritingBasisFactCode requiredFacts
  use arg coverageCodeArg, ratingBasisFactCodeArg, underwritingBasisFactCodeArg, requiredFactsArg=.nil
  coverageCode=.AllJapanInsuranceCanonical~token(coverageCodeArg)
  ratingBasisFactCode=.AllJapanInsuranceCanonical~token(ratingBasisFactCodeArg)
  underwritingBasisFactCode=.AllJapanInsuranceCanonical~token(underwritingBasisFactCodeArg)
  if requiredFactsArg==.nil then requiredFacts=.array~new
  else requiredFacts=requiredFactsArg
::method validate
  expose coverageCode ratingBasisFactCode underwritingBasisFactCode requiredFacts
  if coverageCode="" | ratingBasisFactCode="" | underwritingBasisFactCode="" then return .AllJapanInsuranceResult~failure("COVERAGE_DEFINITION_IDENTITY_REQUIRED")
  seen=.set~new
  do fact over requiredFacts
    code=.AllJapanInsuranceCanonical~token(fact)
    if code="" then return .AllJapanInsuranceResult~failure("COVERAGE_REQUIRED_FACT_INVALID",coverageCode)
    if seen~hasIndex(code) then return .AllJapanInsuranceResult~failure("COVERAGE_REQUIRED_FACT_DUPLICATE",coverageCode || ":" || code)
    seen~put(code)
  end
  return .AllJapanInsuranceResult~success
::method validateRisk
  expose coverageCode ratingBasisFactCode underwritingBasisFactCode requiredFacts
  use arg risk
  do fact over requiredFacts
    code=.AllJapanInsuranceCanonical~token(fact)
    if \risk~hasFact(code) then return .AllJapanInsuranceResult~failure("PRODUCT_RISK_FACT_REQUIRED",risk~riskRef || ":" || code)
  end
  if \risk~hasFact(ratingBasisFactCode) then return .AllJapanInsuranceResult~failure("PRODUCT_RATING_BASIS_REQUIRED",risk~riskRef || ":" || ratingBasisFactCode)
  if \risk~hasFact(underwritingBasisFactCode) then return .AllJapanInsuranceResult~failure("PRODUCT_UNDERWRITING_BASIS_REQUIRED",risk~riskRef || ":" || underwritingBasisFactCode)
  if \.AllJapanInsuranceRatingMath~nonNegativeWhole(risk~fact(ratingBasisFactCode)) then return .AllJapanInsuranceResult~failure("PRODUCT_RATING_BASIS_INVALID",risk~riskRef || ":" || ratingBasisFactCode)
  if \.AllJapanInsuranceRatingMath~nonNegativeWhole(risk~fact(underwritingBasisFactCode)) then return .AllJapanInsuranceResult~failure("PRODUCT_UNDERWRITING_BASIS_INVALID",risk~riskRef || ":" || underwritingBasisFactCode)
  return .AllJapanInsuranceResult~success
::method canonicalText
  expose coverageCode ratingBasisFactCode underwritingBasisFactCode requiredFacts
  out="COVERAGE|" || coverageCode || "|RATING=" || ratingBasisFactCode || "|UW=" || underwritingBasisFactCode
  do fact over requiredFacts
    out||="|REQ=" || .AllJapanInsuranceCanonical~token(fact)
  end
  return out

::class AllJapanInsuranceProductDefinition public
::attribute definitionRef get
::attribute productCode get
::attribute riskType get
::attribute requiredFacts get
::method init
  expose definitionRef productCode riskType requiredFacts coverages duplicateCoverageCode
  use arg definitionRefArg, productCodeArg, riskTypeArg, requiredFactsArg=.nil, coverageDefinitionsArg=.nil
  definitionRef=definitionRefArg~string
  productCode=.AllJapanInsuranceCanonical~token(productCodeArg)
  riskType=.AllJapanInsuranceCanonical~token(riskTypeArg)
  if requiredFactsArg==.nil then requiredFacts=.array~new
  else requiredFacts=requiredFactsArg
  coverages=.table~new
  duplicateCoverageCode=""
  if coverageDefinitionsArg\==.nil then do coverage over coverageDefinitionsArg
    if coverage\==.nil then do
      if coverages~hasIndex(coverage~coverageCode) then duplicateCoverageCode=coverage~coverageCode
      else coverages[coverage~coverageCode]=coverage
    end
  end
::method validate
  expose definitionRef productCode riskType requiredFacts coverages duplicateCoverageCode
  if definitionRef="" | productCode="" | riskType="" then return .AllJapanInsuranceResult~failure("PRODUCT_DEFINITION_IDENTITY_REQUIRED")
  if duplicateCoverageCode\="" then return .AllJapanInsuranceResult~failure("PRODUCT_COVERAGE_DEFINITION_DUPLICATE",duplicateCoverageCode)
  if coverages~items=0 then return .AllJapanInsuranceResult~failure("PRODUCT_COVERAGE_DEFINITION_REQUIRED",definitionRef)
  seen=.set~new
  do fact over requiredFacts
    code=.AllJapanInsuranceCanonical~token(fact)
    if code="" then return .AllJapanInsuranceResult~failure("PRODUCT_REQUIRED_FACT_INVALID",definitionRef)
    if seen~hasIndex(code) then return .AllJapanInsuranceResult~failure("PRODUCT_REQUIRED_FACT_DUPLICATE",definitionRef || ":" || code)
    seen~put(code)
  end
  do code over coverages~allIndexes
    r=coverages[code]~validate
    if \r~ok then return r
  end
  return .AllJapanInsuranceResult~success
::method coverage
  expose coverages
  use arg coverageCodeArg
  return coverages[.AllJapanInsuranceCanonical~token(coverageCodeArg)]
::method coverageCodes
  expose coverages
  a=.array~new
  do code over coverages~allIndexes
    a~append(code)
  end
  a~sort
  return a
::method validateRisk
  expose productCode riskType requiredFacts coverages
  use arg risk
  if risk==.nil then return .AllJapanInsuranceResult~failure("PRODUCT_RISK_REQUIRED")
  if risk~riskRef="" then return .AllJapanInsuranceResult~failure("PRODUCT_RISK_REF_REQUIRED")
  if risk~productCode\=productCode | risk~riskType\=riskType then return .AllJapanInsuranceResult~failure("PRODUCT_RISK_TYPE_MISMATCH",risk~riskRef)
  do fact over requiredFacts
    code=.AllJapanInsuranceCanonical~token(fact)
    if \risk~hasFact(code) then return .AllJapanInsuranceResult~failure("PRODUCT_RISK_FACT_REQUIRED",risk~riskRef || ":" || code)
  end
  if risk~coverages~items=0 then return .AllJapanInsuranceResult~failure("PRODUCT_RISK_COVERAGE_REQUIRED",risk~riskRef)
  seen=.set~new
  do selection over risk~coverages
    if selection==.nil | selection~coverageCode="" then return .AllJapanInsuranceResult~failure("PRODUCT_COVERAGE_SELECTION_INVALID",risk~riskRef)
    if seen~hasIndex(selection~coverageCode) then return .AllJapanInsuranceResult~failure("PRODUCT_COVERAGE_DUPLICATE",risk~riskRef || ":" || selection~coverageCode)
    seen~put(selection~coverageCode)
    definition=coverages[selection~coverageCode]
    if definition==.nil then return .AllJapanInsuranceResult~failure("PRODUCT_COVERAGE_NOT_ALLOWED",risk~riskRef || ":" || selection~coverageCode)
    r=definition~validateRisk(risk)
    if \r~ok then return r
  end
  return .AllJapanInsuranceResult~success
::method canonicalText
  expose definitionRef productCode riskType requiredFacts coverages
  out="AJI-PRODUCT-DEFINITION/0.5" || '0a'x || "DEFINITION_REF=" || definitionRef || '0a'x || "PRODUCT=" || productCode || '0a'x || "RISK_TYPE=" || riskType || '0a'x
  do fact over requiredFacts
    out||="REQUIRED_FACT=" || .AllJapanInsuranceCanonical~token(fact) || '0a'x
  end
  codes=self~coverageCodes
  do code over codes
    out||=coverages[code]~canonicalText || '0a'x
  end
  return out
::method semanticIdentity
  return self~canonicalText

::class AllJapanInsuranceProductDefinitionRegistry public
::method init
  expose definitions
  definitions=.table~new
::method add
  expose definitions
  use arg definition
  if definition==.nil then return .AllJapanInsuranceResult~failure("PRODUCT_DEFINITION_REQUIRED")
  r=definition~validate
  if \r~ok then return r
  if definitions~hasIndex(definition~definitionRef) then return .AllJapanInsuranceResult~failure("PRODUCT_DEFINITION_DUPLICATE",definition~definitionRef)
  definitions[definition~definitionRef]=definition
  return .AllJapanInsuranceResult~success(definition)
::method definition
  expose definitions
  use arg definitionRef
  return definitions[definitionRef~string]
::method count
  expose definitions
  return definitions~items

::class AllJapanInsuranceProductRatingProgram public
::attribute programRef get
::attribute definitionRef get
::attribute productCode get
::attribute jurisdiction get
::attribute currency get
::attribute effectiveFrom get
::attribute effectiveTo get
::attribute functionRef get
::method init
  expose programRef definitionRef productCode jurisdiction currency effectiveFrom effectiveTo functionRef coveragePlanRefs
  use arg programRefArg, definitionRefArg, productCodeArg, jurisdictionArg, currencyArg, effectiveFromArg, effectiveToArg, coveragePlanRefsArg, functionRefArg="AJI.PRODUCT.RATING.COMPOSITE/1"
  programRef=programRefArg~string
  definitionRef=definitionRefArg~string
  productCode=.AllJapanInsuranceCanonical~token(productCodeArg)
  jurisdiction=.AllJapanInsuranceCanonical~token(jurisdictionArg)
  currency=.AllJapanInsuranceCanonical~token(currencyArg)
  effectiveFrom=effectiveFromArg~string
  effectiveTo=effectiveToArg~string
  functionRef=functionRefArg~string
  coveragePlanRefs=.table~new
  if coveragePlanRefsArg\==.nil then do code over coveragePlanRefsArg~allIndexes
    coveragePlanRefs[.AllJapanInsuranceCanonical~token(code)]=coveragePlanRefsArg[code]~string
  end
::method validate
  expose programRef definitionRef productCode jurisdiction currency effectiveFrom effectiveTo functionRef coveragePlanRefs
  if programRef="" | definitionRef="" | productCode="" | jurisdiction="" | currency="" | effectiveFrom="" | functionRef="" then return .AllJapanInsuranceResult~failure("PRODUCT_RATING_PROGRAM_IDENTITY_REQUIRED")
  if \.AllJapanInsuranceCurrency~supported(currency) then return .AllJapanInsuranceResult~failure("CURRENCY_UNSUPPORTED",currency)
  if effectiveTo\="" & effectiveTo<=effectiveFrom then return .AllJapanInsuranceResult~failure("PRODUCT_RATING_PROGRAM_PERIOD_INVALID")
  if coveragePlanRefs~items=0 then return .AllJapanInsuranceResult~failure("PRODUCT_RATING_PROGRAM_PLANS_REQUIRED",programRef)
  do code over coveragePlanRefs~allIndexes
    if code="" | coveragePlanRefs[code]="" then return .AllJapanInsuranceResult~failure("PRODUCT_RATING_PROGRAM_PLAN_INVALID",programRef)
  end
  return .AllJapanInsuranceResult~success
::method planRefFor
  expose coveragePlanRefs
  use arg coverageCodeArg
  return coveragePlanRefs[.AllJapanInsuranceCanonical~token(coverageCodeArg)]
::method coverageCodes
  expose coveragePlanRefs
  a=.array~new
  do code over coveragePlanRefs~allIndexes
    a~append(code)
  end
  a~sort
  return a
::method appliesAsOf
  expose effectiveFrom effectiveTo
  use arg asOfArg
  asOf=asOfArg~string
  if asOf<effectiveFrom then return .false
  if effectiveTo\="" & asOf>=effectiveTo then return .false
  return .true
::method canonicalText
  expose programRef definitionRef productCode jurisdiction currency effectiveFrom effectiveTo functionRef coveragePlanRefs
  out="AJI-PRODUCT-RATING-PROGRAM/0.5" || '0a'x || "PROGRAM_REF=" || programRef || '0a'x || "DEFINITION_REF=" || definitionRef || '0a'x || "PRODUCT=" || productCode || '0a'x || "JURISDICTION=" || jurisdiction || '0a'x || "CURRENCY=" || currency || '0a'x || "EFFECTIVE_FROM=" || effectiveFrom || '0a'x || "EFFECTIVE_TO=" || effectiveTo || '0a'x || "FUNCTION_REF=" || functionRef || '0a'x
  codes=.array~new
  do code over coveragePlanRefs~allIndexes
    codes~append(code)
  end
  codes~sort
  do code over codes
    out||="COVERAGE_PLAN=" || code || ":" || coveragePlanRefs[code] || '0a'x
  end
  return out
::method semanticIdentity
  return self~canonicalText

::class AllJapanInsuranceScopedRatedCost public
::attribute sequence get
::attribute code get
::attribute basisCode get
::attribute basisUnits get
::attribute rateNumerator get
::attribute rateDenominator get
::attribute amountMinor get
::attribute trigger get
::attribute ruleRef get
::attribute riskRef get
::attribute coverageCode get
::attribute subRatingId get
::attribute currency get
::method init
  expose sequence code basisCode basisUnits rateNumerator rateDenominator amountMinor trigger ruleRef riskRef coverageCode subRatingId currency
  use arg sequenceArg, cost, riskRefArg, coverageCodeArg, subRatingIdArg
  sequence=sequenceArg+0
  code=cost~code
  basisCode=cost~basisCode
  basisUnits=cost~basisUnits
  rateNumerator=cost~rateNumerator
  rateDenominator=cost~rateDenominator
  amountMinor=cost~amountMinor
  trigger=cost~trigger
  ruleRef=cost~ruleRef
  riskRef=riskRefArg~string
  coverageCode=.AllJapanInsuranceCanonical~token(coverageCodeArg)
  subRatingId=subRatingIdArg~string
  currency=cost~currency
::method canonicalText
  expose sequence code basisCode basisUnits rateNumerator rateDenominator amountMinor trigger ruleRef riskRef coverageCode subRatingId currency
  return sequence || "|" || riskRef || "|" || coverageCode || "|" || subRatingId || "|" || code || "|" || basisCode || "|" || basisUnits || "|" || rateNumerator || "/" || rateDenominator || "|" || amountMinor || "|" || currency || "|" || trigger || "|" || ruleRef

::class AllJapanInsuranceProductRatingResult public
::attribute ratingId get
::attribute submissionId get
::attribute productCode get
::attribute currency get
::attribute planRef get
::attribute ratingFunctionRef get
::attribute ratedAt get
::attribute rateAsOf get
::attribute costs get
::attribute subRatings get
::attribute totalPremiumMinor get
::attribute requiresUnderwriter get
::method init
  expose ratingId submissionId productCode currency planRef ratingFunctionRef ratedAt rateAsOf costs subRatings totalPremiumMinor requiresUnderwriter
  use arg ratingIdArg, submissionIdArg, productCodeArg, currencyArg, planRefArg, ratingFunctionRefArg, ratedAtArg, rateAsOfArg, costsArg, subRatingsArg, totalPremiumMinorArg, requiresUnderwriterArg
  ratingId=ratingIdArg~string
  submissionId=submissionIdArg~string
  productCode=.AllJapanInsuranceCanonical~token(productCodeArg)
  currency=.AllJapanInsuranceCanonical~token(currencyArg)
  planRef=planRefArg~string
  ratingFunctionRef=ratingFunctionRefArg~string
  ratedAt=ratedAtArg~string
  rateAsOf=rateAsOfArg~string
  costs=costsArg
  subRatings=subRatingsArg
  totalPremiumMinor=totalPremiumMinorArg+0
  requiresUnderwriter=requiresUnderwriterArg
::method balanced
  expose costs totalPremiumMinor
  total=0
  do cost over costs
    total+=cost~amountMinor
  end
  return total=totalPremiumMinor
::method scopeAmount
  expose costs
  use arg riskRefArg, coverageCodeArg
  riskRef=riskRefArg~string
  coverageCode=.AllJapanInsuranceCanonical~token(coverageCodeArg)
  total=0
  do cost over costs
    if cost~riskRef=riskRef & cost~coverageCode=coverageCode then total+=cost~amountMinor
  end
  return total
::method canonicalText
  expose ratingId submissionId productCode currency planRef ratingFunctionRef ratedAt rateAsOf costs totalPremiumMinor requiresUnderwriter
  out="AJI-PRODUCT-RATING/0.6" || '0a'x || "RATING_ID=" || ratingId || '0a'x || "SUBMISSION_ID=" || submissionId || '0a'x || "PRODUCT=" || productCode || '0a'x || "CURRENCY=" || currency || '0a'x || "PROGRAM_REF=" || planRef || '0a'x || "RATING_FUNCTION_REF=" || ratingFunctionRef || '0a'x || "RATE_AS_OF=" || rateAsOf || '0a'x || "RATED_AT=" || ratedAt || '0a'x || "REQUIRES_UNDERWRITER=" || requiresUnderwriter || '0a'x
  do cost over costs
    out||="COST=" || cost~canonicalText || '0a'x
  end
  out||="TOTAL_MINOR=" || totalPremiumMinor || '0a'x
  return out

::class AllJapanInsuranceProductRatingFunctionCompositeV1 public
::method functionRef
  return .AllJapanInsuranceProductRatingBuild~FUNCTION_COMPOSITE
::method execute
  use arg ratingId, submissionId, program, definition, risks, rateBook, ratedAt, rateAsOf
  if risks==.nil | risks~items=0 then return .AllJapanInsuranceResult~failure("PRODUCT_RISK_REQUIRED")
  costs=.array~new
  subRatings=.array~new
  seen=.set~new
  total=0
  anyUnderwriter=.false
  sequence=0
  engine=.AllJapanInsuranceRatingEngine~new(rateBook~functionRegistry)
  do risk over risks
    if risk==.nil then return .AllJapanInsuranceResult~failure("PRODUCT_RISK_REQUIRED")
    if seen~hasIndex(risk~riskRef) then return .AllJapanInsuranceResult~failure("PRODUCT_RISK_DUPLICATE",risk~riskRef)
    seen~put(risk~riskRef)
    r=definition~validateRisk(risk)
    if \r~ok then return r
    do selection over risk~coverages
      coverage=definition~coverage(selection~coverageCode)
      planRef=program~planRefFor(selection~coverageCode)
      if planRef==.nil | planRef="" then return .AllJapanInsuranceResult~failure("PRODUCT_COVERAGE_PLAN_NOT_FOUND",selection~coverageCode)
      plan=rateBook~plan(planRef)
      if plan==.nil then return .AllJapanInsuranceResult~failure("RATE_PLAN_NOT_FOUND",planRef)
      request=.AllJapanInsuranceRatingRequest~new(submissionId,program~productCode,program~jurisdiction,program~currency,rateAsOf,coverage~ratingBasisFactCode,risk~fact(coverage~ratingBasisFactCode),coverage~underwritingBasisFactCode,risk~fact(coverage~underwritingBasisFactCode),risk~facts,selection~selectedModifiers,selection~proration,risk~riskRef,selection~coverageCode)
      subId=ratingId || "/" || risk~riskRef || "/" || selection~coverageCode
      rr=engine~rate(subId,request,plan,ratedAt)
      if \rr~ok then return rr
      sub=rr~value
      subRatings~append(sub)
      total+=sub~totalPremiumMinor
      if sub~requiresUnderwriter then anyUnderwriter=.true
      do cost over sub~costs
        sequence+=1
        costs~append(.AllJapanInsuranceScopedRatedCost~new(sequence,cost,risk~riskRef,selection~coverageCode,subId))
      end
    end
  end
  result=.AllJapanInsuranceProductRatingResult~new(ratingId,submissionId,program~productCode,program~currency,program~programRef,program~functionRef,ratedAt,rateAsOf,costs,subRatings,total,anyUnderwriter)
  if \result~balanced then return .AllJapanInsuranceResult~failure("RATING_COMPONENTS_UNBALANCED")
  return .AllJapanInsuranceResult~success(result)

::class AllJapanInsuranceProductRatingFunctionRegistry public
::method init
  expose functions
  functions=.table~new
::method register
  expose functions
  use arg function
  if function==.nil then return .AllJapanInsuranceResult~failure("PRODUCT_RATING_FUNCTION_REQUIRED")
  ref=function~functionRef
  if ref="" then return .AllJapanInsuranceResult~failure("PRODUCT_RATING_FUNCTION_REF_REQUIRED")
  if functions~hasIndex(ref) then return .AllJapanInsuranceResult~failure("PRODUCT_RATING_FUNCTION_DUPLICATE",ref)
  functions[ref]=function
  return .AllJapanInsuranceResult~success(function)
::method function
  expose functions
  use arg ref
  return functions[ref~string]

::class AllJapanInsuranceProductRatingBook public
::method init
  expose definitionRegistry rateBook functionRegistry programs byRef
  use arg definitionRegistryArg, rateBookArg, functionRegistryArg=.nil
  definitionRegistry=definitionRegistryArg
  rateBook=rateBookArg
  if functionRegistryArg==.nil then do
    functionRegistry=.AllJapanInsuranceProductRatingFunctionRegistry~new
    ignored=functionRegistry~register(.AllJapanInsuranceProductRatingFunctionCompositeV1~new)
  end
  else functionRegistry=functionRegistryArg
  programs=.array~new
  byRef=.table~new
::method definitionRegistry
  expose definitionRegistry
  return definitionRegistry
::method rateBook
  expose rateBook
  return rateBook
::method functionRegistry
  expose functionRegistry
  return functionRegistry
::method addProgram
  expose definitionRegistry rateBook functionRegistry programs byRef
  use arg program
  if program==.nil then return .AllJapanInsuranceResult~failure("PRODUCT_RATING_PROGRAM_REQUIRED")
  r=program~validate
  if \r~ok then return r
  if byRef~hasIndex(program~programRef) then return .AllJapanInsuranceResult~failure("PRODUCT_RATING_PROGRAM_DUPLICATE",program~programRef)
  definition=definitionRegistry~definition(program~definitionRef)
  if definition==.nil then return .AllJapanInsuranceResult~failure("PRODUCT_DEFINITION_NOT_FOUND",program~definitionRef)
  if definition~productCode\=program~productCode then return .AllJapanInsuranceResult~failure("PRODUCT_RATING_DEFINITION_MISMATCH",program~programRef)
  if functionRegistry~function(program~functionRef)==.nil then return .AllJapanInsuranceResult~failure("PRODUCT_RATING_FUNCTION_NOT_FOUND",program~functionRef)
  programCodes=program~coverageCodes
  do code over programCodes
    if definition~coverage(code)==.nil then return .AllJapanInsuranceResult~failure("PRODUCT_COVERAGE_PLAN_UNKNOWN",code)
  end
  codes=definition~coverageCodes
  do code over codes
    planRef=program~planRefFor(code)
    if planRef==.nil | planRef="" then return .AllJapanInsuranceResult~failure("PRODUCT_COVERAGE_PLAN_NOT_FOUND",code)
    plan=rateBook~plan(planRef)
    if plan==.nil then return .AllJapanInsuranceResult~failure("RATE_PLAN_NOT_FOUND",planRef)
    if plan~productCode\=program~productCode | plan~jurisdiction\=program~jurisdiction | plan~currency\=program~currency | plan~coverageCode\=code then return .AllJapanInsuranceResult~failure("PRODUCT_COVERAGE_PLAN_MISMATCH",code || ":" || planRef)
    if plan~effectiveFrom>program~effectiveFrom then return .AllJapanInsuranceResult~failure("PRODUCT_COVERAGE_PLAN_PERIOD_MISMATCH",planRef)
    if program~effectiveTo="" then do
      if plan~effectiveTo\="" then return .AllJapanInsuranceResult~failure("PRODUCT_COVERAGE_PLAN_PERIOD_MISMATCH",planRef)
    end
    else if plan~effectiveTo\="" & plan~effectiveTo<program~effectiveTo then return .AllJapanInsuranceResult~failure("PRODUCT_COVERAGE_PLAN_PERIOD_MISMATCH",planRef)
  end
  programs~append(program)
  byRef[program~programRef]=program
  return .AllJapanInsuranceResult~success(program)
::method program
  expose byRef
  use arg programRef
  return byRef[programRef~string]
::method resolve
  expose programs
  use arg productCodeArg,jurisdictionArg,currencyArg,rateAsOfArg
  product=.AllJapanInsuranceCanonical~token(productCodeArg)
  jurisdiction=.AllJapanInsuranceCanonical~token(jurisdictionArg)
  currency=.AllJapanInsuranceCanonical~token(currencyArg)
  asOf=rateAsOfArg~string
  matches=.array~new
  do program over programs
    if program~productCode\=product | program~jurisdiction\=jurisdiction | program~currency\=currency then iterate
    if \program~appliesAsOf(asOf) then iterate
    matches~append(program)
  end
  if matches~items=0 then return .AllJapanInsuranceResult~failure("PRODUCT_RATING_PROGRAM_NOT_FOUND")
  if matches~items>1 then return .AllJapanInsuranceResult~failure("PRODUCT_RATING_PROGRAM_AMBIGUOUS")
  return .AllJapanInsuranceResult~success(matches[1])
::method rate
  expose definitionRegistry rateBook functionRegistry
  use arg ratingId,submissionId,productCode,jurisdiction,currency,rateAsOf,risks,ratedAt
  if ratingId~string="" | submissionId~string="" | ratedAt~string="" then return .AllJapanInsuranceResult~failure("PRODUCT_RATING_IDENTITY_REQUIRED")
  r=self~resolve(productCode,jurisdiction,currency,rateAsOf)
  if \r~ok then return r
  program=r~value
  definition=definitionRegistry~definition(program~definitionRef)
  function=functionRegistry~function(program~functionRef)
  if function==.nil then return .AllJapanInsuranceResult~failure("PRODUCT_RATING_FUNCTION_NOT_FOUND",program~functionRef)
  return function~execute(ratingId,submissionId,program,definition,risks,rateBook,ratedAt,rateAsOf)
::method ratePinnedProgram
  expose definitionRegistry rateBook functionRegistry byRef
  use arg ratingId,submissionId,programRef,rateAsOf,risks,ratedAt
  if ratingId~string="" | submissionId~string="" | programRef~string="" | ratedAt~string="" then return .AllJapanInsuranceResult~failure("PRODUCT_RATING_IDENTITY_REQUIRED")
  program=byRef[programRef~string]
  if program==.nil then return .AllJapanInsuranceResult~failure("PRODUCT_RATING_PROGRAM_NOT_FOUND",programRef)
  definition=definitionRegistry~definition(program~definitionRef)
  if definition==.nil then return .AllJapanInsuranceResult~failure("PRODUCT_DEFINITION_NOT_FOUND",program~definitionRef)
  function=functionRegistry~function(program~functionRef)
  if function==.nil then return .AllJapanInsuranceResult~failure("PRODUCT_RATING_FUNCTION_NOT_FOUND",program~functionRef)
  /* A mid-term transaction deliberately reuses the exact program pinned at
   * bind. rateAsOf is therefore normally the policy inception date, while
   * transaction proration is carried in each coverage selection. */
  return function~execute(ratingId,submissionId,program,definition,risks,rateBook,ratedAt,rateAsOf)
::method count
  expose programs
  return programs~items

/* Structural product schemas.  The fields are intentionally explicit and
 * versioned, while actual factors/rates live in separately approved plans. */
::class AllJapanInsuranceStandardProductDefinitions public
::method registry class
  registry=.AllJapanInsuranceProductDefinitionRegistry~new

  req=.array~of("PROFESSION_CLASS","ANNUAL_TURNOVER","TERRITORY","CLAIMS_BAND","INDEMNITY_LIMIT")
  cov=.array~new
  cov~append(.AllJapanInsuranceCoverageDefinition~new(.AllJapanInsuranceProductRatingBuild~COVERAGE_PI,"ANNUAL_TURNOVER","INDEMNITY_LIMIT",.array~of("INDEMNITY_LIMIT")))
  ignored=registry~add(.AllJapanInsuranceProductDefinition~new("AJI.PRODUCT.PI/0.5",.AllJapanInsuranceBuild~PRODUCT_PI,.AllJapanInsuranceProductRatingBuild~RISK_PI,req,cov))

  req=.array~of("CONSTRUCTION_CLASS","POSTCODE_ZONE","OCCUPANCY_CLASS","SECURITY_CLASS")
  cov=.array~new
  cov~append(.AllJapanInsuranceCoverageDefinition~new(.AllJapanInsuranceProductRatingBuild~COVERAGE_HOME_BUILDINGS,"REBUILD_VALUE","REBUILD_VALUE",.array~of("REBUILD_VALUE")))
  cov~append(.AllJapanInsuranceCoverageDefinition~new(.AllJapanInsuranceProductRatingBuild~COVERAGE_HOME_CONTENTS,"CONTENTS_VALUE","CONTENTS_VALUE",.array~of("CONTENTS_VALUE")))
  ignored=registry~add(.AllJapanInsuranceProductDefinition~new("AJI.PRODUCT.HOME/0.5",.AllJapanInsuranceBuild~PRODUCT_HOME,.AllJapanInsuranceProductRatingBuild~RISK_HOME,req,cov))

  req=.array~of("VEHICLE_GROUP","DRIVER_AGE","USAGE_CLASS","POSTCODE_ZONE","NCD_YEARS","CLAIMS_BAND","COVER_LEVEL","VEHICLE_VALUE")
  cov=.array~new
  cov~append(.AllJapanInsuranceCoverageDefinition~new(.AllJapanInsuranceProductRatingBuild~COVERAGE_CAR,"VEHICLE_VALUE","VEHICLE_VALUE",.array~of("VEHICLE_VALUE")))
  ignored=registry~add(.AllJapanInsuranceProductDefinition~new("AJI.PRODUCT.CAR/0.5",.AllJapanInsuranceBuild~PRODUCT_CAR,.AllJapanInsuranceProductRatingBuild~RISK_CAR,req,cov))
  return registry

::requires "AllJapanInsuranceRating.cls"
