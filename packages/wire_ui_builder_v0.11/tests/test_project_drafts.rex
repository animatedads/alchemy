call test
say "PASS test_project_drafts"
exit 0

test:
  p=.WireUIBuilderProject~new("SELF.TEST","Self Test")
  s=.table~new; s["publishVersion"]="1"; s["primitive"]="FORM"
  payload=.table~new; payload["artifactId"]="EDITOR"; payload["spec"]=s
  op1=.WireUIDesignOperation~new("draft-1","DESIGN.COMPONENT.DRAFT",0,.nil,payload,"TEST")
  r=p~applyOperation(op1); call assert r~ok,"initial draft accepted"
  call assert p~revision=1,"project revision 1"
  call assert p~workspace~allArtifacts~items=0,"draft edit does not create immutable artifact"

  s2=.table~new; s2["publishVersion"]="1"; s2["primitive"]="TOKEN_FORM"
  payload2=.table~new; payload2["artifactId"]="EDITOR"; payload2["spec"]=s2
  op2=.WireUIDesignOperation~new("draft-2","DESIGN.COMPONENT.DRAFT",1,.nil,payload2,"TEST")
  r=p~applyOperation(op2); call assert r~ok,"second draft accepted"
  call assert p~revision=2,"project revision 2"
  call assert p~workspace~allArtifacts~items=0,"many edits still no public version"
  call assert p~draft("COMPONENT","EDITOR")~spec["primitive"]="TOKEN_FORM","latest draft exact"
  return
assert: use arg ok,msg; if \ok then raise syntax 88.900 array("ASSERT",msg); return
::requires "WireUIBuilderAll.cls"
