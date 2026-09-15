e=.FederationBankStaffCorePolicyFixtures~engine
.FBStaffChannelTestSupport~openAccounts(e)
.FBStaffChannelTestSupport~seed(e,2000000)
ctx=.FBStaffChannelTestSupport~context("TELLER-04","TELLER","S-TEL")
request=.FBStaffChannelTestSupport~relationshipRequest("CASECHAIN")
r=.FBStaffChannelTestSupport~orchestrator(e)~begin(request,.FBStaffChannelTestSupport~contexts(ctx))
.FBStaffChannelTestSupport~assertTrue(r~ok,"relationship orchestration")
w=r~value
.FBStaffChannelTestSupport~assertEq("COMPLETED",w~state,"completed")
.FBStaffChannelTestSupport~assertEq("CASE:CASECHAIN",w~relationshipEvidence~caseId,"case retained")
.FBStaffChannelTestSupport~assertEq("CASE:CASECHAIN",w~action~caseId,"staff action retains case")
.FBStaffChannelTestSupport~assertTrue(w~staffEnvelope<>.nil,"staff authority retained")
.FBStaffChannelTestSupport~assertEq(1750000,e~ledger~balanceMinor("GBP-SRC"),"source")
.FBStaffChannelTestSupport~pass("Relationship decision remains independent evidence through Staff Channel")
::requires "TestSupport.cls"
