parse arg output
if output="" then do; say "usage: build_merchant_package.rex OUTPUT_JSON"; exit 2; end
design=.FBMerchantWireUIDesignFixture~build
r=.WireUICompiler~new~compile(design["workspace"],design["release"])
if \r~ok then do; say r~code r~detail; exit 3; end
pkg=r~value
.json~toJsonFile(output,pkg~asWire,.true)
say "MERCHANT_WIRE_PACKAGE" pkg~packageId pkg~packageVersion pkg~contentAddress design["release"]~contentAddress pkg~definitions~items
exit 0
::requires "json.cls"
::requires "FBMerchantWireUIDesignFixture.cls"
