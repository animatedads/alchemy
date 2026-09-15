/* v0.9 reconciliation acceptance: exact renderer manifest and material set coexist on one bound release. */
b=.WireUIServerBuilderFixture~build
compiler=.WireUICompiler~new
cr=compiler~compile(b["workspace"],b["release"]); call mustDesign cr,"compile"
pkg=cr~value
wirePackage=.table~new
wirePackage["releaseRef"]=pkg~releaseRef~asWire
wirePackage["contentAddress"]=pkg~contentAddress
wirePackage["definitions"]=pkg~definitions
wirePackage["journeyPlans"]=pkg~journeyPlans
wirePackage["materials"]=pkg~materials
wirePackage["experiments"]=pkg~experiments
catalogue=.WireUICompiledCatalogue~new(wirePackage)

manager=.ObjectQueueManager~new("",.QueueGraphPayloadCodec~new,"admin")
server=.WireUIServer~new(manager)
view=.WireUIView~new("OLA.RECONCILED","root")
projection=.WireUIProjection~new
app=.WireUIApplication~new("ola-v09","sess-v09","ap-v09",view,projection)
server~registerApplication(app)
call must server~provisionAccessPoint(app~accessPointId,"browser-gateway"),"provision"
call must app~bindCompiledRelease(catalogue,.WireUIProtocol~PROFILE_HUMAN_VISUAL),"bind"

policy=.WireUIRenderProfilePolicy~new("generic")
call must app~setRenderProfilePolicy(policy),"render policy"
hello=.table~new
hello["type"]=.WireUIProtocol~UI_HELLO
hello["messageId"]="hello-v09"
hello["applicationId"]=app~applicationId
hello["sessionId"]=app~sessionId
hello["accessPointId"]=app~accessPointId
hello["renderCapabilities"]=.table~new
call must app~receive(hello),"hello"
out=app~drainOutbound
call expect out~items>=2,"hello emitted renderer bootstrap"
rp=out[1]
call expect rp["type"]=.WireUIProtocol~UI_RENDER_PROFILE,"render profile first"
call expect rp["siteRelease"]["contentAddress"]=b["release"]~contentAddress,"manifest bound exact release"
call expect rp["manifestId"]<>"","exact definition manifest present"

mr=app~materialSetMessages; call must mr,"material messages"
call expect mr~value~items=1,"one material set"
mat=mr~value[1]
call expect mat["type"]=.WireUIProtocol~UI_MATERIAL_SET,"material message type"
call expect mat["siteRelease"]["contentAddress"]=rp["siteRelease"]["contentAddress"],"material and manifest share exact release"
call expect mat["contentAddress"]=b["material"]~contentAddress,"material identity preserved"

call must server~enqueueMaterialsToAccessPoint(app~applicationId),"enqueue materials"
claim=manager~claim(server~directQueueName(app~accessPointId,"OUT"),"browser-gateway"); call must claim,"claim material"
call expect claim~value~payload["type"]=.WireUIProtocol~UI_MATERIAL_SET,"Queue Fabric carries reconciled material"
ignore=manager~ack(server~directQueueName(app~accessPointId,"OUT"),claim~value~packageId,claim~value~claimToken,"browser-gateway")

say "PASS v0.9 renderer-manifest + material reconciliation"
exit 0

mustDesign: procedure
 use arg r,l
 if \r~ok then do; say "FAIL" l r~code r~detail; exit 1; end
 return
must: procedure
 use arg r,l
 if \r~ok then do; say "FAIL" l r~code r~detail; exit 1; end
 return
expect: procedure
 use arg c,l
 if \c then do; say "FAIL" l; exit 1; end
 say "ok" l
 return

::requires "WireUIServerBuilderFixture.cls"
::requires "WireUICompiler.cls"
::requires "WireUIAll.cls"
::requires "WireUIServer.cls"
