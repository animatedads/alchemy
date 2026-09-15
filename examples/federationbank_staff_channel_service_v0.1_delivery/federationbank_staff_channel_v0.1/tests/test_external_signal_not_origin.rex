now=.DateTime~new
cmd=.FederationBankCommand~new("CMD:X","TRANSFER","IDEM:X","CUST-001","GBP-SRC","GBP-DST","GBP",1000,"STAFF","TELLER-04",now)
snap=.FederationBankStaffChannelCommandSnapshot~fromCommand(cmd)
request=.FederationBankStaffChannelRequest~new("REQ:X","WORK:X","EXTERNAL_SIGNAL","TELLER-04","S-TEL","DOUGLAS","DESK-04",snap,.nil,now)~seal
ctx=.FBStaffChannelTestSupport~context("TELLER-04","TELLER","S-TEL")
r=.FBStaffChannelTestSupport~orchestrator(.FederationBankStaffCorePolicyFixtures~engine)~begin(request,.FBStaffChannelTestSupport~contexts(ctx))
.FBStaffChannelTestSupport~assertFalse(r~ok,"external observation is not an action origin")
.FBStaffChannelTestSupport~assertEq("CHANNEL_POLICY_NO_RULE",r~code,"must become relationship decision first")
.FBStaffChannelTestSupport~pass("external signal cannot jump directly into Staff/Core authority")
::requires "TestSupport.cls"
