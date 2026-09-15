svc=.FBStaffServiceTestSupport~service
ctx=.FBStaffServiceTestSupport~context("TELLER-04","TELLER","S-TEL")
r=.FBStaffServiceTestSupport~putContext(svc,"CTX-IDEM",ctx)
.FBStaffServiceTestSupport~assertTrue(r~ok,"first")
r2=.FBStaffServiceTestSupport~putContext(svc,"CTX-IDEM",ctx)
.FBStaffServiceTestSupport~assertTrue(r2~ok,"replay")
.FBStaffServiceTestSupport~assertEq("IDEMPOTENT_REPLAY",r2~code,"same command replay")
ctx2=.FBStaffServiceTestSupport~context("TELLER-05","TELLER","S-T5")
r3=.FBStaffServiceTestSupport~putContext(svc,"CTX-IDEM",ctx2)
.FBStaffServiceTestSupport~assertFalse(r3~ok,"command id collision")
.FBStaffServiceTestSupport~assertEq("COMMAND_ID_CONFLICT",r3~code,"semantic idempotency")
.FBStaffServiceTestSupport~pass("durable command identity is semantic")
::requires "TestSupport.cls"
