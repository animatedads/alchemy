/* Expected failure: a scenario exporter must never overwrite an old report. */
parse arg outputDirectory
cat = .ArchitectureCatalog~fromFile('catalog/architecture_catalog.json')
planner = .ArchitecturePlanner~new(cat)
p = planner~project('existing','Overwrite guard')
s = .ArchitectureScenario~new('local','Local','Proof','architect')
e = .ArchitectureScenarioComparison~new(planner)
e~register(s)
result = e~compare(p)
call .ArchitectureScenarioWriter~new~write(result,outputDirectory)
exit 0
::requires 'ArchitectureScenarioWriter.cls'
