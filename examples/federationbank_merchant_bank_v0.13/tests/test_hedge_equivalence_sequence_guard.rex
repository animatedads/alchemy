e=.MBDecisionEvidence~new("PERMITTED","PERMITTED","LEGAL","POL")
mb=.FederationBankMerchantBank~new
id=.MBInstrumentIdentity~new("EQ-X","ISIN-X","XLON","ORDINARY","GBP","GBP","GBP")
mb~registerProduct(.MBDerivativeProductDefinition~new("P1","1","CFD","EQ-X","GBP","CASH",e,"","",1,id))
mb~registerProduct(.MBDerivativeProductDefinition~new("P2","1","CFD","EQ-X","GBP","CASH",e,"","",1,id))
mb~createPortfolio("A","C","GBP"); mb~createPortfolio("B","M","GBP")
mb~bookTrade(.MBDerivativeTrade~new("T1","A","C","CFD","LONG","GBP",100,0,0,"",1,"X","P1","EQ-X","09:00"))
h=mb~bookCFDOffset("I1","H1","T1",.MBDerivativeTrade~new("T2","B","M","CFD","SHORT","GBP",100,0,0,"",1,"X","P2","EQ-X","09:01","M","EXTERNAL_HEDGE"),"","AUTH","09:01")
mb~recordHedgeEquivalenceEvidence(.MBHedgeEquivalenceEvidence~new("E1","H1",1,"","09:02","GB","AUTH","SRC1","LEGAL1"))

caught=.false
signal on syntax name badVersion
mb~recordHedgeEquivalenceEvidence(.MBHedgeEquivalenceEvidence~new("E3","H1",3,"E1","09:03","GB","AUTH","SRC3","LEGAL3"))
signal off syntax
if \caught then raise syntax 88.900 array("ASSERT_EXPECTED_SYNTAX","version gap")
signal afterBadVersion
badVersion:
  signal off syntax
  caught=.true
afterBadVersion:
if \caught then raise syntax 88.900 array("ASSERT_EXPECTED_SYNTAX","version gap")
call assertEq "E1",mb~latestHedgeEquivalenceEvidence("H1")~evidenceId,"failed version does not replace current evidence"

caught=.false
signal on syntax name badSupersedes
mb~recordHedgeEquivalenceEvidence(.MBHedgeEquivalenceEvidence~new("E2-BAD","H1",2,"NOT-E1","09:04","GB","AUTH","SRC2","LEGAL2"))
signal off syntax
if \caught then raise syntax 88.900 array("ASSERT_EXPECTED_SYNTAX","wrong supersedes")
signal afterBadSupersedes
badSupersedes:
  signal off syntax
  caught=.true
afterBadSupersedes:
if \caught then raise syntax 88.900 array("ASSERT_EXPECTED_SYNTAX","wrong supersedes")
call assertEq "E1",mb~latestHedgeEquivalenceEvidence("H1")~evidenceId,"wrong predecessor cannot fork current truth silently"

say "PASS test_hedge_equivalence_sequence_guard"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::requires "FederationBankMerchantBank.cls"
