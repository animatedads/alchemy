v=.VectorMeridianMarkets~new
x=.VMMInstitutionalSyntheticService~new(v)
oldc=.VMMInstitutionalCounterparty~new("AJL","ALL_JAPAN_LEGACY_INSURANCE","REL-AJL","JP","KYC-AJL","ISDA-AJL","CSA-AJL","VMM-ONBOARD-OLD")
newc=.VMMInstitutionalCounterparty~new("AJI","ALL_JAPAN_INSURANCE","REL-AJI","JP","KYC-AJI","ISDA-AJI","CSA-AJI","VMM-ONBOARD-NEW")
x~registerCounterparty(oldc); x~registerCounterparty(newc)
x~setRiskPolicy(.VMMSyntheticRiskPolicy~new("SYN-RISK-JPY","JPY",100000000000,50000000000,100,"POL-SYN-JPY"),"VMM-RISK")
pold=.VMMPortfolioReferencePosition~new("P-OLD","AJL","JGB-OLD","JAPAN_GOVERNMENT","SOVEREIGN_BOND","JPY",10000000000,"ALL_JAPAN_LEGACY_INSURANCE","","LEGACY-BOOK","","VAL-OLD")
sold=.VMMPortfolioSnapshot~new("SNAP-OLD","AJL","ALL_JAPAN_LEGACY_INSURANCE","JPY","20260801",.array~of(pold),"LEGACY-POSITIONS","","VMM-PORTFOLIO")
x~registerPortfolioSnapshot(sold)
pnew=.VMMPortfolioReferencePosition~new("P-NEW","AJI","JGB-NEW","JAPAN_GOVERNMENT","SOVEREIGN_BOND","JPY",10000000000,"ALL_JAPAN_INSURANCE","ALL_JAPAN_LEGACY_INSURANCE","MERGED-BOOK","SUCCESSION-AJL-TO-AJI","VAL-NEW")
snew=.VMMPortfolioSnapshot~new("SNAP-NEW","AJI","ALL_JAPAN_INSURANCE","JPY","20260828",.array~of(pnew),"AJI-POSITIONS","MERGER-SUCCESSION-EVID","VMM-PORTFOLIO")
x~registerPortfolioSnapshot(snew)
x~createOffer("OFF-NOV","REQ-NOV","AJL","SNAP-OLD","JPY",10000000000,5,25,120000000,"20260801","20310731","20260801T140000","20260801T120000","MODEL-NOV","MKT-NOV","RISK-NOV")
oldk=x~acceptOffer("CON-OLD","OFF-NOV","20260801T123000","ALL_JAPAN_LEGACY_INSURANCE","AJL-SIGNER")
newk=x~novateContract("NOV-AJI-1","CON-AJI","CON-OLD","AJI","SNAP-NEW","20260828T150000","TRIPARTITE-NOVATION-AGREEMENT","AJL-AUTH","AJI-AUTH","VMM-AUTH")
call assertEq "NOVATED",oldk~state,"old legal contract is closed by novation rather than overwritten"
call assertEq "CON-AJI",oldk~novationTargetContractId,"old contract retains target lineage"
call assertEq "ACTIVE",newk~state,"new legal contract active"
call assertEq "CON-OLD",newk~sourceContractId,"new contract retains source lineage"
call assertEq "AJI",newk~counterpartyId,"new contract belongs to successor counterparty"
call assertEq "SNAP-NEW",newk~currentSnapshotId,"new contract uses successor-owned reference snapshot"
call assertEq "ISDA-AJI",newk~masterAgreementRef,"new counterparty agreement replaces legacy agreement"
call assertNear oldk~initialReferenceValue,newk~initialReferenceValue,0.01,"novation preserves initial reference economics"
call assertNear oldk~terms~protectedNotional,newk~terms~protectedNotional,0.01,"novation preserves protected notional"
say "PASS test_synthetic_novation"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::routine assertNear
  use strict arg expected,actual,tolerance,label
  if abs(expected-actual)>tolerance then raise syntax 88.900 array("ASSERT_NEAR",label,"expected",expected,"actual",actual)
::requires "VMMSyntheticProducts.cls"
