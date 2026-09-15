objectives=.MLObjectiveSet~new('OBJ',.array~of(.MLObjective~new('a','MINIMIZE'),.MLObjective~new('b','MINIMIZE')))
constraints=.MLConstraintSet~new('LIMIT',.array~of(.MLDirectoryFieldConstraint~new('x-max','x','LE',.75)))
delegate=.GateDelegate~new
adapter=.MLConstrainedEvaluatorAdapter~new(objectives,constraints,delegate)

good=.MLGenome~new('GOOD',.array~of(.25,.4))
bad=.MLGenome~new('BAD',.array~of(.90,.1))
eg=adapter~evaluate(good); eb=adapter~evaluate(bad)
call true eg~feasible,'good subject is feasible'
call true \eb~feasible,'bad subject is infeasible'
call eq delegate~scoreCalls,1,'infeasible subject rejected before expensive objective scoring'
call true eb~objectiveVector==.nil,'infeasible evaluation publishes no objective vector'
say 'PASS test_constrained_evaluator_fail_closed'
exit 0

eq: procedure
 use arg a,e,l
 if a\==e then do; say 'FAIL' l; say ' expected='e; say ' actual  ='a; exit 1; end
 return
true: procedure
 use arg v,l
 if \v then do; say 'FAIL' l; exit 1; end
 return
::class GateDelegate public
::method init; expose scoreCalls; scoreCalls=0
::method scoreCalls; expose scoreCalls; return scoreCalls
::method constraintSubject
  use strict arg genome
  d=.directory~new; d['x']=genome~gene(1); return d
::method scores
  expose scoreCalls
  use strict arg genome
  scoreCalls=scoreCalls+1; d=.directory~new; d['a']=genome~gene(1); d['b']=genome~gene(2); return d
::requires "OorexxML.cls"
