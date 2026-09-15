call test
say "PASS test_project_roundtrip"
exit 0

test:
  p=.WireUIBuilderStudioFixture~build
  path="/tmp/wire_ui_builder_project_v06.json"
  r=p~save(path); call assert r~ok,"project saved"
  lr=.WireUIBuilderProject~load(path); call assert lr~ok,"project loaded"
  p2=lr~value
  call assert p2~projectId=p~projectId,"project identity roundtrip"
  call assert p2~revision=p~revision,"project revision roundtrip"
  call assert p2~drafts~items=p~drafts~items,"draft count roundtrip"
  call assert p2~operations~items=p~operations~items,"operation ledger roundtrip"
  call assert p2~asWire["contentAddress"]=p~asWire["contentAddress"],"project content address roundtrip"
  do d over p~drafts
    d2=p2~draft(d~kind,d~artifactId)
    call assert d2<>.nil,"draft restored "d~key
    call assert d2~contentAddress=d~contentAddress,"draft content preserved "d~key
  end
  call sysFileDelete path
  return
assert: use arg ok,msg; if \ok then raise syntax 88.900 array("ASSERT",msg); return
::requires "WireUIBuilderStudioFixture.cls"
