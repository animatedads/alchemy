d=.FBIntermediaryStaffTestSupport~goodBundle
d["REQUEST"]=.FBIntermediaryStaffTestSupport~request(d["ACTION"],"ADVISE","RID-CASE-1","HOME-1|2026.08|TAMPERED")
r=.FBIntermediaryStaffTestSupport~authoriseBundle(d)
.FBIntermediaryStaffTestSupport~assertFalse(r~ok,"tampered product semantic identity rejected")
.FBIntermediaryStaffTestSupport~assertEq("INTERMEDIARY_PRODUCT_IDENTITY_MISMATCH",r~code,"exact product identity")
.FBIntermediaryStaffTestSupport~pass("intermediary staff authority binds exact product semantic identity")
::requires "TestSupport.cls"
