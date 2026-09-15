call test
say "PASS case bridge"
exit 0

test:
  comp=.ComplaintRecord~new("CMP-X","REL-X","INTERACTION:I-X",.DateTime~new)
  rr=.RelationshipCRMCaseBridge~complaintElement("EL-1","CRM-IOM",comp)
  .CRMTest~assertTrue(rr~ok); e=rr~value
  .CRMTest~assertEqual("COMPLAINT",e~elementType); .CRMTest~assertEqual("CRM-IOM",e~sourceSystem); .CRMTest~assertEqual("COMPLAINT:CMP-X",e~sourceRef)
return
::requires "TestSupport.cls"
::requires "RelationshipCRMCaseBridge.cls"
