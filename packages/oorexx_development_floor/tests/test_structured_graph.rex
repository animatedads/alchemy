parse arg specPath
if specPath = "" then specPath = "spec/framework_tooling.json"
g = .DFStructuredGraphLoader~fromJsonFile(specPath)
call assertEqual "DEVELOPMENT_FLOOR", g~project~id, "project id"
call assertEqual "ooRexx", g~project~language, "language"
stages = g~stages
call assertEqual 1, stages~items, "stage count"
call assertEqual "S01", stages[1]~id, "stage id"
requirements = stages[1]~requirements
call assertEqual 3, requirements~items, "requirement count"
call assertEqual "S01-R03", requirements[3]~id, "dogfood requirement"
say "PASS test_structured_graph"
exit 0
assertEqual: procedure
  use arg expected, actual, label
  if expected <> actual then do
    say "FAIL" label "expected=" expected "actual=" actual
    exit 1
  end
  return
::requires "StructuredObjectGraph.cls"
