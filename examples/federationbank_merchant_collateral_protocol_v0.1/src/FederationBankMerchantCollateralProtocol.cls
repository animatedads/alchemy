/* Arm's-length collateral control protocol between FederationBank Merchant Banking
 * and FederationBank Retail/Core Banking.
 *
 * This package defines messages and merchant-side receipt validation only.
 * It deliberately contains no Core Banking account mutation implementation.
 */

::class FBCollateralControlRequest public
::method init
  expose requestId merchantEntity agreementId obligor collateralProvider securedObligations coreAssetRef requestedAmount currency legalEffectRef policyRef requestedAt
  use strict arg requestId,merchantEntity,agreementId,obligor,collateralProvider,securedObligations,coreAssetRef,requestedAmount,currency,legalEffectRef,policyRef,requestedAt
  if requestId="" | merchantEntity="" | agreementId="" | obligor="" | collateralProvider="" | securedObligations="" | coreAssetRef="" then raise syntax 88.900 array("invalid collateral-control request identity")
  if requestedAmount<=0 | currency="" then raise syntax 88.900 array("invalid collateral-control request economics")
  if legalEffectRef="" | policyRef="" then raise syntax 88.900 array("collateral-control request requires Legal Effect and Institutional Policy provenance")
::method requestId; expose requestId; return requestId
::method merchantEntity; expose merchantEntity; return merchantEntity
::method agreementId; expose agreementId; return agreementId
::method obligor; expose obligor; return obligor
::method collateralProvider; expose collateralProvider; return collateralProvider
::method securedObligations; expose securedObligations; return securedObligations
::method coreAssetRef; expose coreAssetRef; return coreAssetRef
::method requestedAmount; expose requestedAmount; return requestedAmount
::method currency; expose currency; return currency
::method legalEffectRef; expose legalEffectRef; return legalEffectRef
::method policyRef; expose policyRef; return policyRef
::method requestedAt; expose requestedAt; return requestedAt
::method asDirectory
  expose requestId merchantEntity agreementId obligor collateralProvider securedObligations coreAssetRef requestedAmount currency legalEffectRef policyRef requestedAt
  d=.directory~new
  d["messageType"]="COLLATERAL_CONTROL_REQUEST"
  d["requestId"]=requestId
  d["merchantEntity"]=merchantEntity
  d["agreementId"]=agreementId
  d["obligor"]=obligor
  d["collateralProvider"]=collateralProvider
  d["securedObligations"]=securedObligations
  d["coreAssetRef"]=coreAssetRef
  d["requestedAmount"]=requestedAmount
  d["currency"]=currency
  d["legalEffectRef"]=legalEffectRef
  d["policyRef"]=policyRef
  d["requestedAt"]=requestedAt
  return d


::class FBCollateralControlDecision public
::method init
  expose decisionId requestId accepted coreAuthorityRef assetOwner encumbranceId encumbranceValid enforceable priority controlledAmount currency decidedAt reasonCode
  use strict arg decisionId,requestId,accepted,coreAuthorityRef,assetOwner,encumbranceId,encumbranceValid,enforceable,priority,controlledAmount,currency,decidedAt,reasonCode=""
  if decisionId="" | requestId="" | coreAuthorityRef="" then raise syntax 88.900 array("invalid Core collateral-control decision")
  if accepted & (assetOwner="" | encumbranceId="" | controlledAmount<=0 | currency="") then raise syntax 88.900 array("accepted control decision lacks Core authority facts")
::method decisionId; expose decisionId; return decisionId
::method requestId; expose requestId; return requestId
::method accepted; expose accepted; return accepted
::method coreAuthorityRef; expose coreAuthorityRef; return coreAuthorityRef
::method assetOwner; expose assetOwner; return assetOwner
::method encumbranceId; expose encumbranceId; return encumbranceId
::method encumbranceValid; expose encumbranceValid; return encumbranceValid
::method enforceable; expose enforceable; return enforceable
::method priority; expose priority; return priority
::method controlledAmount; expose controlledAmount; return controlledAmount
::method currency; expose currency; return currency
::method decidedAt; expose decidedAt; return decidedAt
::method reasonCode; expose reasonCode; return reasonCode
::method usable
  expose accepted encumbranceValid enforceable controlledAmount
  return accepted & encumbranceValid & enforceable & controlledAmount>0


::class FBCollateralRealisationRequest public
::method init
  expose requestId merchantEntity agreementId encumbranceId securedObligations defaultEventRef closeOutRef requestedAmount currency legalEffectRef requestedAt
  use strict arg requestId,merchantEntity,agreementId,encumbranceId,securedObligations,defaultEventRef,closeOutRef,requestedAmount,currency,legalEffectRef,requestedAt
  if requestId="" | merchantEntity="" | agreementId="" | encumbranceId="" | defaultEventRef="" | closeOutRef="" then raise syntax 88.900 array("invalid collateral realisation request")
  if requestedAmount<=0 | legalEffectRef="" then raise syntax 88.900 array("realisation requires positive amount and Legal Effect evidence")
::method requestId; expose requestId; return requestId
::method merchantEntity; expose merchantEntity; return merchantEntity
::method agreementId; expose agreementId; return agreementId
::method encumbranceId; expose encumbranceId; return encumbranceId
::method securedObligations; expose securedObligations; return securedObligations
::method defaultEventRef; expose defaultEventRef; return defaultEventRef
::method closeOutRef; expose closeOutRef; return closeOutRef
::method requestedAmount; expose requestedAmount; return requestedAmount
::method currency; expose currency; return currency
::method legalEffectRef; expose legalEffectRef; return legalEffectRef
::method requestedAt; expose requestedAt; return requestedAt


::class FBCollateralRealisationDecision public
::method init
  expose decisionId requestId accepted coreAuthorityRef realisedAmount currency settlementRef decidedAt reasonCode
  use strict arg decisionId,requestId,accepted,coreAuthorityRef,realisedAmount,currency,settlementRef,decidedAt,reasonCode=""
  if decisionId="" | requestId="" | coreAuthorityRef="" then raise syntax 88.900 array("invalid collateral realisation decision")
  if accepted & (realisedAmount<0 | settlementRef="") then raise syntax 88.900 array("accepted realisation lacks settlement evidence")
::method decisionId; expose decisionId; return decisionId
::method requestId; expose requestId; return requestId
::method accepted; expose accepted; return accepted
::method coreAuthorityRef; expose coreAuthorityRef; return coreAuthorityRef
::method realisedAmount; expose realisedAmount; return realisedAmount
::method currency; expose currency; return currency
::method settlementRef; expose settlementRef; return settlementRef
::method decidedAt; expose decidedAt; return decidedAt
::method reasonCode; expose reasonCode; return reasonCode


::class FBMerchantCollateralProtocolValidator public
::method validateControlDecision
  use strict arg request,decision
  if \request~isA(.FBCollateralControlRequest) | \decision~isA(.FBCollateralControlDecision) then raise syntax 88.900 array("control request/decision types required")
  if decision~requestId<>request~requestId then raise syntax 88.900 array("control decision request identity mismatch")
  if \decision~accepted then return .false
  if decision~assetOwner<>request~collateralProvider then raise syntax 88.900 array("Core ownership does not match collateral provider")
  if decision~currency<>request~currency then raise syntax 88.900 array("control currency mismatch")
  if decision~controlledAmount>request~requestedAmount then raise syntax 88.900 array("Core control exceeds requested amount")
  if \decision~usable then raise syntax 88.900 array("Core decision did not establish enforceable control")
  return .true

::method validateRealisationDecision
  use strict arg request,decision
  if \request~isA(.FBCollateralRealisationRequest) | \decision~isA(.FBCollateralRealisationDecision) then raise syntax 88.900 array("realisation request/decision types required")
  if decision~requestId<>request~requestId then raise syntax 88.900 array("realisation decision request identity mismatch")
  if \decision~accepted then return .false
  if decision~currency<>request~currency then raise syntax 88.900 array("realisation currency mismatch")
  if decision~realisedAmount>request~requestedAmount then raise syntax 88.900 array("Core realised more than requested")
  if decision~settlementRef="" then raise syntax 88.900 array("realisation lacks Core settlement reference")
  return .true
