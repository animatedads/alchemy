/* SLAM selection and bounded consistency scoring: synthetic evidence only. */
s=.SlamRecoveryStrategy~new
call check s~select(3,.true,.true,.true,.true)~items=0,'insufficient frames'
call check s~select(6,.false,.true,.true,.true)~items=0,'no measured motion'
methods=s~select(6,.true,.true,.true,.true)
call check methods~items=5,'five registered methods'
call check s~select(6,.true,.false,.false,.false)~items=1,'only supported method'
m=.directory~new
m['BASELINE_RESIDUAL']=10
m['CANDIDATE_RESIDUAL']=9
m['SUPPORT_FRACTION']=0.8
m['UNCERTAINTY_FRACTION']=0.1
m['HELDOUT_PAIRS']=4
assessment=.MediaVideoRecoveryAssessment~new('ELIGIBLE','CONSISTENCY_ONLY',m)
r=s~score(assessment,'producer','producer')
call check r['STATUS']='UNQUALIFIED','checker cannot be producer'
r=s~score(assessment,'producer','independent-checker')
call check r['STATUS']='SCORED_CONSISTENCY','scoring admitted'
call check r['SCORE']>0 & r['SCORE']<=100,'bounded comparative score'
call check \r['TESTED'],'score not automatic TESTED'
m['CANDIDATE_RESIDUAL']=11
r=s~score(assessment,'producer','independent-checker')
call check r['STATUS']='NO_IMPROVEMENT' & r['SCORE']=0,'no improvement no score'
say 'SLAM_RECOVERY_STRATEGY 9/9 PASS'
exit 0
::routine check
  use strict arg predicate, name
  if \predicate then raise syntax 93.900 array('FAIL',name)
::requires 'SlamRecoveryStrategy.cls'
::requires 'MediaVideoRecoveryEvidence.cls'
