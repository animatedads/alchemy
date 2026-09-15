call test
say "PASS complaint case boundary"
exit 0

test:
  c=.FederationBankCRMPolicyFixtures~publishedCatalog; e=.RelationshipCRMEngine~new(c); r=.RelationshipRecord~new("REL-4","COREBANK","CUST-004")
  call a e~openRelationship(r,"T1","TELLER")~ok
  comp=.ComplaintRecord~new("CMP-1","REL-4","INTERACTION:I-9",.DateTime~new)
  call a e~recogniseComplaint(comp,"T1","TELLER")~ok
  call a e~linkComplaintCase("CMP-1","CASE-77","CASE-SVC","SERVICE")~ok
  denied=e~transitionComplaint("CMP-1","RESOLVE","T1","TELLER"); .CRMTest~assertTrue(\denied~ok)
  call a e~transitionComplaint("CMP-1","RESOLVE","C1","COMPLAINTS")~ok
  .CRMTest~assertEqual("RESOLVED",comp~state); .CRMTest~assertEqual("CASE-77",comp~caseRef)
return
a: procedure; use arg v; .CRMTest~assertTrue(v); return
::requires "TestSupport.cls"
::requires "FederationBankCRMPolicyFixtures.cls"
