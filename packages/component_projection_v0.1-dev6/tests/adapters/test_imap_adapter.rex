call rxfuncadd 'SysLoadFuncs','RexxUtil','SysLoadFuncs'; call SysLoadFuncs
r=.ComponentProjectionRegistry~new
s=.FakeImapSession~new
a=.ImapComponentProjectionAdapter~new(r,s)
a~install
call assertEq "CONNECTED",r~readObject("/imap/session/state"),"state"
call assertTrue \r~exists("/imap/selected/mailbox"),"selected absent"
s~selectFake
call assertEq 1,a~refresh,"refresh selected"
call assertEq "INBOX",r~readObject("/imap/selected/mailbox"),"mailbox"
call assertEq 42,r~readObject("/imap/selected/exists"),"exists"
call assertTrue r~endpoint("/imap/session/state")~writable=.false,"read only"
s~clearFake; a~refresh
call assertTrue \r~exists("/imap/selected/mailbox"),"selected removed"
say "PASS IMAP component projection adapter"
exit 0
assertEq: procedure; use arg e,g,m; if e<>g then do; say "FAIL" m e g; exit 1; end; return
assertTrue: procedure; use arg v,m; if \v then do; say "FAIL" m; exit 1; end; return
::class FakeSelected
::attribute mailbox; ::attribute exists; ::attribute recent; ::attribute unseenCount; ::attribute firstUnseenSequence
::attribute uidValidity; ::attribute uidNext; ::attribute highestModSeq; ::attribute readOnly; ::attribute flags; ::attribute permanentFlags
::method init
  self~mailbox="INBOX"; self~exists=42; self~recent=2; self~unseenCount=5; self~firstUnseenSequence=3
  self~uidValidity="7"; self~uidNext="50"; self~highestModSeq="9"; self~readOnly=.false; self~flags="(\\Seen)"; self~permanentFlags="(\\Seen)"
::class FakeImapSession
::attribute selectedState get
::method init; expose selectedState; selectedState=.nil
::method state; return "CONNECTED"
::method greeting; return "* OK"
::method capabilities; return .array~of("IMAP4REV1")
::method lastEventError; return ""
::method selectFake; expose selectedState; selectedState=.FakeSelected~new
::method clearFake; expose selectedState; selectedState=.nil
::requires "ComponentProjectionImap.cls"
