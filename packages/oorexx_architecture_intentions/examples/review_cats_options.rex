/* Demonstrate design review with no assumed legal/SSC/deployment authority. */
parse arg outputDirectory
if outputDirectory == '' then do
  say 'Usage: rexx examples/review_cats_options.rex existing-empty-directory'
  exit 2
end
catalog = .ArchitectureCatalog~fromFile('catalog/architecture_catalog.json')
planner = .ArchitecturePlanner~new(catalog)
project = planner~project('cats-review-demo','I Love Cats governed options')
project~domain~statement('I Love Cats needs a customer platform', -
  'business owner','discovery://kickoff')
scenarios = .ArchitectureScenarioComparison~new(planner)
scenarios~register(.ArchitectureScenario~new('local','Local pilot', -
  'Test requirements without premature clustering','architect'))
scenarios~register(.ArchitectureScenario~new('grid','RexxOS MU/MI', -
  'Compare continuity and distributed deployment obligations','architect'))
comparison = scenarios~compare(project)
review = .ArchitecturePromotionReview~new(comparison,'local', -
  'architect','Local design chosen for further investigation','decision://local')
review~disposition('grid','DEFERRED','architecture board', -
  'No evidence yet of multiple management units or mesh instances', -
  'decision://grid-later')
review~approve('independent-reviewer','review://pending-verification')
/* The claimed review is NOT identity verified, so this cannot request SSC. */
record = review~handoff
paths = .ArchitecturePromotionWriter~new~write(record,outputDirectory)
say 'Status:' record['status']
say 'Unresolved questions:' record['unresolved']['questions']~items
say 'SSC request produced:' record['sscSubmission'] \== .nil
say 'Files:' paths~items
::requires 'ArchitecturePromotion.cls'
