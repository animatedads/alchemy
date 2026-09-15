/* Vector Meridian Markets Ltd accounting event/policy adapter v0.11.
 *
 * VMM operational objects remain authoritative for economic facts. Normal
 * operational integration emits AccountingEvent objects into Accounting Core
 * v0.7. Effective-dated VMM accounting policy proposes journals; Accounting
 * Core owns legal-entity isolation, replay, policy identity and posting mechanics.
 */

::options digits 50

::class VMMAccountingBuild public
::method version class; return "0.11"
::method protocol class; return "vmm.accounting/0.11"
::method eventApi class; return "accounting.event/0.1"
::method transactionApi class; return "accounting.transaction/0.1"
::method postingApi class; return "accounting.posting/0.2"
::method storeApi class; return "accounting.store/0.1"
::method scopeApi class; return "accounting.scope/0.1"
::method reportingApi class; return "accounting.reporting/0.1"
::method legalEntity class; return "VECTOR_MERIDIAN_MARKETS_LTD"
::method policyIdentityBase class; return "vmm-accounting-artifact/0.11"

::class VMMAccountingDimensions public
::constant BUSINESS_LINE "vmm.businessLine"
::constant ACCOUNTING_FUNCTION "vmm.accountingFunction"
::constant BUSINESS_INSTITUTIONAL_SYNTHETICS "INSTITUTIONAL_SYNTHETICS"
::constant BUSINESS_TREASURY_FUNDING "TREASURY_FUNDING"
::constant FUNCTION_PREMIUM "PREMIUM"
::constant FUNCTION_COLLATERAL_CUSTODY "COLLATERAL_CUSTODY"
::constant FUNCTION_XVA "XVA"
::constant FUNCTION_CLOSEOUT "CLOSEOUT"
::constant FUNCTION_FUNDING "FUNDING"

::class VMMAccountingPolicy public
::method policyVersion class; return "vmm.accounting.policy/0.11"
::method configureEngine class
  use strict arg engine,period
  if engine==.nil | \engine~isA(.AccountingEngine) then raise syntax 88.900 array("AccountingEngine required")
  if engine~legalEntityId<>.VMMAccountingBuild~legalEntity then raise syntax 88.900 array("VMM accounting engine legal entity mismatch",engine~legalEntityId)
  if period==.nil | \period~isA(.AccountingPeriod) then raise syntax 88.900 array("AccountingPeriod required")
  b=engine~book
  if b~chart~accountIds~items<>0 then raise syntax 88.900 array("VMM accounting chart must be empty before configuration")
  b~chart~add(.AccountingAccount~new("1000","Cash","ASSET"))
  b~chart~add(.AccountingAccount~new("1200","Synthetic premium receivable","ASSET"))
  b~chart~add(.AccountingAccount~new("1300","Trading and derivative assets","ASSET"))
  b~chart~add(.AccountingAccount~new("1400","Collateral posted","ASSET"))
  b~chart~add(.AccountingAccount~new("1500","Close-out receivable","ASSET"))
  b~chart~add(.AccountingAccount~new("2100","Arm's-length funding borrowings","LIABILITY"))
  b~chart~add(.AccountingAccount~new("2200","Accrued funding interest payable","LIABILITY"))
  b~chart~add(.AccountingAccount~new("2300","Derivative valuation adjustment reserve","LIABILITY"))
  b~chart~add(.AccountingAccount~new("2400","Close-out payable","LIABILITY"))
  b~chart~add(.AccountingAccount~new("4100","Synthetic premium revenue","REVENUE"))
  b~chart~add(.AccountingAccount~new("4200","Trading revenue","REVENUE"))
  b~chart~add(.AccountingAccount~new("4300","Synthetic close-out gain / recovery","REVENUE"))
  b~chart~add(.AccountingAccount~new("6100","Funding expense","EXPENSE"))
  b~chart~add(.AccountingAccount~new("6200","Execution expense","EXPENSE"))
  b~chart~add(.AccountingAccount~new("6300","XVA expense","EXPENSE"))
  b~chart~add(.AccountingAccount~new("6400","Synthetic close-out loss","EXPENSE"))
  b~chart~seal
  b~addPeriod(period)

  self~registerPolicies(engine)
  return engine

::method registerPolicies class
  use strict arg engine
  if engine==.nil | \engine~isA(.AccountingEngine) then raise syntax 88.900 array("AccountingEngine required")
  if engine~legalEntityId<>.VMMAccountingBuild~legalEntity then raise syntax 88.900 array("VMM accounting engine legal entity mismatch",engine~legalEntityId)
  entity=.VMMAccountingBuild~legalEntity
  from="2026-01-01"
  base=.VMMAccountingBuild~policyIdentityBase
  engine~registerPolicy(.VMMPremiumAccrualAccountingPolicy~new("vmm.accounting.synthetic.premium-accrual/0.11",base||":premium-accrual",entity,"VMM_SYNTHETIC_PREMIUM_ACCRUAL",from))
  engine~registerPolicy(.VMMPremiumSettlementAccountingPolicy~new("vmm.accounting.synthetic.premium-settlement/0.11",base||":premium-settlement",entity,"VMM_SYNTHETIC_PREMIUM_SETTLEMENT",from))
  engine~registerPolicy(.VMMVariationMarginAccountingPolicy~new("vmm.accounting.synthetic.variation-margin/0.11",base||":variation-margin",entity,"VMM_SYNTHETIC_VARIATION_MARGIN_POSTED",from))
  engine~registerPolicy(.VMMInitialMarginAccountingPolicy~new("vmm.accounting.synthetic.initial-margin/0.11",base||":initial-margin",entity,"VMM_SYNTHETIC_INITIAL_MARGIN_POSTED",from))
  engine~registerPolicy(.VMMFundingDrawAccountingPolicy~new("vmm.accounting.funding-draw/0.11",base||":funding-draw",entity,"VMM_FUNDING_DRAW",from))
  engine~registerPolicy(.VMMFundingAccrualAccountingPolicy~new("vmm.accounting.funding-accrual/0.11",base||":funding-accrual",entity,"VMM_FUNDING_INTEREST_ACCRUAL",from))
  engine~registerPolicy(.VMMFundingRepaymentAccountingPolicy~new("vmm.accounting.funding-repayment/0.11",base||":funding-repayment",entity,"VMM_FUNDING_REPAYMENT",from))
  engine~registerPolicy(.VMMXVAAccountingPolicy~new("vmm.accounting.synthetic.xva/0.11",base||":xva",entity,"VMM_SYNTHETIC_XVA_RECORDED",from))
  engine~registerPolicy(.VMMCloseoutDeterminationAccountingPolicy~new("vmm.accounting.synthetic.closeout-determined/0.11",base||":closeout-determined",entity,"VMM_SYNTHETIC_CLOSEOUT_DETERMINED",from))
  engine~registerPolicy(.VMMCloseoutSettlementAccountingPolicy~new("vmm.accounting.synthetic.closeout-settled/0.11",base||":closeout-settled",entity,"VMM_SYNTHETIC_CLOSEOUT_SETTLED",from))
  engine~registerPolicy(.VMMCloseoutFinalizationAccountingPolicy~new("vmm.accounting.synthetic.closeout-finalized/0.11",base||":closeout-finalized",entity,"VMM_SYNTHETIC_CLOSEOUT_FINALIZED",from))
  engine~registerPolicy(.VMMCloseoutFinalSettlementAccountingPolicy~new("vmm.accounting.synthetic.closeout-final-settled/0.11",base||":closeout-final-settled",entity,"VMM_SYNTHETIC_CLOSEOUT_FINAL_SETTLED",from))
  engine~registerPolicy(.VMMNettingSetSettlementAccountingPolicy~new("vmm.accounting.synthetic.master-netting-settled/0.11",base||":master-netting-settled",entity,"VMM_SYNTHETIC_MASTER_NETTING_SETTLED",from))
  engine~registerPolicy(.VMMInitialMarginReturnAccountingPolicy~new("vmm.accounting.synthetic.initial-margin-returned/0.11",base||":initial-margin-returned",entity,"VMM_SYNTHETIC_INITIAL_MARGIN_RETURN_SETTLED",from))
  return engine

::class VMMAccountingEventPolicy subclass AccountingPolicy
::method init
  use arg refArg,identityArg,entityArg,typeArg,fromArg,toArg=""
  self~init:super(refArg,identityArg,entityArg,typeArg,fromArg,toArg)
::method amount
  use strict arg event,key
  return .AccountingUtil~requireWholeNonNegative(event~value(key),key)
::method currency
  use strict arg event
  return .AccountingUtil~requireText(event~value("currency"),"currency")~upper
::method dims
  use strict arg event
  d=event~value("dimensions",.directory~new)
  if \d~isA(.Directory) then raise syntax 88.900 array("VMM accounting dimensions must be Directory")
  return d
::method requireTextValue
  use strict arg event,key
  return .AccountingUtil~requireText(event~value(key),key)
::method signedFromDirection
  use strict arg direction,amount
  if direction="VMM_RECEIVABLE" then return amount
  if direction="VMM_PAYABLE" then return 0-amount
  if direction="FLAT" then do
    if amount<>0 then raise syntax 88.900 array("FLAT direction requires zero amount",amount)
    return 0
  end
  raise syntax 88.900 array("invalid VMM accounting direction",direction)
::method variationCollateralCarryingMinor
  use strict arg book,contractId,currency
  numeric digits 50
  total=0
  do e over book~entriesByEventType("VMM_SYNTHETIC_VARIATION_MARGIN_POSTED")
    if e~correlationRef<>contractId then iterate
    do line over e~lines
      if line~accountId<>"1400" | line~currency<>currency then iterate
      dims=line~dimensions
      if dims~hasIndex("contractId") & dims["contractId"]=contractId then total=total+line~debitMinor-line~creditMinor
    end
  end
  return total

::class VMMPremiumAccrualAccountingPolicy subclass VMMAccountingEventPolicy
::method propose
  use strict arg event,book
  numeric digits 50
  current=self~amount(event,"cumulativeAccruedMinor")
  premiumPeriodId=self~requireTextValue(event,"premiumPeriodId")
  prior=0
  do e over book~entriesByEventType(event~eventType)
    if e~correlationRef<>event~correlationRef then iterate
    m=e~metadata
    if \m~hasIndex("vmm.premiumPeriodId") | m["vmm.premiumPeriodId"]<>premiumPeriodId then iterate
    if m~hasIndex("vmm.cumulativeAccruedMinor") then do
      candidate=.AccountingUtil~requireWholeNonNegative(m["vmm.cumulativeAccruedMinor"],"vmm.cumulativeAccruedMinor")
      if candidate>prior then prior=candidate
    end
  end
  if current<prior then return .AccountingPolicyDecision~reject("PREMIUM_ACCRUAL_BACKWARDS",current||" < "||prior)
  delta=current-prior
  if delta=0 then return .AccountingPolicyDecision~reject("ZERO_DELTA","No incremental premium accrual to post")
  md=.directory~new; md["vmm.premiumPeriodId"]=premiumPeriodId; md["vmm.cumulativeAccruedMinor"]=current; md["vmm.incrementalAccruedMinor"]=delta
  d=self~newDraft(event,book,event~eventDate,"Synthetic premium accrual",.nil,md)
  dims=self~dims(event); c=self~currency(event)
  d~addLine(.AccountingJournalLine~new("1200",c,delta,0,"Premium receivable",dims))
  d~addLine(.AccountingJournalLine~new("4100",c,0,delta,"Synthetic premium revenue",dims))
  return .AccountingPolicyDecision~accept(d,"Cumulative operational accrual mapped to incremental accounting recognition")

::class VMMPremiumSettlementAccountingPolicy subclass VMMAccountingEventPolicy
::method propose
  use strict arg event,book
  n=self~amount(event,"amountMinor"); if n=0 then return .AccountingPolicyDecision~reject("ZERO_AMOUNT","No premium cash to settle")
  d=self~newDraft(event,book,event~eventDate,"Synthetic premium settlement")
  dims=self~dims(event); c=self~currency(event)
  d~addLine(.AccountingJournalLine~new("1000",c,n,0,"Premium cash received",dims))
  d~addLine(.AccountingJournalLine~new("1200",c,0,n,"Settle premium receivable",dims))
  return .AccountingPolicyDecision~accept(d)

::class VMMVariationMarginAccountingPolicy subclass VMMAccountingEventPolicy
::method propose
  use strict arg event,book
  n=self~amount(event,"amountMinor"); if n=0 then return .AccountingPolicyDecision~reject("ZERO_AMOUNT","No variation margin to post")
  d=self~newDraft(event,book,event~eventDate,"Variation margin posted")
  dims=self~dims(event); c=self~currency(event)
  d~addLine(.AccountingJournalLine~new("1400",c,n,0,"Collateral posted",dims))
  d~addLine(.AccountingJournalLine~new("1000",c,0,n,"Cash collateral delivered",dims))
  return .AccountingPolicyDecision~accept(d)

::class VMMInitialMarginAccountingPolicy subclass VMMAccountingEventPolicy
::method propose
  use strict arg event,book
  gross=self~amount(event,"grossAmountMinor"); recognized=self~amount(event,"recognizedRiskValueMinor")
  if gross=0 then return .AccountingPolicyDecision~reject("ZERO_AMOUNT","No initial margin to reclassify")
  if recognized>gross then return .AccountingPolicyDecision~reject("INITIAL_MARGIN_RISK_VALUE_INVALID",recognized||" > "||gross)
  d=self~newDraft(event,book,event~eventDate,"Initial margin asset reclassification")
  dims=self~dims(event); c=self~currency(event)
  d~addLine(.AccountingJournalLine~new("1400",c,gross,0,"Initial margin collateral posted at gross carrying value",dims))
  d~addLine(.AccountingJournalLine~new("1300",c,0,gross,"Trading asset delivered into collateral control",dims))
  return .AccountingPolicyDecision~accept(d)

::class VMMFundingDrawAccountingPolicy subclass VMMAccountingEventPolicy
::method propose
  use strict arg event,book
  n=self~amount(event,"amountMinor"); if n=0 then return .AccountingPolicyDecision~reject("ZERO_AMOUNT","No funding draw to post")
  d=self~newDraft(event,book,event~eventDate,"Arm's-length funding draw")
  dims=self~dims(event); c=self~currency(event)
  d~addLine(.AccountingJournalLine~new("1000",c,n,0,"Funding cash received",dims))
  d~addLine(.AccountingJournalLine~new("2100",c,0,n,"Arm's-length borrowing",dims))
  return .AccountingPolicyDecision~accept(d)

::class VMMFundingAccrualAccountingPolicy subclass VMMAccountingEventPolicy
::method propose
  use strict arg event,book
  n=self~amount(event,"amountMinor"); if n=0 then return .AccountingPolicyDecision~reject("ZERO_AMOUNT","No funding interest to post")
  d=self~newDraft(event,book,event~eventDate,"Funding interest accrual")
  dims=self~dims(event); c=self~currency(event)
  d~addLine(.AccountingJournalLine~new("6100",c,n,0,"Funding expense",dims))
  d~addLine(.AccountingJournalLine~new("2200",c,0,n,"Accrued funding interest payable",dims))
  return .AccountingPolicyDecision~accept(d)

::class VMMFundingRepaymentAccountingPolicy subclass VMMAccountingEventPolicy
::method propose
  use strict arg event,book
  n=self~amount(event,"amountMinor"); if n=0 then return .AccountingPolicyDecision~reject("ZERO_AMOUNT","No funding repayment to post")
  d=self~newDraft(event,book,event~eventDate,"Funding principal repayment")
  dims=self~dims(event); c=self~currency(event)
  d~addLine(.AccountingJournalLine~new("2100",c,n,0,"Reduce arm's-length borrowing",dims))
  d~addLine(.AccountingJournalLine~new("1000",c,0,n,"Funding principal cash paid",dims))
  return .AccountingPolicyDecision~accept(d)

::class VMMXVAAccountingPolicy subclass VMMAccountingEventPolicy
::method propose
  use strict arg event,book
  n=self~amount(event,"amountMinor"); if n=0 then return .AccountingPolicyDecision~reject("ZERO_AMOUNT","No XVA adjustment to post")
  d=self~newDraft(event,book,event~eventDate,"CVA/FVA valuation adjustment")
  dims=self~dims(event); c=self~currency(event)
  d~addLine(.AccountingJournalLine~new("6300",c,n,0,"XVA expense",dims))
  d~addLine(.AccountingJournalLine~new("2300",c,0,n,"Derivative valuation adjustment reserve",dims))
  return .AccountingPolicyDecision~accept(d)

::class VMMCloseoutDeterminationAccountingPolicy subclass VMMAccountingEventPolicy
::method propose
  use strict arg event,book
  numeric digits 50
  c=self~currency(event); dims=self~dims(event)
  gross=self~amount(event,"grossAmountMinor"); collateral=self~amount(event,"cashCollateralMinor"); net=self~amount(event,"netAmountMinor")
  grossDir=self~requireTextValue(event,"grossDirection"); netDir=self~requireTextValue(event,"netDirection")
  signedGross=self~signedFromDirection(grossDir,gross); signedNet=self~signedFromDirection(netDir,net)
  if signedNet<>signedGross+collateral then return .AccountingPolicyDecision~reject("CLOSEOUT_NETTING_MISMATCH",signedNet||" != "||(signedGross+collateral))
  if gross=0 & collateral=0 & net=0 then return .AccountingPolicyDecision~reject("ZERO_AMOUNT","Zero close-out has no journal consequence")
  contractId=self~requireTextValue(event,"contractId")
  carrying=self~variationCollateralCarryingMinor(book,contractId,c)
  if collateral>carrying then return .AccountingPolicyDecision~reject("COLLATERAL_ACCOUNTING_EVIDENCE_MISSING",collateral||" > "||carrying)
  d=self~newDraft(event,book,event~eventDate,"Synthetic early-termination close-out determination")
  if grossDir="VMM_RECEIVABLE" & gross>0 then d~addLine(.AccountingJournalLine~new("4300",c,0,gross,"Contractual close-out gain/recovery",dims))
  if grossDir="VMM_PAYABLE" & gross>0 then d~addLine(.AccountingJournalLine~new("6400",c,gross,0,"Contractual close-out loss",dims))
  if collateral>0 then d~addLine(.AccountingJournalLine~new("1400",c,0,collateral,"Cash variation margin applied/returned through close-out netting",dims))
  if netDir="VMM_RECEIVABLE" & net>0 then d~addLine(.AccountingJournalLine~new("1500",c,net,0,"Net close-out receivable",dims))
  if netDir="VMM_PAYABLE" & net>0 then d~addLine(.AccountingJournalLine~new("2400",c,0,net,"Net close-out payable",dims))
  return .AccountingPolicyDecision~accept(d,"Legal close-out and cash variation-margin netting recognized; segregated IM remains outside automatic netting")

::class VMMCloseoutSettlementAccountingPolicy subclass VMMAccountingEventPolicy
::method propose
  use strict arg event,book
  n=self~amount(event,"amountMinor"); direction=self~requireTextValue(event,"direction")
  if direction="FLAT" then do
    if n<>0 then return .AccountingPolicyDecision~reject("CLOSEOUT_SETTLEMENT_DIRECTION_INVALID","FLAT with non-zero amount")
    return .AccountingPolicyDecision~reject("ZERO_AMOUNT","No cash close-out settlement to post")
  end
  if n=0 then return .AccountingPolicyDecision~reject("ZERO_AMOUNT","No cash close-out settlement to post")
  d=self~newDraft(event,book,event~eventDate,"Synthetic close-out cash settlement")
  dims=self~dims(event); c=self~currency(event)
  if direction="VMM_RECEIVABLE" then do
    d~addLine(.AccountingJournalLine~new("1000",c,n,0,"Close-out cash received",dims))
    d~addLine(.AccountingJournalLine~new("1500",c,0,n,"Settle close-out receivable",dims))
  end
  else if direction="VMM_PAYABLE" then do
    d~addLine(.AccountingJournalLine~new("2400",c,n,0,"Settle close-out payable",dims))
    d~addLine(.AccountingJournalLine~new("1000",c,0,n,"Close-out cash paid",dims))
  end
  else return .AccountingPolicyDecision~reject("CLOSEOUT_SETTLEMENT_DIRECTION_INVALID",direction)
  return .AccountingPolicyDecision~accept(d)

::class VMMCloseoutFinalizationAccountingPolicy subclass VMMAccountingEventPolicy
::method propose
  use strict arg event,book
  numeric digits 50
  c=self~currency(event); dims=self~dims(event)
  gross=self~amount(event,"grossAmountMinor"); collateral=self~amount(event,"cashCollateralMinor"); net=self~amount(event,"netAmountMinor")
  grossDir=self~requireTextValue(event,"grossDirection"); netDir=self~requireTextValue(event,"netDirection")
  signedGross=self~signedFromDirection(grossDir,gross); signedNet=self~signedFromDirection(netDir,net)
  if signedNet<>signedGross+collateral then return .AccountingPolicyDecision~reject("CLOSEOUT_NETTING_MISMATCH",signedNet||" != "||(signedGross+collateral))
  if gross=0 & collateral=0 & net=0 then return .AccountingPolicyDecision~reject("ZERO_AMOUNT","Zero final close-out has no journal consequence")
  contractId=self~requireTextValue(event,"contractId")
  carrying=self~variationCollateralCarryingMinor(book,contractId,c)
  if collateral>carrying then return .AccountingPolicyDecision~reject("COLLATERAL_ACCOUNTING_EVIDENCE_MISSING",collateral||" > "||carrying)
  d=self~newDraft(event,book,event~eventDate,"Finalized synthetic close-out after dispute window/resolution")
  if grossDir="VMM_RECEIVABLE" & gross>0 then d~addLine(.AccountingJournalLine~new("4300",c,0,gross,"Final contractual close-out gain/recovery",dims))
  if grossDir="VMM_PAYABLE" & gross>0 then d~addLine(.AccountingJournalLine~new("6400",c,gross,0,"Final contractual close-out loss",dims))
  if collateral>0 then d~addLine(.AccountingJournalLine~new("1400",c,0,collateral,"Cash variation margin applied through finalized close-out",dims))
  if netDir="VMM_RECEIVABLE" & net>0 then d~addLine(.AccountingJournalLine~new("1500",c,net,0,"Final close-out receivable",dims))
  if netDir="VMM_PAYABLE" & net>0 then d~addLine(.AccountingJournalLine~new("2400",c,0,net,"Final close-out payable",dims))
  return .AccountingPolicyDecision~accept(d,"v0.9 finalization is accounting recognition point; original disputed determination remains evidence only")

::class VMMCloseoutFinalSettlementAccountingPolicy subclass VMMAccountingEventPolicy
::method propose
  use strict arg event,book
  n=self~amount(event,"amountMinor"); direction=self~requireTextValue(event,"direction")
  if direction="FLAT" then do
    if n<>0 then return .AccountingPolicyDecision~reject("CLOSEOUT_SETTLEMENT_DIRECTION_INVALID","FLAT with non-zero amount")
    return .AccountingPolicyDecision~reject("ZERO_AMOUNT","No cash close-out settlement to post")
  end
  if n=0 then return .AccountingPolicyDecision~reject("ZERO_AMOUNT","No cash close-out settlement to post")
  d=self~newDraft(event,book,event~eventDate,"Finalized synthetic close-out cash settlement")
  dims=self~dims(event); c=self~currency(event)
  if direction="VMM_RECEIVABLE" then do
    d~addLine(.AccountingJournalLine~new("1000",c,n,0,"Final close-out cash received",dims))
    d~addLine(.AccountingJournalLine~new("1500",c,0,n,"Settle finalized close-out receivable",dims))
  end
  else if direction="VMM_PAYABLE" then do
    d~addLine(.AccountingJournalLine~new("2400",c,n,0,"Settle finalized close-out payable",dims))
    d~addLine(.AccountingJournalLine~new("1000",c,0,n,"Final close-out cash paid",dims))
  end
  else return .AccountingPolicyDecision~reject("CLOSEOUT_SETTLEMENT_DIRECTION_INVALID",direction)
  return .AccountingPolicyDecision~accept(d)

::class VMMNettingSetSettlementAccountingPolicy subclass VMMAccountingEventPolicy
::method propose
  use strict arg event,book
  numeric digits 50
  receivable=self~amount(event,"totalReceivableMinor"); payable=self~amount(event,"totalPayableMinor"); cash=self~amount(event,"cashAmountMinor")
  direction=self~requireTextValue(event,"direction")
  if direction="VMM_RECEIVABLE" then do
    if receivable-payable<>cash | receivable<=payable then return .AccountingPolicyDecision~reject("NETTING_SET_ARITHMETIC_INVALID")
  end
  else if direction="VMM_PAYABLE" then do
    if payable-receivable<>cash | payable<=receivable then return .AccountingPolicyDecision~reject("NETTING_SET_ARITHMETIC_INVALID")
  end
  else if direction="FLAT" then do
    if receivable<>payable | cash<>0 then return .AccountingPolicyDecision~reject("NETTING_SET_ARITHMETIC_INVALID")
  end
  else return .AccountingPolicyDecision~reject("NETTING_SET_DIRECTION_INVALID",direction)
  if receivable=0 & payable=0 then return .AccountingPolicyDecision~reject("ZERO_AMOUNT","No netting-set balances to settle")
  d=self~newDraft(event,book,event~eventDate,"Master-agreement close-out netting settlement")
  dims=self~dims(event); c=self~currency(event)
  if payable>0 then d~addLine(.AccountingJournalLine~new("2400",c,payable,0,"Clear close-out payables within legal netting set",dims))
  if direction="VMM_RECEIVABLE" & cash>0 then d~addLine(.AccountingJournalLine~new("1000",c,cash,0,"Net close-out cash received",dims))
  if receivable>0 then d~addLine(.AccountingJournalLine~new("1500",c,0,receivable,"Clear close-out receivables within legal netting set",dims))
  if direction="VMM_PAYABLE" & cash>0 then d~addLine(.AccountingJournalLine~new("1000",c,0,cash,"Net close-out cash paid",dims))
  return .AccountingPolicyDecision~accept(d,"Legal opinion/election evidence controls netting; accounting does not invent set-off")

::class VMMInitialMarginReturnAccountingPolicy subclass VMMAccountingEventPolicy
::method propose
  use strict arg event,book
  gross=self~amount(event,"grossAmountMinor")
  if gross=0 then return .AccountingPolicyDecision~reject("ZERO_AMOUNT","No returned initial-margin carrying value")
  d=self~newDraft(event,book,event~eventDate,"Segregated initial margin returned from custody")
  dims=self~dims(event); c=self~currency(event)
  d~addLine(.AccountingJournalLine~new("1300",c,gross,0,"Trading asset returned from collateral custody",dims))
  d~addLine(.AccountingJournalLine~new("1400",c,0,gross,"Release segregated initial-margin collateral carrying value",dims))
  return .AccountingPolicyDecision~accept(d,"Gross carrying value returns; risk haircut is not an accounting write-down")

::class VMMAccountingService public
::method init
  expose vmm engine
  use strict arg vmm,engine
  if vmm==.nil | \vmm~isA(.VectorMeridianMarkets) then raise syntax 88.900 array("VMM accounting service requires VectorMeridianMarkets")
  if engine==.nil | \engine~isA(.AccountingEngine) then raise syntax 88.900 array("VMM accounting service requires AccountingEngine")
  if vmm~legalEntity<>.VMMAccountingBuild~legalEntity | engine~legalEntityId<>.VMMAccountingBuild~legalEntity then raise syntax 88.900 array("VMM accounting legal entity boundary violation")
::method engine; expose engine; return engine
::method book; expose engine; return engine~book
::method vmm; expose vmm; return vmm

::method postPremiumAccrual
  expose engine
  use strict arg accrual,postingDate,periodId
  if \accrual~isA(.VMMSyntheticPremiumAccrual) then raise syntax 88.900 array("VMMSyntheticPremiumAccrual required")
  self~requirePeriod(postingDate,periodId)
  payload=.directory~new; payload["currency"]=accrual~currency; payload["cumulativeAccruedMinor"]=self~minor(accrual~cumulativeAccruedAmount); payload["premiumPeriodId"]=accrual~periodId; payload["dimensions"]=self~syntheticDims(accrual~contractId,"PREMIUM_ACCRUAL")
  evidence=.array~of(accrual~evidenceRef,accrual~authorityRef)
  event=.AccountingEvent~new("VMM:PREMIUM:ACCRUAL:"||accrual~accrualId,.VMMAccountingBuild~legalEntity,"VMM_SYNTHETIC_PREMIUM_ACCRUAL",postingDate,accrual~contractId,"",accrual~authorityRef,payload,evidence,self~eventMeta(periodId))
  return engine~transact(event)

::method postPremiumSettlement
  expose engine
  use strict arg settlement,postingDate,periodId
  if \settlement~isA(.VMMSyntheticPremiumSettlement) then raise syntax 88.900 array("VMMSyntheticPremiumSettlement required")
  if settlement~payeeEntity<>.VMMAccountingBuild~legalEntity then raise syntax 88.900 array("VMM accounting cannot record premium paid to another entity")
  self~requirePeriod(postingDate,periodId)
  dims=self~syntheticDims(settlement~contractId,"PREMIUM_SETTLEMENT"); dims["counterpartyEntity"]=settlement~payerEntity; dims["premiumPeriodId"]=settlement~periodId
  payload=.directory~new; payload["currency"]=settlement~currency; payload["amountMinor"]=self~minor(settlement~amount); payload["dimensions"]=dims
  evidence=.array~of(settlement~paymentEvidenceRef,settlement~authorityRef)
  event=.AccountingEvent~new("VMM:PREMIUM:SETTLEMENT:"||settlement~settlementId,.VMMAccountingBuild~legalEntity,"VMM_SYNTHETIC_PREMIUM_SETTLEMENT",postingDate,settlement~contractId,settlement~payerEntity,settlement~authorityRef,payload,evidence,self~eventMeta(periodId))
  return engine~transact(event)

::method postVariationMarginTransfer
  expose engine
  use strict arg transfer,postingDate,periodId
  if \transfer~isA(.VMMSyntheticCollateralTransfer) then raise syntax 88.900 array("VMMSyntheticCollateralTransfer required")
  if transfer~direction<>"VMM_TO_COUNTERPARTY" then raise syntax 88.900 array("unsupported VMM variation-margin direction")
  self~requirePeriod(postingDate,periodId)
  dims=self~syntheticDims(transfer~contractId,"VARIATION_MARGIN"); dims["custodianRef"]=transfer~custodianRef; dims["controlEvidenceRef"]=transfer~controlEvidenceRef
  payload=.directory~new; payload["currency"]=transfer~currency; payload["amountMinor"]=self~minor(transfer~amount); payload["dimensions"]=dims
  evidence=.array~of(transfer~controlEvidenceRef,transfer~authorityRef)
  event=.AccountingEvent~new("VMM:VM:"||transfer~transferId,.VMMAccountingBuild~legalEntity,"VMM_SYNTHETIC_VARIATION_MARGIN_POSTED",postingDate,transfer~contractId,"",transfer~authorityRef,payload,evidence,self~eventMeta(periodId))
  return engine~transact(event)

::method postInitialMarginTransfer
  expose engine
  use strict arg transfer,postingDate,periodId
  if \transfer~isA(.VMMSyntheticInitialMarginTransfer) then raise syntax 88.900 array("VMMSyntheticInitialMarginTransfer required")
  if transfer~postingEntity<>.VMMAccountingBuild~legalEntity then raise syntax 88.900 array("VMM accounting cannot post another entity's initial margin")
  self~requirePeriod(postingDate,periodId)
  dims=self~syntheticDims(transfer~contractId,"INITIAL_MARGIN"); dims["assetRef"]=transfer~assetRef; dims["assetClass"]=transfer~assetClass; dims["beneficiaryEntity"]=transfer~beneficiaryEntity; dims["custodianRef"]=transfer~custodianRef; dims["controlEvidenceRef"]=transfer~controlEvidenceRef; dims["haircutBps"]=transfer~haircutBps; dims["recognizedRiskValueMinor"]=self~minor(transfer~recognizedValue)
  payload=.directory~new; payload["currency"]=transfer~currency; payload["grossAmountMinor"]=self~minor(transfer~grossMarketValue); payload["recognizedRiskValueMinor"]=self~minor(transfer~recognizedValue); payload["dimensions"]=dims
  evidence=.array~of(transfer~controlEvidenceRef,transfer~authorityRef)
  event=.AccountingEvent~new("VMM:IM:"||transfer~transferId,.VMMAccountingBuild~legalEntity,"VMM_SYNTHETIC_INITIAL_MARGIN_POSTED",postingDate,transfer~contractId,transfer~beneficiaryEntity,transfer~authorityRef,payload,evidence,self~eventMeta(periodId))
  return engine~transact(event)

::method postFundingDraw
  expose engine vmm
  use strict arg draw,postingDate,periodId
  if \draw~isA(.VMMFundingDraw) then raise syntax 88.900 array("VMMFundingDraw required")
  f=vmm~fundingFacility(draw~facilityId); if f==.nil then raise syntax 88.900 array("unknown VMM funding facility",draw~facilityId)
  self~requirePeriod(postingDate,periodId)
  dims=self~fundingDims("FUNDING_DRAW"); dims["facilityId"]=draw~facilityId; dims["lenderEntity"]=f~lenderEntity; dims["sourceClass"]=f~sourceClass; dims["loanObligationRef"]=draw~loanObligationRef
  payload=.directory~new; payload["currency"]=draw~currency; payload["amountMinor"]=self~minor(draw~amount); payload["dimensions"]=dims
  evidence=.array~of(f~legalEffectRef,draw~lenderAuthority,draw~loanObligationRef)
  event=.AccountingEvent~new("VMM:FUNDING:DRAW:"||draw~drawId,.VMMAccountingBuild~legalEntity,"VMM_FUNDING_DRAW",postingDate,draw~loanObligationRef,f~lenderEntity,"VMM.TREASURY.FUNDING",payload,evidence,self~eventMeta(periodId))
  return engine~transact(event)

::method postFundingAccrual
  expose engine vmm
  use strict arg accrual,postingDate,periodId
  if \accrual~isA(.VMMFundingAccrual) then raise syntax 88.900 array("VMMFundingAccrual required")
  f=vmm~fundingFacility(accrual~facilityId); if f==.nil then raise syntax 88.900 array("unknown VMM funding facility",accrual~facilityId)
  self~requirePeriod(postingDate,periodId)
  dims=self~fundingDims("FUNDING_INTEREST_ACCRUAL"); dims["facilityId"]=accrual~facilityId; dims["lenderEntity"]=f~lenderEntity; dims["interestRateBps"]=accrual~interestRateBps; dims["days"]=accrual~days
  payload=.directory~new; payload["currency"]=accrual~currency; payload["amountMinor"]=self~minor(accrual~amount); payload["dimensions"]=dims
  evidence=.array~of(f~legalEffectRef,accrual~authorityRef)
  event=.AccountingEvent~new("VMM:FUNDING:ACCRUAL:"||accrual~accrualId,.VMMAccountingBuild~legalEntity,"VMM_FUNDING_INTEREST_ACCRUAL",postingDate,accrual~facilityId,f~lenderEntity,accrual~authorityRef,payload,evidence,self~eventMeta(periodId))
  return engine~transact(event)

::method postFundingRepayment
  expose engine vmm
  use strict arg repayment,postingDate,periodId
  if \repayment~isA(.VMMFundingRepayment) then raise syntax 88.900 array("VMMFundingRepayment required")
  f=vmm~fundingFacility(repayment~facilityId); if f==.nil then raise syntax 88.900 array("unknown VMM funding facility",repayment~facilityId)
  self~requirePeriod(postingDate,periodId)
  dims=self~fundingDims("FUNDING_REPAYMENT"); dims["facilityId"]=repayment~facilityId; dims["lenderEntity"]=f~lenderEntity; dims["loanObligationRef"]=repayment~loanObligationRef
  payload=.directory~new; payload["currency"]=repayment~currency; payload["amountMinor"]=self~minor(repayment~amount); payload["dimensions"]=dims
  evidence=.array~of(f~legalEffectRef,repayment~authorityRef,repayment~loanObligationRef)
  event=.AccountingEvent~new("VMM:FUNDING:REPAYMENT:"||repayment~repaymentId,.VMMAccountingBuild~legalEntity,"VMM_FUNDING_REPAYMENT",postingDate,repayment~loanObligationRef,f~lenderEntity,repayment~authorityRef,payload,evidence,self~eventMeta(periodId))
  return engine~transact(event)

::method postXVA
  expose engine
  use strict arg report,postingDate,periodId
  if \report~isA(.VMMSyntheticXVAReport) then raise syntax 88.900 array("VMMSyntheticXVAReport required")
  self~requirePeriod(postingDate,periodId)
  dims=self~syntheticDims(report~contractId,"XVA"); dims["valuationId"]=report~valuationId; dims["cvaMinor"]=self~minor(report~cvaAmount); dims["fvaMinor"]=self~minor(report~fvaAmount)
  payload=.directory~new; payload["currency"]=report~currency; payload["amountMinor"]=self~minor(report~totalXva); payload["dimensions"]=dims
  evidence=.array~of(report~creditEvidenceRef,report~fundingCurveEvidenceRef,report~modelEvidenceRef,report~authorityRef)
  event=.AccountingEvent~new("VMM:XVA:"||report~reportId,.VMMAccountingBuild~legalEntity,"VMM_SYNTHETIC_XVA_RECORDED",postingDate,report~contractId,"",report~authorityRef,payload,evidence,self~eventMeta(periodId))
  return engine~transact(event)

::method postCloseoutDetermination
  expose engine
  use strict arg closeout,postingDate,periodId
  if \closeout~isA(.VMMSyntheticCloseoutDetermination) then raise syntax 88.900 array("VMMSyntheticCloseoutDetermination required")
  self~requirePeriod(postingDate,periodId)
  dims=self~syntheticDims(closeout~contractId,"CLOSEOUT_DETERMINATION"); dims["closeoutId"]=closeout~closeoutId; dims["terminationId"]=closeout~terminationId; dims["segregatedInitialMarginRecognizedMinor"]=self~minor(closeout~segregatedInitialMarginRecognized); dims["collateralNettingEvidenceRef"]=closeout~collateralNettingEvidenceRef
  payload=.directory~new; payload["currency"]=closeout~currency; payload["contractId"]=closeout~contractId; payload["grossAmountMinor"]=self~minor(closeout~grossAbsolute); payload["grossDirection"]=closeout~grossDirection; payload["cashCollateralMinor"]=self~minor(closeout~cashVariationMarginPosted); payload["netAmountMinor"]=self~minor(closeout~netAbsolute); payload["netDirection"]=closeout~netDirection; payload["dimensions"]=dims
  evidence=.array~of(closeout~methodologyEvidenceRef,closeout~marketDataEvidenceRef,closeout~collateralNettingEvidenceRef,closeout~valuationAuthority)
  event=.AccountingEvent~new("VMM:CLOSEOUT:"||closeout~closeoutId,.VMMAccountingBuild~legalEntity,"VMM_SYNTHETIC_CLOSEOUT_DETERMINED",postingDate,closeout~contractId,closeout~counterpartyEntity,closeout~valuationAuthority,payload,evidence,self~eventMeta(periodId))
  return engine~transact(event)

::method postCloseoutSettlement
  expose engine
  use strict arg settlement,closeout,postingDate,periodId
  if \settlement~isA(.VMMSyntheticCloseoutSettlement) | \closeout~isA(.VMMSyntheticCloseoutDetermination) then raise syntax 88.900 array("close-out settlement and determination required")
  if settlement~closeoutId<>closeout~closeoutId | settlement~contractId<>closeout~contractId | settlement~amount<>closeout~netAbsolute then raise syntax 88.900 array("close-out settlement does not match determination")
  self~requirePeriod(postingDate,periodId)
  dims=self~syntheticDims(closeout~contractId,"CLOSEOUT_SETTLEMENT"); dims["closeoutId"]=closeout~closeoutId; dims["terminationId"]=closeout~terminationId; dims["payerEntity"]=settlement~payerEntity; dims["payeeEntity"]=settlement~payeeEntity
  payload=.directory~new; payload["currency"]=settlement~currency; payload["amountMinor"]=self~minor(settlement~amount); payload["direction"]=closeout~netDirection; payload["dimensions"]=dims
  evidence=.array~of(settlement~paymentEvidenceRef,settlement~authorityRef)
  counterparty=closeout~counterpartyEntity
  event=.AccountingEvent~new("VMM:CLOSEOUT:SETTLEMENT:"||settlement~settlementId,.VMMAccountingBuild~legalEntity,"VMM_SYNTHETIC_CLOSEOUT_SETTLED",postingDate,closeout~contractId,counterparty,settlement~authorityRef,payload,evidence,self~eventMeta(periodId))
  return engine~transact(event)

::method postCloseoutFinalization
  expose engine
  use strict arg finalization,postingDate,periodId
  if \finalization~isA(.VMMCloseoutFinalization) then raise syntax 88.900 array("VMMCloseoutFinalization required")
  self~requirePeriod(postingDate,periodId)
  dims=self~syntheticDims(finalization~contractId,"CLOSEOUT_FINALIZATION"); dims["closeoutId"]=finalization~closeoutId; dims["finalizationId"]=finalization~finalizationId; dims["basis"]=finalization~basis; dims["sourceRef"]=finalization~sourceRef; dims["segregatedInitialMarginRecognizedMinor"]=self~minor(finalization~segregatedInitialMarginRecognized)
  payload=.directory~new; payload["currency"]=finalization~currency; payload["contractId"]=finalization~contractId; payload["grossAmountMinor"]=self~minor(finalization~grossAbsolute); payload["grossDirection"]=finalization~grossDirection; payload["cashCollateralMinor"]=self~minor(finalization~cashVariationMarginPosted); payload["netAmountMinor"]=self~minor(finalization~netAbsolute); payload["netDirection"]=finalization~netDirection; payload["dimensions"]=dims
  evidence=.array~of(finalization~sourceRef,finalization~methodologyEvidenceRef,finalization~marketDataEvidenceRef,finalization~authorityRef)
  event=.AccountingEvent~new("VMM:CLOSEOUT:FINALIZATION:"||finalization~finalizationId,.VMMAccountingBuild~legalEntity,"VMM_SYNTHETIC_CLOSEOUT_FINALIZED",postingDate,finalization~contractId,finalization~counterpartyEntity,finalization~authorityRef,payload,evidence,self~eventMeta(periodId))
  return engine~transact(event)

::method postCloseoutFinalSettlement
  expose engine
  use strict arg settlement,finalization,postingDate,periodId
  if \settlement~isA(.VMMSyntheticCloseoutSettlement) | \finalization~isA(.VMMCloseoutFinalization) then raise syntax 88.900 array("final close-out settlement and finalization required")
  if settlement~closeoutId<>finalization~closeoutId | settlement~contractId<>finalization~contractId | settlement~finalizationId<>finalization~finalizationId | settlement~amount<>finalization~netAbsolute then raise syntax 88.900 array("final close-out settlement does not match finalization")
  self~requirePeriod(postingDate,periodId)
  dims=self~syntheticDims(finalization~contractId,"CLOSEOUT_FINAL_SETTLEMENT"); dims["closeoutId"]=finalization~closeoutId; dims["finalizationId"]=finalization~finalizationId; dims["payerEntity"]=settlement~payerEntity; dims["payeeEntity"]=settlement~payeeEntity
  payload=.directory~new; payload["currency"]=settlement~currency; payload["amountMinor"]=self~minor(settlement~amount); payload["direction"]=finalization~netDirection; payload["dimensions"]=dims
  evidence=.array~of(settlement~paymentEvidenceRef,settlement~authorityRef,finalization~sourceRef)
  event=.AccountingEvent~new("VMM:CLOSEOUT:FINAL-SETTLEMENT:"||settlement~settlementId,.VMMAccountingBuild~legalEntity,"VMM_SYNTHETIC_CLOSEOUT_FINAL_SETTLED",postingDate,finalization~contractId,finalization~counterpartyEntity,settlement~authorityRef,payload,evidence,self~eventMeta(periodId))
  return engine~transact(event)

::method postNettingSetSettlement
  expose engine
  use strict arg settlement,determination,nettingSet,postingDate,periodId
  if \settlement~isA(.VMMNettingSetSettlement) | \determination~isA(.VMMNettingSetDetermination) | \nettingSet~isA(.VMMMasterAgreementNettingSet) then raise syntax 88.900 array("netting-set settlement/determination/set required")
  if settlement~determinationId<>determination~determinationId | settlement~nettingSetId<>nettingSet~nettingSetId | determination~nettingSetId<>nettingSet~nettingSetId | settlement~amount<>determination~netAbsolute then raise syntax 88.900 array("netting-set settlement identity/arithmetic mismatch")
  self~requirePeriod(postingDate,periodId)
  dims=self~syntheticDims(nettingSet~nettingSetId,"MASTER_NETTING_SETTLEMENT"); dims["nettingSetId"]=nettingSet~nettingSetId; dims["masterAgreementRef"]=nettingSet~masterAgreementRef; dims["counterpartyEntity"]=nettingSet~counterpartyEntity; dims["legalOpinionRef"]=nettingSet~legalOpinionRef; dims["closeoutNettingElectionRef"]=nettingSet~closeoutNettingElectionRef
  payload=.directory~new; payload["currency"]=settlement~currency; payload["totalReceivableMinor"]=self~minor(determination~totalReceivable); payload["totalPayableMinor"]=self~minor(determination~totalPayable); payload["cashAmountMinor"]=self~minor(settlement~amount); payload["direction"]=determination~netDirection; payload["dimensions"]=dims
  evidence=.array~of(nettingSet~legalOpinionRef,nettingSet~closeoutNettingElectionRef,determination~calculationEvidenceRef,settlement~paymentEvidenceRef,settlement~authorityRef)
  event=.AccountingEvent~new("VMM:MASTER-NETTING:SETTLEMENT:"||settlement~settlementId,.VMMAccountingBuild~legalEntity,"VMM_SYNTHETIC_MASTER_NETTING_SETTLED",postingDate,nettingSet~nettingSetId,nettingSet~counterpartyEntity,settlement~authorityRef,payload,evidence,self~eventMeta(periodId))
  return engine~transact(event)

::method postInitialMarginReturn
  expose engine
  use strict arg custodySettlement,returnInstruction,postingDate,periodId
  if \custodySettlement~isA(.VMMCustodyReturnSettlement) | \returnInstruction~isA(.VMMPostTerminationCollateralReturn) then raise syntax 88.900 array("custody settlement and collateral-return instruction required")
  if custodySettlement~returnId<>returnInstruction~returnId | custodySettlement~contractId<>returnInstruction~contractId | custodySettlement~assetRef<>returnInstruction~assetRef | custodySettlement~grossCarryingAmount<>returnInstruction~grossCarryingAmount then raise syntax 88.900 array("initial-margin custody return identity/carrying-value mismatch")
  self~requirePeriod(postingDate,periodId)
  dims=self~syntheticDims(returnInstruction~contractId,"INITIAL_MARGIN_RETURN"); dims["returnId"]=returnInstruction~returnId; dims["closeoutId"]=returnInstruction~closeoutId; dims["finalizationId"]=returnInstruction~finalizationId; dims["assetRef"]=returnInstruction~assetRef; dims["assetClass"]=returnInstruction~assetClass; dims["custodianRef"]=returnInstruction~custodianRef; dims["recognizedRiskValueMinor"]=self~minor(returnInstruction~recognizedRiskValue)
  payload=.directory~new; payload["currency"]=custodySettlement~currency; payload["grossAmountMinor"]=self~minor(custodySettlement~grossCarryingAmount); payload["dimensions"]=dims
  evidence=.array~of(returnInstruction~instructionEvidenceRef,custodySettlement~controlEvidenceRef,custodySettlement~custodianReceiptRef,custodySettlement~authorityRef)
  event=.AccountingEvent~new("VMM:IM:RETURN:"||custodySettlement~settlementId,.VMMAccountingBuild~legalEntity,"VMM_SYNTHETIC_INITIAL_MARGIN_RETURN_SETTLED",postingDate,returnInstruction~contractId,returnInstruction~beneficiaryEntity,custodySettlement~authorityRef,payload,evidence,self~eventMeta(periodId))
  return engine~transact(event)

::method syntheticDims private
  use strict arg contractId,eventType
  d=.directory~new
  d["legalEntity"]=.VMMAccountingBuild~legalEntity
  d["contractId"]=contractId
  d["eventType"]=eventType
  d[.VMMAccountingDimensions~BUSINESS_LINE]=.VMMAccountingDimensions~BUSINESS_INSTITUTIONAL_SYNTHETICS
  d[.VMMAccountingDimensions~ACCOUNTING_FUNCTION]=self~syntheticAccountingFunction(eventType)
  return d
::method fundingDims private
  use strict arg eventType
  d=.directory~new
  d["legalEntity"]=.VMMAccountingBuild~legalEntity
  d["eventType"]=eventType
  d[.VMMAccountingDimensions~BUSINESS_LINE]=.VMMAccountingDimensions~BUSINESS_TREASURY_FUNDING
  d[.VMMAccountingDimensions~ACCOUNTING_FUNCTION]=.VMMAccountingDimensions~FUNCTION_FUNDING
  return d
::method syntheticAccountingFunction private
  use strict arg eventType
  select
    when eventType="PREMIUM_ACCRUAL" | eventType="PREMIUM_SETTLEMENT" then return .VMMAccountingDimensions~FUNCTION_PREMIUM
    when eventType="VARIATION_MARGIN" | eventType="INITIAL_MARGIN" | eventType="INITIAL_MARGIN_RETURN" then return .VMMAccountingDimensions~FUNCTION_COLLATERAL_CUSTODY
    when eventType="XVA" then return .VMMAccountingDimensions~FUNCTION_XVA
    when eventType="CLOSEOUT_DETERMINATION" | eventType="CLOSEOUT_SETTLEMENT" | eventType="CLOSEOUT_FINALIZATION" | eventType="CLOSEOUT_FINAL_SETTLEMENT" | eventType="MASTER_NETTING_SETTLEMENT" then return .VMMAccountingDimensions~FUNCTION_CLOSEOUT
    otherwise return "SYNTHETIC_LIFECYCLE"
  end
::method minor private
  use strict arg amount
  numeric digits 50
  if amount<0 then raise syntax 88.900 array("VMM accounting amount cannot be negative",amount)
  return format(amount*100,,0)
::method eventMeta private
  use strict arg periodId
  m=.directory~new; m["vmm.accountingAdapter"]=.VMMAccountingBuild~protocol; m["vmm.requestedPeriodId"]=periodId; return m
::method requirePeriod private
  expose engine
  use strict arg postingDate,periodId
  p=engine~book~periodForDate(postingDate,.false)
  if p==.nil then raise syntax 88.900 array("No VMM accounting period for posting date",postingDate)
  if p~periodId<>periodId then raise syntax 88.900 array("VMM accounting period mismatch",periodId,p~periodId)
  return p

::requires "AccountingEngine.cls"
::requires "VMMCloseoutOperations.cls"
