/* Opaque provenance fields must not become a covert customer-prose channel. */
failed=.false
signal on syntax name badref
x=.StructuredUtteranceGenerationPlan~new('PLAN-REF-1','UTT-REF-1','AGENT','CHAT','','ORCHESTRATOR','APP','Barbie Example at 12 Private Road')
signal off syntax
say 'FAIL: free prose provider ref accepted'
exit 1
badref:
  signal off syntax
  failed=.true
call assertTrue failed,'free prose provider ref rejected'
plan=.StructuredUtteranceGenerationPlan~new('PLAN-REF-2','UTT-REF-2','AGENT','CHAT','','ORCHESTRATOR','APP','PROVIDER:INV:22','MODEL:42','RESPONSE:PLAN:22')
call assertEqual 'PROVIDER:INV:22',plan~providerInvocationRef,'opaque provider ref preserved'
say 'PASS test_controlled_provenance_refs'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'StructuredUtteranceProducer.cls'
