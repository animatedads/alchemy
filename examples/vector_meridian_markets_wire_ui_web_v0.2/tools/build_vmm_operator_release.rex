parse arg output
if output="" then do
  say "usage: build_vmm_operator_release.rex OUTPUT_JSON"
  exit 2
end
b=.VMMWireUIDesignFixture~build
c=.WireUICompiler~new
r=c~compile(b["workspace"],b["release"])
if \r~ok then do
  say "compile failed:" r~code r~detail
  exit 1
end
pkg=r~value
.json~toJsonFile(output,pkg~asWire,.true)
say "VMM_WIRE_UI_RELEASE="pkg~packageId"@"pkg~packageVersion
say "VMM_WIRE_UI_RELEASE_CONTENT_ADDRESS="pkg~contentAddress
say "VMM_WIRE_UI_DEFINITIONS="pkg~definitions~items
say "VMM_WIRE_UI_JOURNEY_PLANS="pkg~journeyPlans~items
exit 0
::requires "VMMWireUIDesignFixture.cls"
::requires "json.cls"
