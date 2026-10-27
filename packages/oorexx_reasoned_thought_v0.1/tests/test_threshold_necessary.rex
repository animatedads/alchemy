/* Native ooRexx test of NECESSARY vs SUFFICIENT threshold and metric binding.
 * Synthetic chains; no real-world cases. Architecture: Tom Dyer.
 * Owner test: GPT-6; independent adversarial fixture remains Claude's. */
signal on syntax name onSyntax
checks=0

/* A reviewer requiring tier 3 accepts a tier-2 chain and rejects tier-4.
 * The former alone breaks their stated minimum; the latter does not. */
a=.StandardApplicationAudit~new
a~standard('T','THRESHOLD','evidence',3)
a~selfMaterial('T',3)
a~applied('T','ACCEPT_LOW',2,'ACCEPTED')
a~applied('T','REJECT_HIGH',4,'REJECTED')
r=a~audit('T')
call chk r['classification']='STATED_RULE_VIOLATION', 'Accepted below stated minimum is a rule violation'
call chk r['ruleViolations']~items=1, 'Necessary-threshold guard raises exactly one violation'
call chk r['ruleViolations'][1]['chain']='ACCEPT_LOW', 'Violating chain is identified'
call chk r['ruleViolations'][1]['reason']='ACCEPTED_BELOW_NECESSARY_THRESHOLD', 'Reason is a necessary-condition breach'
call chk r['ruleConformingCases']=0, 'Rejected above threshold cannot be certified conforming'
call chk r['unresolvedDispositionCases']=1, 'Rejected above minimum remains not resolved by necessary condition'
call chk r['validatedTruth']=.false, 'No external truth certification'
call chk r['universalConsistencyProven']=.false, 'No universal consistency claim'

/* Two REJECTED values above minimum cannot be condemned without a sufficiency premise. */
b=.StandardApplicationAudit~new
b~standard('B','THRESHOLD','evidence',3)
b~selfMaterial('B',4)
b~applied('B','ONE',3,'REJECTED')
b~applied('B','TWO',4,'REJECTED')
call chk b~audit('B')['classification']='CONSISTENT_APPLICATION', 'Meeting a minimum does not force acceptance'
call chk b~audit('B')['ruleViolations']~items=0, 'No false-positive on rejected high-tier cases'
call chk b~audit('B')['unresolvedDispositionCases']=2, 'No sufficiency inferred for either high-tier rejection'

/* Same apparent numbers measured under another scale: never compare to threshold. */
c=.StandardApplicationAudit~new
c~standard('C','THRESHOLD','evidence',3)
c~selfMaterial('C',4)
c~applied('C','C1',2,'ACCEPTED','evidence','uncalibrated-frequency-score')
q=c~audit('C')
call chk q['classification']='INDETERMINATE_COMPARABILITY', 'Basis mismatch is not a threshold violation'
call chk q['ruleViolations']~items=0, 'Off-basis applications do not create false proof'
call chk q['uncomparableCases']=1, 'Uncomparable case is counted'

/* Explicitly bind the evidence scale and test a proper counterpart. */
d=.StandardApplicationAudit~new
d~standard('D','THRESHOLD','evidence',3,'','HIGHER_WORSE','evidence-tier-v1')
d~selfMaterial('D',3)
d~applied('D','D1',2,'ACCEPTED','evidence','evidence-tier-v1')
call chk d~audit('D')['classification']='STATED_RULE_VIOLATION', 'Explicit matching basis permits bound violation'

/* Unknown is not zero. */
e=.StandardApplicationAudit~new
e~standard('E','THRESHOLD','evidence',3)
e~selfMaterial('E',3)
e~applied('E','E1','UNKNOWN','ACCEPTED')
call chk e~audit('E')['classification']='INDETERMINATE_COMPARABILITY', 'Unknown numeric metric cannot count as zero'

/* Both a self-standard gap and an applicant violation must be preserved. */
f=.StandardApplicationAudit~new
f~standard('F','THRESHOLD','evidence',4)
f~selfMaterial('F',2)
f~applied('F','F1',3,'ACCEPTED')
r=f~audit('F')
call chk r['classification']='STATED_RULE_VIOLATION', 'Applicant violation not concealed behind self gap'
call chk r['selfStandardGap']=.true, 'Independent self-standard gap retained'
call chk r['reasonCodes']~hasItem('SELF_STANDARD_GAP_IF_COMPARABLE'), 'Dual finding explicitly explained'

/* If no self material exists, a direct necessary-condition breach is still examinable. */
g=.StandardApplicationAudit~new
g~standard('G','THRESHOLD','evidence',3)
g~applied('G','G1',2,'ACCEPTED')
call chk g~audit('G')['classification']='STATED_RULE_VIOLATION', 'Known threshold breach not obscured by missing self tier'
call chk g~audit('G')['selfStandardGap']==.nil, 'Missing self tier stays unknown'

/* DISQUALIFY with an absolute boundary must use that boundary's scale. */
h=.StandardApplicationAudit~new
h~standard('H','DISQUALIFY','risk_score',4,'','HIGHER_WORSE','ordinal:severity:v1')
h~applied('H','ONE',5,'ACCEPTED','risk_score','percentage:v1')
h~applied('H','TWO',2,'REJECTED','risk_score','percentage:v1')
call chk h~audit('H')['classification']='INDETERMINATE_COMPARABILITY', 'Both cases off-boundary basis cannot prove disparity'
call chk h~audit('H')['ruleViolations']~items=0, 'Wrong scale cannot trigger explicit threshold violations'
call chk h~audit('H')['incomparablePairs'][1]['reason']='STANDARD_BASIS_MISMATCH', 'Basis mismatch diagnosed against the stated boundary'

say 'THRESHOLD NECESSITY CONTRACT:' checks 'PASS, 0 FAIL'
exit 0
chk: procedure expose checks
 use arg ok,label
 checks+=1
 if ok==.true | ok==1 then do; say 'PASS' label; return; end
 say 'FAIL' label; exit 1
onSyntax:
 say 'SYNTAX rc='||rc 'line' sigl ':' condition('D')
 exit 2
::requires 'StandardApplicationAudit.cls'
