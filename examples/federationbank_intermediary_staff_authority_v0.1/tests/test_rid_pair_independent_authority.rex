d=.FBIntermediaryStaffTestSupport~goodBundle
ignore=d["REGISTRY"]~setRepresentativeStatus("REP-1","SUSPENDED")
r=.FBIntermediaryStaffTestSupport~authoriseBundle(d)
.FBIntermediaryStaffTestSupport~assertFalse(r~ok,"RID suspended representative blocks attribution")
.FBIntermediaryStaffTestSupport~assertEq("REPRESENTATIVE_NOT_ACTIVE",r~code,"RID remains authoritative for active pair")
/* The component deliberately does not inspect RIDAuthorityRegistry grants or
 * product distribution approval; those remain RID's independent decision. */
.FBIntermediaryStaffTestSupport~pass("RID active firm/representative status remains independently authoritative")
::requires "TestSupport.cls"
