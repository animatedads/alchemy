/* Deterministic validation of the Luna planning grammar. */
session = .DFLunaPlanningSession~new(.nil, .nil)
valid = '{"project_id":"HELLO-PLAN","items":[{"id":"W1","kind":"IMPLEMENT","objective":"implement the minimal ooRexx HelloWorld","depends_on":[]},{"id":"W2","kind":"REVIEW","objective":"independently review deterministic evidence","depends_on":["W1"]}]}'
parsed = session~parsePlan(valid, "HELLO-PLAN")
if \parsed[1] then do
  say "FAIL valid Luna plan rejected" parsed[2]
  exit 1
end
plan = parsed[3]
if plan~items~items \= 2 then do
  say "FAIL plan item count"
  exit 1
end
if plan~items[1]~kind \= "IMPLEMENT" then do
  say "FAIL first plan item kind"
  exit 1
end
if plan~items[2]~kind \= "REVIEW" then do
  say "FAIL second plan item kind"
  exit 1
end
invalid = '{"project_id":"HELLO-PLAN","items":[{"id":"W1","kind":"IMPLEMENT","objective":"implement","depends_on":[],"authority":"MODEL"},{"id":"W2","kind":"REVIEW","objective":"review","depends_on":["W1"]}]}'
bad = session~parsePlan(invalid, "HELLO-PLAN")
if bad[1] then do
  say "FAIL extra model authority field accepted"
  exit 1
end
say "PASS Luna planning grammar validation"
exit 0
::requires "PlanningSession.cls"
