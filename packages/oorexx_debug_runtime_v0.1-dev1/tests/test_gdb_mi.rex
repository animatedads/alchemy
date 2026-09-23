parse source . . here
call directory filespec('L',here)

line='*stopped,reason="breakpoint-hit",disp="keep",bkptno="7",thread-id="1",frame={addr="0x0000000000401137",func="main",file="demo.c",fullname="/tmp/demo.c",line="9"}'
r=.GdbMiParser~parse(line)
if r~prefix<>'*' | r~recordClass<>'stopped' then call fail 'record classification'
if r~results['reason']<>'breakpoint-hit' then call fail 'reason parse'
if r~results['frame']['func']<>'main' then call fail 'tuple parse'
e=.GdbMiProjector~providerEvent(r)
if e~type<>.DebugProviderEvents~BREAKPOINT_HIT then call fail 'semantic projection'
if e~data['providerId']<>'7' then call fail 'breakpoint id projection'
if e~data['frame']~source<>'/tmp/demo.c' | e~data['frame']~line<>9 then call fail 'frame projection'

r=.GdbMiParser~parse('=thread-created,id="3",group-id="i1"')
e=.GdbMiProjector~providerEvent(r)
if e~type<>.DebugProviderEvents~THREAD_STARTED | e~data<>'3' then call fail 'thread-created projection'

say 'DEBUG GDB/MI CODEC + PROJECTOR: OK'
exit 0
fail: procedure
  parse arg m; say 'FAIL:' m; exit 1
::requires "GdbMi.cls"
