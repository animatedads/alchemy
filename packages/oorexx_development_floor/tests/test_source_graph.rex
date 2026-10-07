parse arg sourceDir
if sourceDir = "" then sourceDir = "src"
g = .DFSourceGraph~new
g~scanDirectory(sourceDir)
call assertTrue g~files~items >= 3, "source files"
c = g~classNamed("DFBUGRECORD")
call assertTrue c <> .nil, "DFBugRecord present"
call assertTrue c~methodNamed("repairPermitted") <> .nil, "repairPermitted present"
call assertTrue c~methods~items > 0, "methods recorded"
sg = g~classNamed("DFSOURCEGRAPH")
call assertTrue sg <> .nil, "source graph self discovered"
call assertTrue sg~methodNamed("writeJson") <> .nil, "writeJson self discovered"
say "PASS test_source_graph"
exit 0
assertTrue: procedure
  use arg value, label
  if \value then do
    say "FAIL" label
    exit 1
  end
  return
::requires "SourceGraph.cls"
