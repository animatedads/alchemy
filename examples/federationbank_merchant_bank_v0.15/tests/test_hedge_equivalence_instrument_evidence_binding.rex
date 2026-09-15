mb=.FederationBankMerchantBank~new
src=.MBReferenceDocumentEvidence~new("DOC","REF-AUTH","urn:test:doc","Instrument lines","1","09:00")
mb~recordReferenceDocumentEvidence(src)
a=.MBInstrumentResolutionEvidence~new("RA","DOC","U","I","XLON","GBP","LA","SAFE","ORDINARY","GBP","GBP","A","09:00")
b=.MBInstrumentResolutionEvidence~new("RB","DOC","U","I","XLON","USD","LB","SAFE","ORDINARY","GBP","GBP","B","09:00")
mb~recordInstrumentResolutionEvidence(a); mb~recordInstrumentResolutionEvidence(b)
permit=.MBDecisionEvidence~new("PERMITTED","PERMITTED","LEGAL","POL")
mb~registerProduct(.MBDerivativeProductDefinition~new("PA","1","CFD","U","GBP","CASH",permit,"","",1,mb~instrumentIdentityFromEvidence("RA","GBP")))
mb~registerProduct(.MBDerivativeProductDefinition~new("PB","1","CFD","U","GBP","CASH",permit,"","",1,mb~instrumentIdentityFromEvidence("RB","GBP")))
mb~createPortfolio("A","C","GBP"); mb~createPortfolio("B","M","GBP")
mb~bookTrade(.MBDerivativeTrade~new("TA","A","C","CFD","LONG","GBP",100,0,0,"",1,"U","PA","U","09:00"))
mb~bookCFDOffset("I","H","TA",.MBDerivativeTrade~new("TB","B","M","CFD","SHORT","GBP",100,0,0,"",1,"U","PB","U","09:01","M","EXTERNAL_HEDGE"),"","AUTH","09:01")

caught=.false
signal on syntax name mismatch
mb~recordHedgeEquivalenceEvidence(.MBHedgeEquivalenceEvidence~new("EV-BAD","H",1,"","09:02","GB","REF-AUTH","DOC","LEGAL","RB","RA"))
signal off syntax
if \caught then raise syntax 88.900 array("ASSERT_EXPECTED_SYNTAX","swapped instrument evidence")
signal checked
mismatch:
  signal off syntax
  caught=.true
checked:
if \caught then raise syntax 88.900 array("ASSERT_EXPECTED_SYNTAX","swapped instrument evidence")
if mb~latestHedgeEquivalenceEvidence("H")<>.nil then raise syntax 88.900 array("ASSERT_NIL","rejected evidence must not become current")

ok=.MBHedgeEquivalenceEvidence~new("EV-OK","H",1,"","09:03","GB","REF-AUTH","DOC","LEGAL","RA","RB")
mb~recordHedgeEquivalenceEvidence(ok)
call assertEq "RA",mb~latestHedgeEquivalenceEvidence("H")~originalInstrumentEvidenceRef,"original resolution evidence bound"
call assertEq "RB",mb~latestHedgeEquivalenceEvidence("H")~offsetInstrumentEvidenceRef,"offset resolution evidence bound"

say "PASS test_hedge_equivalence_instrument_evidence_binding"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::requires "FederationBankMerchantBank.cls"
