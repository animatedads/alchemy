catalog = .ArchitectureCatalog~fromFile('catalog/architecture_catalog.json')
planner = .ArchitecturePlanner~new(catalog)
project = planner~project('bad-component','Bad component')
project~feature('f1','Unknown component','must','test','tester',.Array~of('untrusted_provider'))
say 'FAIL invalid feature component accepted'
exit 0
::requires 'ArchitecturePlanner.cls'
