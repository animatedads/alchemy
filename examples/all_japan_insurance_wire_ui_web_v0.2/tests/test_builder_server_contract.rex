b=.AllJapanInsuranceWireUIFixture~build
c=.WireUICompiler~new
r=c~compile(b["workspace"],b["release"])
call mustDesign r,"compile AJI release"
p=r~value
call expect p~definitions~items=6,"six AJI human projections"
call expect p~journeyPlans~items=1,"one AJI human journey"
call expect b["release"]~releaseId="ALL_JAPAN_INSURANCE_OPERATIONS","AJI release id"
call expect b["release"]~version="2","AJI release version 2"
wire=.table~new;wire["releaseRef"]=p~releaseRef~asWire;wire["contentAddress"]=p~contentAddress;wire["definitions"]=p~definitions;wire["journeyPlans"]=p~journeyPlans;wire["materials"]=p~materials;wire["experiments"]=p~experiments
catalogue=.WireUICompiledCatalogue~new(wire)
view=.WireUIView~new("AJI.RUNTIME","root"); projection=.WireUIProjection~new
app=.WireUIApplication~new("aji-ui-app","aji-session","aji-ap",view,projection)
r=app~bindCompiledRelease(catalogue,.WireUIProtocol~PROFILE_HUMAN_VISUAL); call must r,"bind AJI compiled release"
call expect app~siteReleaseBinding~releaseId="ALL_JAPAN_INSURANCE_OPERATIONS","server retains exact AJI release"
call expect app~siteReleaseBinding~version="2","server retains exact AJI release version"
call expect app~definition("AJI_WUI_PORTFOLIO@2") \== .nil,"portfolio definition loaded"
call expect app~definition("AJI_WUI_POLICY_LIST@1") \== .nil,"policy-list definition loaded"
call expect app~definition("AJI_WUI_POLICY@2") \== .nil,"policy detail definition loaded"
call expect app~definition("AJI_WUI_BILLING@2") \== .nil,"billing definition loaded"
call expect app~definition("AJI_WUI_CLAIM@2") \== .nil,"claim definition loaded"
call expect app~definition("AJI_WUI_ACCOUNTING@2") \== .nil,"accounting definition loaded"
/* Browser semantic adapter v0.4-dev4 supports these exact server primitives. */
do key over .array~of("AJI_WUI_PORTFOLIO@2","AJI_WUI_POLICY@2","AJI_WUI_BILLING@2","AJI_WUI_CLAIM@2","AJI_WUI_ACCOUNTING@2")
  call expect app~definition(key)~primitive="SEMANTIC_RECORD",key" uses browser-supported semantic record"
end
call expect app~definition("AJI_WUI_POLICY_LIST@1")~primitive="OFFER_LIST","policy list uses browser-supported collection"
say "PASS AJI Builder v0.11 -> Wire UI Server v0.17 contract"
exit 0
mustDesign: procedure; use arg r,l; if \r~ok then do; say "FAIL" l r~code r~detail; exit 1; end; return
must: procedure; use arg r,l; if \r~ok then do; say "FAIL" l r~code r~detail; exit 1; end; return
expect: procedure; use arg c,l; if \c then do; say "FAIL" l; exit 1; end; say "ok" l; return
::requires "AllJapanInsuranceWireUIFixture.cls"
::requires "WireUICompiler.cls"
::requires "WireUIAll.cls"
