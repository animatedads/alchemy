parse arg sourceDir
if sourceDir = "" then sourceDir = "src"
graph = .DFSourceGraph~new
graph~scanDirectory(sourceDir)
planner = .DFDocumentationPlanner~new
segments = planner~build(graph, "DEVELOPMENT_FLOOR")
classCount = 0
methodCount = 0
do fileRecord over graph~files
  classCount += fileRecord~classes~items
  do classRecord over fileRecord~classes
    methodCount += classRecord~methods~items
  end
end
call assertEqual classCount + methodCount, segments~items, "one class segment plus one per method"
call assertEqual "PENDING", segments[1]["state"], "segment pending"
call assertTrue segments[1]["class"] <> "", "class named"
say "PASS test_documentation_planner segments=" segments~items
exit 0
assertEqual: procedure
  use arg expected, actual, label
  if expected <> actual then do
    say "FAIL" label "expected=" expected "actual=" actual
    exit 1
  end
  return
assertTrue: procedure
  use arg value, label
  if \value then do
    say "FAIL" label
    exit 1
  end
  return
::requires "DocumentationPlanner.cls"
