call test
say "PASS test_builder_studio_publish"
exit 0

test:
  parse source . . script
  sourceRoot=filespec("P",script); if sourceRoot~right(6)="tests/" then sourceRoot=sourceRoot~left(sourceRoot~length-6)
  c=.WireUISourceCatalogue~new("BUILDER_SELF_SOURCE"); call assert c~addTree(sourceRoot,"*.cls",.true,"builder")~ok,"scan"; call assert c~seal~ok,"seal"
  p=.WireUIBuilderStudioFixture~build(c)
  before=p~revision
  /* Simulate a visual/AI material edit without publishing another artifact version. */
  old=p~draft("MATERIAL","WIRE_UI_BUILDER_MATERIAL")~spec
  tokens=.WireUIDesignUtil~copyTable(old["tokens"]); tokens["space.unit"]="10"
  spec=.WireUIDesignUtil~copyTable(old); spec["tokens"]=tokens
  payload=.table~new; payload["artifactId"]="WIRE_UI_BUILDER_MATERIAL"; payload["spec"]=spec
  op=.WireUIDesignOperation~new("self-material-edit","DESIGN.MATERIAL.DRAFT",before,.nil,payload,"AI:SELF_TEST","exercise Builder over its own source-backed Studio")
  r=p~applyOperation(op); call assert r~ok,"self edit applied"
  call assert p~workspace~artifact("MATERIAL","WIRE_UI_BUILDER_MATERIAL","1")==.nil,"edit did not publish"
  pr=p~publish("WIRE_UI_BUILDER_STUDIO","0.6")
  call assert pr~ok,"studio published"
  out=pr~value; pkg=out["package"]; release=out["release"]
  call assert release~ref<>.nil,"release sealed"
  call assert p~workspace~artifact("MATERIAL","WIRE_UI_BUILDER_MATERIAL","1")<>.nil,"one material version published"
  call assert pkg~definitions~items=23,"twenty-three Studio projections compiled"
  call assert pkg~journeyPlans~items=1,"one human visual journey plan"
  call assert pkg~materials~items=1,"one material compiled"
  call assert pkg~compositions~items=6,"six Studio compositions compiled"
  found=.false
  do d over pkg~definitions
    if d["definitionKey"]="WUIB_COMPONENT_EDITOR@1" then found=.true
  end
  call assert found,"component editor is real compiled definition"
  wire=release~asWire
  md=wire["metadata"]
  call assert md["builderProjectRevision"]=p~revision,"release records project revision"
  pm=md["builderProjectMetadata"]
  call assert pm["sourceCatalogueContentAddress"]=c~contentAddress,"release retains exact self-source catalogue provenance"
  call assert pm["sourceFileCount"]=c~fileCount,"release retains self-source file count"
  return
assert: use arg ok,msg; if \ok then raise syntax 88.900 array("ASSERT",msg); return
::requires "WireUIBuilderStudioFixture.cls"
::requires "WireUISourceCatalogue.cls"
