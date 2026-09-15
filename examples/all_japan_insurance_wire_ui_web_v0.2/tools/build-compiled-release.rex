parse arg outputFile
if outputFile="" then do; say "output file required"; exit 2; end
b=.AllJapanInsuranceWireUIFixture~build
r=.WireUICompiler~new~compile(b["workspace"],b["release"])
if \r~ok then do; say "compile failed" r~code r~detail; exit 3; end
p=r~value
wire=.directory~new
wire["releaseRef"]=p~releaseRef~asWire
wire["contentAddress"]=p~contentAddress
wire["definitions"]=p~definitions
wire["journeyPlans"]=p~journeyPlans
wire["materials"]=p~materials
wire["experiments"]=p~experiments
call lineout outputFile,.JSON~toJSON(wire); call lineout outputFile
say "AJI_COMPILED_RELEASE" b["release"]~contentAddress p~contentAddress p~definitions~items p~journeyPlans~items
exit 0
::requires "json.cls"
::requires "AllJapanInsuranceWireUIFixture.cls"
::requires "WireUICompiler.cls"
