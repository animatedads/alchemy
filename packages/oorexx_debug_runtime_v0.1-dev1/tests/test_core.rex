parse source . . here
call directory filespec('L',here)

registry=.DebugProviderRegistry~new
provider=.DebugMemoryProvider~new
registry~register(provider)
runtime=.DebugRuntime~new(registry)
target=.DebugTarget~new('proc:42','PROCESS','fixture',.nil,.array~of('DEBUG.MEMORY'))
session=runtime~attach(target)
if session~state<>'RUNNING' then call fail 'attach did not observe RUNNING'

observer=.TestObserver~new
binding=session~when(.Execution~enters('calculateInvoice'))
registration=binding~notify(observer,'hit')
if registration==.nil then call fail 'registration missing'

bp=.nil
do id over session~breakpoints
  bp=session~breakpoints[id]
end
if bp==.nil | \bp~installed | \bp~observedEnabled then call fail 'breakpoint did not become observed installed/enabled'

provider~simulateThread(session,'1','main')
frame=.DebugFrame~new('f1',0,.DebugLocation~new('calculateInvoice','invoice.rex',217), 'ooRexx')
frame~locals~put(.DebugValue~new('customer','Customer','CUST-7'))
frame~locals~put(.DebugValue~new('total','Number',125.50))
if frame~locals~customer~value<>'CUST-7' then call fail 'UNKNOWN local projection failed'
provider~simulateBreakpointHit(session,bp,'1',frame)
if observer~hits<>1 then call fail 'registered breakpoint event not delivered'
if session~state<>'STOPPED' then call fail 'breakpoint hit did not observe STOPPED'
if session~currentFrame~function<>'calculateInvoice' then call fail 'current frame not projected'

/* Control is a request, not an observed state change. */
session~continue
if session~state<>'STOPPED' then call fail 'continue request lied about observed state'
session~acceptProviderEvent(.DebugProviderEvent~new(.DebugProviderEvents~RUNNING))
if session~state<>'RUNNING' then call fail 'provider RUNNING not observed'

say 'DEBUG RUNTIME CORE: OK'
exit 0

fail: procedure
  parse arg m
  say 'FAIL:' m
  exit 1

::class TestObserver
::attribute hits get
::method init
  expose hits
  hits=0
::method hit
  expose hits
  use strict arg event
  hits+=1

::requires "DebugRuntime.cls"
