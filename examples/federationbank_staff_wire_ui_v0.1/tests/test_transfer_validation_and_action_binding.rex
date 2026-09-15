svc=.FBStaffWireFakeService~new
perm=.FBStaffWireAllowPermissionPort~new
app=.FBStaffWireTestFixtures~app(svc,perm)

/* A semantic action not bound to the form is rejected before application dispatch. */
r=app~receive(.FBStaffWireTestFixtures~action(app,"customer-transfer","CORE.EXECUTE",.directory~new,.nil,"BAD-ACTION"))
.FBStaffWireTestSupport~assertFalse(r~ok)
.FBStaffWireTestSupport~assertEq("ACTION_NOT_BOUND_TO_ELEMENT",r~code)
.FBStaffWireTestSupport~assertEq(0,perm~calls)

/* Invalid amount fails before method permission is even consulted. */
d=.FBStaffWireTestFixtures~transferDetail; d["amountMinor"]="NOT-A-NUMBER"
r=app~receive(.FBStaffWireTestFixtures~action(app,"customer-transfer","CUSTOMER.TRANSFER.SUBMIT",d,.nil,"BAD-AMOUNT"))
.FBStaffWireTestSupport~assertFalse(r~ok)
.FBStaffWireTestSupport~assertEq("FB_STAFF_TRANSFER_AMOUNT_INVALID",r~code)
.FBStaffWireTestSupport~assertEq(0,perm~calls)

/* Duplicate Wire UI message id is replayed by the application, not re-submitted. */
d=.FBStaffWireTestFixtures~transferDetail
m=.FBStaffWireTestFixtures~action(app,"customer-transfer","CUSTOMER.TRANSFER.SUBMIT",d,.nil,"DUP-TX")
r1=app~receive(m); .FBStaffWireTestSupport~assertTrue(r1~ok)
r2=app~receive(m); .FBStaffWireTestSupport~assertTrue(r2~ok)
.FBStaffWireTestSupport~assertEq("DUPLICATE",r2~code)
.FBStaffWireTestSupport~assertEq(1,perm~calls,"duplicate message does not re-enter permission boundary")
.FBStaffWireTestSupport~assertEq(1,svc~state~works~items,"duplicate message does not create second work")
say "PASS Staff Banking form validation/action binding/idempotent UI receipt fail closed"
exit 0
::requires "TestSupport.cls"
