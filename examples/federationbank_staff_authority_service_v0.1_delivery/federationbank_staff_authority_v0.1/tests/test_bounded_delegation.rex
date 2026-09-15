now=.DateTime~new
d=.FederationBankStaffDelegation~new("DEL-1","REL-01","TELLER","DOUGLAS",300000,now-.TimeSpan~new(0,0,5),now+.TimeSpan~new(0,30),"SUP-01","IAM-DELEGATION:1","FB-IAM",.array~of("TRANSFER"))~seal
principal=.FBStaffTestSupport~principal("REL-01","DOUGLAS")
session=.FBStaffTestSupport~session("REL-01","S-REL","DOUGLAS","DESK-09")
ctx=.FederationBankStaffContextSnapshot~new("CTX-REL",principal,session,.array~new,.array~of(d),.array~new)~seal
e=.FBStaffTestSupport~engine
a=.FBStaffTestSupport~action("A-DEL","REL-01","S-REL",250000,"DOUGLAS","DESK-09")
r=e~authorise("ENV-DEL",a,.FBStaffTestSupport~contexts(ctx))
.FBStaffTestSupport~assertTrue(r~ok,"bounded delegated teller role allowed")
.FBStaffTestSupport~assertEq("DEL-1",r~value["decision"]~delegationId,"delegation evidence retained")
a2=.FBStaffTestSupport~action("A-DEL-HIGH","REL-01","S-REL",350000,"DOUGLAS","DESK-09")
r=e~decide(a2,.FBStaffTestSupport~contexts(ctx))
.FBStaffTestSupport~assertFalse(r~ok,"delegation ceiling cannot be exceeded")
.FBStaffTestSupport~assertEq("STAFF_AMOUNT_EXCEEDS_CHECKER_LIMIT",r~code,"delegation limits maker/checker ceiling")
.FBStaffTestSupport~pass("delegation is bounded and cannot increase policy authority")
::requires "TestSupport.cls"
