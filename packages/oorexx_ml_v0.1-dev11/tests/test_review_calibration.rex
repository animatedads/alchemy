objective=.MLObjective~new('audio-distance','MINIMIZE','weighted physical/perceptual distance','lower is better')
empty=.directory~new
candidates=.directory~new
candidates['A']=.MLSearchCandidate~new('A','C',empty,1.0,objective)
candidates['B']=.MLSearchCandidate~new('B','C',empty,2.0,objective)
candidates['C']=.MLSearchCandidate~new('C','C',empty,.5,objective)

session=.MLObjectiveCalibrationSession~new('AUDIO-CAL',objective)
root=session~journalPoint
session~addJudgement(.MLPreferenceJudgement~new('J1','listener-1','A','B','LEFT',.9,'A clearer','AB-001'))
session~addJudgement(.MLPreferenceJudgement~new('J2','listener-1','C','A','LEFT',.8,'C clearer','CA-001'))
session~addJudgement(.MLPreferenceJudgement~new('J3','listener-2','A','B','RIGHT',.7,'B preferred','AB-002'))
session~addJudgement(.MLPreferenceJudgement~new('J4','listener-2','B','C','UNDECIDABLE',.5,'too close','BC-001'))
report=session~report(candidates,'AUDIO-OBJECTIVE-V1')
call eq report~totalJudgements,4,'total judgements'
call eq report~comparableJudgements,3,'comparable judgements'
call eq report~undecidableJudgements,1,'undecidable excluded from agreement denominator'
call eq report~concordantJudgements,2,'two human preferences agree with objective'
call eq report~discordantJudgements,1,'one human preference disagrees with objective'
call true report~agreementRate>.66 & report~agreementRate<.67,'agreement rate is two thirds'
call true report~acceptable(.60,3),'report acceptable at explicit 60 percent / 3 comparison threshold'
call true \report~acceptable(.80,3),'report rejects stronger calibration threshold'
qual=.MLObjectiveCalibrationQualification~assess(report,.60,3)
call true qual~passed,'calibration qualification passes explicit threshold'
qual2=.MLObjectiveCalibrationQualification~assess(report,.80,3)
call true \qual2~passed,'calibration qualification fails if human agreement is inadequate'

future=session~journalPoint
session~rollback(root,'listener-future')
call eq session~at('judgementCount'),0,'calibration evidence rewinds'
session~rollForward('listener-future')
call eq session~at('judgementCount'),4,'calibration evidence future is retained'

case=.MLReviewCase~new('REVIEW-A','A','AUDIO_CANDIDATE')
caseRoot=case~journalPoint
d1=.MLReviewDecision~new('D1','listener-1','A','PROMOTE',.9,'speech clearer','listen-001','audio-review-v1')
case~recordDecision(d1); case~selectDecision('D1')
call eq case~status,'RESOLVED','review case resolves explicitly'
call eq case~selectedDecision~decision,'PROMOTE','selected decision retained'
caseFuture=case~journalPoint
case~rollback(caseRoot,'resolved-future')
call eq case~status,'PENDING','review case can rewind before human decision'
case~rollForward('resolved-future')
call eq case~selectedDecision~id,'D1','reviewed future can be replayed'
case~reopen('blind second listen')
call eq case~status,'PENDING','review can reopen without deleting old decision evidence'
call eq case~decisionIds~items,1,'old decision evidence remains after reopen'

say 'PASS test_review_calibration'
exit 0

eq: procedure
 use arg a,e,l
 if a\==e then do; say 'FAIL' l; say ' expected='e; say ' actual  ='a; exit 1; end
 return
true: procedure
 use arg v,l
 if \v then do; say 'FAIL' l; exit 1; end
 return
::requires "OorexxML.cls"
