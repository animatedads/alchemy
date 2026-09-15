/* FederationBank Merchant Banking authoritative Wire UI runtime factory v0.1. */
::class FBMerchantWireAuthorityRuntimeFactory public
::constant VERSION "0.1"
::constant API_VERSION "federationbank.merchant.wire-authority-runtime/0.1"

::method buildFromAuthorities class
  use strict arg applicationId,sessionId,accessPointId,bank,risk,accounting,wirePackage,merchantEntity="FEDERATIONBANK_MERCHANT_BANK"
  adapter=.FBMerchantWireAuthorityProjectionAdapter~new(bank,risk,accounting)
  feed=.FBMerchantWireProjectionFeed~new
  return .FBMerchantWireRuntimeFactory~buildFromPackage(applicationId,sessionId,accessPointId,feed,wirePackage,merchantEntity,adapter)

::requires "FBMerchantWireUIApplication.cls"
::requires "FBMerchantWireAuthorityProjectionAdapter.cls"
