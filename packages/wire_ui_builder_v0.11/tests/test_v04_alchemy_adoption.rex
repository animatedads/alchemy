call test
say "PASS v0.4 AlchemyObject STANDARD adoption 4"
exit 0

test:
  jr=.WireUIArtifactRef~new("JOURNEY","J","1","sealed")
  row=.table~new; row["elementId"]="E"; row["span"]=12
  composition=.WireUICompositionDesign~new("LAYOUT","1",jr,"HUMAN_VISUAL","HOME","GRID12",.array~of(row))
  project=.WireUIBuilderProject~new("ADOPT.V04","Adoption v0.4")
  spec=.table~new; spec["publishVersion"]="1"; spec["journeyId"]="J"; spec["profile"]="HUMAN_VISUAL"; spec["stateId"]="HOME"; spec["layoutModel"]="GRID12"; spec["placements"]=.array~of(row)
  payload=.table~new; payload["artifactId"]="LAYOUT"; payload["spec"]=spec
  op=.WireUIDesignOperation~new("v04-adopt-op","DESIGN.COMPOSITION.DRAFT",0,.nil,payload,"TEST")
  r=project~applyOperation(op); call assert r~ok,"composition draft"
  draft=project~draft("COMPOSITION","LAYOUT")
  do o over .array~of(composition,project,draft,op)
    vr=.AlchemyAdoptionVerifier~verify(o,"STANDARD")
    if \vr~ok then do
      say "FAIL adoption" o~class~id vr~failures~items
      do f over vr~failures; say f["code"] f["message"]; end
      exit 1
    end
  end
  return
assert: use arg ok,msg; if \ok then raise syntax 88.900 array("ASSERT",msg); return
::requires "WireUIBuilderAll.cls"
::requires "AlchemyAdoption.cls"
