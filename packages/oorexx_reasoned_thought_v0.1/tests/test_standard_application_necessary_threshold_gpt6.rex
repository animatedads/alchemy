/* Owner regression for threshold necessary-versus-sufficient semantics.
 * Synthetic only. An ACCEPTED case below a minimum violates the stated standard;
 * a REJECTED case above a minimum does NOT necessarily violate it because the
 * minimum is necessary, not sufficient. All comparisons remain conditional. */
signal on syntax name onSyntax
checks=0
m=.StandardApplicationAudit~new
m~standard('S','THRESHOLD','quality',3)
m~applied('S','A',2,'ACCEPTED')
m~applied('S','B',1,'ACCEPTED')
r=m~audit('S')
call check r['classification']='STATED_RULE_VIOLATION', 'accepted below a stated minimum is a declared-rule contradiction'
call check r['ruleViolations']~items=2, 'both violating applications named'
call check r['validatedTruth']=.false & r['conditional']=.true, 'no underlying truth or legal outcome certified'

n=.StandardApplicationAudit~new
n~standard('S','THRESHOLD','quality',3)
n~selfMaterial('S',3)
n~applied('S','REJECTED_BUT_QUALIFIED',5,'REJECTED')
call check n~audit('S')['ruleViolations']~items=0, 'rejection above necessary minimum does not imply disparity'
call check n~audit('S')['classification']='CONSISTENT_APPLICATION', 'no observed violation, not proof of sufficiency'

p=.StandardApplicationAudit~new
p~standard('S','THRESHOLD','quality',3)
p~selfMaterial('S',3)
p~applied('S','UNLIKE_MEASUREMENT',1,'ACCEPTED','quality','different-standardization')
call check p~audit('S')['classification']='INDETERMINATE_COMPARABILITY', 'nonmatching measurement basis cannot disqualify a claim'
call check p~audit('S')['ruleViolations']~items=0, 'unknown basis not promoted into violation'

q=.StandardApplicationAudit~new
q~standard('S','THRESHOLD','quality',3,'','HIGHER_WORSE','official-standard')
q~selfMaterial('S',4)
q~applied('S','BAD',2,'ACCEPTED','quality','official-standard')
q~applied('S','UNRELATED',1,'ACCEPTED','quality','alternative-standard')
r=q~audit('S')
call check r['classification']='STATED_RULE_VIOLATION', 'explicit bound basis violation detected'
call check r['ruleViolations']~items=1, 'incomparable second case is not counted as a violation'
call check r['uncomparableCases']=1, 'report carries incomplete comparison provenance'

s=.StandardApplicationAudit~new
s~standard('S','THRESHOLD','quality',3)
s~selfMaterial('S',2)
s~applied('S','BELOW',1,'ACCEPTED')
r=s~audit('S')
call check r['classification']='STATED_RULE_VIOLATION', 'direct violation takes precedence over self-standard gap'
call check r['reasonCodes']~hasItem('SELF_STANDARD_GAP_IF_COMPARABLE'), 'independent self-standard gap retained, not erased'

say 'NECESSARY THRESHOLD PASS:' checks 'checks'
exit 0
check: procedure expose checks
  use arg ok,description
  checks+=1
  if ok=.true | ok=1 then do; say 'PASS:' description; return; end
  say 'FAIL:' description
  exit 1
onSyntax: say 'SYNTAX line' sigl ':' condition('D'); exit 2
::requires 'StandardApplicationAudit.cls'
