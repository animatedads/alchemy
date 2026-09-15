root="/tmp/fbstaff-service-"||time("S")||"-"||random(100000,999999)
store=.FederationBankStaffAuthorityServiceStore~new(root)
svc=.FBStaffServiceTestSupport~service(store)
ctx=.FBStaffServiceTestSupport~context("TELLER-04","TELLER","S-TEL")
.FBStaffServiceTestSupport~assertTrue(.FBStaffServiceTestSupport~putContext(svc,"CTX-P",ctx)~ok,"context")
a=.FBStaffServiceTestSupport~action("P")
p=.directory~new; p["action"]=a; p["envelopeId"]="ENV:P"
r=svc~handle(.FederationBankStaffServiceEnvelope~new("AUTH-P","FBSTAFF.ACTION.AUTHORISE","TELLER-04","TELLER",p))
.FBStaffServiceTestSupport~assertTrue(r~ok,"authority")
svc2=.FBStaffServiceTestSupport~service(store)
rec=svc2~state~record("ACT:P")
.FBStaffServiceTestSupport~assertTrue(rec<>.nil,"record recovered")
.FBStaffServiceTestSupport~assertTrue(rec~envelope~binds(rec~action),"typed action/envelope graph recovered")
r2=svc2~handle(.FederationBankStaffServiceEnvelope~new("AUTH-P","FBSTAFF.ACTION.AUTHORISE","TELLER-04","TELLER",p))
.FBStaffServiceTestSupport~assertEq("IDEMPOTENT_REPLAY",r2~code,"receipt recovered")
.FBStaffServiceTestSupport~pass("staff authority state/idempotency recover across restart")
::requires "FederationBankStaffAuthorityServicePersistence.cls"
::requires "TestSupport.cls"
