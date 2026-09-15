now = .DateTime~new
subject = 'BARBIE'
store = .SecurityEvidenceStore~new
reportTime = now - .TimeSpan~new(0,0,10,0,0)
obs = .SecurityObservation~new('OBS-MOTHER-1','THIRD_PARTY_REPORT','ACCOUNT',subject,'SHANNON',reportTime,80,'Mother reports illegal habits relevant to restricted product')
obs~putMetadata('ASSERTION_STATUS','UNVERIFIED_THIRD_PARTY_REPORT')
obs~seal
call assertTrue store~recordObservation(obs)~ok,'third-party observation retained'
f = .SecurityFinding~new('F-BAGS-1','RESTRICTED_PRODUCT_MISUSE_POSSIBLE','CONCERN',subject,80,reportTime,now + .TimeSpan~new(0,0,1,0,0),'unresolved prior interaction evidence','HARDWORLD')
f~addEvidence(.SecurityEvidenceAnchor~new('F-BAGS-1:SOURCE','HARDWORLD','prior Shannon/HardWorld assessment',reportTime,80,obs))
f~addObservationRef('OBS-MOTHER-1')
f~seal
call assertTrue store~recordFinding(f)~ok,'cross-domain finding retained'

/* New session: no conversational memory is passed to the evaluator. */
snap = store~snapshotFor(subject,now)
policy = .SecurityTestSupport~basePolicy(now)
engine = .SecurityEffectEngine~new
buy = .SecurityActionSurface~new('A-BAGS',subject,'PURCHASE_MORE_BAGS',now,'MEDIUM','BAG_PURCHASE')~seal
ass = engine~evaluate(buy,snap,policy)~value
call assertEqual 'REVIEW_REQUIRED',ass~disposition,'buy-more-bags routed to review'
call assertTrue ass~containsConstraint('ROUTE_TO_REVIEW'),'review route constraint returned'
call assertTrue .SecurityCanonical~containsString(ass~unaffectedAbilities,'VIEW_EXISTING_ORDER'),'existing order remains usable'

order = .SecurityActionSurface~new('A-ORDER',subject,'VIEW_EXISTING_ORDER',now,'LOW','VIEW_EXISTING_ORDER')~seal
ordAss = engine~evaluate(order,snap,policy)~value
call assertEqual 'ALLOW',ordAss~disposition,'unrelated safe action still allowed'
say 'PASS test_barbie_cross_session'
exit 0
assertTrue: procedure
  use arg v,l
  if v = .false then do; say 'FAIL:' l; exit 1; end
  return
assertEqual: procedure
  use arg e,a,l
  if e <> a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end
  return
::requires 'TestSupport.cls'
