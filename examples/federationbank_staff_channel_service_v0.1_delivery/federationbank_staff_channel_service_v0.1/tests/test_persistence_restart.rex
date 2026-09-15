e=.FederationBankStaffCorePolicyFixtures~engine
.FBStaffChannelServiceTestSupport~openAccounts(e)
.FBStaffChannelServiceTestSupport~seed(e,3000000)
root="/tmp/fbstaffch-state-"||time("S")||"-"||random(100000,999999)
store=.FederationBankStaffChannelServiceStore~new(root)
teller=.FBStaffChannelServiceTestSupport~context("TELLER-04","TELLER","S-TEL")
sup=.FBStaffChannelServiceTestSupport~context("SUP-01","SUPERVISOR","S-SUP")
contexts=.FBStaffChannelServiceTestSupport~contexts(teller,sup)
req=.FBStaffChannelServiceTestSupport~request("PERSIST","TELLER-04","S-TEL",1000000)
svc=.FBStaffChannelServiceTestSupport~service(e,store)
r=svc~handle(.FBStaffChannelServiceTestSupport~submitEnvelope("SUBMIT:PERSIST",req,contexts))
.FBStaffChannelServiceTestSupport~assertEq("APPROVAL_REQUIRED",r~value~state,"persisted pending approval")
svc2=.FBStaffChannelServiceTestSupport~service(e,store)
w=svc2~state~work(req~workId)
.FBStaffChannelServiceTestSupport~assertTrue(w<>.nil,"work recovered")
.FBStaffChannelServiceTestSupport~assertEq("APPROVAL_REQUIRED",w~state,"state recovered")
.FBStaffChannelServiceTestSupport~assertEq(w~request~semanticIdentity,req~semanticIdentity,"typed request graph recovered")
ap=.FederationBankStaffApproval~new("AP:PERSIST",w~action,"SUP-01","S-SUP","SUPERVISOR","EVID:PERSIST")~seal
r=svc2~handle(.FBStaffChannelServiceTestSupport~resumeEnvelope("RESUME:PERSIST",w~workId,contexts,.array~of(ap)))
.FBStaffChannelServiceTestSupport~assertTrue(r~ok,"resume recovered work")
.FBStaffChannelServiceTestSupport~assertEq("COMPLETED",r~value~state,"completed")
.FBStaffChannelServiceTestSupport~pass("typed Staff Channel work graph survives service restart")
::requires "FederationBankStaffChannelServicePersistence.cls"
::requires "TestSupport.cls"
