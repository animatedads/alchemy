agent=value("STAFF_METHOD_PERMISSION_AGENT",,"ENVIRONMENT")
if agent="" then do; say "FAIL STAFF_METHOD_PERMISSION_AGENT not set"; exit 2; end
fx=.FBStaffWireRealPermissionFixture~build
port=.FederationBankStaffWireMethodPermissionBoundaryPort~new(fx["boundary"],fx["ingress"],agent)
r=port~admit("FB-STAFF-WIRE-TRANSFER/1|TEST")
.FBStaffWireTestSupport~assertTrue(r~ok,"real Security Manager method permission admitted")
a=r~value
.FBStaffWireTestSupport~assertEq("TELLER-04",a~staffId)
.FBStaffWireTestSupport~assertEq("S-TEL",a~sessionId)
.FBStaffWireTestSupport~assertEq("ADMIT",a~methodName)
.FBStaffWireTestSupport~assertFalse(a~businessAuthorityImplied,"method proof is not business authority")
.FBStaffWireTestSupport~assertFalse(a~accessControlImplied,"method proof is not access control")
.FBStaffWireTestSupport~assertFalse(a~authenticationImplied,"method proof is not authentication")
say "PASS Staff Wire port executes real ooRexx Security Manager permission boundary"
exit 0
::requires "TestSupport.cls"
