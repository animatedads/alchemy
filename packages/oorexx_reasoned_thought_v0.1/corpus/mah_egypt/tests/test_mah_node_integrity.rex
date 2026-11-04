/* Synthetic adversarial test of public MAH ledger. No case-specific witness data. */
signal on syntax name onSyntax
checks=0
j=.JudgmentReasoningLedger~new
j~record('CA_APPLIED','CA_JUDICIAL_FINDING','APPLIED_STANDARD','37','CA described too-high operative proof standard')
j~record('UT_STATED','UT_AS_REPORTED','STATED_STANDARD','23','UT stated lower proof standard')
j~record('CA_DUTY','CA_LEGAL_RULE','CORROBORATION','86','No universal duty to corroborate')
j~relate('CA_APPLIED','UT_STATED','CORRECTS_STANDARD')
call check j~audit['findings']~items=1,'Valid source-to-target correction qualifies'
old=j~node('CA_APPLIED')
old['cite']='999';old['actor']='UT_AS_REPORTED';old['kind']='CREDIBILITY';old['statement']='changed externally'
call check j~node('CA_APPLIED')['cite']='37','Caller cannot rewrite source citation'
call check j~node('CA_APPLIED')['actor']='CA_JUDICIAL_FINDING','Caller cannot rewrite actor'
call check j~node('CA_APPLIED')['kind']='APPLIED_STANDARD','Caller cannot rewrite kind'
call check j~node('CA_APPLIED')['statement']<>'changed externally','Caller cannot rewrite statement'
call check j~audit['findings']~items=1,'Detached snapshot cannot invalidate existing edge'
call check j~audit['findings'][1]['sourceCite']='37','Audit retains originally admitted citation'
j~relate('CA_DUTY','CA_DUTY','QUALIFIES_NO_DUTY')
r=j~audit
call check r['relationCount']=2,'Self relation remains visible in raw attempted edges'
call check r['findings']~items=1,'Self relation does not become corroboration'
call check r['rejectedEdges'][1]['reason']='SELF_RELATION','Self relation rejected with explicit reason'
call check r['citationValidated']=.false,'Syntactic citation is not authenticated text'
call check r['validatedTruth']=.false,'No judicial or factual truth certified by the ledger'
say 'MAH LEDGER NODE INTEGRITY:' checks 'PASS, 0 FAIL'
exit 0
check: procedure expose checks
  use arg ok,label
  checks+=1
  if ok=1 | ok==.true then do; say 'PASS:' label; return; end
  say 'FAIL:' label
  exit 1
onSyntax:
  say 'SYNTAX ERROR' condition('D') 'line' sigl
  exit 2
::requires 'JudgmentReasoningLedger.cls'
