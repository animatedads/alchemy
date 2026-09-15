e=.FBStaffTestSupport~engine
maker=.FBStaffTestSupport~context("TELLER-04","TELLER","S-MAKER")
checker=.FBStaffTestSupport~context("SUP-01","SUPERVISOR","S-CHECK")
a=.FBStaffTestSupport~action("A-CHECK","TELLER-04","S-MAKER",1200000)
contexts=.FBStaffTestSupport~contexts(maker,checker)
r=e~decide(a,contexts)
.FBStaffTestSupport~assertFalse(r~ok,"checker required")
.FBStaffTestSupport~assertEq("APPROVAL_REQUIRED",r~code,"structured approval requirement")
selfAppr=.FederationBankStaffApproval~new("AP-SELF",a,"TELLER-04","S-MAKER","SUPERVISOR","EVID:SELF")~seal
r=e~decide(a,contexts,.array~of(selfAppr))
.FBStaffTestSupport~assertFalse(r~ok,"maker cannot check own work")
appr=.FederationBankStaffApproval~new("AP-SUP",a,"SUP-01","S-CHECK","SUPERVISOR","EVID:SUP")~seal
r=e~authorise("ENV-CHECK",a,contexts,.array~of(appr))
.FBStaffTestSupport~assertTrue(r~ok,"independent supervisor satisfies checker")
.FBStaffTestSupport~assertEq(1,r~value["decision"]~approvalIds~items,"one selected checker")
.FBStaffTestSupport~assertEq("AP-SUP",r~value["decision"]~approvalIds[1],"checker evidence retained")
.FBStaffTestSupport~pass("maker/checker separation of duties")
::requires "TestSupport.cls"
