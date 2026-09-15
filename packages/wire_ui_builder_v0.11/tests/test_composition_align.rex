call test
say "PASS test_composition_align"
exit 0

test:
  p=.WireUIBuilderProject~new("ALIGN.TEST")
  call draft p,"DESIGN.COMPOSITION.DRAFT","LAYOUT",compositionSpec()
  payload=.table~new; payload["artifactId"]="LAYOUT"; payload["placementKey"]="A||DEFAULT"; payload["align"]="CENTER"
  op=.WireUIDesignOperation~new("align-1","DESIGN.COMPOSITION.ALIGN",p~revision,.nil,payload,"TEST")
  r=p~applyOperation(op); call assert r~ok,"align accepted"
  row=p~draft("COMPOSITION","LAYOUT")~spec["placements"][1]
  call assert row["align"]="CENTER","alignment stored in draft"
  call assert p~workspace~allArtifacts~items=0,"align does not publish"

  payload=.table~new; payload["artifactId"]="LAYOUT"; payload["placementKey"]="A||DEFAULT"; payload["align"]="MIDDLE"
  op=.WireUIDesignOperation~new("align-bad","DESIGN.COMPOSITION.ALIGN",p~revision,.nil,payload,"TEST")
  r=p~applyOperation(op); call assert \r~ok & r~code="COMPOSITION_ALIGN_INVALID","unknown alignment rejected"
  call assert p~revision=2,"rejected alignment does not advance revision"
  return

draft:
  use arg p,verb,id,spec
  payload=.table~new; payload["artifactId"]=id; payload["spec"]=spec
  op=.WireUIDesignOperation~new("op-"p~revision"-"id,verb,p~revision,.nil,payload,"TEST")
  r=p~applyOperation(op); if \r~ok then raise syntax 88.900 array(r~code,r~detail); return
compositionSpec:
  s=.table~new; s["publishVersion"]="1"; s["journeyId"]="J"; s["profile"]="HUMAN_VISUAL"; s["stateId"]="HOME"; s["layoutModel"]="GRID12"
  rows=.array~new
  row=.table~new; row["elementId"]="A"; row["projectionId"]=""; row["viewportClass"]="DEFAULT"; row["region"]="main"; row["order"]=10; row["span"]=6; row["rowSpan"]=1; row["align"]="STRETCH"; rows~append(row)
  s["placements"]=rows; return s
assert: use arg ok,msg; if \ok then raise syntax 88.900 array("ASSERT",msg); return
::requires "WireUIBuilderAll.cls"
