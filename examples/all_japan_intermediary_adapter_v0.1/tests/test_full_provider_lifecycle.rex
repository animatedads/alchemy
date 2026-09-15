svc=.AJIIntermediaryAdapterFixtures~distributionService
c=.AJIIntermediaryAdapterFixtures~readyCase(svc,"CASE-LIFE")
aji=.AJIIntermediaryAdapterFixtures~authority
adapter=.AllJapanIntermediaryAdapter~new
.AJIAdapterTestSupport~ok(adapter~submitRisk(svc,aji,c~caseId,"AJI-LIFE-1","HOME-LIFE-1",.table~new,.AJIIntermediaryAdapterFixtures~now))
uw=.AJIIntermediaryAdapterFixtures~underwriter
d=.AllJapanInsuranceUnderwritingDecision~new("D-LIFE-1","AJI-LIFE-1","HOME","ACCEPT","AJI-PRODUCT-HOME/0.1","AJI-UW-1","2026-08-28T12:05:00","AJI:EVID:D1")
rr=aji~recordDecision(uw,d); .AJIAdapterTestSupport~assert(rr~ok,rr~code||" "||rr~detail)
.AJIAdapterTestSupport~ok(adapter~projectUnderwritingDecision(svc,aji,c~caseId,d~decisionId,2,.DateTime~fromIsoDate("2026-08-28T12:05:01.000000")))
q=.AllJapanInsuranceQuote~new("Q-LIFE-1",d~decisionId,"AJI-LIFE-1","HOME",25000,"GBP","2026-09-05T23:59:59","2026-08-28T12:06:00","","","MANUAL_OVERRIDE","intermediary qualification")
qr=aji~issueQuote(uw,q); .AJIAdapterTestSupport~assert(qr~ok,qr~code||" "||qr~detail)
.AJIAdapterTestSupport~ok(adapter~projectQuote(svc,aji,c~caseId,q~quoteId,3,.DateTime~fromIsoDate("2026-08-28T12:06:01.000000")))
pol=.AllJapanInsurancePolicy~new("P-LIFE-1",q~quoteId,c~subjectRef,"HOME","HOME-LIFE-1","2026-09-01","2027-09-01","2026-08-29T10:00:00")
br=aji~bindPolicy(.AJIIntermediaryAdapterFixtures~policyActor,pol); .AJIAdapterTestSupport~assert(br~ok,br~code||" "||br~detail)
final=.AJIAdapterTestSupport~ok(adapter~projectBoundPolicy(svc,aji,c~caseId,pol~policyId,4,.DateTime~fromIsoDate("2026-08-29T10:00:01.000000")))~value
.AJIAdapterTestSupport~eq("BOUND",final~providerStatus)
.AJIAdapterTestSupport~eq(4,final~providerSequence)
.AJIAdapterTestSupport~eq("AJI-POLICY-P-LIFE-1",final~providerEventId)
say "PASS actual AJI provider lifecycle projects into intermediary case"
::requires "AdapterFixtures.cls"
::requires "AJIAdapterTestSupport.cls"
