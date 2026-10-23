p = .StructuredUtteranceProducer~new
fake = '<<SALESPROP>>Would <<CUSTNAME>>Barbie<</CUSTNAME>> like an extra bag?<</SALESPROP>>'
r = p~rejectFlattenedReply(fake,'PROVIDER:INV:77')
call assertFalse r~ok, 'flattened reply rejected'
call assertEqual 'FLATTENED_REPLY_INSUFFICIENT', r~code, 'stable failure code'
r2 = .StructuredUtteranceGenerationPlan~fromFlattenedReply(fake,'PROVIDER:INV:77')
call assertFalse r2~ok, 'plan cannot be reconstructed from text'
call assertEqual 'FLATTENED_REPLY_INSUFFICIENT', r2~code, 'class-level rejection code'
/* The markup is intentionally never parsed. */
call assertTrue r~detail~pos('markup') > 0, 'failure explains markup is not authority'
say 'PASS test_flattened_reply_fails_closed'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'StructuredUtteranceProducer.cls'
