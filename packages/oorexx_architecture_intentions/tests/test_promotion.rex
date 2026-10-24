/* Genuine planner comparison promoted only as a non-executable design. */
cat = .ArchitectureCatalog~fromFile('catalog/architecture_catalog.json')
planner = .ArchitecturePlanner~new(cat)
p = planner~project('cats-review','Cats: governed design approval')
p~domain~statement('We love cats','customer','interview://1')
options = .ArchitectureScenarioComparison~new(planner)
options~register(.ArchitectureScenario~new('minimal','Local pilot','Minimise infrastructure','architect'))
options~register(.ArchitectureScenario~new('distributed','Distributed service','Remote clients','architect'))
comparison = options~compare(p)
call assert comparison['scenarios'][1]['state'] \== 'INCONSISTENT', -
  'candidate eligible for a DESIGN review'
review = .ArchitecturePromotionReview~new(comparison,'minimal','architect', -
  'Select simple local pilot','review://candidate-1')
call assert review~matches(comparison),'snapshot agrees before mutation'
call assert review~status == 'OPEN_REVIEW','review starts open'
call assert review~review['alternatives'][1]['disposition'] == 'UNREVIEWED', -
  'alternative remains visible even before disposition'
row = review~disposition('distributed','DEFERRED','design board', -
  'No remote users confirmed yet','review://alternative-2')
call assert row['disposition'] == 'DEFERRED','alternative disposition recorded'
row['reason'] = 'attempted tamper'
call assert review~review['alternatives'][1]['reason'] \== 'attempted tamper', -
  'returned review cannot modify retained decision evidence'
review~approve('separate reviewer','approval://board-1')
call assert review~status == 'DESIGN_SELECTED','explicit named review complete'
plan = review~handoff
call assert plan['schema'] == 'alchemy.architecture.promotion-handoff/0.1', -
  'handoff schema'
call assert plan['status'] == 'DESIGN_ONLY_UNRESOLVED', -
  'unsatisfied business questions block SSC submission'
call assert plan['readyForSSC'] == .JSON~false,'no automatic SSC qualification'
call assert plan['sscSubmission'] == .nil,'no SSC request while unresolved'
call assert plan['deploymentPlan'] == .nil,'no deployment plan fabricated'
call assert plan['executable'] == .JSON~false,'never executable'
call assert plan['consideredAlternatives']~items == 1, -
  'retain full nonselected candidate plan'
call assert plan['otherScenarios'][1]['disposition'] == 'DEFERRED', -
  'retains unchosen alternatives and review reasons'
/* Returned handoffs are fresh parses, never retained mutable references. */
plan['plan']['state'] = 'READY_FOR_DEPENDENCY_RESOLUTION'
call assert review~handoff['status'] == 'DESIGN_ONLY_UNRESOLVED', -
  'caller mutation cannot qualify selected design'
comparison['projectId'] = 'attacker-changed-project'
call assert \review~matches(comparison), -
  'changed comparison not equal to approved frozen generation'
if arg(1,'E') then do
  parse arg outputDirectory
  files = .ArchitecturePromotionWriter~new~write(review~handoff,outputDirectory)
  call assert files~items == 5,'design-only emits five reviewable files'
  do path over files
    parsed = .JSON~fromJSON(charin(path,1,chars(path)))
    call stream path,'C','CLOSE'
    call assert parsed \== .nil,'handoff valid JSON'
  end
end
say 'PASS governed scenario review, evidence, immutable plan, design-only gate'
exit 0
assert:
  use arg condition, description
  if condition then return
  say 'FAIL:' description
  exit 1
::requires 'ArchitecturePromotion.cls'
