/* build_source_graph.rex - first self-hosted Development Floor tool. */
parse arg sourceDir outputDir
if sourceDir = "" then sourceDir = "src"
if outputDir = "" then outputDir = "state"
call SysMkDir outputDir
graph = .DFSourceGraph~new
graph~scanDirectory(sourceDir)
graph~writeJson(outputDir || "/source_graph.json")
graph~writeHierarchy(outputDir || "/class_hierarchy.txt")
say "SOURCE_GRAPH files=" graph~files~items "output=" outputDir
exit 0
::requires "SourceGraph.cls"
