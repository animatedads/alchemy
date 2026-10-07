workload = .Object~new
resource = .Object~new
compute = .ChangingCompute~new(resource)
pass = .AlwaysPass~new
provider = .GeneralizedComputeIntentionProvider~new(compute, pass, pass, pass)

r1 = provider~planAdmittance(workload)
if r1~state \= 'READY' then call fail 'first discovery should be READY'
compute~available = .false
r2 = provider~planAdmittance(workload)
if r2~state \= 'INFEASIBLE' then call fail 'second discovery should reflect current state'
if r2~candidates~items \= 0 then call fail 'candidate catalogue was incorrectly cached'
say 'PASS intentions dynamically rediscover compute state'
exit 0

fail: procedure
 use arg msg
 say 'FAIL' msg
 exit 1

::class ChangingCompute subclass ComputeIntentionAdapter
::method init
 expose resource available
 use arg resource
 available = .true
::attribute available
::method discoverCandidates
 expose resource available
 use arg workload, context=.nil
 if available then return .array~of(resource)
 return .array~new
::method assess
 use arg workload, resource, context=.nil
 return .IntentionAssessment~new(.true, 'compute', 'CAPABLE')

::class AlwaysPass
::method assess
 use arg workload, resource, context=.nil
 return .IntentionAssessment~new(.true, 'test-authority', 'OK')

::requires '../src/GeneralizedComputeIntentions.cls'
