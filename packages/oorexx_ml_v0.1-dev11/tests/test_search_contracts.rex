objective=.MLObjective~new('audio-distance','MINIMIZE','0.35*global+0.40*median+penalties','lower is better')
call eq objective~fitnessFor(7.5),-7.5,'minimize score becomes negative fitness'
call true objective~better(2,3),'minimize objective comparison'
adapter=.MLObjectiveFitnessAdapter~new(objective,.ScoreSeven~new)
call eq adapter~fitness('anything'),-7,'objective adapter owns score-to-fitness sign'

spaceA=.MLSearchSpace~new('A',.array~of(,
  .MLParameterDomain~new('gain_db',.array~of(16,18,20,22,24,26,28,30,32,34,36,38,40)),,
  .MLParameterDomain~new('highpass',.array~of(40,50,70,90,120,150))))
spaceC=.MLSearchSpace~new('C',.array~of(,
  .MLParameterDomain~new('gain_db',.array~of(18,20,22,24,26,28,30,32,34,36,38)),,
  .MLParameterDomain~new('highpass',.array~of(40,50,70,90,120,150))))
cmp=.MLSearchSpaceComparison~compare(spaceA,spaceC)
call eq cmp~relation,'RIGHT_SUBSET','GA space explicitly identified as narrower'
call true \cmp~equivalent,'spaces are not silently comparable as equal'

workspace=.MLWorkspaceBudget~gib(7,1,8,24,'NONE','FAIL_CLOSED')
unit=1073741824
pre=workspace~preflight(8*unit)
call true pre['allowed'],'8 GiB launch preflight passes'
pre2=workspace~preflight(7*unit)
call true \pre2['allowed'],'7 GiB launch preflight fails because reserve is required'
call eq workspace~retainedOutputLimit,24,'retained output cap'

retention=.MLRetentionPolicy~new(24,'PCM_HASH','PROMOTED_ONLY')
strategy=.MLSearchStrategySpec~new('C-GA','GENETIC',.directory~new)
lane=.MLSearchLane~new('C',strategy,spaceC,objective,workspace,retention)
experiment=.MLSearchExperiment~new('audio-search')
experiment~addLane(lane)
root=experiment~checkpoint('before-search','SEARCH')
lane~begin; lane~recordEvaluation(.true); lane~recordEvaluation(.false); lane~recordPromotion
call eq lane~at('evaluations'),2,'lane evaluation count'
call eq lane~at('uniqueEvaluations'),1,'lane unique evaluation count'
call eq lane~at('promoted'),1,'lane promotion count'
future=experiment~checkpoint('search-future','SEARCH')
experiment~rollback(root,'first-search-future')
call eq lane~at('evaluations'),0,'coordinated rollback restores lane state'
experiment~rollForward('first-search-future')
call eq lane~at('evaluations'),2,'retained search future restores lane state'
report=.MLSearchQualification~preflight(lane,8*unit)
call true report~passed,'search qualification preflight'
say 'PASS test_search_contracts'
exit 0

eq: procedure
 use arg a,e,l
 if a\==e then do; say 'FAIL' l; say ' expected='e; say ' actual  ='a; exit 1; end
 return
true: procedure
 use arg v,l
 if \v then do; say 'FAIL' l; exit 1; end
 return
::class ScoreSeven public
::method score
  use strict arg subject
  return 7
::requires "OorexxML.cls"
