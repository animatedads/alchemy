svc=.AJIIntermediaryAdapterFixtures~distributionService
c=.AJIIntermediaryAdapterFixtures~readyCase(svc,"CASE-SUB")
aji=.AJIIntermediaryAdapterFixtures~authority
adapter=.AllJapanIntermediaryAdapter~new
facts=.table~new; facts["propertyRef"]="PROP:1"
r=.AJIAdapterTestSupport~ok(adapter~submitRisk(svc,aji,c~caseId,"AJI-SUB-1","HOME-RISK-1",facts,.AJIIntermediaryAdapterFixtures~now))
.AJIAdapterTestSupport~assert(aji~submission("AJI-SUB-1") <> .nil,"AJI must own risk submission")
view=r~value["distributionCase"]
.AJIAdapterTestSupport~eq("RECEIVED",view~providerStatus)
.AJIAdapterTestSupport~eq("AJI-SUB-1",view~providerCaseRef)
/* Distribution-channel role cannot perform underwriting. */
d=.AllJapanInsuranceUnderwritingDecision~new("D-BAD","AJI-SUB-1","HOME","ACCEPT","AJI-PRODUCT-HOME/0.1","FEDERATION-REP","2026-08-28T12:01:00","EVID:BAD")
bad=aji~recordDecision(adapter~distributionActor,d)
.AJIAdapterTestSupport~assert(\bad~ok,"bank distribution actor must not inherit AJI underwriting")
.AJIAdapterTestSupport~eq("AUTHORITY_DENIED",bad~code)
say "PASS intermediary submit boundary and insurer authority separation"
::requires "AdapterFixtures.cls"
::requires "AJIAdapterTestSupport.cls"
