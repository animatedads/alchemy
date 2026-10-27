/* Synthetic counterexample: equally wrong decisions evade pairwise disparity. */
signal on syntax name onSyntax
checks = 0
say 'ABSOLUTE-RULE REGRESSION / StandardApplicationAudit'

/* Both cases violate a published disqualification boundary, but are treated alike.
 * Pairwise-only v0.2 incorrectly reports consistent; v0.3 must report rule violation. */
a = .StandardApplicationAudit~new
a~standard('S','DISQUALIFY','severity',3,'reject severity >= 3','HIGHER_WORSE','common-rubric')
a~applied('S','CASE_A',4,'ACCEPTED','severity','common-rubric')
a~applied('S','CASE_B',5,'ACCEPTED','severity','common-rubric')
r = a~audit('S')
call check r['classification'] == 'STATED_RULE_VIOLATION', 'equally wrong ACCEPTS do not pass absolute boundary'
call check r['pairs']~items = 0, 'no spurious pairwise disparity'
call check r['ruleViolations']~items = 2, 'both violated applications named'
call check r['validatedTruth'] == .false, 'classification not an external truth claim'

/* False rejection below threshold is also recorded even if all cases match. */
b = .StandardApplicationAudit~new
b~standard('S','DISQUALIFY','severity',3,'','HIGHER_WORSE','rubric')
b~applied('S','CASE_C',0,'REJECTED','severity','rubric')
b~applied('S','CASE_D',1,'REJECTED','severity','rubric')
call check b~audit('S')['ruleViolations']~items = 2, 'equally wrong REJECTS also caught'

/* A correct pair cannot make an explicit boundary violation disappear. */
c = .StandardApplicationAudit~new
c~standard('S','DISQUALIFY','severity',3,'','HIGHER_WORSE','rubric')
c~applied('S','CASE_E',1,'ACCEPTED','severity','rubric')
c~applied('S','CASE_F',5,'REJECTED','severity','rubric')
call check c~audit('S')['classification'] == 'CONSISTENT_APPLICATION', 'correct declared boundary applications are consistent within sample'
call check c~audit('S')['ruleViolations']~items = 0, 'no invented rule violation'

/* Reversed severity: low number is worse and triggers rejection. */
d = .StandardApplicationAudit~new
d~standard('S','DISQUALIFY','quality',3,'low quality disqualifies','LOWER_WORSE','rubric')
d~applied('S','CASE_G',2,'ACCEPTED','quality','rubric')
call check d~audit('S')['classification'] == 'STATED_RULE_VIOLATION', 'lower-worse severity triggers correct direction'

/* Missing measurement must not secretly equal zero. */
e = .StandardApplicationAudit~new
e~standard('S','DISQUALIFY','severity',3,'','HIGHER_WORSE','rubric')
e~applied('S','CASE_H','UNKNOWN','ACCEPTED','severity','rubric')
call check e~audit('S')['ruleViolations']~items = 0, 'unknown cannot violate numeric boundary'
call check e~audit('S')['classification'] == 'INSUFFICIENT_APPLICATIONS', 'no false certainty from one unknown case'

/* Different dimension never supports this standard's absolute rule. */
f = .StandardApplicationAudit~new
f~standard('S','DISQUALIFY','severity',3,'','HIGHER_WORSE','rubric')
f~applied('S','CASE_I',9,'ACCEPTED','unrelated_quality','rubric')
call check f~audit('S')['ruleViolations']~items = 0, 'off-dimension measurement ineligible'

/* Legacy no-boundary API remains compatible: just pairwise observations. */
g = .StandardApplicationAudit~new
g~standard('S','DISQUALIFY','severity')
g~applied('S','CASE_J',4,'ACCEPTED')
g~applied('S','CASE_K',5,'ACCEPTED')
call check g~audit('S')['classification'] == 'CONSISTENT_APPLICATION', 'legacy pairwise mode unchanged'
call check g~audit('S')['ruleViolations']~items = 0, 'no boundary fabricated for legacy standards'

say 'ABSOLUTE-RULE PASS:' checks 'checks'
exit 0
check: procedure expose checks
  use arg ok, description
  checks += 1
  if ok == .true | ok == 1 then do
    say 'PASS:' description
    return
  end
  say 'FAIL:' description
  exit 1
onSyntax:
  say 'SYNTAX:' condition('D') 'line' sigl
  exit 2
::requires 'StandardApplicationAudit.cls'
