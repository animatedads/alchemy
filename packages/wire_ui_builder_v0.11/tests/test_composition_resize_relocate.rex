call test
say "PASS test_composition_resize_relocate"
exit 0

test:
  p=.WireUIBuilderProject~new("VISUAL.OPS.TEST")
  call draft p,"DESIGN.COMPOSITION.DRAFT","LAYOUT",compositionSpec()
  payload=.table~new; payload["artifactId"]="LAYOUT"; payload["placementKey"]="A||DEFAULT"; payload["span"]=7; payload["rowSpan"]=2
  op=.WireUIDesignOperation~new("resize-1","DESIGN.COMPOSITION.RESIZE",p~revision,.nil,payload,"TEST")
  r=p~applyOperation(op); call assert r~ok,"resize accepted"
  row=p~draft("COMPOSITION","LAYOUT")~spec["placements"][1]
  call assert row["span"]=7 & row["rowSpan"]=2,"resize stored in draft"
  call assert p~workspace~allArtifacts~items=0,"resize does not publish"

  payload=.table~new; payload["artifactId"]="LAYOUT"; payload["placementKey"]="A||DEFAULT"; payload["region"]="sidebar"
  op=.WireUIDesignOperation~new("relocate-1","DESIGN.COMPOSITION.RELOCATE",p~revision,.nil,payload,"TEST")
  r=p~applyOperation(op); call assert r~ok,"relocate accepted"
  row=p~draft("COMPOSITION","LAYOUT")~spec["placements"][1]
  call assert row["region"]="sidebar","region stored in draft"
  call assert p~revision=3,"draft + resize + relocate revisioned"
  call assert p~workspace~allArtifacts~items=0,"relocate does not publish"
  return

draft:
  use arg p,verb,id,spec
  payload=.table~new; payload["artifactId"]=id; payload["spec"]=spec
  op=.WireUIDesignOperation~new("op-"p~revision"-"id,verb,p~revision,.nil,payload,"TEST")
  r=p~applyOperation(op); if \r~ok then raise syntax 88.900 array(r~code,r~detail); return
compositionSpec:
  s=.table~new; s["publishVersion"]="1"; s["journeyId"]="J"; s["profile"]="HUMAN_VISUAL"; s["stateId"]="HOME"; s["layoutModel"]="GRID12"
  rows=.array~new
  do name over .array~of("A","B")
    row=.table~new; row["elementId"]=name; row["projectionId"]=""; row["viewportClass"]="DEFAULT"; row["region"]="main"; row["order"]=rows~items*10+10; row["span"]=6; row["rowSpan"]=1; row["align"]="STRETCH"; rows~append(row)
  end
  s["placements"]=rows; return s
assert: use arg ok,msg; if \ok then raise syntax 88.900 array("ASSERT",msg); return
::requires "WireUIBuilderAll.cls"
