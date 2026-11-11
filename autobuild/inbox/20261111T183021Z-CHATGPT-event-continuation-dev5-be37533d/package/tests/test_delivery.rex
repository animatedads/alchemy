/* Isolated native regression for registered predicates, escaped journal, dead letters. */
parse arg root
if root='' then root=directory()
flag=root||'/input/delivery.flag'
other=root||'/input/delivery-other.flag'
log=root||'/state/delivery-test.journal'
do path over .array~of(flag,other,log)
  if stream(path,'C','QUERY EXISTS')<>'' then call SysFileDelete path
end

registry=.ContinuationPredicateRegistry~new
call assert registry~supports('FILE_EXISTS'), 'builtin file provider registered'
call assert \registry~supports('NOT_THERE'), 'unknown provider absent'
call assert registry~register('ALWAYS',.ConstantPredicate~new), 'external predicate registered'
c=.ContinuationCoordinator~new(log,.nil,registry)
watch=.ContinuationWatch~new('PIPE','FILE_EXISTS',flag,'no-such-chat','disk|90% full')
c~addWatch(watch)
c~addWatch(.ContinuationWatch~new('GOOD','FILE_EXISTS',other,'operations','second'))
c~addWatch(.ContinuationWatch~new('CUSTOM','ALWAYS',other,'general','custom triggered'))
call assert c~tick~items=1, 'custom predicate fires without file'
call lineout flag,'present'
call stream flag,'C','CLOSE'
call lineout other,'present'
call stream other,'C','CLOSE'
call assert c~tick~items=2, 'both independent file events fire'

replayed=.ContinuationCoordinator~new(log,.nil,registry)
call assert replayed~hasWatch('PIPE'), 'escaped W2 registration survives restart'
call assert replayed~hasWatch('CUSTOM'), 'custom test registration survives restart'
call assert replayed~next(100)~watchId='CUSTOM', 'first custom event preserved'
custom=replayed~next(100)
call assert custom~nudge=='The event you registered a request for CUSTOM has occurred, check Rasen Falcon MCP', 'nudge exact, contains no observation payload'
call assert pos('custom triggered',custom~wire)=0, 'raw result not copied into chat wire'
call assert replayed~claim(custom~eventId,'worker',100,2), 'custom lease assigned'
call assert replayed~receive(custom~eventId,'worker',100), 'receipt posted'
call assert replayed~complete(custom~eventId,'worker',101), 'read after receipt completes'
pipe=replayed~next(101)
call assert pipe~message='disk|90% full', 'pipe byte preserved in event journal'
call assert pipe~watchId='PIPE', 'event identity exact'

/* An unreachable target gets a finite number of leases and then DLQ state. */
call assert replayed~claim(pipe~eventId,'browser1',100,2), 'unreachable target lease 1'
call assert replayed~claim(pipe~eventId,'browser2',102,2), 'unreachable target lease 2'
call assert replayed~claim(pipe~eventId,'browser3',104,2), 'unreachable target lease 3'
remaining=replayed~next(106)
call assert remaining<>.nil & remaining~watchId='GOOD', 'dead target does not starve later result'
call assert replayed~store~deadLetters~items=1, 'exhausted event dead-lettered'
call assert replayed~store~eventById(pipe~eventId)~dead, 'dead-letter visible by ID'
call assert \replayed~claim(pipe~eventId,'browser4',107,2), 'dead-letter cannot be reclaimed'

recovered=.ContinuationCoordinator~new(log,.nil,registry)
call assert recovered~store~deadLetters~items=1, 'dead-letter survives restart'
call assert recovered~store~eventById(pipe~eventId)~message='disk|90% full', 'pipe survives later replay'
call assert recovered~next(107)~watchId='GOOD', 'nondead delivery available after recovery'

call SysFileDelete flag
call SysFileDelete other
say 'PASS test_delivery: provider registration, hex journal, fixed nudge, retry budget, DLQ and restart'
exit 0

::routine assert
  use strict arg value,message
  if \value then do
    say 'FAIL: '||message
    exit 2
  end

::class ConstantPredicate public
::method evaluate
  use strict arg watch
  return .true

::requires 'ContinuationCore.cls'
