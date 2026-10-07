parse source . . here
base=filespec("L",here)
call value "REXX_PATH", base||"/../src:"||value("REXX_PATH",,"ENVIRONMENT"), "ENVIRONMENT"

a=.MessagingAddress~new("agent-a","example.test","one")
b=.MessagingAddress~new("agent-b","example.test")
meta=.directory~new
meta["AUTHORITY"]="RTO2"
m=.Message~new("m1",a,b,"hello","","text/plain","thread-7","2026-10-07T13:00:00Z",.nil,meta)
call assertTrue m~fromAddress==a,"from object preserved"
call assertTrue m~toAddress==b,"to object preserved"
call assertEq "RTO2",m~metadata["AUTHORITY"],"metadata object preserved"
r=m~reply("m2","reply")
call assertTrue r~fromAddress==b,"reply from original recipient"
call assertTrue r~toAddress==a,"reply to original sender"
call assertTrue r~replyTo==m,"reply relationship preserves message object"
call assertEq "thread-7",r~threadId,"thread preserved"
p=.PresenceState~new(a,.PresenceAvailability~AVAILABLE,"ready")
call assertTrue p~address==a,"presence preserves address object"
say "PASS test_core_objects"
exit 0
assertEq: procedure
  use arg e,a,l
  if e==a then return
  say "FAIL" l "expected="e "actual="a
  exit 1
assertTrue: procedure
  use arg v,l
  if v then return
  say "FAIL" l
  exit 1
::requires "MessagingPresence.cls"
