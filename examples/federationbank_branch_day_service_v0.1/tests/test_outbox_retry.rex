sink=.FederationBankBranchDayMemoryEventSink~new; sink~failNext; s=.FBBranchDayServiceTest~service(.nil,sink); d=.FBBranchDayServiceTest~create(s,"DAY-EVT"); r=s~flushOutbox; .FBBranchDayServiceTest~assertTrue(\r~ok); .FBBranchDayServiceTest~assertEq(s~state~outbox~items,1); r=s~flushOutbox; .FBBranchDayServiceTest~assertTrue(r~ok); .FBBranchDayServiceTest~assertEq(s~state~outbox~items,0)
say "PASS: Branch Day events are durable and retried at least once"
::requires "TestSupport.cls"
