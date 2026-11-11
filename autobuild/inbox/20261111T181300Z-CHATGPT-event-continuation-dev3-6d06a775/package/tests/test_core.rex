/* Native ooRexx deterministic domain tests. No networking or browser required. */
parse arg root
if root='' then root=directory()
flag=root||'/input/test.flag'
log=root||'/state/test.journal'
sizeFlag=root||'/input/size.flag'
absentFlag=root||'/input/absent.flag'
if stream(flag,'C','QUERY EXISTS')<>'' then call SysFileDelete flag
if stream(sizeFlag,'C','QUERY EXISTS')<>'' then call SysFileDelete sizeFlag
if stream(absentFlag,'C','QUERY EXISTS')<>'' then call SysFileDelete absentFlag
if stream(log,'C','QUERY EXISTS')<>'' then call SysFileDelete log
c=.ContinuationCoordinator~new(log)
w=.ContinuationWatch~new('A','FILE_EXISTS',flag,'rasen-falcon','Your file exists')
c~addWatch(w)
call assert c~tick~items=0, 'no event before creation'
call lineout flag,'data'
call stream flag,'C','CLOSE'
call assert c~tick~items=1, 'edge generated once'
e=c~next(100)
call assert e<>.nil, 'event pending'
id=e~eventId
call assert c~tick~items=0,'no repeated event while true'
call assert c~next(100)~eventId==id, 'unclaimed event visible'
call assert \c~complete(id,'A1',101), 'unclaimed completion rejected'
call assert c~claim(id,'A1',100,10), 'first claim succeeds'
call assert \c~claim(id,'A2',101,10), 'competing session rejected'
call assert c~next(105)==.nil, 'in-flight event not offered to second browser'
call assert \c~receive(id,'A2',101), 'foreign receipt rejected'
call assert c~receive(id,'A1',101), 'own receipt accepted'
call assert \c~complete(id,'A1',111), 'expired lease cannot complete'
call assert c~next(111)~eventId==id, 'expired lease becomes deliverable'
call assert c~claim(id,'A2',112,10), 'expired lease can be re-claimed'
call assert c~receive(id,'A2',113), 'new owner may receive'
call assert c~complete(id,'A2',113), 'new owner completes'
call assert c~complete(id,'A2',113), 'completion retry is idempotent'
call assert \c~complete(id,'A1',113), 'wrong completion retry rejected'
call assert c~next(200)==.nil, 'completed event hidden'
call assert \c~claim('EV-UNKNOWN','A1',100,5), 'unknown event rejected'
call assert \c~claim(id,'A1',200,10), 'completed event not re-claimed'
call assert c~tick~items=0, 'high level does not retrigger'
call SysFileDelete flag
call assert c~tick~items=0, 'falling edge re-arms durably'
/* This restart is the dev1 failure case: file was removed before restart. */
c2=.ContinuationCoordinator~new(log)
call assert c2~hasWatch('A'), 'watch survives restart'
call assert \c2~store~latched('A'), 'falling edge survived restart'
call lineout flag,'data again'
call stream flag,'C','CLOSE'
call assert c2~tick~items=1, 'reappearance AFTER restart fires new event'
newId=c2~next(200)~eventId
call assert newId<>id, 'monotonically increasing event identity'
call assert c2~claim(newId,'B1',200,10), 'claim second event'
call assert c2~receive(newId,'B1',201), 'receive second event'
c3=.ContinuationCoordinator~new(log)
call assert c3~next(205)==.nil, 'active lease reconstructed after restart'
call assert c3~next(211)~eventId==newId, 'lease expiry reconstructed after restart'
call assert c3~claim(newId,'B2',211,10), 'reclaim after restart'
call assert c3~receive(newId,'B2',212), 'new owner acknowledges receipt'
call assert c3~complete(newId,'B2',212), 'complete after recovery'
call assert c3~tick~items=0, 'already high after restart does not refire'
call SysFileDelete flag
call assert c3~tick~items=0, 'second falling edge persisted'

wSize=.ContinuationWatch~new('SIZE','FILE_SIZE_GE',sizeFlag,'general','Size threshold',5)
c3~addWatch(wSize)
call lineout sizeFlag,'abc'
call stream sizeFlag,'C','CLOSE'
call assert c3~tick~items=0,'below size threshold no event'
call lineout sizeFlag,'abcdef'
call stream sizeFlag,'C','CLOSE'
call assert c3~tick~items=1,'size threshold generates event'

wAbsent=.ContinuationWatch~new('ABSENT','FILE_ABSENT',absentFlag,'operations','File is absent')
c3~addWatch(wAbsent)
call assert c3~tick~items=1,'file absent fires initial edge'
call assert c3~tick~items=0,'absence stays high without repeat'
call lineout absentFlag,'exists'
call stream absentFlag,'C','CLOSE'
call assert c3~tick~items=0, 'presence re-arms absent predicate'
call SysFileDelete absentFlag
call assert c3~tick~items=1,'file absent again fires a new event'

call SysFileDelete flag
call SysFileDelete sizeFlag
call SysFileDelete absentFlag
say 'PASS test_core: durable rearm, leases, receipt, completion, restart and three predicates'
exit 0

::routine assert
  use strict arg condition,message
  if \condition then do
    say 'FAIL: '||message
    exit 2
  end

::requires 'ContinuationCore.cls'
