/* Merchant-side adapter from the arm's-length Core collateral protocol
 * into FederationBank Merchant Bank collateral evidence.
 */
::class FBMerchantCollateralAdapter public
::method init
  expose validator
  validator=.FBMerchantCollateralProtocolValidator~new

::method acceptControlDecision
  expose validator
  use strict arg merchantBank,request,decision,merchantAssetId
  if \merchantBank~isA(.FederationBankMerchantBank) then raise syntax 88.900 array("FederationBankMerchantBank required")
  if \validator~validateControlDecision(request,decision) then return .false
  asset=merchantBank~collateralAsset(merchantAssetId)
  agreement=merchantBank~collateralAgreement(request~agreementId)
  if asset==.nil | agreement==.nil then raise syntax 88.900 array("unknown Merchant collateral asset/agreement")
  if asset~coreAssetRef<>request~coreAssetRef then raise syntax 88.900 array("Core asset reference mismatch")
  if asset~owner<>request~collateralProvider | agreement~collateralProvider<>request~collateralProvider then raise syntax 88.900 array("collateral provider mismatch")
  if agreement~securedObligations<>request~securedObligations then raise syntax 88.900 array("secured obligation mismatch")
  r=.MBCollateralControlReceipt~new(decision~encumbranceId,request~agreementId,merchantAssetId,decision~coreAuthorityRef,decision~assetOwner,decision~encumbranceValid,decision~enforceable,decision~priority,decision~controlledAmount,decision~currency,decision~decidedAt)
  merchantBank~acknowledgeCoreControl(r)
  return r

::requires "FederationBankMerchantBank.cls"
::requires "FederationBankMerchantCollateralProtocol.cls"
