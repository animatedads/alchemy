t=.FakeTransport~new
w=.TN3270Wire~new
s=.TN3270LiveSession~new(t,w,"MVS3270-1")
required=.array~of("SESSIONID","STATE","OPEN","OBSERVERPORT","SNAPSHOT","PUMPONCE","ENABLECONTROLGATE","ACQUIRECONTROL","REVOKECONTROL","CONTROLACTIVE","ACTIVECONTROLLERIDENTITY","CLOSE","CLAIMEXCLUSIVEOWNER","RELEASEEXCLUSIVEOWNER")
do m over required
 if \s~hasMethod(m) then call fail "missing "m
end
owner=.Object~new
r=s~claimExclusiveOwner(owner); if \r~ok then call fail "claim"
r=s~open(owner); if \r~ok | s~state<>"OPEN" then call fail "open"
if s~observerPort~hasMethod("SETINPUTTEXTAT") then call fail "observer mutation leak"
if s~setInputTextAt(1,1,"X")~code<>"SESSION_OWNERSHIP_REQUIRED" then call fail "direct mutation after claim"
r=s~close(owner); if \r~ok then call fail "close"
r=s~releaseExclusiveOwner(owner); if \r~ok then call fail "release"
say "PASS TN3270 ownership surface"
exit 0
fail: procedure
 parse arg why
 say "FAIL" why
 exit 1
::class FakeTransport public
::method open; return .TerminalResult~success(.true)
::method close; return .TerminalResult~success(.true)
::method waitReadable; use arg timeout=1; return .TerminalResult~success(.false)
::method receiveBytes; use arg maximum=8192; return .TerminalResult~success("")
::method sendBytes; use arg bytes; return .TerminalResult~success(length(bytes))
::requires "TN3270LiveSession.cls"
