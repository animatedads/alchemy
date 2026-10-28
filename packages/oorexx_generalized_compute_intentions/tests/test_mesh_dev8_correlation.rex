/* Instrumentation Mesh dev8 explicit correlation integration.
 * Correlation, causation and context references are accepted only from caller
 * context.  GCI never infers them from time/resource/service adjacency.
 */
identity=.InstrumentationCodec~identity('alchemy','generalized-compute-intentions','planner-dev7','node-a','','COMPUTE_INTENTIONS')
telemetry=.GeneralizedComputeIntentionsInstrumentation~new(identity)
resource=.Object~new
allow=.AllowAdapter~new
planner=.GeneralizedComputeIntentionProvider~new(.ComputeAdapter~new(resource),allow,allow,allow)
instrumented=.InstrumentedGeneralizedComputeIntentionProvider~new(planner,telemetry)

context=.directory~new
context['INSTRUMENTATION_EVENT_OBSERVED_AT']='2026-10-28T17:00:00Z'
context['INSTRUMENTATION_CORRELATION_ID']='corr-workload-42'
context['INSTRUMENTATION_CAUSATION_ID']='intent-17'
context['INSTRUMENTATION_CONTEXT_REFS']=.array~of('workload:42','conversation:17')

route=instrumented~planAdmittance(.Object~new,context)
call assertEqual 'READY',route~state,'route ready'
events=telemetry~events('2026-10-28T17:00:01Z')
call assertTrue events~items>=2,'events retained'
do e over events
  call assertEqual 'corr-workload-42',e['correlation_id'],'explicit correlation retained'
  call assertEqual 'intent-17',e['causation_id'],'explicit causation retained'
  call assertTrue e['context_refs']~items=2,'context references retained'
  call assertEqual 'workload:42',e['context_refs'][1],'first context reference'
end

/* No caller correlation means no correlation. There is intentionally no
 * inference from the same resource, planner, timestamp or operation family. */
plain=instrumented~planAdmittance(.Object~new,.directory~new)
call assertEqual 'READY',plain~state,'plain route ready'
allEvents=telemetry~events('2026-10-28T17:00:02Z')
last=allEvents[allEvents~items]
call assertEqual '',last['correlation_id'],'correlation is not inferred'
call assertEqual '',last['causation_id'],'causation is not inferred'
call assertEqual 0,last['context_refs']~items,'context refs are not inferred'

say 'PASS Instrumentation Mesh dev8 explicit correlation propagation'
exit 0

assertEqual: procedure
  use strict arg expected,actual,label
  if expected \= actual then raise syntax 93.900 array('assertEqual failed:' label 'expected='expected 'actual='actual)
  return
assertTrue: procedure
  use strict arg value,label
  if value \== .true then raise syntax 93.900 array('assertTrue failed:' label)
  return

::class ComputeAdapter subclass ComputeIntentionAdapter
::method init
  expose resource
  use strict arg resource
::method discoverCandidates
  expose resource
  use arg workload,context=.nil
  return .array~of(resource)
::method assess
  use arg workload,resource,context=.nil
  return .IntentionAssessment~new(.true,'compute','CAPABLE',resource)

::class AllowAdapter
::method assess
  use arg workload,resource,context=.nil
  return .IntentionAssessment~new(.true,'authority','ALLOW',resource)

::requires '../src/GeneralizedComputeInstrumentation.cls'
