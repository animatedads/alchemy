call test
say "PASS test_composition_move"
exit 0

test:
  p=.WireUIBuilderProject~new("MOVE.TEST")
  call draft p,"DESIGN.COMPOSITION.DRAFT","LAYOUT",compositionSpec()
  before=p~draft("COMPOSITION","LAYOUT")~spec["placements"]
  call assert before[1]["elementId"]="A" & before[3]["elementId"]="C","initial order"
  payload=.table~new; payload["artifactId"]="LAYOUT"; payload["sourcePlacementKey"]="C||DEFAULT"; payload["targetPlacementKey"]="A||DEFAULT"
  op=.WireUIDesignOperation~new("move-1","DESIGN.COMPOSITION.MOVE",p~revision,.nil,payload,"TEST")
  r=p~applyOperation(op); call assert r~ok,"move accepted"
  after=p~draft("COMPOSITION","LAYOUT")~spec["placements"]
  call assert after[1]["elementId"]="C","C moved before A"
  call assert after[2]["elementId"]="A","A follows C"
  call assert after[1]["order"]=10 & after[2]["order"]=20 & after[3]["order"]=30,"orders renormalised"
  call assert p~workspace~allArtifacts~items=0,"direct manipulation remains draft only"
  return

draft:
  use arg p,verb,id,spec
  payload=.table~new; payload["artifactId"]=id; payload["spec"]=spec
  op=.WireUIDesignOperation~new("op-"p~revision"-"id,verb,p~revision,.nil,payload,"TEST")
  r=p~applyOperation(op); if \r~ok then raise syntax 88.900 array(r~code,r~detail); return
compositionSpec:
  s=.table~new; s["publishVersion"]="1"; s["journeyId"]="J"; s["profile"]="HUMAN_VISUAL"; s["stateId"]="HOME"; s["layoutModel"]="GRID12"
  rows=.array~new
  do name over .array~of("A","B","C")
    row=.table~new; row["elementId"]=name; row["projectionId"]=""; row["viewportClass"]="DEFAULT"; row["region"]="main"; row["order"]=rows~items*10+10; row["span"]=4; row["rowSpan"]=1; row["align"]="STRETCH"; rows~append(row)
  end
  s["placements"]=rows; return s
assert: use arg ok,msg; if \ok then raise syntax 88.900 array("ASSERT",msg); return
::requires "WireUIBuilderAll.cls"
