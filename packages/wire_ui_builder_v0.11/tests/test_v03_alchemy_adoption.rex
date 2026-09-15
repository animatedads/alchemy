call test
say "PASS v0.3 AlchemyObject STANDARD adoption 5"
exit 0

test:
  parse source . . script
  root=filespec("P",script)"../src"
  p=.WireUIBuilderProject~new("ADOPT.V03","Adoption v0.3")
  s=.table~new; s["publishVersion"]="1"; s["primitive"]="PANEL"
  payload=.table~new; payload["artifactId"]="PANEL"; payload["spec"]=s
  op=.WireUIDesignOperation~new("v03-adopt-op","DESIGN.COMPONENT.DRAFT",0,.nil,payload,"TEST")
  r=p~applyOperation(op); if \r~ok then do; say "FAIL draft" r~code; exit 1; end
  draft=p~draft("COMPONENT","PANEL")
  cat=.WireUISourceCatalogue~new("ADOPTION_SOURCE"); r=cat~addTree(root,"WireUIBuilderProject.cls",.false,"src"); if \r~ok then do; say "FAIL source" r~code; exit 1; end; cat~seal
  sourceFile=cat~files[1]
  adapter=.WireUIBuilderProjectActionAdapter~new(p)
  objects=.array~of(p,draft,cat,sourceFile,adapter)
  do o over objects
    vr=.AlchemyAdoptionVerifier~verify(o,"STANDARD")
    if \vr~ok then do
      say "FAIL adoption" o~class~id vr~failures~items
      do f over vr~failures; say f["code"] f["message"]; end
      exit 1
    end
  end
  return
::requires "WireUIBuilderAll.cls"
::requires "AlchemyAdoption.cls"
