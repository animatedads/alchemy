now = .DateTime~new
subject = 'CUSTOMER-EVIDENCE'
obs = .SecurityObservation~new('OBS-REPORT','THIRD_PARTY_REPORT','ACCOUNT',subject,'SHANNON',now,70,'unverified statement')~seal
f = .SecurityFinding~new('F-REPORT','RESTRICTED_PRODUCT_MISUSE_POSSIBLE','CONCERN',subject,70,now,.nil,'possible, not proven','HARDWORLD')
f~addEvidence(.SecurityEvidenceAnchor~new('E1','INTERACTION_EVENT','mother statement',now,70,obs))
f~addCounterEvidence(.SecurityEvidenceAnchor~new('E2','ACCOUNT_HISTORY','no prior confirmed misuse',now,80))
f~addObservationRef('OBS-REPORT')
f~seal
call assertEqual 'CONCERN',f~findingState,'finding is concern, not truth assertion'
call assertEqual 1,f~counterEvidence~items,'counterevidence preserved'
call assertEqual 'HARDWORLD',f~sourceDomain,'source domain preserved'
say 'PASS test_evidence_uncertainty'
exit 0
assertEqual: procedure
  use arg e,a,l
  if e <> a then do; say 'FAIL:' l; exit 1; end
  return
::requires 'SecurityEffect.cls'
