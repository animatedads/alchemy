/* v0.8 server-authoritative render-profile and definition-manifest acceptance. */
call main
exit 0

main: procedure
  app=buildApp()
  policy=.WireUIRenderProfilePolicy~new("generic")
  call must policy~registerFingerprint("large.fine.rm0.light.d1.s1.r1","large-fine"),"profile mapping"
  call must app~setRenderProfilePolicy(policy),"set render policy"

  hello=.table~new
  hello["type"]=.WireUIProtocol~UI_HELLO
  hello["messageId"]="hello-1"
  hello["applicationId"]=app~applicationId
  hello["sessionId"]=app~sessionId
  hello["accessPointId"]=app~accessPointId
  hello["capabilityFingerprint"]="large.fine.rm0.light.d1.s1.r1"
  caps=.table~new; caps["viewportClass"]="large"; caps["pointer"]="fine"
  hello["renderCapabilities"]=caps
  r=app~receive(hello); call must r,"hello"
  call expect app~renderProfileId="large-fine","server selects renderer profile"

  out=app~drainOutbound
  call expect out~items>=2,"hello emits bootstrap messages"
  rp=out[1]
  call expect rp["type"]=.WireUIProtocol~UI_RENDER_PROFILE,"render profile first"
  call expect rp["profileId"]="large-fine","profile id on wire"
  call expect rp["definitions"]~items=2,"manifest contains active/prefetch definitions only"
  manifestId=rp["manifestId"]
  call expect manifestId<>"","manifest identity present"
  call expect \findDefinition(rp["definitions"],"INSURANCE_TERMS",1),"inactive on-demand definition absent"

  forged=.table~new
  forged["type"]=.WireUIProtocol~UI_DEFINITION_REQUIRED
  forged["messageId"]="req-forged"
  forged["manifestId"]=manifestId
  forged["profileId"]="large-fine"
  f=.table~new; f["id"]="INSURANCE_TERMS"; f["version"]=1; f["contentAddress"]=app~definition("INSURANCE_TERMS@1")~contentAddress
  forged["definitions"]=.array~of(f)
  r=app~receive(forged)
  call expect \r~ok & r~code="DEFINITION_NOT_AUTHORISED_BY_MANIFEST","manifest blocks catalogue probing"

  req=.table~new
  req["type"]=.WireUIProtocol~UI_DEFINITION_REQUIRED
  req["messageId"]="req-cold"
  req["manifestId"]=manifestId
  req["profileId"]="large-fine"
  refs=.array~new
  do e over rp["definitions"]; refs~append(e); end
  req["definitions"]=refs
  r=app~receive(req); call must r,"cold definition request"
  delivered=app~drainOutbound
  call expect delivered~items=2,"cold request queues two definitions"
  call expect delivered[1]["type"]=.WireUIProtocol~UI_DEFINITION,"definition delivery semantic type"

  dup=.table~new; do k over req~allIndexes; dup[k]=req[k]; end
  dup["messageId"]="req-duplicate"
  r=app~receive(dup); call must r,"duplicate logical definition request"
  call expect r~code="DEFINITION_ALREADY_QUEUED","same manifest does not duplicate definition payload"
  call expect app~drainOutbound~items=0,"no duplicate definition messages"

  oldManifest=app~currentDefinitionManifest~manifestId
  call must app~activateSubscription("TERMS"),"activate on-demand subscription"
  call must app~refreshDefinitionManifest(.true),"refresh manifest after authorised change"
  changed=app~drainOutbound
  call expect changed~items=1 & changed[1]["type"]=.WireUIProtocol~UI_DEFINITION_MANIFEST,"manifest update emitted"
  call expect changed[1]["manifestId"]<>oldManifest,"manifest id changes with authorised definition set"
  call expect findDefinition(changed[1]["definitions"],"INSURANCE_TERMS",1),"newly authorised exact definition appears"

  stale=.table~new; do k over req~allIndexes; stale[k]=req[k]; end
  stale["messageId"]="req-stale-manifest"
  r=app~receive(stale)
  call expect \r~ok & r~code="DEFINITION_MANIFEST_MISMATCH","stale manifest request rejected"

  say "PASS render-profile/definition-manifest cache contract"
  return

buildApp: procedure
  view=.WireUIView~new("FlyLo.Search","root")
  slots=.table~new; slots["visible"]=.true
  call must view~createInstance("root","FLYLO_SHELL@1",slots),"root"
  search=.table~new; search["visible"]=.true
  call must view~createInstance("search","FLIGHT_SEARCH@1",search,"root"),"search"
  projection=.WireUIProjection~new
  app=.WireUIApplication~new("FLYLO","S1","AP1",view,projection)
  call must app~registerDefinition(.WireUIElementDefinition~new("FLYLO_SHELL","1","PANEL","","","",.nil,"shell-ca")),"shell def"
  call must app~registerDefinition(.WireUIElementDefinition~new("FLIGHT_SEARCH","1","FORM","FLIGHT.SEARCH","","",.nil,"search-ca")),"search def"
  call must app~registerDefinition(.WireUIElementDefinition~new("INSURANCE_TERMS","1","DOCUMENT","","","",.nil,"terms-ca")),"terms def"
  active=.WireUISubscription~new("SEARCH","1","active search","policy:search")
  active~addDefinition("FLYLO_SHELL@1"); active~addDefinition("FLIGHT_SEARCH@1"); active~activate; app~addSubscription(active)
  terms=.WireUISubscription~new("TERMS","1","explicit insurance terms","policy:terms")
  terms~addDefinition("INSURANCE_TERMS@1"); app~addSubscription(terms)
  return app

findDefinition: procedure
  use arg entries,id,version
  do e over entries
    if e["id"]=id & e["version"]=version then return .true
  end
  return .false

must: procedure
  use arg r,label
  if \r~ok then do; say "FAIL" label r~code r~detail; exit 2; end
  return

expect: procedure
  use arg condition,label
  if \condition then do; say "FAIL" label; exit 3; end
  say "ok" label
  return

::requires "WireUIAll.cls"
