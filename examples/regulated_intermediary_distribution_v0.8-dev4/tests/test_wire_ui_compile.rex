b=.RIDWireUIDesignFixture~build
r=.WireUICompiler~new~compile(b["workspace"],b["release"])
.RIDTestSupport~assertTrue(r~ok,"Wire UI intermediary release compiles")
.RIDTestSupport~assertEq(9,r~value~definitions~items,"nine operational definitions including case timeline")
say "PASS intermediary Wire UI Builder release compiles"
exit 0
::requires "WireUITestSupport.cls"
