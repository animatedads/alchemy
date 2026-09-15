/* VMMDefaultCloseout.cls -- institutional synthetic default and close-out v0.8.
 *
 * Default notice, cure, termination election, close-out determination and
 * settlement remain distinct legal/economic facts. Internal VMM hedge P&L is
 * recorded separately and never changes the contractual close-out amount.
 */

::class VMMDefaultCloseoutBuild public
::method version class; return "0.9"
::method protocol class; return "vmm.institutional.synthetic.default/0.8"
::method legalEntity class; return "VECTOR_MERIDIAN_MARKETS_LTD"

::class VMMDefaultDateUtil public
::method requireIsoDate class
  use strict arg value,label
  text=value~string~strip
  signal on syntax name bad
  ignore=date("B",text,"I")
  signal off syntax
  return text
bad:
  signal off syntax
  raise syntax 88.900 array(label||" must be YYYY-MM-DD",text)
::method addDays class
  use strict arg isoDate,days
  numeric digits 50
  d=self~requireIsoDate(isoDate,"date")
  if \datatype(days~string,"W") | days<0 then raise syntax 88.900 array("days must be non-negative whole number",days)
  return date("I",date("B",d,"I")+days,"B")

::class VMMSyntheticDefaultPolicy public
::method init
  expose policyId currency paymentCureDays collateralCureDays otherCureDays closeoutMethodologyRef policyRef
  use strict arg policyId,currency,paymentCureDays,collateralCureDays,otherCureDays,closeoutMethodologyRef,policyRef
  if policyId="" | currency="" | closeoutMethodologyRef="" | policyRef="" then raise syntax 88.900 array("invalid VMM synthetic default policy")
  if paymentCureDays<0 | collateralCureDays<0 | otherCureDays<0 then raise syntax 88.900 array("invalid VMM synthetic cure days")
::method policyId; expose policyId; return policyId
::method currency; expose currency; return currency
::method closeoutMethodologyRef; expose closeoutMethodologyRef; return closeoutMethodologyRef
::method policyRef; expose policyRef; return policyRef
::method cureDays
  expose paymentCureDays collateralCureDays otherCureDays
  use strict arg defaultType
  select
    when defaultType="FAILURE_TO_PAY_PREMIUM" then return paymentCureDays
    when defaultType="FAILURE_TO_POST_COLLATERAL" then return collateralCureDays
    when defaultType="INSOLVENCY" then return 0
    when defaultType="REPUDIATION" then return otherCureDays
    otherwise raise syntax 88.900 array("unsupported VMM synthetic default type",defaultType)
  end

::class VMMSyntheticDefaultEvent public
::method init
  expose eventId contractId currency defaultType defaultingEntity nonDefaultingEntity occurredDate noticeDate cureDeadline defaultEvidenceRef noticeAuthority policyRef state
  use strict arg eventId,contractId,currency,defaultType,defaultingEntity,nonDefaultingEntity,occurredDate,noticeDate,cureDeadline,defaultEvidenceRef,noticeAuthority,policyRef
  if eventId="" | contractId="" | currency="" | defaultingEntity="" | nonDefaultingEntity="" | defaultEvidenceRef="" | noticeAuthority="" | policyRef="" then raise syntax 88.900 array("invalid VMM synthetic default event")
  ignore=.VMMDefaultDateUtil~requireIsoDate(occurredDate,"occurredDate")
  ignore=.VMMDefaultDateUtil~requireIsoDate(noticeDate,"noticeDate")
  ignore=.VMMDefaultDateUtil~requireIsoDate(cureDeadline,"cureDeadline")
  if occurredDate>noticeDate | noticeDate>cureDeadline then raise syntax 88.900 array("invalid VMM synthetic default date ordering")
  if defaultingEntity=nonDefaultingEntity then raise syntax 88.900 array("default requires distinct parties")
  state="OPEN"
::method eventId; expose eventId; return eventId
::method contractId; expose contractId; return contractId
::method currency; expose currency; return currency
::method defaultType; expose defaultType; return defaultType
::method defaultingEntity; expose defaultingEntity; return defaultingEntity
::method nonDefaultingEntity; expose nonDefaultingEntity; return nonDefaultingEntity
::method occurredDate; expose occurredDate; return occurredDate
::method noticeDate; expose noticeDate; return noticeDate
::method cureDeadline; expose cureDeadline; return cureDeadline
::method defaultEvidenceRef; expose defaultEvidenceRef; return defaultEvidenceRef
::method noticeAuthority; expose noticeAuthority; return noticeAuthority
::method policyRef; expose policyRef; return policyRef
::method state; expose state; return state
::method markCured
  expose state
  if state<>"OPEN" then raise syntax 88.900 array("default event is not open for cure",state)
  state="CURED"; return self
::method markUncured
  expose state
  if state<>"OPEN" then raise syntax 88.900 array("default event is not open for uncured assessment",state)
  state="UNCURED"; return self

::class VMMSyntheticDefaultCure public
::method init
  expose cureId eventId contractId curingEntity curedDate cureEvidenceRef authorityRef
  use strict arg cureId,eventId,contractId,curingEntity,curedDate,cureEvidenceRef,authorityRef
  if cureId="" | eventId="" | contractId="" | curingEntity="" | cureEvidenceRef="" | authorityRef="" then raise syntax 88.900 array("invalid VMM synthetic default cure")
  ignore=.VMMDefaultDateUtil~requireIsoDate(curedDate,"curedDate")
::method cureId; expose cureId; return cureId
::method eventId; expose eventId; return eventId
::method contractId; expose contractId; return contractId
::method curingEntity; expose curingEntity; return curingEntity
::method curedDate; expose curedDate; return curedDate
::method cureEvidenceRef; expose cureEvidenceRef; return cureEvidenceRef
::method authorityRef; expose authorityRef; return authorityRef

::class VMMSyntheticUncuredAssessment public
::method init
  expose assessmentId eventId contractId assessedDate evidenceRef authorityRef
  use strict arg assessmentId,eventId,contractId,assessedDate,evidenceRef,authorityRef
  if assessmentId="" | eventId="" | contractId="" | evidenceRef="" | authorityRef="" then raise syntax 88.900 array("invalid VMM synthetic uncured assessment")
  ignore=.VMMDefaultDateUtil~requireIsoDate(assessedDate,"assessedDate")
::method assessmentId; expose assessmentId; return assessmentId
::method eventId; expose eventId; return eventId
::method contractId; expose contractId; return contractId
::method assessedDate; expose assessedDate; return assessedDate
::method evidenceRef; expose evidenceRef; return evidenceRef
::method authorityRef; expose authorityRef; return authorityRef

::class VMMSyntheticEarlyTermination public
::method init
  expose terminationId eventId contractId defaultingEntity electingEntity terminationDate terminationNoticeRef valuationAgentRef authorityRef
  use strict arg terminationId,eventId,contractId,defaultingEntity,electingEntity,terminationDate,terminationNoticeRef,valuationAgentRef,authorityRef
  if terminationId="" | eventId="" | contractId="" | defaultingEntity="" | electingEntity="" | terminationNoticeRef="" | valuationAgentRef="" | authorityRef="" then raise syntax 88.900 array("invalid VMM synthetic early termination")
  ignore=.VMMDefaultDateUtil~requireIsoDate(terminationDate,"terminationDate")
  if defaultingEntity=electingEntity then raise syntax 88.900 array("defaulting party cannot elect its own early termination")
::method terminationId; expose terminationId; return terminationId
::method eventId; expose eventId; return eventId
::method contractId; expose contractId; return contractId
::method defaultingEntity; expose defaultingEntity; return defaultingEntity
::method electingEntity; expose electingEntity; return electingEntity
::method terminationDate; expose terminationDate; return terminationDate
::method terminationNoticeRef; expose terminationNoticeRef; return terminationNoticeRef
::method valuationAgentRef; expose valuationAgentRef; return valuationAgentRef
::method authorityRef; expose authorityRef; return authorityRef

/* Signed grossAmountToVMM: positive means VMM is owed money under the legal
 * close-out determination, negative means VMM owes the counterparty. Only
 * cash variation margin already posted by VMM is automatically included in
 * v0.8 close-out netting. Segregated initial margin remains separately shown. */
::class VMMSyntheticCloseoutDetermination public
::method init
  expose closeoutId terminationId contractId counterpartyEntity currency grossAmountToVMM cashVariationMarginPosted segregatedInitialMarginRecognized netAmountToVMM determinedDate methodologyEvidenceRef marketDataEvidenceRef collateralNettingEvidenceRef valuationAuthority
  use strict arg closeoutId,terminationId,contractId,counterpartyEntity,currency,grossAmountToVMM,cashVariationMarginPosted,segregatedInitialMarginRecognized,determinedDate,methodologyEvidenceRef,marketDataEvidenceRef,collateralNettingEvidenceRef,valuationAuthority
  numeric digits 50
  if closeoutId="" | terminationId="" | contractId="" | counterpartyEntity="" | currency="" | methodologyEvidenceRef="" | marketDataEvidenceRef="" | collateralNettingEvidenceRef="" | valuationAuthority="" then raise syntax 88.900 array("invalid VMM synthetic close-out determination")
  ignore=.VMMDefaultDateUtil~requireIsoDate(determinedDate,"determinedDate")
  if cashVariationMarginPosted<0 | segregatedInitialMarginRecognized<0 then raise syntax 88.900 array("invalid VMM close-out collateral values")
  netAmountToVMM=grossAmountToVMM+cashVariationMarginPosted
::method closeoutId; expose closeoutId; return closeoutId
::method terminationId; expose terminationId; return terminationId
::method contractId; expose contractId; return contractId
::method counterpartyEntity; expose counterpartyEntity; return counterpartyEntity
::method currency; expose currency; return currency
::method grossAmountToVMM; expose grossAmountToVMM; return grossAmountToVMM
::method cashVariationMarginPosted; expose cashVariationMarginPosted; return cashVariationMarginPosted
::method segregatedInitialMarginRecognized; expose segregatedInitialMarginRecognized; return segregatedInitialMarginRecognized
::method netAmountToVMM; expose netAmountToVMM; return netAmountToVMM
::method determinedDate; expose determinedDate; return determinedDate
::method methodologyEvidenceRef; expose methodologyEvidenceRef; return methodologyEvidenceRef
::method marketDataEvidenceRef; expose marketDataEvidenceRef; return marketDataEvidenceRef
::method collateralNettingEvidenceRef; expose collateralNettingEvidenceRef; return collateralNettingEvidenceRef
::method valuationAuthority; expose valuationAuthority; return valuationAuthority
::method grossDirection
  expose grossAmountToVMM
  if grossAmountToVMM>0 then return "VMM_RECEIVABLE"
  if grossAmountToVMM<0 then return "VMM_PAYABLE"
  return "FLAT"
::method netDirection
  expose netAmountToVMM
  if netAmountToVMM>0 then return "VMM_RECEIVABLE"
  if netAmountToVMM<0 then return "VMM_PAYABLE"
  return "FLAT"
::method grossAbsolute
  expose grossAmountToVMM
  return abs(grossAmountToVMM)
::method netAbsolute
  expose netAmountToVMM
  return abs(netAmountToVMM)

::class VMMSyntheticCloseoutSettlement public
::method init
  expose settlementId closeoutId contractId currency amount payerEntity payeeEntity settledDate paymentEvidenceRef authorityRef finalizationId
  use strict arg settlementId,closeoutId,contractId,currency,amount,payerEntity,payeeEntity,settledDate,paymentEvidenceRef,authorityRef,finalizationId=""
  if settlementId="" | closeoutId="" | contractId="" | currency="" | paymentEvidenceRef="" | authorityRef="" | amount<0 then raise syntax 88.900 array("invalid VMM synthetic close-out settlement")
  ignore=.VMMDefaultDateUtil~requireIsoDate(settledDate,"settledDate")
  if amount>0 & (payerEntity="" | payeeEntity="" | payerEntity=payeeEntity) then raise syntax 88.900 array("cash close-out settlement requires distinct payer/payee")
  if amount=0 & (payerEntity<>"" | payeeEntity<>"") then raise syntax 88.900 array("zero close-out settlement must not invent a payer/payee")
::method settlementId; expose settlementId; return settlementId
::method closeoutId; expose closeoutId; return closeoutId
::method contractId; expose contractId; return contractId
::method currency; expose currency; return currency
::method amount; expose amount; return amount
::method payerEntity; expose payerEntity; return payerEntity
::method payeeEntity; expose payeeEntity; return payeeEntity
::method settledDate; expose settledDate; return settledDate
::method paymentEvidenceRef; expose paymentEvidenceRef; return paymentEvidenceRef
::method authorityRef; expose authorityRef; return authorityRef
::method finalizationId; expose finalizationId; return finalizationId

::class VMMSyntheticCloseoutHedgeAttribution public
::method init
  expose attributionId terminationId contractId currency hedgePnl attributedDate executionEvidenceRef methodologyEvidenceRef authorityRef
  use strict arg attributionId,terminationId,contractId,currency,hedgePnl,attributedDate,executionEvidenceRef,methodologyEvidenceRef,authorityRef
  if attributionId="" | terminationId="" | contractId="" | currency="" | executionEvidenceRef="" | methodologyEvidenceRef="" | authorityRef="" then raise syntax 88.900 array("invalid VMM synthetic close-out hedge attribution")
  ignore=.VMMDefaultDateUtil~requireIsoDate(attributedDate,"attributedDate")
::method attributionId; expose attributionId; return attributionId
::method terminationId; expose terminationId; return terminationId
::method contractId; expose contractId; return contractId
::method currency; expose currency; return currency
::method hedgePnl; expose hedgePnl; return hedgePnl
::method attributedDate; expose attributedDate; return attributedDate
::method executionEvidenceRef; expose executionEvidenceRef; return executionEvidenceRef
::method methodologyEvidenceRef; expose methodologyEvidenceRef; return methodologyEvidenceRef
::method authorityRef; expose authorityRef; return authorityRef

::class VMMInstitutionalDefaultCloseoutService public
::method init
  expose productService policies defaultEvents cures uncuredAssessments terminations closeouts settlements hedgeAttributions activeDefaultByContract terminationByEvent closeoutByTermination settlementByCloseout settlementController
  use strict arg productService
  if productService==.nil | \productService~isA(.VMMInstitutionalSyntheticService) then raise syntax 88.900 array("VMM default/close-out service requires institutional synthetic service")
  policies=.directory~new; defaultEvents=.directory~new; cures=.directory~new; uncuredAssessments=.directory~new; terminations=.directory~new; closeouts=.directory~new; settlements=.directory~new; hedgeAttributions=.directory~new
  activeDefaultByContract=.directory~new; terminationByEvent=.directory~new; closeoutByTermination=.directory~new; settlementByCloseout=.directory~new; settlementController=.nil
::method productService; expose productService; return productService
::method setSettlementController
  expose settlementController
  use strict arg controller
  if controller==.nil then raise syntax 88.900 array("VMM settlement controller required")
  if settlementController<>.nil & settlementController<>controller then raise syntax 88.900 array("VMM close-out settlement controller already bound")
  settlementController=controller
  return controller
::method settlementController; expose settlementController; return settlementController
::method vmm; expose productService; return productService~vmm
::method setPolicy
  expose productService policies
  use strict arg policy,authorityRef
  if \policy~isA(.VMMSyntheticDefaultPolicy) | authorityRef="" then raise syntax 88.900 array("invalid VMM synthetic default policy registration")
  policies[policy~currency]=policy
  productService~vmm~journal~put("synthetic:defaultPolicy:"||policy~currency,policy,"VMM_SYNTHETIC_DEFAULT_POLICY_SET",self~meta("authority",authorityRef))
  return policy
::method policy
  expose policies
  use strict arg currency
  return policies[currency]
::method declareDefault
  expose productService policies defaultEvents activeDefaultByContract
  use strict arg eventId,contractId,defaultType,defaultingEntity,occurredDate,noticeDate,defaultEvidenceRef,noticeAuthority
  if defaultEvents~hasIndex(eventId) then raise syntax 88.900 array("duplicate VMM synthetic default event",eventId)
  if activeDefaultByContract~hasIndex(contractId) then raise syntax 88.900 array("contract already has active default event",contractId,activeDefaultByContract[contractId])
  k=productService~contract(contractId); if k==.nil | k~state<>"ACTIVE" then raise syntax 88.900 array("default notice requires active synthetic contract",contractId)
  cp=productService~counterparty(k~counterpartyId); if cp==.nil then raise syntax 88.900 array("synthetic counterparty unavailable",k~counterpartyId)
  if defaultingEntity<>cp~legalEntity & defaultingEntity<>.VMMDefaultCloseoutBuild~legalEntity then raise syntax 88.900 array("defaulting entity is not a party to contract",defaultingEntity)
  if defaultingEntity=cp~legalEntity then nonDefault=.VMMDefaultCloseoutBuild~legalEntity; else nonDefault=cp~legalEntity
  p=policies[k~terms~currency]; if p==.nil then raise syntax 88.900 array("synthetic default policy required",k~terms~currency)
  /* A premium-payment default by the client must correspond to an outstanding VMM receivable. */
  if defaultType="FAILURE_TO_PAY_PREMIUM" & defaultingEntity=cp~legalEntity & productService~premiumReceivable(contractId)<=0 then raise syntax 88.900 array("premium-payment default requires outstanding premium receivable",contractId)
  cureDeadline=.VMMDefaultDateUtil~addDays(noticeDate,p~cureDays(defaultType))
  d=.VMMSyntheticDefaultEvent~new(eventId,contractId,k~terms~currency,defaultType,defaultingEntity,nonDefault,occurredDate,noticeDate,cureDeadline,defaultEvidenceRef,noticeAuthority,p~policyRef)
  defaultEvents[eventId]=d; activeDefaultByContract[contractId]=eventId
  productService~vmm~journal~put("synthetic:default:"||eventId,d,"VMM_SYNTHETIC_DEFAULT_NOTICED",self~meta("contract",contractId))
  return d
::method defaultEvent
  expose defaultEvents
  use strict arg eventId
  return defaultEvents[eventId]
::method cureDefault
  expose productService defaultEvents cures activeDefaultByContract
  use strict arg cureId,eventId,curingEntity,curedDate,cureEvidenceRef,authorityRef
  if cures~hasIndex(cureId) then raise syntax 88.900 array("duplicate VMM synthetic cure",cureId)
  d=defaultEvents[eventId]; if d==.nil | d~state<>"OPEN" then raise syntax 88.900 array("default event not open for cure",eventId)
  if curingEntity<>d~defaultingEntity then raise syntax 88.900 array("only defaulting party can cure default",curingEntity,d~defaultingEntity)
  ignore=.VMMDefaultDateUtil~requireIsoDate(curedDate,"curedDate")
  if curedDate>d~cureDeadline then raise syntax 88.900 array("default cure is after contractual cure deadline",curedDate,d~cureDeadline)
  c=.VMMSyntheticDefaultCure~new(cureId,eventId,d~contractId,curingEntity,curedDate,cureEvidenceRef,authorityRef)
  cures[cureId]=c; d~markCured; activeDefaultByContract~remove(d~contractId)
  productService~vmm~journal~put("synthetic:defaultCure:"||cureId,c,"VMM_SYNTHETIC_DEFAULT_CURED",self~meta("contract",d~contractId))
  return c
::method cure
  expose cures
  use strict arg cureId
  return cures[cureId]
::method assessUncured
  expose productService defaultEvents uncuredAssessments
  use strict arg assessmentId,eventId,assessedDate,evidenceRef,authorityRef
  if uncuredAssessments~hasIndex(assessmentId) then raise syntax 88.900 array("duplicate VMM uncured assessment",assessmentId)
  d=defaultEvents[eventId]; if d==.nil | d~state<>"OPEN" then raise syntax 88.900 array("default event not open for uncured assessment",eventId)
  ignore=.VMMDefaultDateUtil~requireIsoDate(assessedDate,"assessedDate")
  if assessedDate<=d~cureDeadline then raise syntax 88.900 array("cure period has not expired",assessedDate,d~cureDeadline)
  a=.VMMSyntheticUncuredAssessment~new(assessmentId,eventId,d~contractId,assessedDate,evidenceRef,authorityRef)
  uncuredAssessments[assessmentId]=a; d~markUncured
  productService~vmm~journal~put("synthetic:uncured:"||assessmentId,a,"VMM_SYNTHETIC_DEFAULT_UNCURED",self~meta("contract",d~contractId))
  return a
::method uncuredAssessment
  expose uncuredAssessments
  use strict arg assessmentId
  return uncuredAssessments[assessmentId]
::method electTermination
  expose productService defaultEvents terminations terminationByEvent activeDefaultByContract
  use strict arg terminationId,eventId,electingEntity,terminationDate,terminationNoticeRef,valuationAgentRef,authorityRef
  if terminations~hasIndex(terminationId) | terminationByEvent~hasIndex(eventId) then raise syntax 88.900 array("duplicate VMM early termination",terminationId,eventId)
  d=defaultEvents[eventId]; if d==.nil | d~state<>"UNCURED" then raise syntax 88.900 array("early termination requires uncured default",eventId)
  if electingEntity<>d~nonDefaultingEntity then raise syntax 88.900 array("only non-defaulting party may elect termination",electingEntity,d~nonDefaultingEntity)
  k=productService~contract(d~contractId); if k==.nil | k~state<>"ACTIVE" then raise syntax 88.900 array("termination election requires active contract",d~contractId)
  t=.VMMSyntheticEarlyTermination~new(terminationId,eventId,d~contractId,d~defaultingEntity,electingEntity,terminationDate,terminationNoticeRef,valuationAgentRef,authorityRef)
  terminations[terminationId]=t; terminationByEvent[eventId]=terminationId; activeDefaultByContract~remove(d~contractId); k~terminate
  productService~vmm~journal~put("synthetic:termination:"||terminationId,t,"VMM_SYNTHETIC_EARLY_TERMINATION_ELECTED",self~meta("contract",d~contractId))
  return t
::method termination
  expose terminations
  use strict arg terminationId
  return terminations[terminationId]
::method determineCloseout
  expose productService terminations closeouts closeoutByTermination settlementController
  use strict arg closeoutId,terminationId,grossAmountToVMM,determinedDate,methodologyEvidenceRef,marketDataEvidenceRef,collateralNettingEvidenceRef,valuationAuthority
  numeric digits 50
  if closeouts~hasIndex(closeoutId) | closeoutByTermination~hasIndex(terminationId) then raise syntax 88.900 array("duplicate VMM close-out determination",closeoutId,terminationId)
  t=terminations[terminationId]; if t==.nil then raise syntax 88.900 array("unknown VMM early termination",terminationId)
  k=productService~contract(t~contractId); if k==.nil | k~state<>"TERMINATED" then raise syntax 88.900 array("close-out requires terminated synthetic contract",t~contractId)
  cp=productService~counterparty(k~counterpartyId); if cp==.nil then raise syntax 88.900 array("synthetic counterparty unavailable",k~counterpartyId)
  vm=productService~collateralPosted(t~contractId)
  im=productService~initialMarginRecognized(t~contractId)
  c=.VMMSyntheticCloseoutDetermination~new(closeoutId,terminationId,t~contractId,cp~legalEntity,k~terms~currency,grossAmountToVMM,vm,im,determinedDate,methodologyEvidenceRef,marketDataEvidenceRef,collateralNettingEvidenceRef,valuationAuthority)
  closeouts[closeoutId]=c; closeoutByTermination[terminationId]=closeoutId
  productService~vmm~journal~put("synthetic:closeout:"||closeoutId,c,"VMM_SYNTHETIC_CLOSEOUT_DETERMINED",self~meta("contract",t~contractId))
  if settlementController<>.nil then settlementController~registerDetermination(c)
  return c
::method closeout
  expose closeouts
  use strict arg closeoutId
  return closeouts[closeoutId]
::method settleCloseout
  expose productService closeouts settlements settlementByCloseout settlementController
  use strict arg settlementId,closeoutId,settledDate,paymentEvidenceRef,authorityRef
  if settlements~hasIndex(settlementId) | settlementByCloseout~hasIndex(closeoutId) then raise syntax 88.900 array("duplicate VMM close-out settlement",settlementId,closeoutId)
  c=closeouts[closeoutId]; if c==.nil then raise syntax 88.900 array("unknown VMM close-out determination",closeoutId)
  finalization=.nil
  if settlementController<>.nil then do
    finalization=settlementController~settlementAuthorization(closeoutId)
    if finalization==.nil then raise syntax 88.900 array("v0.9 close-out requires finalized, non-netting-set settlement authorization",closeoutId)
    amount=finalization~netAbsolute; direction=finalization~netDirection
  end
  else do
    amount=c~netAbsolute; direction=c~netDirection
  end
  if direction="VMM_RECEIVABLE" then do; payer=c~counterpartyEntity; payee=.VMMDefaultCloseoutBuild~legalEntity; end
  else if direction="VMM_PAYABLE" then do; payer=.VMMDefaultCloseoutBuild~legalEntity; payee=c~counterpartyEntity; end
  else do; payer=""; payee=""; end
  fid=""; if finalization<>.nil then fid=finalization~finalizationId
  s=.VMMSyntheticCloseoutSettlement~new(settlementId,closeoutId,c~contractId,c~currency,amount,payer,payee,settledDate,paymentEvidenceRef,authorityRef,fid)
  settlements[settlementId]=s; settlementByCloseout[closeoutId]=settlementId
  productService~vmm~journal~put("synthetic:closeoutSettlement:"||settlementId,s,"VMM_SYNTHETIC_CLOSEOUT_SETTLED",self~meta("contract",c~contractId))
  if settlementController<>.nil then settlementController~recordDirectSettlement(s)
  return s
::method settlement
  expose settlements
  use strict arg settlementId
  return settlements[settlementId]
::method effectiveCashCollateralPosted
  expose productService settlementByCloseout closeoutByTermination terminations settlementController
  use strict arg contractId
  /* Once a close-out linked to the contract has settled, its cash VM has been
   * disposed through the netting settlement even though the pre-termination
   * product-service history remains immutable. */
  do terminationId over terminations
    t=terminations[terminationId]
    if t~contractId<>contractId then iterate
    closeoutId=closeoutByTermination[terminationId]
    if closeoutId<>.nil then do
      if settlementByCloseout~hasIndex(closeoutId) then return 0
      if settlementController<>.nil & settlementController~isCloseoutCashSettled(closeoutId) then return 0
    end
  end
  return productService~collateralPosted(contractId)
::method recordHedgeAttribution
  expose productService terminations hedgeAttributions
  use strict arg attributionId,terminationId,hedgePnl,attributedDate,executionEvidenceRef,methodologyEvidenceRef,authorityRef
  if hedgeAttributions~hasIndex(attributionId) then raise syntax 88.900 array("duplicate VMM close-out hedge attribution",attributionId)
  t=terminations[terminationId]; if t==.nil then raise syntax 88.900 array("unknown VMM termination for hedge attribution",terminationId)
  k=productService~contract(t~contractId)
  h=.VMMSyntheticCloseoutHedgeAttribution~new(attributionId,terminationId,t~contractId,k~terms~currency,hedgePnl,attributedDate,executionEvidenceRef,methodologyEvidenceRef,authorityRef)
  hedgeAttributions[attributionId]=h
  productService~vmm~journal~put("synthetic:closeoutHedge:"||attributionId,h,"VMM_SYNTHETIC_CLOSEOUT_HEDGE_ATTRIBUTED",self~meta("contract",t~contractId))
  return h
::method hedgeAttribution
  expose hedgeAttributions
  use strict arg attributionId
  return hedgeAttributions[attributionId]
::method meta private
  use strict arg key,value
  m=.directory~new; m[key]=value; return m

::requires "VMMSyntheticProducts.cls"
