/* Must fail: architect cannot claim independent second-party approval. */
cat = .ArchitectureCatalog~fromFile('catalog/architecture_catalog.json')
planner = .ArchitecturePlanner~new(cat)
p = planner~project('self','Negative self-approval test')
engine = .ArchitectureScenarioComparison~new(planner)
engine~register(.ArchitectureScenario~new('selected','Selected','Primary','architect'))
review = .ArchitecturePromotionReview~new(engine~compare(p), 'selected', -
  'architect','Choose selected','evidence://1')
review~approve('architect','evidence://2')
say 'FAIL accepted self-approval'
exit 0
::requires 'ArchitecturePromotion.cls'
