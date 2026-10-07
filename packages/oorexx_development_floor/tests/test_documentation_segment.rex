s = .DFDocumentationSegment~new("DOC-1", "ALCHEMY_LOG", "LogStore", "append", "r17")
call assertEqual "PENDING", s~state, "initial"
s~start
call assertEqual "ACTIVE", s~state, "active"
s~complete
call assertEqual "COMPLETE", s~state, "complete"
say "PASS test_documentation_segment"
exit 0
assertEqual: procedure
  use arg expected, actual, label
  if expected <> actual then do
    say "FAIL" label "expected=" expected "actual=" actual
    exit 1
  end
  return
::requires "DevelopmentFloor.cls"
