d=.FBIntermediaryStaffTestSupport~goodBundle
/* Jurisdiction */
d["REQUEST"]=.FBIntermediaryStaffTestSupport~request(d["ACTION"],"ADVISE","RID-CASE-1","HOME-1|2026.08|A","MORTGAGE","IM","ADVISED")
r=.FBIntermediaryStaffTestSupport~authoriseBundle(d)
.FBIntermediaryStaffTestSupport~assertEq("INTERMEDIARY_JURISDICTION_MISMATCH",r~code,"jurisdiction exact")
/* Advice mode */
d=.FBIntermediaryStaffTestSupport~goodBundle
d["REQUEST"]=.FBIntermediaryStaffTestSupport~request(d["ACTION"],"ADVISE","RID-CASE-1","HOME-1|2026.08|A","MORTGAGE","GB","EXECUTION_ONLY")
r=.FBIntermediaryStaffTestSupport~authoriseBundle(d)
.FBIntermediaryStaffTestSupport~assertEq("INTERMEDIARY_ADVICE_MODE_MISMATCH",r~code,"advice mode exact")
/* Activity maps exactly to the Staff Authority operation. */
d=.FBIntermediaryStaffTestSupport~goodBundle
d["REQUEST"]=.FBIntermediaryStaffTestSupport~request(d["ACTION"],"ARRANGE")
r=.FBIntermediaryStaffTestSupport~authoriseBundle(d)
.FBIntermediaryStaffTestSupport~assertEq("INTERMEDIARY_OPERATION_ACTIVITY_MISMATCH",r~code,"activity exact")
/* Case is part of both action and RID request identity. */
d=.FBIntermediaryStaffTestSupport~goodBundle
d["REQUEST"]=.FBIntermediaryStaffTestSupport~request(d["ACTION"],"ADVISE","RID-CASE-OTHER")
r=.FBIntermediaryStaffTestSupport~authoriseBundle(d)
.FBIntermediaryStaffTestSupport~assertEq("INTERMEDIARY_STAFF_ACTION_MISMATCH",r~code,"case exact")
.FBIntermediaryStaffTestSupport~pass("jurisdiction, activity, advice mode and case are exact-bound dimensions")
::requires "TestSupport.cls"
