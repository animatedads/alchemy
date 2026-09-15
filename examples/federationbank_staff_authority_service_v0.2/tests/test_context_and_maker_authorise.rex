svc=.FBStaffServiceTestSupport~service
ctx=.FBStaffServiceTestSupport~context("TELLER-04","TELLER","S-TEL")
r=.FBStaffServiceTestSupport~putContext(svc,"CTX-CMD",ctx)
.FBStaffServiceTestSupport~assertTrue(r~ok,"context stored")
a=.FBStaffServiceTestSupport~action("LOW")
p=.directory~new; p["action"]=a; p["envelopeId"]="ENV:LOW"
r=svc~handle(.FederationBankStaffServiceEnvelope~new("AUTH-CMD","FBSTAFF.ACTION.AUTHORISE","TELLER-04","TELLER",p))
.FBStaffServiceTestSupport~assertTrue(r~ok,"maker authority issued")
.FBStaffServiceTestSupport~assertEq("AUTHORISED",r~code,"service result")
.FBStaffServiceTestSupport~assertEq("AUTHORISED",r~value~status,"record status")
.FBStaffServiceTestSupport~assertTrue(r~value~envelope~binds(a),"exact action envelope")
.FBStaffServiceTestSupport~pass("service stores authoritative staff context and issues maker authority")
::requires "TestSupport.cls"
