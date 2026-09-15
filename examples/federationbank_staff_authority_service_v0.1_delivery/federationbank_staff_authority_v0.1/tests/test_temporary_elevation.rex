now=.DateTime~new
ctx=.FBStaffTestSupport~context("SUP-01","SUPERVISOR","S-SUP","DOUGLAS","CASH-01",0,.array~of("WITHDRAW_COMMIT"))
a=.FBStaffTestSupport~action("A-CASH","SUP-01","S-SUP",50000,"DOUGLAS","CASH-01","WITHDRAW_COMMIT","GBP")
e=.FBStaffTestSupport~engine
r=e~decide(a,.FBStaffTestSupport~contexts(ctx))
.FBStaffTestSupport~assertFalse(r~ok,"cash override requires elevation")
.FBStaffTestSupport~assertEq("STAFF_ELEVATION_REQUIRED",r~code,"explicit elevation requirement")
elev=.FederationBankStaffElevation~new("ELEV-1","SUP-01","CASH_OVERRIDE","DOUGLAS",100000,now-.TimeSpan~new(0,0,5),now+.TimeSpan~new(0,20),"MANAGER-1","BREAKGLASS:1","cash till recovery")~seal
ctx=.FederationBankStaffContextSnapshot~new("CTX-SUP-E",.FBStaffTestSupport~principal("SUP-01"),.FBStaffTestSupport~session("SUP-01","S-SUP","DOUGLAS","CASH-01"),.array~of(.FBStaffTestSupport~assignment("SUP-01","SUPERVISOR","","DOUGLAS",0,.array~of("WITHDRAW_COMMIT"))),.array~new,.array~of(elev))~seal
r=e~decide(a,.FBStaffTestSupport~contexts(ctx))
.FBStaffTestSupport~assertTrue(r~ok,"bounded elevation permits maker amount")
.FBStaffTestSupport~pass("temporary elevation is explicit, bounded and evidenced")
::requires "TestSupport.cls"
