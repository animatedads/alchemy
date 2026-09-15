/* MLReview.cls - human review, pairwise preference evidence and objective calibration. */

::class MLReviewDecision public
::attribute id
::attribute reviewerId
::attribute subjectId
::attribute decision
::attribute confidence
::attribute rationale
::attribute evidenceRef
::attribute policyId
::method init
  use strict arg id,reviewerId,subjectId,decision,confidence=.nil,rationale='',evidenceRef='',policyId=''
  if id='' | subjectId='' then raise syntax 88.900 array('review decision requires id and subjectId')
  self~id=id; self~reviewerId=reviewerId; self~subjectId=subjectId; self~decision=decision
  self~confidence=confidence; self~rationale=rationale; self~evidenceRef=evidenceRef; self~policyId=policyId
::method canonicalText
  return 'REVIEW_DECISION='||self~id||'|reviewer='||self~reviewerId||'|subject='||self~subjectId||'|decision='||self~decision||'|confidence='||self~confidence||'|evidence='||self~evidenceRef||'|policy='||self~policyId||'|rationale='||self~rationale

::class MLReviewCase subclass MLDriveableObject public
::method init
  expose subjectId subjectKind
  use strict arg id,subjectId,subjectKind='CANDIDATE'
  initial=.directory~new
  initial['status']='PENDING'; initial['subjectId']=subjectId; initial['subjectKind']=subjectKind~translate
  initial['decisionCount']=0; initial['selectedDecisionId']=''; initial['reopenReason']=''
  self~init:super(id,'REVIEW_CASE',initial)
::method subjectId; expose subjectId; return subjectId
::method subjectKind; expose subjectKind; return subjectKind
::method status; return self~at('status')
::method recordDecision
  use strict arg decision
  if \decision~isA(.MLReviewDecision) then raise syntax 88.900 array('review case requires MLReviewDecision')
  if decision~subjectId\==self~at('subjectId') then raise syntax 88.900 array('review subject mismatch',decision~subjectId,self~at('subjectId'))
  key='decision:'||decision~id
  if self~hasState(key) then raise syntax 88.900 array('duplicate review decision',decision~id)
  changes=.directory~new; changes[key]=decision; changes['decisionCount']=self~at('decisionCount')+1; changes['status']='REVIEWED'
  return self~mutate(changes,'REVIEW_DECISION')
::method decision
  use strict arg id
  key='decision:'||id
  if self~hasState(key) then return self~at(key)
  return .nil
::method decisionIds
  snap=self~snapshot; ids=.array~new
  do key over snap~allIndexes
    if key~left(9)='decision:' then ids~append(key~substr(10))
  end
  ids~sort; return ids
::method selectDecision
  use strict arg id
  if self~decision(id)==.nil then raise syntax 88.900 array('unknown review decision',id)
  changes=.directory~new; changes['selectedDecisionId']=id; changes['status']='RESOLVED'; changes['reopenReason']=''
  return self~mutate(changes,'REVIEW_RESOLVE')
::method selectedDecision
  id=self~at('selectedDecisionId')
  if id='' then return .nil
  return self~decision(id)
::method reopen
  use strict arg reason=''
  changes=.directory~new; changes['status']='PENDING'; changes['selectedDecisionId']=''; changes['reopenReason']=reason
  return self~mutate(changes,'REVIEW_REOPEN')

::class MLPreferenceJudgement public
::attribute id
::attribute reviewerId
::attribute leftCandidateId
::attribute rightCandidateId
::attribute preference
::attribute confidence
::attribute rationale
::attribute evidenceRef
::method init
  use strict arg id,reviewerId,leftCandidateId,rightCandidateId,preference,confidence=.nil,rationale='',evidenceRef=''
  p=preference~translate
  if p<>'LEFT' & p<>'RIGHT' & p<>'TIE' & p<>'UNDECIDABLE' then raise syntax 88.900 array('preference must be LEFT, RIGHT, TIE or UNDECIDABLE')
  if leftCandidateId=rightCandidateId then raise syntax 88.900 array('preference candidates must differ')
  self~id=id; self~reviewerId=reviewerId; self~leftCandidateId=leftCandidateId; self~rightCandidateId=rightCandidateId
  self~preference=p; self~confidence=confidence; self~rationale=rationale; self~evidenceRef=evidenceRef
::method canonicalText
  return 'PREFERENCE='||self~id||'|reviewer='||self~reviewerId||'|left='||self~leftCandidateId||'|right='||self~rightCandidateId||'|preference='||self~preference||'|confidence='||self~confidence||'|evidence='||self~evidenceRef||'|rationale='||self~rationale

::class MLCalibrationComparison public
::attribute judgementId
::attribute humanPreference
::attribute objectivePreference
::attribute concordant
::attribute leftScore
::attribute rightScore
::method init
  use strict arg judgementId,humanPreference,objectivePreference,concordant,leftScore,rightScore
  self~judgementId=judgementId; self~humanPreference=humanPreference; self~objectivePreference=objectivePreference
  self~concordant=concordant; self~leftScore=leftScore; self~rightScore=rightScore
::method canonicalText
  return 'CALIBRATION_COMPARISON='||self~judgementId||'|human='||self~humanPreference||'|objective='||self~objectivePreference||'|concordant='||self~concordant||'|leftScore='||self~leftScore||'|rightScore='||self~rightScore

::class MLObjectiveCalibrationReport public
::attribute id
::attribute objectiveId
::attribute totalJudgements
::attribute comparableJudgements
::attribute undecidableJudgements
::attribute concordantJudgements
::attribute discordantJudgements
::attribute agreementRate
::method init
  expose comparisons
  use strict arg id,objectiveId,totalJudgements,comparableJudgements,undecidableJudgements,concordantJudgements,discordantJudgements,sourceComparisons
  self~id=id; self~objectiveId=objectiveId; self~totalJudgements=totalJudgements; self~comparableJudgements=comparableJudgements
  self~undecidableJudgements=undecidableJudgements; self~concordantJudgements=concordantJudgements; self~discordantJudgements=discordantJudgements
  if comparableJudgements=0 then self~agreementRate=.nil; else self~agreementRate=concordantJudgements/comparableJudgements
  comparisons=.array~new; do c over sourceComparisons; comparisons~append(c); end
::method comparisons
  expose comparisons
  out=.array~new; do c over comparisons; out~append(c); end; return out
::method acceptable
  use strict arg minimumAgreement=.70,minimumComparable=5
  if self~agreementRate==.nil then return .false
  return self~comparableJudgements>=minimumComparable & self~agreementRate>=minimumAgreement
::method canonicalText
  expose comparisons
  lines=.array~new; lines~append('OBJECTIVE_CALIBRATION='||self~id||'|objective='||self~objectiveId||'|total='||self~totalJudgements||'|comparable='||self~comparableJudgements||'|undecidable='||self~undecidableJudgements||'|concordant='||self~concordantJudgements||'|discordant='||self~discordantJudgements||'|agreement='||self~agreementRate)
  do c over comparisons; lines~append(c~canonicalText); end
  return lines~makeString('L')

::class MLObjectiveCalibration public
::method compare class
  use strict arg id,objective,candidates,judgements
  if \objective~isA(.MLObjective) then raise syntax 88.900 array('objective calibration requires MLObjective')
  if \candidates~isA(.Directory) then raise syntax 88.900 array('objective calibration candidates must be Directory')
  if \judgements~isA(.Array) then raise syntax 88.900 array('objective calibration judgements must be Array')
  total=judgements~items; comparable=0; undecidable=0; concordant=0; discordant=0; comparisons=.array~new
  do j over judgements
    if \j~isA(.MLPreferenceJudgement) then raise syntax 88.900 array('calibration entries must be MLPreferenceJudgement')
    if j~preference='UNDECIDABLE' then do; undecidable=undecidable+1; iterate; end
    if \candidates~hasIndex(j~leftCandidateId) | \candidates~hasIndex(j~rightCandidateId) then raise syntax 88.900 array('calibration candidate missing',j~id)
    left=candidates[j~leftCandidateId]; right=candidates[j~rightCandidateId]
    if left~objective~id\==objective~id | right~objective~id\==objective~id then raise syntax 88.900 array('calibration objective mismatch',j~id)
    if left~score==right~score then predicted='TIE'
    else if objective~better(left~score,right~score) then predicted='LEFT'
    else predicted='RIGHT'
    ok=(predicted=j~preference); comparable=comparable+1
    if ok then concordant=concordant+1; else discordant=discordant+1
    comparisons~append(.MLCalibrationComparison~new(j~id,j~preference,predicted,ok,left~score,right~score))
  end
  return .MLObjectiveCalibrationReport~new(id,objective~id,total,comparable,undecidable,concordant,discordant,comparisons)

::class MLObjectiveCalibrationSession subclass MLDriveableObject public
::method init
  expose objective
  use strict arg id,objective
  if \objective~isA(.MLObjective) then raise syntax 88.900 array('calibration session requires MLObjective')
  initial=.directory~new; initial['objectiveId']=objective~id; initial['judgementCount']=0
  self~init:super(id,'OBJECTIVE_CALIBRATION_SESSION',initial)
::method objective; expose objective; return objective
::method addJudgement
  use strict arg judgement
  if \judgement~isA(.MLPreferenceJudgement) then raise syntax 88.900 array('calibration session requires MLPreferenceJudgement')
  key='judgement:'||judgement~id
  if self~hasState(key) then raise syntax 88.900 array('duplicate calibration judgement',judgement~id)
  changes=.directory~new; changes[key]=judgement; changes['judgementCount']=self~at('judgementCount')+1
  return self~mutate(changes,'CALIBRATION_JUDGEMENT')
::method judgementIds
  snap=self~snapshot; ids=.array~new
  do key over snap~allIndexes
    if key~left(10)='judgement:' then ids~append(key~substr(11))
  end
  ids~sort; return ids
::method judgements
  ids=self~judgementIds; out=.array~new
  do id over ids; out~append(self~at('judgement:'||id)); end
  return out
::method report
  expose objective
  use strict arg candidates,id='CALIBRATION'
  return .MLObjectiveCalibration~compare(id,objective,candidates,self~judgements)

::class MLObjectiveCalibrationQualification public
::method assess class
  use strict arg report,minimumAgreement=.70,minimumComparable=5
  checks=.array~new
  checks~append(.MLQualificationCheck~new('EVIDENCE','human-comparison-count',report~comparableJudgements>=minimumComparable,'comparable='||report~comparableJudgements||' required='||minimumComparable))
  agreementOK=.false; if report~agreementRate\==.nil then agreementOK=(report~agreementRate>=minimumAgreement)
  checks~append(.MLQualificationCheck~new('EVIDENCE','objective-human-agreement',agreementOK,'agreement='||report~agreementRate||' required='||minimumAgreement))
  return .MLQualificationReport~new('CALIBRATION:'||report~id,checks)

::requires "MLSearch.cls"
