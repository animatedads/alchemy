parse arg output sourceRoot
if output="" | sourceRoot="" then do; say "usage: build_studio_package.rex OUTPUT_JSON SOURCE_ROOT"; exit 2; end
catalogue=.WireUISourceCatalogue~new("WIRE_UI_BUILDER_V011_SOURCE")
r=catalogue~addTree(sourceRoot,"*.cls",.true,"builder"); if \r~ok then do; say r~code r~detail; exit 4; end
r=catalogue~seal; if \r~ok then do; say r~code; exit 5; end
project=.WireUIBuilderStudioFixture~build(catalogue)
r=project~publish("WIRE_UI_BUILDER_STUDIO","0.11"); if \r~ok then do; say r~code r~detail; exit 6; end
pkg=r~value["package"]
.json~toJsonFile(output,pkg~asWire,.true)
say "BUILDER_STUDIO_PACKAGE" pkg~contentAddress catalogue~contentAddress project~revision catalogue~fileCount
exit 0
::requires "json.cls"
::requires "WireUIBuilderStudioFixture.cls"
::requires "WireUISourceCatalogue.cls"
