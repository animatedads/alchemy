mb=.FederationBankMerchantBank~new
src=.MBReferenceDocumentEvidence~new("DOC-EQ-1","CUSTODY-REF-AUTH","urn:test:dual-line","Dual line reference","1","09:00","","SOURCE_OBSERVED")
mb~recordReferenceDocumentEvidence(src)
a=.MBInstrumentResolutionEvidence~new("RES-A",src~documentEvidenceId,"EQ-UNDERLYING","ISIN-EQ","XLON","GBP","LINE-GBP","CRSTGB22","ORDINARY","GBP","GBP","line=GBP","09:00")
b=.MBInstrumentResolutionEvidence~new("RES-B",src~documentEvidenceId,"EQ-UNDERLYING","ISIN-EQ","XLON","USD","LINE-USD","CRSTGB22","ORDINARY","GBP","GBP","line=USD","09:00")
mb~recordInstrumentResolutionEvidence(a); mb~recordInstrumentResolutionEvidence(b)
ia=mb~instrumentIdentityFromEvidence("RES-A","GBP",1,"ISSUER-EQ")
ib=mb~instrumentIdentityFromEvidence("RES-B","GBP",1,"ISSUER-EQ")
permit=.MBDecisionEvidence~new("PERMITTED","PERMITTED","LEGAL-PROD","POL-PROD")
mb~registerProduct(.MBDerivativeProductDefinition~new("CFD-A","1","CFD","EQ-UNDERLYING","GBP","CASH",permit,"","",1,ia))
mb~registerProduct(.MBDerivativeProductDefinition~new("CFD-B","1","CFD","EQ-UNDERLYING","GBP","CASH",permit,"","",1,ib))
mb~createPortfolio("PF-A","CLIENT-A","GBP")
mb~createPortfolio("PF-B","MM-A","GBP")
mb~bookTrade(.MBDerivativeTrade~new("TR-A","PF-A","CLIENT-A","CFD","LONG","GBP",1000000,0,0,"",1,"EQ","CFD-A","EQ-UNDERLYING","09:00"))
off=.MBDerivativeTrade~new("TR-B","PF-B","MM-A","CFD","SHORT","GBP",1000000,0,0,"",1,"EQ","CFD-B","EQ-UNDERLYING","09:01","MM-A","EXTERNAL_HEDGE")
h=mb~bookCFDOffset("INT-EQ","H-EQ","TR-A",off,"","TRADE-AUTH","09:01")
call assertEq "CROSS_LISTED_HEDGE",h~relationshipType,"same ISIN+venue but different settlement line is not exact offset"

v1=.MBHedgeEquivalenceEvidence~new("EQE-1","H-EQ",1,"","09:02","GB","MARKET-STRUCTURE-AUTH","DOC-EQ-1","LEGAL-EQ-1","RES-A","RES-B",.true,.true,.true,.true,.true,"BASELINE_FUNGIBLE")
mb~recordHedgeEquivalenceEvidence(v1)
call assertEq 1,mb~latestHedgeEquivalenceEvidence("H-EQ")~version,"first evidence becomes current"
call assertEq "EQUIVALENT",h~equivalenceState,"healthy evidence establishes equivalence"
call assertEq "EQE-1",h~equivalenceEvidenceRef,"hedge retains exact evidence version"
r1=mb~assessHedgeRisk("HRA-EQ-1","H-EQ","","","","","09:02")
call assertEq "NET_ZERO_MARKET_RISK_WITH_MONITORING",r1~riskState,"healthy equivalence can be net-zero market risk"
call assertEq "EQE-1",r1~equivalenceEvidenceRef,"assessment binds evidence version"

v2=.MBHedgeEquivalenceEvidence~new("EQE-2","H-EQ",2,"EQE-1","11:17","GB","SANCTIONS-AUTH","SANCTION-EVENT-77","LEGAL-SANCTION-77","RES-A","RES-B",.true,.false,.false,.false,.false,"JURISDICTIONAL_TRANSFER_RESTRICTION")
mb~recordHedgeEquivalenceEvidence(v2)
call assertEq 2,mb~latestHedgeEquivalenceEvidence("H-EQ")~version,"second evidence supersedes first"
call assertEq 1,mb~hedgeEquivalenceEvidence("EQE-1")~healthy,"history is retained rather than rewritten"
call assertEq 0,mb~hedgeEquivalenceEvidence("EQE-2")~healthy,"new observation records impairment"
call assertEq "IMPAIRED",h~equivalenceState,"legal/operational impairment changes current equivalence"
call assertEq "HEDGE_IMPAIRED",h~economicState,"impairment is visible immediately without a new price mark"
call assertEq "EQE-2",h~equivalenceEvidenceRef,"hedge points at current evidence"
r2=mb~reassessHedgeRiskFromLatestKnown("HRA-EQ-2","H-EQ","EQE-2","11:17")
call assertEq "HEDGE_IMPAIRED",r2~riskState,"risk assessment consumes latest equivalence evidence automatically"
call assertEq "EQE-2",r2~equivalenceEvidenceRef,"risk assessment retains impairment evidence"
call assertEq "HRA-EQ-2",mb~latestHedgeRiskAssessment("H-EQ")~assessmentId,"latest hedge risk assessment retained for evidence-only reassessment"

v3=.MBHedgeEquivalenceEvidence~new("EQE-3","H-EQ",3,"EQE-2","14:30","GB","LEGAL-MARKET-AUTH","RELEASE-EVENT-88","LEGAL-RELEASE-88","RES-A","RES-B",.true,.true,.true,.true,.true,"FUNGIBILITY_RESTORED")
mb~recordHedgeEquivalenceEvidence(v3)
call assertEq "EQUIVALENT",h~equivalenceState,"later evidence can restore equivalence"
call assertEq "EQE-3",h~equivalenceEvidenceRef,"restoration has distinct evidence identity"
r3=mb~reassessHedgeRiskFromLatestKnown("HRA-EQ-3","H-EQ","EQE-3","14:30")
call assertEq "NET_ZERO_MARKET_RISK_WITH_MONITORING",r3~riskState,"restored fungibility does not terminate monitoring"
call assertEq 1,r3~monitoringRequired,"contracts remain monitored after restoration"

say "PASS test_hedge_equivalence_version_stream"
exit 0

::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)

::requires "FederationBankMerchantBank.cls"
