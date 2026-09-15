ref=.RelationshipCRMReference~new("CRM-IOM", "CUSTOMER", "42", "CUSTOMER_MASTER", "CRM_IDENTITY_REFERENCE", "INTERNAL")
r=.RelationshipCaseCRMBridge~subject("CRM-SUBJECT-1", ref, .DateTime~new)
.RelationshipCaseServiceTestSupport~assertTrue(r~ok, "CRM subject bridge")
e=r~value
.RelationshipCaseServiceTestSupport~assertEqual("CRM-IOM", e~sourceSystem, "CRM remains authoritative source")
.RelationshipCaseServiceTestSupport~assertEqual("CUSTOMER:42", e~sourceRef, "opaque CRM record reference")
.RelationshipCaseServiceTestSupport~assertEqual("SUBJECT", e~elementType, "case element semantic")
.RelationshipCaseServiceTestSupport~assertEqual("CRM_IDENTITY_REFERENCE", e~authorityClass, "reference is not banking authority")
say "PASS test_crm_boundary"
exit 0
::requires "TestSupport.cls"
::requires "RelationshipCaseCRMBridge.cls"
