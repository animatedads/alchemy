svc=.FBStaffServiceTestSupport~service
maker=.FBStaffServiceTestSupport~context("TELLER-04","TELLER","S-TEL")
checker=.FBStaffServiceTestSupport~context("SUP-01","SUPERVISOR","S-SUP")
.FBStaffServiceTestSupport~assertTrue(.FBStaffServiceTestSupport~putContext(svc,"CTX-M",maker)~ok,"maker context")
.FBStaffServiceTestSupport~assertTrue(.FBStaffServiceTestSupport~putContext(svc,"CTX-S",checker)~ok,"checker context")
a=.FBStaffServiceTestSupport~action("HIGH","TELLER-04","S-TEL",1200000)
p=.directory~new; p["action"]=a; p["envelopeId"]="ENV:HIGH"
r=svc~handle(.FederationBankStaffServiceEnvelope~new("AUTH-1","FBSTAFF.ACTION.AUTHORISE","TELLER-04","TELLER",p))
.FBStaffServiceTestSupport~assertFalse(r~ok,"approval required")
.FBStaffServiceTestSupport~assertEq("APPROVAL_REQUIRED",r~code,"structured checker state")
self=.FederationBankStaffApproval~new("AP-SELF",a,"TELLER-04","S-TEL","SUPERVISOR","EVID:SELF")~seal
ap=.directory~new; ap["action"]=a; ap["approval"]=self
r=svc~handle(.FederationBankStaffServiceEnvelope~new("AP-CMD-SELF","FBSTAFF.APPROVAL.RECORD","TELLER-04","TELLER",ap))
.FBStaffServiceTestSupport~assertFalse(r~ok,"self approval refused")
.FBStaffServiceTestSupport~assertEq("MAKER_CHECKER_NOT_DISTINCT",r~code,"separation of duties")
appr=.FederationBankStaffApproval~new("AP-SUP",a,"SUP-01","S-SUP","SUPERVISOR","EVID:SUP")~seal
ap=.directory~new; ap["action"]=a; ap["approval"]=appr
r=svc~handle(.FederationBankStaffServiceEnvelope~new("AP-CMD","FBSTAFF.APPROVAL.RECORD","SUP-01","SUPERVISOR",ap))
.FBStaffServiceTestSupport~assertTrue(r~ok,"approval recorded")
p=.directory~new; p["action"]=a; p["envelopeId"]="ENV:HIGH"
r=svc~handle(.FederationBankStaffServiceEnvelope~new("AUTH-2","FBSTAFF.ACTION.AUTHORISE","TELLER-04","TELLER",p))
.FBStaffServiceTestSupport~assertTrue(r~ok,"approved authority issued")
.FBStaffServiceTestSupport~assertEq("AP-SUP",r~value~decision~approvalIds[1],"approval evidence retained")
.FBStaffServiceTestSupport~pass("service maker/checker workflow")
::requires "TestSupport.cls"
