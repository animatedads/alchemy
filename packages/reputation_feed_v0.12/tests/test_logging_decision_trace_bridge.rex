/* Feed supplies the payload; ooRexx Logging owns policy/targets/scopes. */
trace=.ReputationFeedDecisionTrace~new('TRACE-LOG')
trace~seal

service=.LogService~new('reputation-feed-audit')
memory=.LogMemoryTarget~new('memory',.Log~INTERNAL)
service~addTarget(memory)
rule=.LogRule~new('feed-decision-audit','reputation_feed','ReputationFeedLoggingBridge','record', -
  .Log~INTERNAL,.Log~INTERNAL,.Log~INFO,.LogConditionAlways~new,.array~of('memory'),.array~of('DECISION'))
service~addRule(rule)
bridge=.ReputationFeedLoggingBridge~new(service,.Log~INTERNAL,.Log~INFO)
call true bridge~record(trace),'configured logging rule accepts trace'
call eq 1,memory~count,'one structured log event emitted'
event=memory~events[1]
call same trace,event~payload,'log payload is exact Feed trace object'
call eq 'REPUTATIONFEEDDECISIONTRACE',event~payloadClass,'payload class retained'
call eq 'DECISION',event~point,'decision point retained'
call eq .Log~INTERNAL,event~sourceScope,'source scope remains logging-owned'

service2=.LogService~new('reputation-feed-no-policy')
bridge2=.ReputationFeedLoggingBridge~new(service2,.Log~INTERNAL,.Log~INFO)
call false bridge2~record(trace),'absence of logging rule is clean no-op'

unsealed=.ReputationFeedDecisionTrace~new('TRACE-UNSEALED')
signal on syntax name expectedUnsealed
ignore=bridge~record(unsealed)
say 'FAIL: unsealed trace was accepted'; exit 1
expectedUnsealed:
  signal off syntax

adoption=.AlchemyAdoptionVerifier~verify(bridge,'STANDARD'); call true adoption~ok,'logging bridge Alchemy adoption'
say 'PASS test_logging_decision_trace_bridge events='memory~count 'payload_object=preserved policy_owned_by=logging'
exit 0

same: procedure
  use arg expected,actual,label
  if expected \== actual then do; say 'FAIL:' label; exit 1; end
  return
true: procedure
  use arg value,label
  if \value then do; say 'FAIL:' label; exit 1; end
  return
false: procedure
  use arg value,label
  if value then do; say 'FAIL:' label; exit 1; end
  return
eq: procedure
  use arg expected,actual,label
  if expected \== actual then do; say 'FAIL:' label 'expected='expected 'actual='actual; exit 1; end
  return

::requires 'AlchemyAdoption.cls'
::requires 'ReputationFeedLoggingBridge.cls'
