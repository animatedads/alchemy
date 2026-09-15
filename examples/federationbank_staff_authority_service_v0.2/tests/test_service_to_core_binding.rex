svc=.FBStaffServiceTestSupport~service
ctx=.FBStaffServiceTestSupport~context("TELLER-04","TELLER","S-TEL")
.FBStaffServiceTestSupport~assertTrue(.FBStaffServiceTestSupport~putContext(svc,"CTX-B",ctx)~ok,"context")
a=.FBStaffServiceTestSupport~action("B")
p=.directory~new; p["action"]=a; p["envelopeId"]="ENV:B"
r=svc~handle(.FederationBankStaffServiceEnvelope~new("AUTH-B","FBSTAFF.ACTION.AUTHORISE","TELLER-04","TELLER",p))
.FBStaffServiceTestSupport~assertTrue(r~ok,"authority")
cmd=.FederationBankCommand~new(a~commandId,a~operation,a~idempotencyKey,a~customerId,a~sourceAccountId,a~targetAccountId,a~currency,a~amountMinor,"STAFF",a~staffId,a~requestedAt)
b=.FederationBankStaffCommandBinder~bind(a,r~value~envelope,cmd)
.FBStaffServiceTestSupport~assertTrue(b~ok,"service-issued envelope binds ordinary Core command")
.FBStaffServiceTestSupport~assertEq(r~value~envelope~semanticIdentity,b~value~detail("staffAuthorityEnvelopeIdentity"),"full authority identity retained")
.FBStaffServiceTestSupport~pass("service authority crosses boundary only as exact command evidence")
::requires "TestSupport.cls"
