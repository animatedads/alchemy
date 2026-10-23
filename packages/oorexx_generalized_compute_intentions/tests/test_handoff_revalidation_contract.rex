workload = .Object~new
resource = .Object~new
allow = .AllowAdapter~new
planner = .GeneralizedComputeIntentionProvider~new(.ComputeAdapter~new(resource), allow, allow, allow)
handoff = planner~prepareAdmission(workload)
call assertTrue handoff \== .nil, 'handoff exists'
call assertTrue handoff~revalidationRequired, 'handoff requires revalidation'
a = handoff~revalidationAuthorities
call assertEqual 4, a~items, 'four revalidation authorities'
call assertEqual 'COMPUTE', a[1], 'compute revalidation'
call assertEqual 'ALLOCATION', a[2], 'allocation revalidation'
call assertEqual 'WLU', a[3], 'WLU revalidation'
call assertEqual 'ROUTER', a[4], 'router revalidation'
call assertTrue handoff~workload == workload, 'workload identity retained'
call assertTrue handoff~resource == resource, 'resource identity retained'
say 'PASS planned handoff explicitly requires authoritative revalidation'
exit 0

assertEqual: procedure
  use arg expected, actual, label
  if expected \= actual then do
    say 'FAIL' label 'expected='expected 'actual='actual
    exit 1
  end
  return
assertTrue: procedure
  use arg condition, label
  if \condition then do
    say 'FAIL' label
    exit 1
  end
  return

::class ComputeAdapter subclass ComputeIntentionAdapter
::method init
  expose resource
  use arg resource
::method discoverCandidates
  expose resource
  use arg workload, context=.nil
  return .array~of(resource)
::method assess
  use arg workload, resource, context=.nil
  return .IntentionAssessment~new(.true, 'compute', 'CAPABLE', resource)
::class AllowAdapter
::method assess
  use arg workload, resource, context=.nil
  return .IntentionAssessment~new(.true, 'authority', 'ALLOW', resource)
::requires '../src/GeneralizedComputeIntentions.cls'
