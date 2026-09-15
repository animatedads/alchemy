/* Vector Meridian Markets v0.5 <-> FederationBank Merchant Bank adapter */

::class VectorMeridianFederationMerchantAdapter public
::method init
  expose vmmLegalEntity
  use strict arg vmmLegalEntity="VECTOR_MERIDIAN_MARKETS_LTD"
  if vmmLegalEntity="" then raise syntax 88.900 array("VMM legal entity required")
::method vmmLegalEntity; expose vmmLegalEntity; return vmmLegalEntity

::method asMerchantExternalHedgeTrade
  expose vmmLegalEntity
  use strict arg vmmTrade,merchantTradeId,portfolioId,clientObligor,productType="CFD",productId="",underlyingRef="",marketRef=""
  if \vmmTrade~isA(.VMMPrincipalTrade) then raise syntax 88.900 array("VMMPrincipalTrade required")
  if vmmTrade~instrumentIdentity<>.nil then do
    if underlyingRef="" then underlyingRef=vmmTrade~instrumentIdentity~economicUnderlyingId
    if marketRef="" then marketRef=vmmTrade~instrumentIdentity~venueMic
  end
  return .MBDerivativeTrade~new(merchantTradeId,portfolioId,clientObligor,productType,vmmTrade~principalSide,vmmTrade~currency,vmmTrade~notional,vmmTrade~price,0,"",1,marketRef,productId,underlyingRef,vmmTrade~executedAt,vmmLegalEntity,"EXTERNAL_HEDGE")

::method asMerchantInstrumentIdentity
  use strict arg vmmInstrument,contractCurrency=""
  if \vmmInstrument~isA(.VMMTradableInstrument) then raise syntax 88.900 array("VMMTradableInstrument required")
  if contractCurrency="" then contractCurrency=vmmInstrument~quoteCurrency
  return .MBInstrumentIdentity~new(vmmInstrument~economicUnderlyingId,vmmInstrument~isin,vmmInstrument~venueMic,vmmInstrument~representationType,vmmInstrument~quoteCurrency,vmmInstrument~settlementCurrency,contractCurrency,1,"",vmmInstrument~denominationCurrency,"","",vmmInstrument~resolutionEvidenceRef)

::requires "VectorMeridianMarkets.cls"
::requires "FederationBankMerchantBank.cls"
