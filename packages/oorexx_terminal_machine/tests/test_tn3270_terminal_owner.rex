transport=.FakeTransport~new
wire=.TN3270Wire~new
cp=wire~stream~codepage
rec=.Command3270~ERASE_WRITE||"02"x||.Order3270~SBA||.Address3270~encode(0)||.Order3270~SF||"20"x||cp~encode("Logon ===>")||.Order3270~SBA||.Address3270~encode(80)||.Order3270~SF||"00"x||.Order3270~IC||.Order3270~SBA||.Address3270~encode(100)||.Order3270~SF||"20"x
r=wire~stream~applyHostRecord(rec); if \r~ok then call fail "screen"
live=.TN3270LiveSession~new(transport,wire,"MVS3270-OWNER")
owner=.TerminalSessionOwner~new(live,2)
if \owner~open~ok then call fail "owner open"
a=owner~attachObserver("AI_A"); if \a~ok then call fail "observer A"
b=owner~attachObserver("AI_B"); if \b~ok then call fail "observer B"
if a~value~hasMethod("SETFIELD") then call fail "observer leaks mutation"
auth=.FakeAdmissionAuthority~new
if \owner~enableControlGate(auth,"TERMINAL:SESSION:MVS3270-OWNER")~ok then call fail "gate"
ra=.FakeReservation~new("AI_A","TERMINAL:SESSION:MVS3270-OWNER")
rb=.FakeReservation~new("AI_B","TERMINAL:SESSION:MVS3270-OWNER")
ctlr=a~value~requestControl(ra); if \ctlr~ok then call fail "control A"
busy=b~value~requestControl(rb); if busy~ok | busy~code<>"CONTROL_BUSY" then call fail "one writer"
ctl=ctlr~value
gen=ctl~snapshot~value~generation
fields=ctl~snapshot~value~fields
inputId=""
do f over fields
 if f~inputCapable then do; inputId=f~fieldId; leave; end
end
if inputId=="" then call fail "input field"
r=ctl~setField(gen,inputId,"HERC03"); if \r~ok then call fail "field write"
r=ctl~press(gen,"ENTER"); if \r~ok then call fail "enter"
if transport~sent~length=0 then call fail "no AID wire"
if \owner~close~ok then call fail "close"
if live~ownershipClaimed then call fail "ownership release"
say "PASS TN3270 TerminalSessionOwner one-writer path"
exit 0
fail: procedure
 parse arg why
 say "FAIL" why
 exit 1
::class FakeReservation
::attribute identity get
::attribute scope get
::method init
 expose identity scope
 use arg i,s
 identity=i; scope=s
::class FakeAdmissionAuthority
::method admit
 use arg reservation
 return .TerminalResult~success(reservation)
::class FakeTransport public
::attribute sent get
::method init
 expose sent
 sent=""
::method open; return .TerminalResult~success(.true)
::method close; return .TerminalResult~success(.true)
::method waitReadable; use arg timeout=1; return .TerminalResult~success(.false)
::method receiveBytes; use arg maximum=8192; return .TerminalResult~success("")
::method sendBytes
 expose sent
 use arg bytes
 sent||=bytes
 return .TerminalResult~success(length(bytes))
::requires "TN3270LiveSession.cls"
::requires "TerminalOwnership.cls"
