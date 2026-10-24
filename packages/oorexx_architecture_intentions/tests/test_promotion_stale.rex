/* Must fail: a changed comparison invalidates the approved generation. */
cat = .ArchitectureCatalog~fromFile('catalog/architecture_catalog.json')
planner = .ArchitecturePlanner~new(cat)
p = planner~project('stale','Negative stale test')
engine = .ArchitectureScenarioComparison~new(planner)
engine~register(.ArchitectureScenario~new('selected','Selected','Primary','architect'))
comparison = engine~compare(p)
review = .ArchitecturePromotionReview~new(comparison,'selected','architect','Choose','evidence://1')
review~approve('reviewer','evidence://2')
comparison['projectId'] = 'DIFFERENT'
review~handoff(comparison)
say 'FAIL accepted modified comparison'
exit 0
::requires 'ArchitecturePromotion.cls'
