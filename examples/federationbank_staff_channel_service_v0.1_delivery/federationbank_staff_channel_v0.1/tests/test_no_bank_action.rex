e=.FederationBankStaffCorePolicyFixtures~engine
request=.FBStaffChannelTestSupport~noActionRequest("NOACTION")
r=.FBStaffChannelTestSupport~orchestrator(e)~begin(request,.directory~new)
.FBStaffChannelTestSupport~assertTrue(r~ok,"no-action coordination")
w=r~value
.FBStaffChannelTestSupport~assertEq("NO_BANK_ACTION",w~state,"durable no action")
.FBStaffChannelTestSupport~assertEq("NONE",w~route,"no core route")
.FBStaffChannelTestSupport~assertTrue(w~action==.nil,"no staff banking action fabricated")
.FBStaffChannelTestSupport~pass("NO_BANK_ACTION is a positive coordinated outcome")
::requires "TestSupport.cls"
