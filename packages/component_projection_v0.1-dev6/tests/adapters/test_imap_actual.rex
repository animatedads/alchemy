call rxfuncadd 'SysLoadFuncs','RexxUtil','SysLoadFuncs'; call SysLoadFuncs
r=.ComponentProjectionRegistry~new
t=.FakeTransport~new
s=.ImapSession~new(t)
a=.ImapComponentProjectionAdapter~new(r,s)
a~install
if r~readObject("/imap/session/state")<>"CONNECTED" then call fail "actual session state"
if r~exists("/imap/selected/mailbox") then call fail "unexpected selected tree"
if r~endpoint("/imap/session/state")~writable then call fail "actual IMAP report became writable"
say "PASS IMAP actual session projection adapter"
exit 0
fail: procedure; parse arg why; say "FAIL" why; exit 1
::class FakeTransport
::method write; return 1
::method read; return ""
::requires "ImapCore.cls"
::requires "ImapSession.cls"
::requires "ComponentProjection.cls"
::requires "ComponentProjectionImap.cls"
