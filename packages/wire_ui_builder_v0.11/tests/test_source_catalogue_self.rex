call test
say "PASS test_source_catalogue_self"
exit 0

test:
  parse source . . script
  sourceRoot=filespec("P",script); if sourceRoot~right(6)="tests/" then sourceRoot=sourceRoot~left(sourceRoot~length-6)
  c=.WireUISourceCatalogue~new("BUILDER_SELF_SOURCE")
  r=c~addTree(sourceRoot,"*.cls",.true,"builder"); call assert r~ok,"source tree scanned"
  r=c~seal; call assert r~ok,"source catalogue sealed"
  call assert c~fileCount>=28,"whole Builder src tree scanned"
  call assert c~classCount>=20,"classes discovered"
  call assert c~methodCount>=200,"methods discovered"
  call assert c~attributeCount>=120,"attributes discovered"
  call assert c~constantCount>=2,"constants discovered"
  call assert c~contentAddress~left(10)="sourcecat-","source catalogue fingerprint"
  found=.false
  do f over c~files
    call assert f~path~left(1)<>"/","catalogue path is relocation-stable"
    if f~path="builder/src/WireUISourceCatalogue.cls" then do
      found=.true
      call assert f~constants~items>=0,"source file constants surface available"
      call assert f~packageOptions~items>=0,"source file package-options surface available"
    end
  end
  call assert found,"source catalogue includes itself"
  p=.WireUIBuilderStudioFixture~build(c)
  call assert p~drafts~items>=20,"studio authored from neutral drafts"
  call assert p~workspace~allArtifacts~items=0,"source-driven authoring still unpublished"
  return
assert: use arg ok,msg; if \ok then raise syntax 88.900 array("ASSERT",msg); return
::requires "WireUIBuilderStudioFixture.cls"
::requires "WireUISourceCatalogue.cls"
