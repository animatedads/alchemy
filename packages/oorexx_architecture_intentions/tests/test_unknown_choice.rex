/* Expected to terminate with a visible ooRexx syntax error, not an invented choice. */
catalog = .ArchitectureCatalog~fromFile('catalog/architecture_catalog.json')
planner = .ArchitecturePlanner~new(catalog)
project = planner~project('bad-choice','Bad choice')
project~answer('deployment_model','arbitrary_unqualified_name','unsafe','tester')
say 'FAIL invalid option accepted'
exit 0
::requires 'ArchitecturePlanner.cls'
