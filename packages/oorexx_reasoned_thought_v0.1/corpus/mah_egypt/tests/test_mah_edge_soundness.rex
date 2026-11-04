/* Public and synthetic edge-integrity qualification. No private case data. */
signal on syntax name onSyntax
checks = 0
j=.JudgmentReasoningLedger~new
j~record('CA_PROOF','CA_JUDICIAL_FINDING','APPLIED_STANDARD','37','UT applied too high a standard')
j~record('UT_CRED','UT_AS_REPORTED','CREDIBILITY','46','UT described applicant as untruthful')
j~record('UT_STANDARD','UT_AS_REPORTED','STATED_STANDARD','23','UT stated lower standard')
j~record('CA_DISTINCT','CA_JUDICIAL_FINDING','PROPOSITION_IDENTITY','88','Reliability differs from dishonesty')
j~record('CA_NO_DUTY','CA_LEGAL_RULE','CORROBORATION','86','Corroboration not compulsory')
j~record('CA_OTHER','CA_LEGAL_RULE','STANDARD','49','Reasonable likelihood')
j~record('UT_BAD','UT_AS_REPORTED','THESIS','15','Tribunal thesis')
/* First two must fail: same actors, wrong kinds. */
j~relate('CA_PROOF','UT_CRED','REJECTS_CONFLATION')
j~relate('CA_DISTINCT','UT_STANDARD','CORRECTS_STANDARD')
j~relate('CA_NO_DUTY','CA_OTHER','QUALIFIES_NO_DUTY')
/* Positive controls, supported types. */
j~relate('CA_PROOF','UT_STANDARD','CORRECTS_STANDARD')
j~relate('CA_DISTINCT','UT_CRED','REJECTS_CONFLATION')
j~relate('CA_PROOF','UT_STANDARD','CORRECTS_STANDARD') /* repeated citation is not a second finding */
r=j~audit
call check r['relationCount']=6,'All six attempted edges retained in source history'
call check r['findings']~items=2,'Only two proposition-kind-compatible edges count'
call check r['rejectedEdges']~items=4,'Three wrongly typed edges and a duplicate are explicitly rejected'
call check r['unqualifiedCount']=4,'Rejected-edge count is visible'
call check r['rejectedEdges'][4]['reason']='DUPLICATE_RELATION','Duplicate edge has explicit cause'
call check r['citationValidated']=.false,'Citation references not authenticated by ledger'
call check r['validatedTruth']=.false,'No external truth certificate'
call check j~hasFinding('REJECTS_CONFLATION'),'Valid actor and proposition-type correction kept'
call check j~hasFinding('CORRECTS_STANDARD'),'Valid standard correction kept'
say 'EDGE SOUNDNESS:' checks 'PASS, 0 FAIL'
exit 0
check: procedure expose checks
  use arg ok, label
  checks += 1
  if ok==1 | ok==.true then do; say 'PASS:' label; return; end
  say 'FAIL:' label
  exit 1
onSyntax:
  say 'SYNTAX:' condition('D') 'at' sigl
  exit 2
::requires 'JudgmentReasoningLedger.cls'
