/* Public judgment MAH (Egypt) [2023] EWCA Civ 216.
 * Based on CA judgment, not private data; no invented numeric evidence tiers.
 * Grounding: https://caselaw.nationalarchives.gov.uk/ewca/civ/2023/216
 * Mechanics: live StandardApplicationAudit/0.5 and WorldEnsemble/0.2,
 * plus generic JudgmentReasoningLedger/0.1 source-bound trace.
 */
signal on syntax name onSyntax
checks=0
j=.JudgmentReasoningLedger~new

/* Actor/category separation: each statement is about the RECORD OF COURT REASONING. */
j~record('UT_STATED','UT_AS_REPORTED','STATED_STANDARD','23,49','UT repeatedly described its approach as the lower standard')
j~record('CA_RISK_RULE','CA_LEGAL_RULE','STANDARD','49','reasonable degree of likelihood; not balance of probabilities')
j~record('CA_HIGHER','CA_JUDICIAL_FINDING','APPLIED_STANDARD','37,81','UT effectively imposed too high a proof threshold')
j~record('CA_NO_DUTY','CA_LEGAL_RULE','CORROBORATION','86','no general legal duty of corroboration')
j~record('CA_CAN_WEIGHT','CA_LEGAL_RULE','CORROBORATION','86','a reasonably obtainable missing item may carry evidential weight')
j~record('CA_ART4_INVERSE','CA_LEGAL_RULE','CORROBORATION','77','criteria allowing evidence without corroboration do not imply it is always needed otherwise')
j~record('UT_MISSING','UT_AS_REPORTED','CREDIBILITY_INFERENCE','15,38-45','UT drew negative credibility inferences from missing corroboration')
j~record('CA_MORE','CA_JUDICIAL_FINDING','WARRANT','87','UT required more corroboration on these facts than necessary')
j~record('UT_UNTRUTH','UT_AS_REPORTED','CREDIBILITY','46','UT described the appellant as untruthful')
j~record('CA_DISTINCT','CA_JUDICIAL_FINDING','PROPOSITION_IDENTITY','88','fear not accepted is distinct from witness dishonesty')
j~record('UT_SUMMARY','UT_AS_REPORTED','REASONS','21,46','UT summary did not include prior family-home visits')
j~record('CA_OMISSION','CA_JUDICIAL_FINDING','OMITTED_EVIDENCE','93','positive evidence of earlier visits to family home materially omitted')
j~record('CA_CONTEXT','CA_REPORTED_EVIDENCE','COUNTRY_CONTEXT','94','expert context on arrests of rights lawyers and state of emergency')
j~record('UT_DISMISS','UT_AS_REPORTED','DISPOSITION','13,47','underlying asylum appeal dismissed in UT')
j~record('CA_REMAKE','CA_OUTCOME','DISPOSITION','99,102-104','Court of Appeal remade and allowed underlying appeal')
j~record('CA_G2','CA_JUDICIAL_FINDING','GROUND','83','Ground 2 was not made out')
j~record('CA_G4','CA_JUDICIAL_FINDING','GROUND','90','Ground 4 was not made out')
j~record('CA_G6','CA_JUDICIAL_FINDING','GROUND','97','Ground 6 alone was not accepted as determinative')

j~relate('CA_HIGHER','UT_STATED','CORRECTS_STANDARD')
j~relate('CA_CAN_WEIGHT','CA_NO_DUTY','QUALIFIES_NO_DUTY')
j~relate('CA_ART4_INVERSE','CA_NO_DUTY','QUALIFIES_NO_DUTY')
j~relate('CA_MORE','UT_MISSING','CHALLENGES_CORROBORATION')
j~relate('CA_DISTINCT','UT_UNTRUTH','REJECTS_CONFLATION')
j~relate('CA_OMISSION','UT_SUMMARY','IDENTIFIES_OMISSION')
j~relate('CA_REMAKE','UT_DISMISS','REMAKES_PRIOR')
report=j~audit
call check report['sourceCount']=18,'Each court and tribunal proposition individually attributed'
call check report['relationCount']=7,'Seven typed corrections/qualifications (no automatic verdict)'
call check report['findings']~items=7,'All seven source-bound relationships qualify for tracing'
call check j~hasFinding('CORRECTS_STANDARD'),'Judicial standard mismatch sourced para 37'
call check j~hasFinding('QUALIFIES_NO_DUTY'),'No duty does not make missing corroboration immaterial'
call check j~node('CA_ART4_INVERSE')['cite']='77','Article 4(5) inverse fallacy explicitly represented'
call check j~hasFinding('CHALLENGES_CORROBORATION'),'Court rejected this factual use of corroboration'
call check j~hasFinding('REJECTS_CONFLATION'),'Non-acceptance is not proven untruthfulness'
call check j~hasFinding('IDENTIFIES_OMISSION'),'Positive family-home visit account omitted from UT reasons'
call check j~hasFinding('REMAKES_PRIOR'),'Court outcome recorded as a revision of UT result'
call check j~node('UT_UNTRUTH')['actor']='UT_AS_REPORTED','UT belief not relabelled as appellate fact'
call check j~node('CA_CONTEXT')['underlyingTruthCertified']=.false,'Expert material not silently promoted to independently certified real-world fact'
call check report['validatedTruth']=.false & report['outcomeIndependentlyDetermined']=.false,'No algorithmic merits or asylum verdict'
call check j~node('CA_G2')['statement']\='' & j~node('CA_G4')['statement']\='', -
   'Unsuccessful appeal grounds preserved; avoid partisan selection'

/* A tribunal allegation is not sufficient to create a CA finding by itself. */
invalid=.JudgmentReasoningLedger~new
invalid~record('A','UT_AS_REPORTED','THESIS','15','UT blamed missing corroboration')
invalid~record('B','UT_AS_REPORTED','THESIS','21','UT self-assessed its approach')
invalid~relate('A','B','CORRECTS_STANDARD')
call check invalid~audit['findings']~items=0,'Actor provenance gate blocks upgrading a UT claim to appellate ruling'

/* Numeric standard audit must not invent metrics for qualitative risk assessments. */
a=.StandardApplicationAudit~new
a~standard('PROOF','DISQUALIFY','QUALITATIVE_ASYLUM_REASONING')
a~applied('PROOF','FATHER_LAWYER','UNKNOWN','REJECTED',- 
  'QUALITATIVE_ASYLUM_REASONING','indictment_document_availability')
a~applied('PROOF','HUMAN_RIGHTS_ORG','UNKNOWN','REJECTED',- 
  'QUALITATIVE_ASYLUM_REASONING','organisation_contact_feasibility')
a~applied('PROOF','FAMILY_WITNESS','UNKNOWN','REJECTED',- 
  'QUALITATIVE_ASYLUM_REASONING','family_contact_feasibility')
ar=a~audit('PROOF')
call check ar['classification']='INDETERMINATE_COMPARABILITY','No fabricated common numeric evidentiary score'
call check ar['pairs']~items=0,'Unmatched retrieval bases do not create fictional unequal-treatment findings'
call check ar['validatedTruth']=.false & ar['universalConsistencyProven']=.false, -
  'Stated-standard operator retains its scope ceiling'

/* WorldEnsemble: judicial outcomes can coexist with contrary hypothetical
 * world facts. This is logical countermodel work, not a new merits decision. */
w=.WorldEnsemble~new
call world w,'HYP_RISK_YES_HONEST','YES','NO'
call world w,'HYP_RISK_YES_UNTRUTH','YES','YES'
call world w,'HYP_RISK_NO_HONEST','NO','NO'
call world w,'HYP_RISK_NO_UNTRUTH','NO','YES'
w~admit('E_UT_ACCEPT','FATHER_IMPRISONED_ACCEPTED','YES','official-judgment-para14','ADMITTED')
w~admit('E_UT_RESULT','UT_DISMISSED_APPEAL','YES','official-judgment-para13','ADMITTED')
w~admit('E_CA_RESULT','CA_ALLOWED_APPEAL','YES','official-judgment-para104','ADMITTED')
call check w~survivors~items=4,'Historical procedural outcomes do not logically force a hypothetical world truth'
call check w~assess('FUTURE_RISK','YES')['status']='UNDERDETERMINED',- 
  'Court outcome as admitted procedural fact does not prove empirical prediction by model'
call check w~assess('WITNESS_UNTRUTHFUL','YES')['status']='UNDERDETERMINED',- 
  'Failed UT claim does not force person-level dishonesty'
call check w~indistinguishablePair('FUTURE_RISK')~items=2,'Opposed risk worlds remain observationally identical'
call check w~indistinguishablePair('WITNESS_UNTRUTHFUL')~items=2,'Truthfulness is independent of future-risk hypotheses'
call check w~assess('CA_ALLOWED_APPEAL','YES')['status']='HOLDS_IN_LISTED_WORLDS_ONLY',- 
  'Recorded appellate decision remains true in each hypothetical world'
call check w~assess('FUTURE_RISK','YES')['actualTruthProven']=.false,- 
  'Countermodels are not likelihood estimates or truth certificates'

say 'MAH EGYPT PUBLIC JUDGMENT: 'checks 'PASS, 0 FAIL'
say 'No likelihood invented; no automatic refugee-status adjudication.'
exit 0
world: procedure
  use strict arg model,id,risk,untruth
  d=.directory~new
  d['FATHER_IMPRISONED_ACCEPTED']='YES'
  d['UT_DISMISSED_APPEAL']='YES'
  d['CA_ALLOWED_APPEAL']='YES'
  d['FUTURE_RISK']=risk
  d['WITNESS_UNTRUTHFUL']=untruth
  model~addWorld(id,d)
  return
check: procedure expose checks
  use arg ok,label
  checks+=1
  if ok=.true | ok=1 then do; say 'PASS:' label; return; end
  say 'FAIL:' label
  exit 1
onSyntax:
  say 'SYNTAX rc='||rc 'line' sigl ':' condition('D')
  exit 2
::requires 'JudgmentReasoningLedger.cls'
::requires 'StandardApplicationAudit.cls'
::requires 'WorldEnsemble.cls'
