/* build_documentation_queue.rex - dog-fooded Gwen segment planner. */
parse arg sourceDir outputDir packageId
if sourceDir = "" then sourceDir = "src"
if outputDir = "" then outputDir = "state"
if packageId = "" then packageId = "DEVELOPMENT_FLOOR"
call SysMkDir outputDir
graph = .DFSourceGraph~new
graph~scanDirectory(sourceDir)
planner = .DFDocumentationPlanner~new
segments = planner~build(graph, packageId)
planner~writeJson(graph, packageId, outputDir || "/documentation_queue.json")
say "DOCUMENTATION_QUEUE segments=" segments~items "output=" outputDir
exit 0
::requires "DocumentationPlanner.cls"
