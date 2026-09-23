/* AudioObjectiveCalibration.rex - pairwise perceptual calibration for recovered-audio ranking. */
parse arg catalogPath judgementsPath outDir minimumAgreement minimumComparable
if words(arg(1))<3 then do
  say 'usage: AudioObjectiveCalibration.rex CATALOG.tsv JUDGEMENTS.tsv OUTDIR [MIN_AGREEMENT] [MIN_COMPARABLE]'
  exit 2
end
if minimumAgreement='' then minimumAgreement=.70
if minimumComparable='' then minimumComparable=5
minimumAgreement=minimumAgreement+0; minimumComparable=minimumComparable+0
call ensureDir outDir
objective=.MLObjective~new('quality-target-distance','MINIMIZE',,
  '0.35*global + 0.40*window_median + 0.10*window_p25 + 0.15*temporal + 18*pre_limiter_over + 40*post_limiter_clip + low-silence penalty',,
  'lower score is better; artefact weights require perceptual calibration')
candidates=loadCandidates(catalogPath,objective)
if candidates~items<2 then do; say 'FAIL: at least two candidates required'; exit 3; end
session=.MLObjectiveCalibrationSession~new('AUDIO-RECOVERED-OBJECTIVE-CALIBRATION',objective)
count=loadJudgements(judgementsPath,session)
if count=0 then do; say 'FAIL: no judgements supplied'; exit 3; end
report=session~report(candidates,'AUDIO-RECOVERED-OBJECTIVE-V1')
qualification=.MLObjectiveCalibrationQualification~assess(report,minimumAgreement,minimumComparable)
call writeText outDir'/calibration.txt',report,qualification,minimumAgreement,minimumComparable
call writeJson outDir'/calibration.json',report,qualification,minimumAgreement,minimumComparable
say report~canonicalText
say qualification~canonicalText
if qualification~passed then say 'PASS AUDIO OBJECTIVE CALIBRATION comparable='report~comparableJudgements 'agreement='report~agreementRate
else say 'UNQUALIFIED AUDIO OBJECTIVE comparable='report~comparableJudgements 'agreement='report~agreementRate
exit 0

loadCandidates: procedure
  use strict arg path,objective
  tab='09'x; out=.directory~new; s=.stream~new(path); s~open('read')
  first=.true
  do while s~lines>0
    line=s~linein
    if line='' | line~left(1)='#' then iterate
    f=line~makeArray(tab)
    if first then do
      first=.false
      if f[1]='candidate_id' then iterate
    end
    if f~items<7 then raise syntax 88.900 array('malformed candidate catalog row',line)
    id=f[1]; lane=f[2]; score=f[4]+0; material=f[5]; objectiveId=f[7]
    if objectiveId<>objective~id then raise syntax 88.900 array('candidate objective mismatch',id,objectiveId)
    if out~hasIndex(id) then raise syntax 88.900 array('duplicate candidate id',id)
    config=.directory~new; refs=.array~of(material)
    out[id]=.MLSearchCandidate~new(id,lane,config,score,objective,.nil,refs)
  end
  s~close
  return out

loadJudgements: procedure
  use strict arg path,session
  tab='09'x; count=0; s=.stream~new(path); s~open('read'); first=.true
  do while s~lines>0
    line=s~linein
    if line='' | line~left(1)='#' then iterate
    f=line~makeArray(tab)
    if first then do
      first=.false
      if f[1]='judgement_id' then iterate
    end
    if f~items<5 then raise syntax 88.900 array('malformed judgement row',line)
    id=f[1]; reviewer=f[2]; left=f[3]; right=f[4]; pref=f[5]
    confidence=.nil; if f~items>=6 then if f[6]<>'' then confidence=f[6]+0
    rationale=''; if f~items>=7 then rationale=f[7]
    evidence=''; if f~items>=8 then evidence=f[8]
    j=.MLPreferenceJudgement~new(id,reviewer,left,right,pref,confidence,rationale,evidence)
    session~addJudgement(j); count=count+1
  end
  s~close
  return count

writeText: procedure
  use strict arg path,report,qualification,minimumAgreement,minimumComparable
  s=.stream~new(path); s~open('write replace')
  s~lineout('audio.objective.calibration/1')
  s~lineout('minimum_agreement='minimumAgreement)
  s~lineout('minimum_comparable='minimumComparable)
  s~lineout(report~canonicalText)
  s~lineout(qualification~canonicalText)
  s~close
  return

writeJson: procedure
  use strict arg path,report,qualification,minimumAgreement,minimumComparable
  s=.stream~new(path); s~open('write replace')
  if report~agreementRate==.nil then agreement='null'; else agreement=report~agreementRate
  s~lineout('{')
  s~lineout('  "schema": "audio.objective.calibration/1",')
  s~lineout('  "objective_id": 'jstr(report~objectiveId)',')
  s~lineout('  "total_judgements": 'report~totalJudgements',')
  s~lineout('  "comparable_judgements": 'report~comparableJudgements',')
  s~lineout('  "undecidable_judgements": 'report~undecidableJudgements',')
  s~lineout('  "concordant_judgements": 'report~concordantJudgements',')
  s~lineout('  "discordant_judgements": 'report~discordantJudgements',')
  s~lineout('  "agreement_rate": 'agreement',')
  s~lineout('  "policy": {"minimum_agreement": 'minimumAgreement', "minimum_comparable": 'minimumComparable'},')
  s~lineout('  "qualified": 'jbool(qualification~passed)',')
  s~lineout('  "comparisons": [')
  comps=report~comparisons
  do i=1 to comps~items
    c=comps[i]; comma=','; if i=comps~items then comma=''
    s~lineout('    {"judgement_id": 'jstr(c~judgementId)', "human_preference": 'jstr(c~humanPreference)', "objective_preference": 'jstr(c~objectivePreference)', "concordant": 'jbool(c~concordant)', "left_score": 'c~leftScore', "right_score": 'c~rightScore'}'comma)
  end
  s~lineout('  ],')
  s~lineout('  "checks": [')
  checks=qualification~checks
  do i=1 to checks~items
    c=checks[i]; comma=','; if i=checks~items then comma=''
    s~lineout('    {"category": 'jstr(c~category)', "name": 'jstr(c~name)', "passed": 'jbool(c~passed)', "detail": 'jstr(c~detail)'}'comma)
  end
  s~lineout('  ]')
  s~lineout('}'); s~close
  return

ensureDir: procedure
  use strict arg path
  address system 'mkdir -p -- 'shellQuote(path)
  if rc<>0 then raise syntax 88.900 array('cannot create output directory',path)
  return
shellQuote: procedure
  use strict arg v
  return "'"||v~changeStr("'","'\\''")||"'"
jbool: procedure
  use strict arg v
  if v then return 'true'
  return 'false'
jstr: procedure
  use strict arg x
  if x==.nil then return 'null'
  t=x~string; t=t~changeStr('\\','\\\\')~changeStr('"','\\"')~changeStr('0a'x,'\\n')~changeStr('0d'x,'\\r')
  return '"'||t||'"'

::requires 'OorexxML.cls'
