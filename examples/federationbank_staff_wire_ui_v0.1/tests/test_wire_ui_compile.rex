b=.FederationBankStaffWireUIDesignFixture~build
r=.WireUICompiler~new~compile(b["workspace"],b["release"])
.FBStaffWireTestSupport~assertTrue(r~ok,"Staff Banking release compiles")
.FBStaffWireTestSupport~assertEq(7,r~value~definitions~items,"seven definitions")
say "PASS Staff Banking Wire UI release compiles"
exit 0
::requires "TestSupport.cls"
