/* Builder MATERIAL -> Server exact release -> Queue Fabric UI_MATERIAL_SET. */
b=.WireUIServerBuilderFixture~build
compiler=.WireUICompiler~new
cr=compiler~compile(b["workspace"],b["release"]); call mustDesign cr,"compile"
pkg=cr~value
wirePackage=.table~new
wirePackage["releaseRef"]=pkg~releaseRef~asWire; wirePackage["contentAddress"]=pkg~contentAddress
wirePackage["definitions"]=pkg~definitions; wirePackage["journeyPlans"]=pkg~journeyPlans; wirePackage["materials"]=pkg~materials; wirePackage["experiments"]=pkg~experiments
catalogue=.WireUICompiledCatalogue~new(wirePackage)
manager=.ObjectQueueManager~new("",.QueueGraphPayloadCodec~new,"admin")
server=.WireUIServer~new(manager)
view=.WireUIView~new("OLA.MATERIAL","root"); projection=.WireUIProjection~new
app=.WireUIApplication~new("ola-material-app","sess-material","ap-material",view,projection)
server~registerApplication(app)
r=server~provisionAccessPoint(app~accessPointId,"browser-gateway"); call must r,"provision"
r=app~bindCompiledRelease(catalogue,.WireUIProtocol~PROFILE_HUMAN_VISUAL); call must r,"bind"
r=app~materialSetMessages; call must r,"material messages"
call expect r~value~items=1,"one material message"
m=r~value[1]
call expect m["type"]=.WireUIProtocol~UI_MATERIAL_SET,"material message type"
call expect m["materialId"]="WIRE_UI_SERVER_TEST_MATERIAL","material identity exact"
call expect m["version"]="1","material version exact"
call expect m["contentAddress"]=b["material"]~contentAddress,"material content address exact"
call expect m["tokens"]["space.unit"]="8","material token preserved"
call expect m["recipes"]["query.form"]="surface.primary/form.standard","material recipe preserved"
call expect m["siteRelease"]["contentAddress"]=b["release"]~contentAddress,"material binds site release"
r=server~enqueueMaterialsToAccessPoint(app~applicationId); call must r,"enqueue material"
claim=manager~claim(server~directQueueName(app~accessPointId,"OUT"),"browser-gateway"); call must claim,"browser material claim"
payload=claim~value~payload
call expect payload["type"]=.WireUIProtocol~UI_MATERIAL_SET,"Queue Fabric carries material"
call expect payload["contentAddress"]=b["material"]~contentAddress,"Queue Fabric preserves material version content"
ignore=manager~ack(server~directQueueName(app~accessPointId,"OUT"),claim~value~packageId,claim~value~claimToken,"browser-gateway")
say "PASS versioned material delivery Builder -> Server -> Queue Fabric"
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
