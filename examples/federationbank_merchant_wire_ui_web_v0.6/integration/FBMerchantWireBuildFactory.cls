/* Authoring/test bridge. Builder is not a runtime dependency once package JSON is compiled. */
::class FBMerchantWireBuildFactory public
::method build class
  use arg applicationId,sessionId,accessPointId,feed,merchantEntity="FEDERATIONBANK_MERCHANT_BANK"
  design=.FBMerchantWireUIDesignFixture~build
  compiled=.WireUICompiler~new~compile(design["workspace"],design["release"]); if \compiled~ok then return compiled
  return .FBMerchantWireRuntimeFactory~buildFromPackage(applicationId,sessionId,accessPointId,feed,compiled~value~asWire,merchantEntity)
::requires "FBMerchantWireUIApplication.cls"
::requires "FBMerchantWireUIDesignFixture.cls"
