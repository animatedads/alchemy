svc=.RIDServiceFixtures~service
semantic=.AllJapanInsuranceCatalogue~new~product("HOME")~semanticIdentity
/* Deliberately wrong: group bank is not the insurer legal entity. */
.RIDServiceFixtures~env(svc,"INSURANCE","ADVISED",semantic,"FEDERATIONBANK_PLC",.AllJapanIntermediaryAdapterBuild~PROVIDER_SYSTEM,"HOME","0.1")
.RIDServiceFixtures~readyInsuranceSubmission(svc,"CASE-WRONG")
adapter=.AllJapanIntermediaryAdapter~new
r=adapter~submitRisk(svc,.AJIIntermediaryAdapterFixtures~authority,"CASE-WRONG","S-WRONG","RISK-WRONG",.table~new,.AJIIntermediaryAdapterFixtures~now)
.AJIAdapterTestSupport~fail("PROVIDER_IDENTITY_MISMATCH",r)
say "PASS Federation group ownership does not rewrite insurer identity"
::requires "AdapterFixtures.cls"
::requires "AJIAdapterTestSupport.cls"
