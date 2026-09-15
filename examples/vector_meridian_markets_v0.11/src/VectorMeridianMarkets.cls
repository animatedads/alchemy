/* Vector Meridian Markets Ltd v0.7 */

::class VMMTradableInstrument public
::method init
  expose instrumentRef economicUnderlyingId isin venueMic representationType quoteCurrency settlementCurrency denominationCurrency resolutionEvidenceRef
  use strict arg instrumentRef,economicUnderlyingId,isin,venueMic,representationType,quoteCurrency,settlementCurrency,denominationCurrency="",resolutionEvidenceRef=""
  if instrumentRef="" | economicUnderlyingId="" | isin="" | venueMic="" | representationType="" | quoteCurrency="" | settlementCurrency="" | resolutionEvidenceRef="" then raise syntax 88.900 array("invalid VMM tradable instrument identity")
  if denominationCurrency="" then denominationCurrency=quoteCurrency
::method instrumentRef; expose instrumentRef; return instrumentRef
::method economicUnderlyingId; expose economicUnderlyingId; return economicUnderlyingId
::method isin; expose isin; return isin
::method venueMic; expose venueMic; return venueMic
::method representationType; expose representationType; return representationType
::method quoteCurrency; expose quoteCurrency; return quoteCurrency
::method settlementCurrency; expose settlementCurrency; return settlementCurrency
::method denominationCurrency; expose denominationCurrency; return denominationCurrency
::method resolutionEvidenceRef; expose resolutionEvidenceRef; return resolutionEvidenceRef
::method identityKey
  expose isin venueMic denominationCurrency quoteCurrency settlementCurrency
  return isin||"|"||venueMic||"|"||denominationCurrency||"|"||quoteCurrency||"|"||settlementCurrency
::method sameTradableLine
  expose isin venueMic denominationCurrency quoteCurrency settlementCurrency
  use strict arg other
  if \other~isA(.VMMTradableInstrument) then return .false
  return isin=other~isin & venueMic=other~venueMic & denominationCurrency=other~denominationCurrency & quoteCurrency=other~quoteCurrency & settlementCurrency=other~settlementCurrency


::class VMMFlowRequest public
::method init
  expose requestId instrumentRef productType customerSide currency notional anonRelationshipRef sourceAuthority requestedAt customerEntity instrumentIdentity instrumentKey
  use strict arg requestId,instrumentRef,productType,customerSide,currency,notional,anonRelationshipRef,sourceAuthority,requestedAt,customerEntity="",instrumentIdentity=.nil
  if requestId="" | instrumentRef="" | productType="" | currency="" | anonRelationshipRef="" | sourceAuthority="" | requestedAt="" then raise syntax 88.900 array("invalid VMM flow request")
  if customerSide<>"LONG" & customerSide<>"SHORT" then raise syntax 88.900 array("invalid customer side",customerSide)
  if notional<=0 then raise syntax 88.900 array("invalid VMM notional",notional)
  if customerEntity<>"" then raise syntax 88.900 array("VMM flow must not contain customer legal identity")
  if instrumentIdentity<>.nil then do
    if \instrumentIdentity~isA(.VMMTradableInstrument) then raise syntax 88.900 array("VMMTradableInstrument required")
    if instrumentIdentity~instrumentRef<>instrumentRef then raise syntax 88.900 array("VMM flow instrument reference/identity mismatch")
    if instrumentIdentity~quoteCurrency<>currency then raise syntax 88.900 array("VMM flow quote currency/identity mismatch")
    instrumentKey=instrumentIdentity~identityKey
  end
  else instrumentKey=instrumentRef
::method requestId; expose requestId; return requestId
::method instrumentRef; expose instrumentRef; return instrumentRef
::method productType; expose productType; return productType
::method customerSide; expose customerSide; return customerSide
::method currency; expose currency; return currency
::method notional; expose notional; return notional
::method anonRelationshipRef; expose anonRelationshipRef; return anonRelationshipRef
::method sourceAuthority; expose sourceAuthority; return sourceAuthority
::method requestedAt; expose requestedAt; return requestedAt
::method customerEntity; expose customerEntity; return customerEntity
::method instrumentIdentity; expose instrumentIdentity; return instrumentIdentity
::method instrumentKey; expose instrumentKey; return instrumentKey
::method principalSide
  expose customerSide
  if customerSide="LONG" then return "SHORT"
  return "LONG"


::class VMMAlgorithmStrategy public
::method init
  expose strategyId strategyVersion family sourceEvidenceRef modelEvidenceRef perTradeLimit inventoryLimit policyRef state
  use strict arg strategyId,strategyVersion,family,sourceEvidenceRef,modelEvidenceRef,perTradeLimit,inventoryLimit,policyRef
  if strategyId="" | strategyVersion="" | family="" | sourceEvidenceRef="" | policyRef="" then raise syntax 88.900 array("invalid VMM strategy identity")
  if perTradeLimit<=0 | inventoryLimit<=0 then raise syntax 88.900 array("invalid VMM strategy limits")
  state="REGISTERED"
::method strategyId; expose strategyId; return strategyId
::method strategyVersion; expose strategyVersion; return strategyVersion
::method family; expose family; return family
::method sourceEvidenceRef; expose sourceEvidenceRef; return sourceEvidenceRef
::method modelEvidenceRef; expose modelEvidenceRef; return modelEvidenceRef
::method perTradeLimit; expose perTradeLimit; return perTradeLimit
::method inventoryLimit; expose inventoryLimit; return inventoryLimit
::method policyRef; expose policyRef; return policyRef
::method state; expose state; return state
::method enabled; expose state; return state="ENABLED"
::method enable
  expose state
  if state="RETIRED" then raise syntax 88.900 array("retired VMM strategy cannot be enabled")
  state="ENABLED"
  return self
::method disable
  expose state
  if state<>"RETIRED" then state="DISABLED"
  return self
::method retire
  expose state
  state="RETIRED"
  return self


::class VMMAlgorithmDecision public
::method init
  expose decisionId strategyId instrumentIdentity action notional decisionAt marketDataEvidenceRef signalEvidenceRef decisionAuthority
  use strict arg decisionId,strategyId,instrumentIdentity,action,notional,decisionAt,marketDataEvidenceRef,signalEvidenceRef,decisionAuthority
  if decisionId="" | strategyId="" | decisionAt="" | marketDataEvidenceRef="" | signalEvidenceRef="" | decisionAuthority="" then raise syntax 88.900 array("invalid VMM algorithm decision")
  if \instrumentIdentity~isA(.VMMTradableInstrument) then raise syntax 88.900 array("VMM algorithm decision requires tradable instrument identity")
  if action<>"BUY" & action<>"SELL" & action<>"HOLD" then raise syntax 88.900 array("invalid VMM algorithm action",action)
  if action="HOLD" then do
    if notional<>0 then raise syntax 88.900 array("VMM HOLD decision must have zero notional")
  end
  else if notional<=0 then raise syntax 88.900 array("VMM algorithm decision requires positive notional")
::method decisionId; expose decisionId; return decisionId
::method strategyId; expose strategyId; return strategyId
::method instrumentIdentity; expose instrumentIdentity; return instrumentIdentity
::method action; expose action; return action
::method notional; expose notional; return notional
::method decisionAt; expose decisionAt; return decisionAt
::method marketDataEvidenceRef; expose marketDataEvidenceRef; return marketDataEvidenceRef
::method signalEvidenceRef; expose signalEvidenceRef; return signalEvidenceRef
::method decisionAuthority; expose decisionAuthority; return decisionAuthority
::method side
  expose action
  if action="BUY" then return "LONG"
  if action="SELL" then return "SHORT"
  return "HOLD"


::class VMMQuote public
::method init
  expose quoteId requestId strategyId instrumentRef customerSide principalSide currency notional bid ask referencePrice spreadBps validUntil state instrumentIdentity instrumentKey
  use strict arg quoteId,requestId,strategyId,instrumentRef,customerSide,principalSide,currency,notional,bid,ask,referencePrice,spreadBps,validUntil,instrumentIdentity=.nil
  if quoteId="" | requestId="" | strategyId="" | instrumentRef="" | currency="" | validUntil="" then raise syntax 88.900 array("invalid VMM quote")
  if bid<=0 | ask<=0 | ask<bid then raise syntax 88.900 array("invalid VMM quote prices")
  if instrumentIdentity<>.nil then do
    if \instrumentIdentity~isA(.VMMTradableInstrument) then raise syntax 88.900 array("VMMTradableInstrument required")
    instrumentKey=instrumentIdentity~identityKey
  end
  else instrumentKey=instrumentRef
  state="OPEN"
::method quoteId; expose quoteId; return quoteId
::method requestId; expose requestId; return requestId
::method strategyId; expose strategyId; return strategyId
::method instrumentRef; expose instrumentRef; return instrumentRef
::method customerSide; expose customerSide; return customerSide
::method principalSide; expose principalSide; return principalSide
::method currency; expose currency; return currency
::method notional; expose notional; return notional
::method bid; expose bid; return bid
::method ask; expose ask; return ask
::method referencePrice; expose referencePrice; return referencePrice
::method spreadBps; expose spreadBps; return spreadBps
::method validUntil; expose validUntil; return validUntil
::method state; expose state; return state
::method instrumentIdentity; expose instrumentIdentity; return instrumentIdentity
::method instrumentKey; expose instrumentKey; return instrumentKey
::method executionPrice
  expose customerSide bid ask
  if customerSide="LONG" then return ask
  return bid
::method markExecuted
  expose state
  if state<>"OPEN" then raise syntax 88.900 array("VMM quote not open")
  state="EXECUTED"
  return self
::method cancel
  expose state
  if state="OPEN" then state="CANCELLED"
  return self


::class VMMPrincipalTrade public
::method init
  expose tradeId quoteId requestId strategyId instrumentRef principalSide currency notional price executedAt anonRelationshipRef executionAuthority counterpartyChannel instrumentIdentity instrumentKey
  use strict arg tradeId,quoteId,requestId,strategyId,instrumentRef,principalSide,currency,notional,price,executedAt,anonRelationshipRef,executionAuthority,counterpartyChannel="FEDERATIONBANK_MERCHANT_FLOW",instrumentIdentity=.nil
  if tradeId="" | quoteId="" | requestId="" | strategyId="" | instrumentRef="" | currency="" | executedAt="" | anonRelationshipRef="" | executionAuthority="" then raise syntax 88.900 array("invalid VMM principal trade")
  if principalSide<>"LONG" & principalSide<>"SHORT" then raise syntax 88.900 array("invalid VMM principal side")
  if notional<=0 | price<=0 then raise syntax 88.900 array("invalid VMM trade economics")
  if instrumentIdentity<>.nil then do
    if \instrumentIdentity~isA(.VMMTradableInstrument) then raise syntax 88.900 array("VMMTradableInstrument required")
    instrumentKey=instrumentIdentity~identityKey
  end
  else instrumentKey=instrumentRef
::method tradeId; expose tradeId; return tradeId
::method quoteId; expose quoteId; return quoteId
::method requestId; expose requestId; return requestId
::method strategyId; expose strategyId; return strategyId
::method instrumentRef; expose instrumentRef; return instrumentRef
::method principalSide; expose principalSide; return principalSide
::method currency; expose currency; return currency
::method notional; expose notional; return notional
::method price; expose price; return price
::method executedAt; expose executedAt; return executedAt
::method anonRelationshipRef; expose anonRelationshipRef; return anonRelationshipRef
::method executionAuthority; expose executionAuthority; return executionAuthority
::method counterpartyChannel; expose counterpartyChannel; return counterpartyChannel
::method instrumentIdentity; expose instrumentIdentity; return instrumentIdentity
::method instrumentKey; expose instrumentKey; return instrumentKey


::class VMMFundingFacility public
::method init
  expose facilityId lenderEntity borrowerEntity sourceClass currency commitment interestRateBps legalEffectRef policyRef maturity outstanding state
  use strict arg facilityId,lenderEntity,borrowerEntity,sourceClass,currency,commitment,interestRateBps,legalEffectRef,policyRef,maturity
  if facilityId="" | lenderEntity="" | borrowerEntity="" | sourceClass="" | currency="" | legalEffectRef="" | policyRef="" | maturity="" then raise syntax 88.900 array("invalid VMM funding facility")
  if borrowerEntity<>"VECTOR_MERIDIAN_MARKETS_LTD" then raise syntax 88.900 array("facility borrower is not VMM",borrowerEntity)
  if sourceClass<>"CORE_TREASURY_CAPITAL" & sourceClass<>"MERCHANT_CAPITAL" & sourceClass<>"EXTERNAL_WHOLESALE" then raise syntax 88.900 array("prohibited VMM funding source class",sourceClass)
  if commitment<=0 | interestRateBps<0 then raise syntax 88.900 array("invalid VMM funding economics")
  outstanding=0
  state="ACTIVE"
::method facilityId; expose facilityId; return facilityId
::method lenderEntity; expose lenderEntity; return lenderEntity
::method borrowerEntity; expose borrowerEntity; return borrowerEntity
::method sourceClass; expose sourceClass; return sourceClass
::method currency; expose currency; return currency
::method commitment; expose commitment; return commitment
::method interestRateBps; expose interestRateBps; return interestRateBps
::method legalEffectRef; expose legalEffectRef; return legalEffectRef
::method policyRef; expose policyRef; return policyRef
::method maturity; expose maturity; return maturity
::method outstanding; expose outstanding; return outstanding
::method available
  expose commitment outstanding
  return commitment-outstanding
::method state; expose state; return state
::method draw
  expose outstanding commitment state
  use strict arg amount
  if state<>"ACTIVE" then raise syntax 88.900 array("VMM funding facility not active")
  if amount<=0 | outstanding+amount>commitment then raise syntax 88.900 array("VMM funding draw exceeds facility",amount,commitment-outstanding)
  outstanding=outstanding+amount
  return outstanding
::method repay
  expose outstanding
  use strict arg amount
  if amount<=0 | amount>outstanding then raise syntax 88.900 array("invalid VMM funding repayment",amount,outstanding)
  outstanding=outstanding-amount
  return outstanding
::method suspend
  expose state
  state="SUSPENDED"
  return self


::class VMMFundingDraw public
::method init
  expose drawId facilityId amount currency drawnAt lenderAuthority loanObligationRef state
  use strict arg drawId,facilityId,amount,currency,drawnAt,lenderAuthority,loanObligationRef
  if drawId="" | facilityId="" | currency="" | drawnAt="" | lenderAuthority="" | loanObligationRef="" | amount<=0 then raise syntax 88.900 array("invalid VMM funding draw")
  state="OUTSTANDING"
::method drawId; expose drawId; return drawId
::method facilityId; expose facilityId; return facilityId
::method amount; expose amount; return amount
::method currency; expose currency; return currency
::method drawnAt; expose drawnAt; return drawnAt
::method lenderAuthority; expose lenderAuthority; return lenderAuthority
::method loanObligationRef; expose loanObligationRef; return loanObligationRef
::method state; expose state; return state
::method markRepaid; expose state; state="REPAID"; return self


::class VMMSurveillanceEvidence public
::method init
  expose evidenceId observationType sourceAuthority sourceRef observedAt severity details
  use strict arg evidenceId,observationType,sourceAuthority,sourceRef,observedAt,severity="INFO",details=""
  if evidenceId="" | observationType="" | sourceAuthority="" | sourceRef="" | observedAt="" then raise syntax 88.900 array("invalid VMM surveillance evidence")
::method evidenceId; expose evidenceId; return evidenceId
::method observationType; expose observationType; return observationType
::method sourceAuthority; expose sourceAuthority; return sourceAuthority
::method sourceRef; expose sourceRef; return sourceRef
::method observedAt; expose observedAt; return observedAt
::method severity; expose severity; return severity
::method details; expose details; return details


::class VMMFundingAccrual public
::method init
  expose accrualId facilityId currency principal interestRateBps days amount accruedAt authorityRef
  use strict arg accrualId,facilityId,currency,principal,interestRateBps,days,amount,accruedAt,authorityRef
  if accrualId="" | facilityId="" | currency="" | accruedAt="" | authorityRef="" then raise syntax 88.900 array("invalid VMM funding accrual")
  if principal<0 | interestRateBps<0 | days<=0 | amount<0 then raise syntax 88.900 array("invalid VMM funding accrual economics")
::method accrualId; expose accrualId; return accrualId
::method facilityId; expose facilityId; return facilityId
::method currency; expose currency; return currency
::method principal; expose principal; return principal
::method interestRateBps; expose interestRateBps; return interestRateBps
::method days; expose days; return days
::method amount; expose amount; return amount
::method accruedAt; expose accruedAt; return accruedAt
::method authorityRef; expose authorityRef; return authorityRef


::class VMMFundingRepayment public
::method init
  expose repaymentId facilityId currency amount repaidAt authorityRef loanObligationRef
  use strict arg repaymentId,facilityId,currency,amount,repaidAt,authorityRef,loanObligationRef
  if repaymentId="" | facilityId="" | currency="" | repaidAt="" | authorityRef="" | loanObligationRef="" | amount<=0 then raise syntax 88.900 array("invalid VMM funding repayment")
::method repaymentId; expose repaymentId; return repaymentId
::method facilityId; expose facilityId; return facilityId
::method currency; expose currency; return currency
::method amount; expose amount; return amount
::method repaidAt; expose repaidAt; return repaidAt
::method authorityRef; expose authorityRef; return authorityRef
::method loanObligationRef; expose loanObligationRef; return loanObligationRef


::class VMMMarketOrder public
::method init
  expose orderId strategyId instrumentIdentity side notional orderType limitPrice origin parentTradeId decisionId createdAt executionAuthority state filledNotional averagePrice executionState executionCorrelationId executionCommandId venueOrderRef lastExecutionEventId executionFeeTotal executionRebateTotal
  use strict arg orderId,strategyId,instrumentIdentity,side,notional,orderType,limitPrice,origin,parentTradeId,decisionId,createdAt,executionAuthority
  if orderId="" | strategyId="" | createdAt="" | executionAuthority="" then raise syntax 88.900 array("invalid VMM market order")
  if \instrumentIdentity~isA(.VMMTradableInstrument) then raise syntax 88.900 array("VMM market order requires tradable instrument identity")
  if side<>"LONG" & side<>"SHORT" then raise syntax 88.900 array("invalid VMM market order side",side)
  if notional<=0 then raise syntax 88.900 array("invalid VMM market order notional")
  if orderType<>"MARKET" & orderType<>"LIMIT" then raise syntax 88.900 array("invalid VMM market order type",orderType)
  if orderType="LIMIT" & limitPrice<=0 then raise syntax 88.900 array("VMM limit order requires positive price")
  if orderType="MARKET" & limitPrice<0 then raise syntax 88.900 array("invalid VMM market order price")
  if origin="INVENTORY_HEDGE" then do
    if parentTradeId="" | decisionId<>"" then raise syntax 88.900 array("inventory hedge requires parent trade and no proprietary decision")
  end
  else if origin="PROPRIETARY_SIGNAL" then do
    if decisionId="" | parentTradeId<>"" then raise syntax 88.900 array("proprietary order requires decision and no customer-flow parent")
  end
  else if origin="SYNTHETIC_HEDGE" then do
    if parentTradeId="" | decisionId<>"" then raise syntax 88.900 array("synthetic hedge requires parent contract reference and no proprietary decision")
  end
  else raise syntax 88.900 array("invalid VMM market order origin",origin)
  state="OPEN"; filledNotional=0; averagePrice=0; executionFeeTotal=0; executionRebateTotal=0
  executionState="CREATED"; executionCorrelationId=""; executionCommandId=""; venueOrderRef=""; lastExecutionEventId=""
::method orderId; expose orderId; return orderId
::method strategyId; expose strategyId; return strategyId
::method instrumentIdentity; expose instrumentIdentity; return instrumentIdentity
::method side; expose side; return side
::method notional; expose notional; return notional
::method orderType; expose orderType; return orderType
::method limitPrice; expose limitPrice; return limitPrice
::method origin; expose origin; return origin
::method parentTradeId; expose parentTradeId; return parentTradeId
::method parentExposureRef; expose parentTradeId; return parentTradeId
::method decisionId; expose decisionId; return decisionId
::method createdAt; expose createdAt; return createdAt
::method executionAuthority; expose executionAuthority; return executionAuthority
::method state; expose state; return state
::method filledNotional; expose filledNotional; return filledNotional
::method remainingNotional; expose notional filledNotional; return notional-filledNotional
::method averagePrice; expose averagePrice; return averagePrice
::method executionState; expose executionState; return executionState
::method executionCorrelationId; expose executionCorrelationId; return executionCorrelationId
::method executionCommandId; expose executionCommandId; return executionCommandId
::method venueOrderRef; expose venueOrderRef; return venueOrderRef
::method lastExecutionEventId; expose lastExecutionEventId; return lastExecutionEventId
::method executionFeeTotal; expose executionFeeTotal; return executionFeeTotal
::method executionRebateTotal; expose executionRebateTotal; return executionRebateTotal
::method netExecutionCost; expose executionFeeTotal executionRebateTotal; return executionFeeTotal-executionRebateTotal
::method recordExecutionCost
  expose executionFeeTotal executionRebateTotal
  use strict arg feeAmount,rebateAmount
  if feeAmount<0 | rebateAmount<0 then raise syntax 88.900 array("invalid VMM execution fee/rebate")
  executionFeeTotal=executionFeeTotal+feeAmount; executionRebateTotal=executionRebateTotal+rebateAmount
  return self
::method markRiskAccepted
  expose executionState executionCorrelationId executionCommandId
  use strict arg correlationId,commandId
  if correlationId="" | commandId="" then raise syntax 88.900 array("VMM execution correlation/command required")
  if executionState<>"CREATED" & executionState<>"RISK_ACCEPTED" then raise syntax 88.900 array("VMM order not risk-acceptable",executionState)
  executionCorrelationId=correlationId; executionCommandId=commandId; executionState="RISK_ACCEPTED"
  return self
::method markRouted
  expose executionState executionCorrelationId executionCommandId
  use strict arg correlationId,commandId
  if executionState<>"RISK_ACCEPTED" & executionState<>"ROUTED" then raise syntax 88.900 array("VMM order not routable",executionState)
  if executionCorrelationId<>correlationId | executionCommandId<>commandId then raise syntax 88.900 array("VMM route correlation/command mismatch")
  executionState="ROUTED"
  return self
::method markExecutionAcknowledged
  expose executionState venueOrderRef lastExecutionEventId
  use strict arg newVenueOrderRef,eventId
  if newVenueOrderRef="" | eventId="" then raise syntax 88.900 array("VMM execution acknowledgement identity required")
  if executionState<>"ROUTED" & executionState<>"UNKNOWN_PENDING_RECONCILIATION" & executionState<>"ACKNOWLEDGED" then raise syntax 88.900 array("VMM order cannot acknowledge",executionState)
  venueOrderRef=newVenueOrderRef; lastExecutionEventId=eventId; executionState="ACKNOWLEDGED"
  return self
::method markExecutionUnknown
  expose executionState lastExecutionEventId
  use strict arg eventId
  if eventId="" then raise syntax 88.900 array("VMM unknown execution event identity required")
  if executionState="FILLED" | executionState="REJECTED" | executionState="CANCELLED" then return self
  lastExecutionEventId=eventId; executionState="UNKNOWN_PENDING_RECONCILIATION"
  return self
::method markExecutionRejected
  expose state executionState lastExecutionEventId
  use strict arg eventId
  if eventId="" then raise syntax 88.900 array("VMM rejection event identity required")
  if executionState="FILLED" then raise syntax 88.900 array("filled VMM order cannot be rejected")
  lastExecutionEventId=eventId; executionState="REJECTED"; state="CANCELLED"
  return self
::method markCancelPending
  expose state executionState
  if state="FILLED" | executionState="REJECTED" | executionState="CANCELLED" then return self
  if executionState="CREATED" | executionState="RISK_ACCEPTED" then do
    state="CANCELLED"; executionState="CANCELLED"; return self
  end
  executionState="CANCEL_PENDING"
  return self
::method markExecutionCancelled
  expose state executionState lastExecutionEventId
  use strict arg eventId
  if eventId="" then raise syntax 88.900 array("VMM cancellation event identity required")
  if state="FILLED" then return self
  lastExecutionEventId=eventId; state="CANCELLED"; executionState="CANCELLED"
  return self
::method recordFill
  expose state notional filledNotional averagePrice executionState
  use strict arg fillNotional,fillPrice
  if state<>"OPEN" & state<>"PARTIALLY_FILLED" then raise syntax 88.900 array("VMM market order not fillable",state)
  if fillNotional<=0 | fillPrice<=0 | filledNotional+fillNotional>notional then raise syntax 88.900 array("invalid VMM market fill")
  old=filledNotional
  averagePrice=((averagePrice*old)+(fillPrice*fillNotional))/(old+fillNotional)
  filledNotional=old+fillNotional
  if filledNotional=notional then do
    state="FILLED"; executionState="FILLED"
  end
  else do
    state="PARTIALLY_FILLED"; executionState="PART_FILLED"
  end
  return self
::method cancel
  return self~markCancelPending


::class VMMExecutionFill public
::method init
  expose fillId orderId venueExecutionRef instrumentKey side notional price currency executedAt executingCounterparty settlementRef routeId feeAmount rebateAmount
  use strict arg fillId,orderId,venueExecutionRef,instrumentKey,side,notional,price,currency,executedAt,executingCounterparty,settlementRef="",routeId="",feeAmount=0,rebateAmount=0
  if fillId="" | orderId="" | venueExecutionRef="" | instrumentKey="" | currency="" | executedAt="" | executingCounterparty="" then raise syntax 88.900 array("invalid VMM execution fill")
  if side<>"LONG" & side<>"SHORT" | notional<=0 | price<=0 | feeAmount<0 | rebateAmount<0 then raise syntax 88.900 array("invalid VMM execution fill economics")
::method fillId; expose fillId; return fillId
::method orderId; expose orderId; return orderId
::method venueExecutionRef; expose venueExecutionRef; return venueExecutionRef
::method instrumentKey; expose instrumentKey; return instrumentKey
::method side; expose side; return side
::method notional; expose notional; return notional
::method price; expose price; return price
::method currency; expose currency; return currency
::method executedAt; expose executedAt; return executedAt
::method executingCounterparty; expose executingCounterparty; return executingCounterparty
::method settlementRef; expose settlementRef; return settlementRef
::method routeId; expose routeId; return routeId
::method feeAmount; expose feeAmount; return feeAmount
::method rebateAmount; expose rebateAmount; return rebateAmount
::method netExecutionCost; expose feeAmount rebateAmount; return feeAmount-rebateAmount


::class VMMMarketMark public
::method init
  expose markId instrumentIdentity price observedAt sourceAuthority sourceRef status
  use strict arg markId,instrumentIdentity,price,observedAt,sourceAuthority,sourceRef,status="CURRENT"
  if markId="" | observedAt="" | sourceAuthority="" | sourceRef="" then raise syntax 88.900 array("invalid VMM market mark")
  if \instrumentIdentity~isA(.VMMTradableInstrument) | price<=0 then raise syntax 88.900 array("invalid VMM market mark instrument/price")
  if status<>"CURRENT" & status<>"INDICATIVE" & status<>"STALE" & status<>"RESTRICTED" & status<>"UNPRICEABLE" then raise syntax 88.900 array("invalid VMM market mark status")
::method markId; expose markId; return markId
::method instrumentIdentity; expose instrumentIdentity; return instrumentIdentity
::method price; expose price; return price
::method observedAt; expose observedAt; return observedAt
::method sourceAuthority; expose sourceAuthority; return sourceAuthority
::method sourceRef; expose sourceRef; return sourceRef
::method status; expose status; return status


::class VMMShortLocate public
::method init
  expose locateId instrumentKey lenderEntity availableNotional reservedNotional consumedNotional feeBps expiresAt evidenceRef authorityRef state
  use strict arg locateId,instrumentKey,lenderEntity,availableNotional,feeBps,expiresAt,evidenceRef,authorityRef
  if locateId="" | instrumentKey="" | lenderEntity="" | expiresAt="" | evidenceRef="" | authorityRef="" then raise syntax 88.900 array("invalid VMM short locate identity")
  if availableNotional<=0 | feeBps<0 then raise syntax 88.900 array("invalid VMM short locate economics")
  reservedNotional=0; consumedNotional=0; state="ACTIVE"
::method locateId; expose locateId; return locateId
::method instrumentKey; expose instrumentKey; return instrumentKey
::method lenderEntity; expose lenderEntity; return lenderEntity
::method availableNotional; expose availableNotional; return availableNotional
::method reservedNotional; expose reservedNotional; return reservedNotional
::method consumedNotional; expose consumedNotional; return consumedNotional
::method remainingCapacity; expose availableNotional reservedNotional consumedNotional; return availableNotional-reservedNotional-consumedNotional
::method feeBps; expose feeBps; return feeBps
::method expiresAt; expose expiresAt; return expiresAt
::method evidenceRef; expose evidenceRef; return evidenceRef
::method authorityRef; expose authorityRef; return authorityRef
::method state; expose state; return state
::method reserve
  expose state reservedNotional
  use strict arg amount
  if state<>"ACTIVE" | amount<=0 | amount>self~remainingCapacity then raise syntax 88.900 array("VMM short locate capacity unavailable",amount,self~remainingCapacity)
  reservedNotional=reservedNotional+amount
  return self
::method consume
  expose reservedNotional consumedNotional
  use strict arg amount
  if amount<0 | amount>reservedNotional then raise syntax 88.900 array("VMM short locate consumption exceeds reservation")
  reservedNotional=reservedNotional-amount; consumedNotional=consumedNotional+amount
  return self
::method release
  expose reservedNotional
  use strict arg amount
  if amount<0 | amount>reservedNotional then raise syntax 88.900 array("VMM short locate release exceeds reservation")
  reservedNotional=reservedNotional-amount
  return self
::method close; expose state; state="CLOSED"; return self


::class VMMShortLocateReservation public
::method init
  expose reservationId locateId orderId reservedNotional consumedNotional createdAt authorityRef state
  use strict arg reservationId,locateId,orderId,reservedNotional,createdAt,authorityRef
  if reservationId="" | locateId="" | orderId="" | createdAt="" | authorityRef="" | reservedNotional<=0 then raise syntax 88.900 array("invalid VMM short locate reservation")
  consumedNotional=0; state="RESERVED"
::method reservationId; expose reservationId; return reservationId
::method locateId; expose locateId; return locateId
::method orderId; expose orderId; return orderId
::method reservedNotional; expose reservedNotional; return reservedNotional
::method consumedNotional; expose consumedNotional; return consumedNotional
::method remainingNotional; expose reservedNotional consumedNotional; return reservedNotional-consumedNotional
::method state; expose state; return state
::method consume
  expose consumedNotional state
  use strict arg amount
  if amount<0 | amount>self~remainingNotional then raise syntax 88.900 array("VMM short locate reservation exhausted")
  consumedNotional=consumedNotional+amount
  if self~remainingNotional=0 then state="CONSUMED"
  return self
::method release
  expose state
  state="RELEASED"; return self


::class VMMMarketRestriction public
::method init
  expose restrictionId instrumentKey venueMic effect reasonCode effectiveAt evidenceRef authorityRef status jurisdiction
  use strict arg restrictionId,instrumentKey,venueMic,effect,reasonCode,effectiveAt,evidenceRef,authorityRef,jurisdiction=""
  if restrictionId="" | effect="" | reasonCode="" | effectiveAt="" | evidenceRef="" | authorityRef="" then raise syntax 88.900 array("invalid VMM market restriction")
  if instrumentKey="" & venueMic="" then raise syntax 88.900 array("VMM market restriction requires instrument or venue scope")
  if effect<>"BLOCK_NEW" & effect<>"CLOSE_ONLY" & effect<>"SETTLEMENT_IMPAIRED" & effect<>"PRICE_UNRELIABLE" then raise syntax 88.900 array("invalid VMM market restriction effect",effect)
  status="ACTIVE"
::method restrictionId; expose restrictionId; return restrictionId
::method instrumentKey; expose instrumentKey; return instrumentKey
::method venueMic; expose venueMic; return venueMic
::method effect; expose effect; return effect
::method reasonCode; expose reasonCode; return reasonCode
::method effectiveAt; expose effectiveAt; return effectiveAt
::method evidenceRef; expose evidenceRef; return evidenceRef
::method authorityRef; expose authorityRef; return authorityRef
::method status; expose status; return status
::method jurisdiction; expose jurisdiction; return jurisdiction
::method lift; expose status; status="LIFTED"; return self


::class VMMMarketStructureLink public
::method init
  expose linkId leftInstrumentKey rightInstrumentKey relation status evidenceRef authorityRef reasonCode changedAt
  use strict arg linkId,leftInstrumentKey,rightInstrumentKey,relation,evidenceRef,authorityRef
  if linkId="" | leftInstrumentKey="" | rightInstrumentKey="" | evidenceRef="" | authorityRef="" then raise syntax 88.900 array("invalid VMM market-structure link")
  if leftInstrumentKey=rightInstrumentKey then raise syntax 88.900 array("VMM market-structure link requires distinct tradable lines")
  if relation<>"FUNGIBLE" & relation<>"HEDGE_EQUIVALENT" then raise syntax 88.900 array("invalid VMM market-structure relation",relation)
  status="ACTIVE"; reasonCode=""; changedAt=""
::method linkId; expose linkId; return linkId
::method leftInstrumentKey; expose leftInstrumentKey; return leftInstrumentKey
::method rightInstrumentKey; expose rightInstrumentKey; return rightInstrumentKey
::method relation; expose relation; return relation
::method status; expose status; return status
::method evidenceRef; expose evidenceRef; return evidenceRef
::method authorityRef; expose authorityRef; return authorityRef
::method reasonCode; expose reasonCode; return reasonCode
::method changedAt; expose changedAt; return changedAt
::method active; expose status; return status="ACTIVE"
::method impair
  expose status reasonCode evidenceRef authorityRef changedAt
  use strict arg newStatus,newReasonCode,newEvidenceRef,newAuthorityRef,at
  if newStatus<>"IMPAIRED" & newStatus<>"BROKEN" & newStatus<>"SUSPENDED" & newStatus<>"ACTIVE" then raise syntax 88.900 array("invalid VMM market-structure status",newStatus)
  if newReasonCode="" | newEvidenceRef="" | newAuthorityRef="" | at="" then raise syntax 88.900 array("VMM market-structure change requires evidence")
  status=newStatus; reasonCode=newReasonCode; evidenceRef=newEvidenceRef; authorityRef=newAuthorityRef; changedAt=at
  return self


::class VMMCapitalPolicy public
::method init
  expose policyId currency capitalBase maxLeverage policyRef
  use strict arg policyId,currency,capitalBase,maxLeverage,policyRef
  if policyId="" | currency="" | policyRef="" | capitalBase<=0 | maxLeverage<=0 then raise syntax 88.900 array("invalid VMM capital policy")
::method policyId; expose policyId; return policyId
::method currency; expose currency; return currency
::method capitalBase; expose capitalBase; return capitalBase
::method maxLeverage; expose maxLeverage; return maxLeverage
::method maxGrossExposure; expose capitalBase maxLeverage; return capitalBase*maxLeverage
::method policyRef; expose policyRef; return policyRef


::class VMMCapitalSnapshot public
::method init
  expose snapshotId currency capitalBase grossExposure leverage maxLeverage breachCode evaluatedAt authorityRef
  use strict arg snapshotId,currency,capitalBase,grossExposure,leverage,maxLeverage,breachCode,evaluatedAt,authorityRef
  if snapshotId="" | currency="" | breachCode="" | evaluatedAt="" | authorityRef="" then raise syntax 88.900 array("invalid VMM capital snapshot")
::method snapshotId; expose snapshotId; return snapshotId
::method currency; expose currency; return currency
::method capitalBase; expose capitalBase; return capitalBase
::method grossExposure; expose grossExposure; return grossExposure
::method leverage; expose leverage; return leverage
::method maxLeverage; expose maxLeverage; return maxLeverage
::method breachCode; expose breachCode; return breachCode
::method breached; expose breachCode; return breachCode<>"NONE"
::method evaluatedAt; expose evaluatedAt; return evaluatedAt
::method authorityRef; expose authorityRef; return authorityRef


::class VMMFirmRiskLimits public
::method init
  expose limitId currency maxGrossNotional maxSingleInstrumentNotional maxFundingOutstanding maxLoss policyRef
  use strict arg limitId,currency,maxGrossNotional,maxSingleInstrumentNotional,maxFundingOutstanding,maxLoss,policyRef
  if limitId="" | currency="" | policyRef="" then raise syntax 88.900 array("invalid VMM firm risk limits")
  if maxGrossNotional<=0 | maxSingleInstrumentNotional<=0 | maxFundingOutstanding<=0 | maxLoss<=0 then raise syntax 88.900 array("invalid VMM firm risk economics")
::method limitId; expose limitId; return limitId
::method currency; expose currency; return currency
::method maxGrossNotional; expose maxGrossNotional; return maxGrossNotional
::method maxSingleInstrumentNotional; expose maxSingleInstrumentNotional; return maxSingleInstrumentNotional
::method maxFundingOutstanding; expose maxFundingOutstanding; return maxFundingOutstanding
::method maxLoss; expose maxLoss; return maxLoss
::method policyRef; expose policyRef; return policyRef


::class VMMRiskSnapshot public
::method init
  expose snapshotId currency grossNotional netNotional tradingPnl fundingOutstanding fundingExpense netPnl breachCode evaluatedAt authorityRef
  use strict arg snapshotId,currency,grossNotional,netNotional,tradingPnl,fundingOutstanding,fundingExpense,netPnl,breachCode,evaluatedAt,authorityRef
  if snapshotId="" | currency="" | breachCode="" | evaluatedAt="" | authorityRef="" then raise syntax 88.900 array("invalid VMM risk snapshot")
::method snapshotId; expose snapshotId; return snapshotId
::method currency; expose currency; return currency
::method grossNotional; expose grossNotional; return grossNotional
::method netNotional; expose netNotional; return netNotional
::method tradingPnl; expose tradingPnl; return tradingPnl
::method fundingOutstanding; expose fundingOutstanding; return fundingOutstanding
::method fundingExpense; expose fundingExpense; return fundingExpense
::method netPnl; expose netPnl; return netPnl
::method breachCode; expose breachCode; return breachCode
::method breached; expose breachCode; return breachCode<>"NONE"
::method evaluatedAt; expose evaluatedAt; return evaluatedAt
::method authorityRef; expose authorityRef; return authorityRef


::class VectorMeridianMarkets public
::method init
  expose legalEntity strategies flowRequests quotes trades inventory inventoryCurrency instrumentCatalog facilities fundingDraws fundingAccruals fundingRepayments surveillance algorithmDecisions marketOrders fills marks latestMarkByInstrument tradingCash fundingCash fundingExpenses riskLimits riskSnapshots killSwitch killAuthority killReason journal executionService executionBindingAuthority shortLocates shortLocateReservations marketRestrictions marketStructureLinks capitalPolicies capitalSnapshots executionCosts
  use strict arg legalEntity="VECTOR_MERIDIAN_MARKETS_LTD"
  if legalEntity="" then raise syntax 88.900 array("VMM legal entity required")
  if legalEntity="FEDERATIONBANK_CORE" | legalEntity="FEDERATIONBANK_MERCHANT_BANK" then raise syntax 88.900 array("VMM must be a separate legal entity",legalEntity)
  strategies=.directory~new; flowRequests=.directory~new; quotes=.directory~new; trades=.directory~new
  inventory=.directory~new; inventoryCurrency=.directory~new; instrumentCatalog=.directory~new
  facilities=.directory~new; fundingDraws=.directory~new; fundingAccruals=.directory~new; fundingRepayments=.directory~new
  surveillance=.directory~new; algorithmDecisions=.directory~new; marketOrders=.directory~new; fills=.directory~new
  marks=.directory~new; latestMarkByInstrument=.directory~new; tradingCash=.directory~new; fundingCash=.directory~new; fundingExpenses=.directory~new
  riskLimits=.directory~new; riskSnapshots=.directory~new
  shortLocates=.directory~new; shortLocateReservations=.directory~new; marketRestrictions=.directory~new; marketStructureLinks=.directory~new
  capitalPolicies=.directory~new; capitalSnapshots=.directory~new; executionCosts=.directory~new
  killSwitch=.false; killAuthority=""; killReason=""
  executionService=.nil; executionBindingAuthority=""
  initial=.directory~new; initial["legalEntity"]=legalEntity
  journal=.JournalPointedState~new(initial,"VMM-"||legalEntity)
::method legalEntity; expose legalEntity; return legalEntity
::method journal; expose journal; return journal
::method journalPoint; expose journal; return journal~journalPoint
::method killSwitchActive; expose killSwitch; return killSwitch
::method executionServiceBound; expose executionService; return executionService<>.nil

::method bindExecutionService
  expose executionService executionBindingAuthority journal
  use strict arg service,authorityRef
  if service==.nil | authorityRef="" then raise syntax 88.900 array("VMM execution service and binding authority required")
  if \service~hasMethod("submitMarketOrder") | \service~hasMethod("requestCancel") then raise syntax 88.900 array("invalid VMM execution service contract")
  if executionService<>.nil & executionService\==service then raise syntax 88.900 array("VMM execution service already bound")
  executionService=service; executionBindingAuthority=authorityRef
  journal~put("execution:binding",authorityRef,"VMM_QUEUE_EXECUTION_BOUND",self~eventMeta("authority",authorityRef))
  return service

::method routeMarketOrder
  expose marketOrders executionService killSwitch journal
  use strict arg orderId,idempotencyKey,correlationId,submittedAt,authorityRef
  if killSwitch then raise syntax 88.900 array("VMM kill switch active")
  if executionService==.nil then raise syntax 88.900 array("VMM queue execution service not bound")
  o=marketOrders[orderId]; if o==.nil then raise syntax 88.900 array("unknown VMM market order",orderId)
  routeResult=executionService~submitMarketOrder(o,idempotencyKey,correlationId,submittedAt,authorityRef)
  ignore=journal~put("execution:route:"||orderId,routeResult,"VMM_QUEUE_EXECUTION_ROUTE_ATTEMPT",self~eventMeta("order",orderId))
  return routeResult

::method acceptExecutionAcknowledgement
  expose marketOrders executionService journal
  use strict arg orderId,commandId,correlationId,venueOrderRef,eventId,serviceRef
  self~requireExecutionService(serviceRef)
  o=marketOrders[orderId]; if o==.nil then raise syntax 88.900 array("unknown VMM market order",orderId)
  if o~executionCommandId<>commandId | o~executionCorrelationId<>correlationId then raise syntax 88.900 array("VMM execution acknowledgement binding mismatch")
  o~markExecutionAcknowledged(venueOrderRef,eventId)
  journal~put("marketOrder:"||orderId,o,"VMM_EXECUTION_ACKNOWLEDGED",self~eventMeta("event",eventId))
  return o

::method acceptExecutionUnknown
  expose marketOrders journal
  use strict arg orderId,commandId,correlationId,eventId,serviceRef
  self~requireExecutionService(serviceRef)
  o=marketOrders[orderId]; if o==.nil then raise syntax 88.900 array("unknown VMM market order",orderId)
  if o~executionCommandId<>commandId | o~executionCorrelationId<>correlationId then raise syntax 88.900 array("VMM execution unknown binding mismatch")
  o~markExecutionUnknown(eventId)
  journal~put("marketOrder:"||orderId,o,"VMM_EXECUTION_STATUS_UNKNOWN",self~eventMeta("event",eventId))
  return o

::method acceptExecutionRejection
  expose marketOrders journal
  use strict arg orderId,commandId,correlationId,eventId,serviceRef
  self~requireExecutionService(serviceRef)
  o=marketOrders[orderId]; if o==.nil then raise syntax 88.900 array("unknown VMM market order",orderId)
  if o~executionCommandId<>commandId | o~executionCorrelationId<>correlationId then raise syntax 88.900 array("VMM execution rejection binding mismatch")
  o~markExecutionRejected(eventId)
  self~releaseShortLocateReservation(orderId)
  journal~put("marketOrder:"||orderId,o,"VMM_EXECUTION_REJECTED",self~eventMeta("event",eventId))
  return o

::method acceptExecutionCancellation
  expose marketOrders journal
  use strict arg orderId,commandId,correlationId,eventId,serviceRef
  self~requireExecutionService(serviceRef)
  o=marketOrders[orderId]; if o==.nil then raise syntax 88.900 array("unknown VMM market order",orderId)
  if o~executionCorrelationId<>correlationId then raise syntax 88.900 array("VMM execution cancellation binding mismatch")
  o~markExecutionCancelled(eventId)
  self~releaseShortLocateReservation(orderId)
  journal~put("marketOrder:"||orderId,o,"VMM_EXECUTION_CANCELLED",self~eventMeta("event",eventId))
  return o

::method registerStrategy
  expose strategies journal
  use strict arg strategy
  if \strategy~isA(.VMMAlgorithmStrategy) then raise syntax 88.900 array("VMMAlgorithmStrategy required")
  if strategies~hasIndex(strategy~strategyId) then raise syntax 88.900 array("duplicate VMM strategy",strategy~strategyId)
  strategies[strategy~strategyId]=strategy
  journal~put("strategy:"||strategy~strategyId,strategy,"VMM_STRATEGY_REGISTERED",self~eventMeta("version",strategy~strategyVersion))
  return strategy

::method enableStrategy
  expose strategies journal
  use strict arg strategyId,authorityRef
  if authorityRef="" then raise syntax 88.900 array("VMM strategy enable authority required")
  s=strategies[strategyId]
  if s==.nil then raise syntax 88.900 array("unknown VMM strategy",strategyId)
  s~enable
  journal~put("strategy:"||strategyId,s,"VMM_STRATEGY_ENABLED",self~eventMeta("authority",authorityRef))
  return s

::method disableStrategy
  expose strategies journal
  use strict arg strategyId,authorityRef
  if authorityRef="" then raise syntax 88.900 array("VMM strategy disable authority required")
  s=strategies[strategyId]
  if s==.nil then raise syntax 88.900 array("unknown VMM strategy",strategyId)
  s~disable
  journal~put("strategy:"||strategyId,s,"VMM_STRATEGY_DISABLED",self~eventMeta("authority",authorityRef))
  return s

::method setKillSwitch
  expose killSwitch killAuthority killReason journal marketOrders executionService
  use strict arg active,authorityRef,reasonCode,at
  if authorityRef="" | reasonCode="" | at="" then raise syntax 88.900 array("VMM kill switch requires authority/reason/time")
  killSwitch=active; killAuthority=authorityRef; killReason=reasonCode
  if active then do orderId over marketOrders
    order=marketOrders[orderId]
    if order~state="OPEN" | order~state="PARTIALLY_FILLED" then do
      routed = order~executionState="ROUTED" | order~executionState="ACKNOWLEDGED" | order~executionState="PART_FILLED" | order~executionState="UNKNOWN_PENDING_RECONCILIATION"
      if executionService<>.nil & routed then do
        order~markCancelPending
        ignore=executionService~requestCancel(orderId,"KILL-"||orderId,order~executionCorrelationId,at,authorityRef,reasonCode)
      end
      else order~cancel
    end
  end
  d=.directory~new; d["active"]=active; d["authority"]=authorityRef; d["reason"]=reasonCode; d["at"]=at
  journal~put("control:killSwitch",d,"VMM_KILL_SWITCH_CHANGED",self~eventMeta("authority",authorityRef))
  return active

::method setFirmRiskLimits
  expose riskLimits journal
  use strict arg limits,authorityRef
  if \limits~isA(.VMMFirmRiskLimits) | authorityRef="" then raise syntax 88.900 array("VMM firm risk limits and authority required")
  riskLimits[limits~currency]=limits
  journal~put("riskLimits:"||limits~currency,limits,"VMM_FIRM_RISK_LIMITS_SET",self~eventMeta("authority",authorityRef))
  return limits

::method requestQuote
  expose strategies flowRequests quotes killSwitch journal instrumentCatalog inventoryCurrency
  use strict arg request,strategyId,quoteId,referencePrice,spreadBps,validUntil
  if killSwitch then raise syntax 88.900 array("VMM kill switch active")
  if \request~isA(.VMMFlowRequest) then raise syntax 88.900 array("VMMFlowRequest required")
  if flowRequests~hasIndex(request~requestId) then raise syntax 88.900 array("duplicate VMM flow request",request~requestId)
  s=strategies[strategyId]
  if s==.nil then raise syntax 88.900 array("VMM strategy not enabled",strategyId)
  if \s~enabled then raise syntax 88.900 array("VMM strategy not enabled",strategyId)
  if request~notional>s~perTradeLimit then raise syntax 88.900 array("VMM per-trade limit exceeded",request~notional,s~perTradeLimit)
  if referencePrice<=0 | spreadBps<0 then raise syntax 88.900 array("invalid VMM quote inputs")
  key=request~instrumentKey
  projected=self~projectedInventory(key,request~principalSide,request~notional)
  if abs(projected)>s~inventoryLimit then raise syntax 88.900 array("VMM projected inventory limit exceeded",projected,s~inventoryLimit)
  self~checkProjectedFirmRisk(key,request~currency,projected)
  if request~instrumentIdentity<>.nil then instrumentCatalog[key]=request~instrumentIdentity
  inventoryCurrency[key]=request~currency
  half=spreadBps/20000; bid=referencePrice*(1-half); ask=referencePrice*(1+half)
  q=.VMMQuote~new(quoteId,request~requestId,strategyId,request~instrumentRef,request~customerSide,request~principalSide,request~currency,request~notional,bid,ask,referencePrice,spreadBps,validUntil,request~instrumentIdentity)
  flowRequests[request~requestId]=request; quotes[quoteId]=q
  edit=journal~beginEdit("VMM_QUOTE_ISSUED",self~eventMeta("strategy",strategyId)); edit~put("flow:"||request~requestId,request); edit~put("quote:"||quoteId,q); edit~commit
  return q

::method executeQuote
  expose strategies flowRequests quotes trades inventory inventoryCurrency instrumentCatalog tradingCash killSwitch journal
  use strict arg tradeId,quoteId,executedAt,executionAuthority
  if killSwitch then raise syntax 88.900 array("VMM kill switch active")
  if trades~hasIndex(tradeId) then raise syntax 88.900 array("duplicate VMM trade",tradeId)
  q=quotes[quoteId]
  if q==.nil then raise syntax 88.900 array("VMM quote unavailable",quoteId)
  if q~state<>"OPEN" then raise syntax 88.900 array("VMM quote unavailable",quoteId)
  s=strategies[q~strategyId]
  if s==.nil then raise syntax 88.900 array("VMM strategy not enabled at execution",q~strategyId)
  if \s~enabled then raise syntax 88.900 array("VMM strategy not enabled at execution",q~strategyId)
  r=flowRequests[q~requestId]
  if r==.nil then raise syntax 88.900 array("VMM quote has no flow request",q~requestId)
  key=q~instrumentKey; projected=self~projectedInventory(key,q~principalSide,q~notional)
  if abs(projected)>s~inventoryLimit then raise syntax 88.900 array("VMM inventory limit exceeded at execution",projected,s~inventoryLimit)
  self~checkProjectedFirmRisk(key,q~currency,projected)
  t=.VMMPrincipalTrade~new(tradeId,q~quoteId,q~requestId,q~strategyId,q~instrumentRef,q~principalSide,q~currency,q~notional,q~executionPrice,executedAt,r~anonRelationshipRef,executionAuthority,"FEDERATIONBANK_MERCHANT_FLOW",q~instrumentIdentity)
  inventory[key]=projected; inventoryCurrency[key]=q~currency
  if q~instrumentIdentity<>.nil then instrumentCatalog[key]=q~instrumentIdentity
  cashDelta=q~notional*q~executionPrice
  if q~principalSide="LONG" then cashDelta=-cashDelta
  self~adjustAmount(tradingCash,q~currency,cashDelta)
  q~markExecuted; trades[tradeId]=t
  edit=journal~beginEdit("VMM_PRINCIPAL_TRADE_EXECUTED",self~eventMeta("instrument",q~instrumentRef)); edit~put("quote:"||q~quoteId,q); edit~put("trade:"||tradeId,t); edit~put("inventory:"||key,projected); edit~put("tradingCash:"||q~currency,self~directoryAmount(tradingCash,q~currency)); edit~commit
  return t

::method inventoryFor
  expose inventory
  use strict arg instrument
  if instrument~isA(.VMMTradableInstrument) then key=instrument~identityKey
  else key=instrument
  v=inventory[key]; if v==.nil then return 0
  return v

::method principalTrade
  expose trades
  use strict arg tradeId
  return trades[tradeId]
::method quote
  expose quotes
  use strict arg quoteId
  return quotes[quoteId]

::method recordAlgorithmDecision
  expose algorithmDecisions strategies instrumentCatalog journal killSwitch
  use strict arg decision
  if killSwitch then raise syntax 88.900 array("VMM kill switch active")
  if \decision~isA(.VMMAlgorithmDecision) then raise syntax 88.900 array("VMMAlgorithmDecision required")
  if algorithmDecisions~hasIndex(decision~decisionId) then raise syntax 88.900 array("duplicate VMM algorithm decision",decision~decisionId)
  s=strategies[decision~strategyId]
  if s==.nil then raise syntax 88.900 array("VMM strategy not enabled for algorithm decision",decision~strategyId)
  if \s~enabled then raise syntax 88.900 array("VMM strategy not enabled for algorithm decision",decision~strategyId)
  if decision~action<>"HOLD" & decision~notional>s~perTradeLimit then raise syntax 88.900 array("VMM algorithm decision exceeds per-trade limit")
  instrumentCatalog[decision~instrumentIdentity~identityKey]=decision~instrumentIdentity
  algorithmDecisions[decision~decisionId]=decision
  journal~put("algoDecision:"||decision~decisionId,decision,"VMM_ALGORITHM_DECISION_RECORDED",self~eventMeta("strategy",decision~strategyId))
  return decision

::method createProprietaryOrder
  expose algorithmDecisions strategies marketOrders inventoryCurrency instrumentCatalog killSwitch journal
  use strict arg orderId,decisionId,orderType,limitPrice,createdAt,executionAuthority
  if killSwitch then raise syntax 88.900 array("VMM kill switch active")
  if marketOrders~hasIndex(orderId) then raise syntax 88.900 array("duplicate VMM market order",orderId)
  d=algorithmDecisions[decisionId]
  if d==.nil then raise syntax 88.900 array("unknown VMM algorithm decision",decisionId)
  if d~action="HOLD" then raise syntax 88.900 array("HOLD decision cannot create market order")
  s=strategies[d~strategyId]
  if s==.nil then raise syntax 88.900 array("VMM strategy not enabled at order creation",d~strategyId)
  if \s~enabled then raise syntax 88.900 array("VMM strategy not enabled at order creation",d~strategyId)
  key=d~instrumentIdentity~identityKey; projected=self~projectedInventory(key,d~side,d~notional)
  if abs(projected)>s~inventoryLimit then raise syntax 88.900 array("VMM strategy inventory limit exceeded by proprietary order")
  self~checkProjectedFirmRisk(key,d~instrumentIdentity~quoteCurrency,projected)
  o=.VMMMarketOrder~new(orderId,d~strategyId,d~instrumentIdentity,d~side,d~notional,orderType,limitPrice,"PROPRIETARY_SIGNAL","",decisionId,createdAt,executionAuthority)
  marketOrders[orderId]=o; instrumentCatalog[key]=d~instrumentIdentity; inventoryCurrency[key]=d~instrumentIdentity~quoteCurrency
  journal~put("marketOrder:"||orderId,o,"VMM_PROPRIETARY_ORDER_CREATED",self~eventMeta("decision",decisionId))
  return o

::method createInventoryHedgeOrder
  expose trades strategies marketOrders inventoryCurrency instrumentCatalog killSwitch journal
  use strict arg orderId,parentTradeId,strategyId,notional,orderType,limitPrice,createdAt,executionAuthority
  if killSwitch then raise syntax 88.900 array("VMM kill switch active")
  if marketOrders~hasIndex(orderId) then raise syntax 88.900 array("duplicate VMM market order",orderId)
  t=trades[parentTradeId]
  if t==.nil then raise syntax 88.900 array("unknown VMM parent principal trade",parentTradeId)
  if t~instrumentIdentity==.nil then raise syntax 88.900 array("VMM cannot externally hedge legacy bare instrument reference; full identity required")
  if notional<=0 | notional>t~notional then raise syntax 88.900 array("VMM inventory hedge notional exceeds parent trade")
  s=strategies[strategyId]
  if s==.nil then raise syntax 88.900 array("VMM strategy not enabled at hedge order creation",strategyId)
  if \s~enabled then raise syntax 88.900 array("VMM strategy not enabled at hedge order creation",strategyId)
  if t~principalSide="LONG" then side="SHORT"; else side="LONG"
  key=t~instrumentKey; projected=self~projectedInventory(key,side,notional)
  if abs(projected)>s~inventoryLimit then raise syntax 88.900 array("VMM strategy inventory limit exceeded by hedge order")
  self~checkProjectedFirmRisk(key,t~currency,projected)
  o=.VMMMarketOrder~new(orderId,strategyId,t~instrumentIdentity,side,notional,orderType,limitPrice,"INVENTORY_HEDGE",parentTradeId,"",createdAt,executionAuthority)
  marketOrders[orderId]=o; instrumentCatalog[key]=t~instrumentIdentity; inventoryCurrency[key]=t~currency
  journal~put("marketOrder:"||orderId,o,"VMM_INVENTORY_HEDGE_ORDER_CREATED",self~eventMeta("parentTrade",parentTradeId))
  return o

::method createSyntheticHedgeOrder
  expose strategies marketOrders inventoryCurrency instrumentCatalog killSwitch journal
  use strict arg orderId,contractId,strategyId,instrumentIdentity,side,notional,orderType,limitPrice,createdAt,executionAuthority
  if killSwitch then raise syntax 88.900 array("VMM kill switch active")
  if contractId="" then raise syntax 88.900 array("VMM synthetic hedge requires parent contract reference")
  if marketOrders~hasIndex(orderId) then raise syntax 88.900 array("duplicate VMM market order",orderId)
  if \instrumentIdentity~isA(.VMMTradableInstrument) then raise syntax 88.900 array("VMM synthetic hedge requires exact tradable instrument identity")
  if side<>"LONG" & side<>"SHORT" then raise syntax 88.900 array("invalid VMM synthetic hedge side",side)
  if notional<=0 then raise syntax 88.900 array("invalid VMM synthetic hedge notional")
  s=strategies[strategyId]
  if s==.nil then raise syntax 88.900 array("VMM strategy not enabled at synthetic hedge creation",strategyId)
  if \s~enabled then raise syntax 88.900 array("VMM strategy not enabled at synthetic hedge creation",strategyId)
  key=instrumentIdentity~identityKey; projected=self~projectedInventory(key,side,notional)
  if abs(projected)>s~inventoryLimit then raise syntax 88.900 array("VMM strategy inventory limit exceeded by synthetic hedge")
  self~checkProjectedFirmRisk(key,instrumentIdentity~quoteCurrency,projected)
  o=.VMMMarketOrder~new(orderId,strategyId,instrumentIdentity,side,notional,orderType,limitPrice,"SYNTHETIC_HEDGE",contractId,"",createdAt,executionAuthority)
  marketOrders[orderId]=o; instrumentCatalog[key]=instrumentIdentity; inventoryCurrency[key]=instrumentIdentity~quoteCurrency
  journal~put("marketOrder:"||orderId,o,"VMM_SYNTHETIC_HEDGE_ORDER_CREATED",self~eventMeta("contract",contractId))
  return o

::method fillMarketOrder
  expose executionService
  use strict arg fillId,orderId,venueExecutionRef,fillNotional,price,executedAt,executingCounterparty,settlementRef=""
  if executionService<>.nil then raise syntax 88.900 array("VMM queue execution bound; direct fill bypass denied")
  return self~fillMarketOrderCore(fillId,orderId,venueExecutionRef,fillNotional,price,executedAt,executingCounterparty,settlementRef,.true)

::method acceptQueuedFill
  use strict arg fillId,orderId,commandId,correlationId,venueExecutionRef,fillNotional,price,executedAt,executingCounterparty,settlementRef,eventId,serviceRef
  self~requireExecutionService(serviceRef)
  o=self~marketOrder(orderId)
  if o==.nil then raise syntax 88.900 array("unknown VMM market order",orderId)
  if o~executionCommandId<>commandId | o~executionCorrelationId<>correlationId then raise syntax 88.900 array("VMM queued fill binding mismatch")
  f=self~fillMarketOrderCore(fillId,orderId,venueExecutionRef,fillNotional,price,executedAt,executingCounterparty,settlementRef,.false)
  return f

::method acceptSmartQueuedFill
  use strict arg fillId,orderId,commandId,correlationId,venueExecutionRef,fillNotional,price,executedAt,executingCounterparty,settlementRef,eventId,routeId,feeAmount,rebateAmount,serviceRef
  self~requireExecutionService(serviceRef)
  o=self~marketOrder(orderId)
  if o==.nil then raise syntax 88.900 array("unknown VMM market order",orderId)
  if o~executionCommandId<>commandId | o~executionCorrelationId<>correlationId then raise syntax 88.900 array("VMM smart queued fill binding mismatch")
  return self~fillMarketOrderCore(fillId,orderId,venueExecutionRef,fillNotional,price,executedAt,executingCounterparty,settlementRef,.false,routeId,feeAmount,rebateAmount)

::method fillMarketOrderCore private
  expose marketOrders fills strategies inventory inventoryCurrency instrumentCatalog tradingCash journal executionCosts shortLocateReservations shortLocates
  use strict arg fillId,orderId,venueExecutionRef,fillNotional,price,executedAt,executingCounterparty,settlementRef="",enforceRisk=.true,routeId="",feeAmount=0,rebateAmount=0
  if fills~hasIndex(fillId) then raise syntax 88.900 array("duplicate VMM execution fill",fillId)
  o=marketOrders[orderId]
  if o==.nil then raise syntax 88.900 array("unknown VMM market order",orderId)
  s=strategies[o~strategyId]
  if s==.nil then raise syntax 88.900 array("VMM strategy unavailable at external fill",o~strategyId)
  key=o~instrumentIdentity~identityKey; current=self~inventoryFor(key); projected=self~projectedInventory(key,o~side,fillNotional)
  if enforceRisk then do
    if \s~enabled then raise syntax 88.900 array("VMM strategy not enabled at direct external fill",o~strategyId)
    if abs(projected)>s~inventoryLimit then raise syntax 88.900 array("VMM strategy inventory limit exceeded at fill")
    self~checkProjectedFirmRisk(key,o~instrumentIdentity~quoteCurrency,projected)
  end
  shortIncrease=0
  if o~side="SHORT" then shortIncrease=max(0,-projected)-max(0,-current)
  if shortIncrease>0 & routeId<>"" then self~consumeShortLocateReservation(orderId,shortIncrease)
  o~recordFill(fillNotional,price); o~recordExecutionCost(feeAmount,rebateAmount)
  f=.VMMExecutionFill~new(fillId,orderId,venueExecutionRef,key,o~side,fillNotional,price,o~instrumentIdentity~quoteCurrency,executedAt,executingCounterparty,settlementRef,routeId,feeAmount,rebateAmount)
  fills[fillId]=f; inventory[key]=projected; inventoryCurrency[key]=o~instrumentIdentity~quoteCurrency; instrumentCatalog[key]=o~instrumentIdentity
  cashDelta=fillNotional*price; if o~side="LONG" then cashDelta=-cashDelta
  cashDelta=cashDelta-(feeAmount-rebateAmount)
  self~adjustAmount(tradingCash,o~instrumentIdentity~quoteCurrency,cashDelta)
  executionCosts[fillId]=feeAmount-rebateAmount
  edit=journal~beginEdit("VMM_MARKET_ORDER_FILLED",self~eventMeta("order",orderId)); edit~put("marketOrder:"||orderId,o); edit~put("fill:"||fillId,f); edit~put("inventory:"||key,projected); edit~put("tradingCash:"||o~instrumentIdentity~quoteCurrency,self~directoryAmount(tradingCash,o~instrumentIdentity~quoteCurrency)); edit~commit
  return f

::method marketOrder
  expose marketOrders
  use strict arg orderId
  return marketOrders[orderId]
::method executionFill
  expose fills
  use strict arg fillId
  return fills[fillId]

::method recordMarketMark
  expose marks latestMarkByInstrument instrumentCatalog journal
  use strict arg mark
  if \mark~isA(.VMMMarketMark) then raise syntax 88.900 array("VMMMarketMark required")
  if marks~hasIndex(mark~markId) then raise syntax 88.900 array("duplicate VMM market mark",mark~markId)
  key=mark~instrumentIdentity~identityKey; marks[mark~markId]=mark; latestMarkByInstrument[key]=mark; instrumentCatalog[key]=mark~instrumentIdentity
  journal~put("marketMark:"||mark~markId,mark,"VMM_MARKET_MARK_RECORDED",self~eventMeta("instrumentKey",key))
  return mark

::method tradingCashBalance
  expose tradingCash
  use strict arg currency
  return self~directoryAmount(tradingCash,currency)
::method fundingCashBalance
  expose fundingCash
  use strict arg currency
  return self~directoryAmount(fundingCash,currency)
::method availableLiquidity
  expose tradingCash fundingCash
  use strict arg currency
  return self~directoryAmount(tradingCash,currency)+self~directoryAmount(fundingCash,currency)

::method markedTradingPnl
  expose inventory inventoryCurrency latestMarkByInstrument tradingCash
  use strict arg currency
  pnl=self~directoryAmount(tradingCash,currency)
  do key over inventory
    if inventoryCurrency[key]=currency & inventory[key]<>0 then do
      m=latestMarkByInstrument[key]
      if m==.nil then raise syntax 88.900 array("VMM open position lacks usable market mark",key)
      if m~status<>"CURRENT" & m~status<>"INDICATIVE" then raise syntax 88.900 array("VMM open position lacks usable market mark",key)
      pnl=pnl+(inventory[key]*m~price)
    end
  end
  return pnl

::method grossInventoryNotional
  expose inventory inventoryCurrency
  use strict arg currency
  total=0
  do key over inventory
    if inventoryCurrency[key]=currency then total=total+abs(inventory[key])
  end
  return total
::method netInventoryNotional
  expose inventory inventoryCurrency
  use strict arg currency
  total=0
  do key over inventory
    if inventoryCurrency[key]=currency then total=total+inventory[key]
  end
  return total

::method registerFundingFacility
  expose facilities legalEntity journal
  use strict arg facility
  if \facility~isA(.VMMFundingFacility) then raise syntax 88.900 array("VMMFundingFacility required")
  if facility~borrowerEntity<>legalEntity then raise syntax 88.900 array("funding facility borrower/legal entity mismatch")
  if facilities~hasIndex(facility~facilityId) then raise syntax 88.900 array("duplicate VMM funding facility",facility~facilityId)
  facilities[facility~facilityId]=facility
  journal~put("fundingFacility:"||facility~facilityId,facility,"VMM_FUNDING_FACILITY_ACCEPTED",self~eventMeta("lender",facility~lenderEntity))
  return facility

::method drawFunding
  expose facilities fundingDraws fundingCash riskLimits journal
  use strict arg drawId,facilityId,amount,drawnAt,lenderAuthority,loanObligationRef
  if fundingDraws~hasIndex(drawId) then raise syntax 88.900 array("duplicate VMM funding draw",drawId)
  f=facilities[facilityId]; if f==.nil then raise syntax 88.900 array("unknown VMM funding facility",facilityId)
  limits=riskLimits[f~currency]
  if limits<>.nil then do
    if f~outstanding+amount>limits~maxFundingOutstanding then raise syntax 88.900 array("VMM arm-length funding draw exceeds firm funding limit",f~outstanding+amount,limits~maxFundingOutstanding)
  end
  f~draw(amount); d=.VMMFundingDraw~new(drawId,facilityId,amount,f~currency,drawnAt,lenderAuthority,loanObligationRef); fundingDraws[drawId]=d
  self~adjustAmount(fundingCash,f~currency,amount)
  edit=journal~beginEdit("VMM_FUNDING_DRAW_RECORDED",self~eventMeta("facility",facilityId)); edit~put("fundingFacility:"||facilityId,f); edit~put("fundingDraw:"||drawId,d); edit~put("fundingCash:"||f~currency,self~directoryAmount(fundingCash,f~currency)); edit~commit
  return d

::method repayFunding
  expose facilities fundingRepayments fundingCash journal
  use strict arg repaymentId,facilityId,amount,repaidAt,authorityRef,loanObligationRef
  if fundingRepayments~hasIndex(repaymentId) then raise syntax 88.900 array("duplicate VMM funding repayment",repaymentId)
  f=facilities[facilityId]; if f==.nil then raise syntax 88.900 array("unknown VMM funding facility",facilityId)
  f~repay(amount); r=.VMMFundingRepayment~new(repaymentId,facilityId,f~currency,amount,repaidAt,authorityRef,loanObligationRef); fundingRepayments[repaymentId]=r
  self~adjustAmount(fundingCash,f~currency,-amount)
  edit=journal~beginEdit("VMM_FUNDING_REPAID",self~eventMeta("facility",facilityId)); edit~put("fundingFacility:"||facilityId,f); edit~put("fundingRepayment:"||repaymentId,r); edit~put("fundingCash:"||f~currency,self~directoryAmount(fundingCash,f~currency)); edit~commit
  return r

::method accrueFundingCost
  expose facilities fundingAccruals fundingExpenses journal
  use strict arg accrualId,facilityId,days,accruedAt,authorityRef
  if fundingAccruals~hasIndex(accrualId) then raise syntax 88.900 array("duplicate VMM funding accrual",accrualId)
  f=facilities[facilityId]; if f==.nil then raise syntax 88.900 array("unknown VMM funding facility",facilityId)
  if days<=0 then raise syntax 88.900 array("invalid VMM funding accrual days")
  amount=f~outstanding*(f~interestRateBps/10000)*(days/365)
  a=.VMMFundingAccrual~new(accrualId,facilityId,f~currency,f~outstanding,f~interestRateBps,days,amount,accruedAt,authorityRef); fundingAccruals[accrualId]=a
  self~adjustAmount(fundingExpenses,f~currency,amount)
  journal~put("fundingAccrual:"||accrualId,a,"VMM_FUNDING_COST_ACCRUED",self~eventMeta("facility",facilityId))
  return a

::method fundingOutstanding
  expose facilities
  use strict arg currency
  total=0
  do facilityId over facilities
    f=facilities[facilityId]
    if f~currency=currency then total=total+f~outstanding
  end
  return total
::method fundingExpense
  expose fundingExpenses
  use strict arg currency
  return self~directoryAmount(fundingExpenses,currency)
::method netPnl
  use strict arg currency
  return self~markedTradingPnl(currency)-self~fundingExpense(currency)

::method fundingFacility
  expose facilities
  use strict arg facilityId
  return facilities[facilityId]
::method fundingDraw
  expose fundingDraws
  use strict arg drawId
  return fundingDraws[drawId]
::method fundingAccrual
  expose fundingAccruals
  use strict arg accrualId
  return fundingAccruals[accrualId]

::method evaluateRisk
  expose riskLimits riskSnapshots inventory inventoryCurrency journal
  use strict arg snapshotId,currency,evaluatedAt,authorityRef,enforce=.false
  if riskSnapshots~hasIndex(snapshotId) then raise syntax 88.900 array("duplicate VMM risk snapshot",snapshotId)
  limits=riskLimits[currency]; if limits==.nil then raise syntax 88.900 array("no VMM firm risk limits for currency",currency)
  gross=self~grossInventoryNotional(currency); net=self~netInventoryNotional(currency); tpnl=self~markedTradingPnl(currency); funded=self~fundingOutstanding(currency); expense=self~fundingExpense(currency); npnl=tpnl-expense
  breach="NONE"
  do key over inventory
    if inventoryCurrency[key]=currency & abs(inventory[key])>limits~maxSingleInstrumentNotional then do
      breach=self~appendBreach(breach,"SINGLE_INSTRUMENT")
      leave
    end
  end
  if gross>limits~maxGrossNotional then breach=self~appendBreach(breach,"GROSS_NOTIONAL")
  if funded>limits~maxFundingOutstanding then breach=self~appendBreach(breach,"FUNDING_OUTSTANDING")
  if npnl < -limits~maxLoss then breach=self~appendBreach(breach,"MAX_LOSS")
  snap=.VMMRiskSnapshot~new(snapshotId,currency,gross,net,tpnl,funded,expense,npnl,breach,evaluatedAt,authorityRef); riskSnapshots[snapshotId]=snap
  journal~put("riskSnapshot:"||snapshotId,snap,"VMM_RISK_SNAPSHOT_RECORDED",self~eventMeta("breach",breach))
  if enforce & snap~breached then self~setKillSwitch(.true,authorityRef,"FIRM_RISK_BREACH:"||breach,evaluatedAt)
  return snap

::method registerShortLocate
  expose shortLocates journal
  use strict arg locate
  if \locate~isA(.VMMShortLocate) then raise syntax 88.900 array("VMMShortLocate required")
  if shortLocates~hasIndex(locate~locateId) then raise syntax 88.900 array("duplicate VMM short locate",locate~locateId)
  shortLocates[locate~locateId]=locate
  journal~put("shortLocate:"||locate~locateId,locate,"VMM_SHORT_LOCATE_REGISTERED",self~eventMeta("lender",locate~lenderEntity))
  return locate

::method shortLocate
  expose shortLocates
  use strict arg locateId
  return shortLocates[locateId]

::method shortLocateReservation
  expose shortLocateReservations
  use strict arg orderId
  return shortLocateReservations[orderId]

::method reserveShortLocateForOrder
  expose marketOrders shortLocates shortLocateReservations journal
  use strict arg orderId,at,authorityRef
  if shortLocateReservations~hasIndex(orderId) then return shortLocateReservations[orderId]
  o=marketOrders[orderId]; if o==.nil then raise syntax 88.900 array("unknown VMM market order",orderId)
  if o~side<>"SHORT" then return .nil
  key=o~instrumentIdentity~identityKey; current=self~inventoryFor(key); projected=current-o~remainingNotional
  needed=max(0,-projected)-max(0,-current)
  if needed<=0 then return .nil
  chosen=.nil
  do locateId over shortLocates
    l=shortLocates[locateId]
    if l~instrumentKey=key & l~state="ACTIVE" & l~remainingCapacity>=needed then do
      if at<=l~expiresAt then do; chosen=l; leave; end
    end
  end
  if chosen==.nil then raise syntax 88.900 array("VMM short locate required",key,needed)
  chosen~reserve(needed)
  r=.VMMShortLocateReservation~new("LOCRES-"||orderId,chosen~locateId,orderId,needed,at,authorityRef)
  shortLocateReservations[orderId]=r
  edit=journal~beginEdit("VMM_SHORT_LOCATE_RESERVED",self~eventMeta("order",orderId)); edit~put("shortLocate:"||chosen~locateId,chosen); edit~put("shortLocateReservation:"||orderId,r); edit~commit
  return r

::method consumeShortLocateReservation private
  expose shortLocateReservations shortLocates journal
  use strict arg orderId,amount
  r=shortLocateReservations[orderId]
  if r==.nil then raise syntax 88.900 array("VMM smart short fill lacks locate reservation",orderId,amount)
  if amount>r~remainingNotional then raise syntax 88.900 array("VMM smart short fill exceeds locate reservation",orderId,amount,r~remainingNotional)
  l=shortLocates[r~locateId]; if l==.nil then raise syntax 88.900 array("VMM locate reservation source missing",r~locateId)
  r~consume(amount); l~consume(amount)
  edit=journal~beginEdit("VMM_SHORT_LOCATE_CONSUMED",self~eventMeta("order",orderId)); edit~put("shortLocate:"||l~locateId,l); edit~put("shortLocateReservation:"||orderId,r); edit~commit
  return r

::method releaseShortLocateReservation
  expose shortLocateReservations shortLocates journal
  use strict arg orderId
  r=shortLocateReservations[orderId]; if r==.nil then return .false
  if r~state="RELEASED" | r~remainingNotional<=0 then return .false
  l=shortLocates[r~locateId]; if l<>.nil then l~release(r~remainingNotional)
  r~release
  edit=journal~beginEdit("VMM_SHORT_LOCATE_RELEASED",self~eventMeta("order",orderId)); if l<>.nil then edit~put("shortLocate:"||l~locateId,l); edit~put("shortLocateReservation:"||orderId,r); edit~commit
  return .true

::method recordMarketRestriction
  expose marketRestrictions journal
  use strict arg restriction
  if \restriction~isA(.VMMMarketRestriction) then raise syntax 88.900 array("VMMMarketRestriction required")
  if marketRestrictions~hasIndex(restriction~restrictionId) then raise syntax 88.900 array("duplicate VMM market restriction",restriction~restrictionId)
  marketRestrictions[restriction~restrictionId]=restriction
  journal~put("marketRestriction:"||restriction~restrictionId,restriction,"VMM_MARKET_RESTRICTION_RECORDED",self~eventMeta("reason",restriction~reasonCode))
  return restriction

::method liftMarketRestriction
  expose marketRestrictions journal
  use strict arg restrictionId,authorityRef,at
  r=marketRestrictions[restrictionId]; if r==.nil then raise syntax 88.900 array("unknown VMM market restriction",restrictionId)
  r~lift
  journal~put("marketRestriction:"||restrictionId,r,"VMM_MARKET_RESTRICTION_LIFTED",self~eventMeta("authority",authorityRef))
  return r

::method registerMarketStructureLink
  expose marketStructureLinks journal
  use strict arg link
  if \link~isA(.VMMMarketStructureLink) then raise syntax 88.900 array("VMMMarketStructureLink required")
  if marketStructureLinks~hasIndex(link~linkId) then raise syntax 88.900 array("duplicate VMM market-structure link",link~linkId)
  marketStructureLinks[link~linkId]=link
  journal~put("marketStructureLink:"||link~linkId,link,"VMM_MARKET_STRUCTURE_LINK_RECORDED",self~eventMeta("relation",link~relation))
  return link

::method impairMarketStructureLink
  expose marketStructureLinks journal
  use strict arg linkId,newStatus,reasonCode,evidenceRef,authorityRef,at
  l=marketStructureLinks[linkId]; if l==.nil then raise syntax 88.900 array("unknown VMM market-structure link",linkId)
  l~impair(newStatus,reasonCode,evidenceRef,authorityRef,at)
  journal~put("marketStructureLink:"||linkId,l,"VMM_MARKET_STRUCTURE_LINK_CHANGED",self~eventMeta("reason",reasonCode))
  return l

::method marketStructureEquivalent
  expose marketStructureLinks
  use strict arg leftInstrument,rightInstrument
  if leftInstrument~isA(.VMMTradableInstrument) then leftKey=leftInstrument~identityKey; else leftKey=leftInstrument
  if rightInstrument~isA(.VMMTradableInstrument) then rightKey=rightInstrument~identityKey; else rightKey=rightInstrument
  if leftKey=rightKey then return .true
  do linkId over marketStructureLinks
    l=marketStructureLinks[linkId]
    match=(l~leftInstrumentKey=leftKey & l~rightInstrumentKey=rightKey) | (l~leftInstrumentKey=rightKey & l~rightInstrumentKey=leftKey)
    if match & l~active then return .true
  end
  return .false

::method setCapitalPolicy
  expose capitalPolicies journal
  use strict arg policy,authorityRef
  if \policy~isA(.VMMCapitalPolicy) | authorityRef="" then raise syntax 88.900 array("VMM capital policy and authority required")
  capitalPolicies[policy~currency]=policy
  journal~put("capitalPolicy:"||policy~currency,policy,"VMM_CAPITAL_POLICY_SET",self~eventMeta("authority",authorityRef))
  return policy

::method evaluateCapital
  expose capitalPolicies capitalSnapshots journal
  use strict arg snapshotId,currency,evaluatedAt,authorityRef
  if capitalSnapshots~hasIndex(snapshotId) then raise syntax 88.900 array("duplicate VMM capital snapshot",snapshotId)
  p=capitalPolicies[currency]; if p==.nil then raise syntax 88.900 array("no VMM capital policy for currency",currency)
  gross=self~grossInventoryNotional(currency); lev=gross/p~capitalBase; breach="NONE"; if lev>p~maxLeverage then breach="MAX_LEVERAGE"
  s=.VMMCapitalSnapshot~new(snapshotId,currency,p~capitalBase,gross,lev,p~maxLeverage,breach,evaluatedAt,authorityRef); capitalSnapshots[snapshotId]=s
  journal~put("capitalSnapshot:"||snapshotId,s,"VMM_CAPITAL_SNAPSHOT_RECORDED",self~eventMeta("breach",breach))
  return s

::method assertSmartExecutionPermitted
  expose marketRestrictions
  use strict arg order,route,at
  if \order~isA(.VMMMarketOrder) then raise syntax 88.900 array("VMMMarketOrder required")
  i=order~instrumentIdentity; key=i~identityKey
  if route~venueMic<>i~venueMic then raise syntax 88.900 array("VMM smart route cannot silently change tradable line",i~venueMic,route~venueMic)
  do restrictionId over marketRestrictions
    r=marketRestrictions[restrictionId]
    if r~status="ACTIVE" then do
      scoped=(r~instrumentKey="" | r~instrumentKey=key) & (r~venueMic="" | r~venueMic=i~venueMic)
      if scoped then do
        if r~effect="BLOCK_NEW" | r~effect="SETTLEMENT_IMPAIRED" | r~effect="PRICE_UNRELIABLE" then raise syntax 88.900 array("VMM market restriction blocks smart execution",r~effect,r~reasonCode)
        if r~effect="CLOSE_ONLY" then do
          current=self~inventoryFor(key); projected=self~projectedInventory(key,order~side,order~remainingNotional)
          if abs(projected)>=abs(current) | (current<>0 & projected<>0 & sign(current)<>sign(projected)) then raise syntax 88.900 array("VMM market restriction permits close-only execution",r~reasonCode)
        end
      end
    end
  end
  projected=self~projectedInventory(key,order~side,order~remainingNotional)
  self~checkProjectedFirmRisk(key,i~quoteCurrency,projected)
  return .true

::method recordSurveillanceEvidence
  expose surveillance journal
  use strict arg evidence
  if \evidence~isA(.VMMSurveillanceEvidence) then raise syntax 88.900 array("VMMSurveillanceEvidence required")
  if surveillance~hasIndex(evidence~evidenceId) then raise syntax 88.900 array("duplicate VMM surveillance evidence")
  surveillance[evidence~evidenceId]=evidence
  journal~put("surveillance:"||evidence~evidenceId,evidence,"VMM_SURVEILLANCE_EVIDENCE_RECORDED",self~eventMeta("authority",evidence~sourceAuthority))
  return evidence

::method projectedInventory private
  expose inventory
  use strict arg instrumentKey,side,notional
  current=inventory[instrumentKey]; if current==.nil then current=0
  if side="LONG" then return current+notional
  if side="SHORT" then return current-notional
  raise syntax 88.900 array("invalid VMM inventory side",side)

::method checkProjectedFirmRisk private
  expose riskLimits inventory inventoryCurrency
  use strict arg instrumentKey,currency,projected
  limits=riskLimits[currency]
  if limits==.nil then do; self~checkProjectedCapital(instrumentKey,currency,projected); return .true; end
  if abs(projected)>limits~maxSingleInstrumentNotional then raise syntax 88.900 array("VMM firm single-instrument limit exceeded",projected,limits~maxSingleInstrumentNotional)
  current=inventory[instrumentKey]; if current==.nil then current=0
  gross=self~grossInventoryNotional(currency)-abs(current)+abs(projected)
  if gross>limits~maxGrossNotional then raise syntax 88.900 array("VMM firm gross-notional limit exceeded",gross,limits~maxGrossNotional)
  if self~fundingOutstanding(currency)>limits~maxFundingOutstanding then raise syntax 88.900 array("VMM firm funding-outstanding limit exceeded")
  self~checkProjectedCapital(instrumentKey,currency,projected)
  return .true

::method checkProjectedCapital private
  expose capitalPolicies inventory
  use strict arg instrumentKey,currency,projected
  p=capitalPolicies[currency]; if p==.nil then return .true
  current=inventory[instrumentKey]; if current==.nil then current=0
  gross=self~grossInventoryNotional(currency)-abs(current)+abs(projected)
  if gross>p~maxGrossExposure then raise syntax 88.900 array("VMM maximum leverage exceeded",gross,p~maxGrossExposure)
  return .true

::method requireExecutionService private
  expose executionService
  use strict arg serviceRef
  if executionService==.nil | serviceRef\==executionService then raise syntax 88.900 array("VMM execution event did not arrive through bound Queue Fabric service")
  return .true

::method adjustAmount private
  use strict arg directory,key,delta
  old=directory[key]; if old==.nil then old=0
  directory[key]=old+delta
  return directory[key]
::method directoryAmount private
  use strict arg directory,key
  v=directory[key]; if v==.nil then return 0
  return v
::method appendBreach private
  use strict arg current,code
  if current="NONE" then return code
  return current||"|"||code
::method eventMeta private
  use strict arg key,value
  d=.directory~new; d[key]=value
  return d

::requires "JournalPointedState.cls"
