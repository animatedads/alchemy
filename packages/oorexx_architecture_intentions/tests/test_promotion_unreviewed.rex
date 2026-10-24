/* Must fail: approval cannot silently drop rejected alternatives. */
cat = .ArchitectureCatalog~fromFile('catalog/architecture_catalog.json')
planner = .ArchitecturePlanner~new(cat)
p = planner~project('unreviewed','Negative review test')
engine = .ArchitectureScenarioComparison~new(planner)
engine~register(.ArchitectureScenario~new('selected','Selected','Primary','architect'))
engine~register(.ArchitectureScenario~new('other','Other','Alternative','architect'))
review = .ArchitecturePromotionReview~new(engine~compare(p), 'selected', -
  'architect','Choose selected','evidence://1')
review~approve('reviewer','evidence://2')
say 'FAIL accepted unreviewed alternative'
exit 0
::requires 'ArchitecturePromotion.cls'
