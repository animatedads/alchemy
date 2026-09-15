p20=.MLGABudgetPlan~forCandidateLimit(20,30,3,4)
call eq p20~populationSize,6,'20-budget population'
call eq p20~breedingSteps,2,'20-budget breeding steps'
call eq p20~evaluatedGenerations,3,'20-budget evaluated generations'
call eq p20~plannedEvaluationRequests,18,'20-budget planned requests'
call true p20~plannedEvaluationRequests<=20,'20-budget bounded'

p30=.MLGABudgetPlan~forCandidateLimit(30,30,3,4)
call eq p30~populationSize,10,'30-budget population'
call eq p30~breedingSteps,2,'30-budget breeding steps'
call eq p30~evaluatedGenerations,3,'30-budget evaluated generations'
call eq p30~plannedEvaluationRequests,30,'30-budget exact use'

p180=.MLGABudgetPlan~forCandidateLimit(180,30,3,4)
call eq p180~populationSize,30,'180-budget preferred population'
call eq p180~breedingSteps,5,'180-budget breeding steps'
call eq p180~evaluatedGenerations,6,'180-budget evaluated generations'
call eq p180~plannedEvaluationRequests,180,'180-budget exact use'
say 'PASS test_ga_budget_plan'
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
