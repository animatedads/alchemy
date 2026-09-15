v=.VectorMeridianMarkets~new
x=.VMMInstitutionalSyntheticService~new(v)
cp=.VMMInstitutionalCounterparty~new("AJI","ALL_JAPAN_INSURANCE","REL-AJI","JP","KYC-AJI","ISDA-AJI","CSA-AJI","VMM-ONBOARD")
x~registerCounterparty(cp)
x~setRiskPolicy(.VMMSyntheticRiskPolicy~new("RISK-JPY","JPY",100000000000,50000000000,100,"RISK-POL"),"VMM-RISK")
p=.VMMPortfolioReferencePosition~new("P-AIMRET","AJI","JGB-AIMRET","JAPAN_GOVERNMENT","SOVEREIGN_BOND","JPY",10000000,"ALL_JAPAN_INSURANCE","","BOOK-AIMRET","","VAL-AIMRET")
s=.VMMPortfolioSnapshot~new("SNAP-AIMRET","AJI","ALL_JAPAN_INSURANCE","JPY","20260828",.array~of(p),"POS-AIMRET","","VMM-PORTFOLIO")
x~registerPortfolioSnapshot(s)
x~createOffer("OFF-AIMRET","REQ-AIMRET","AJI","SNAP-AIMRET","JPY",10000000,5,25,100000,"20260901","20310831","20260828T140000","20260828T132100","MODEL-AIMRET","MKT-AIMRET","RISK-AIMRET")
k=x~acceptOffer("CON-AIMRET","OFF-AIMRET","20260828T132200","ALL_JAPAN_INSURANCE","AJI-SIGNER")
x~setInitialMarginTerms(k~contractId,.VMMSyntheticInitialMarginTerms~new("IM-TERMS-AIMRET","JPY",900000,"SOVEREIGN_BOND",1000,"IM-POL-AIMRET"),"VMM-COLLATERAL")
im=.VMMSyntheticInitialMarginTransfer~new("IM-XFER-AIMRET",k~contractId,"JPY","JGB-COLL-AIMRET","SOVEREIGN_BOND",1000000,500,"VECTOR_MERIDIAN_MARKETS_LTD","ALL_JAPAN_INSURANCE","THIRD_PARTY_CUSTODIAN","CONTROL-AIMRET","20260901T090000","VMM-COLLATERAL")
x~recordInitialMarginTransfer(im)

d=.VMMInstitutionalDefaultCloseoutService~new(x)
d~setPolicy(.VMMSyntheticDefaultPolicy~new("DEF-JPY","JPY",2,1,3,"ISDA-CLOSEOUT","DEF-POL"),"VMM-LEGAL")
ops=.VMMCloseoutOperationsService~new(d)
ops~setPolicy(.VMMCloseoutOperationsPolicy~new("OPS-JPY","JPY",0,3,"INDEPENDENT-VALUATION-AGENT","LEGAL-NETTING-OPINION-POLICY","OPS-POL"),"VMM-LEGAL")
ev=d~declareDefault("DEF-AIMRET",k~contractId,"INSOLVENCY","ALL_JAPAN_INSURANCE","2026-10-06","2026-10-06","INSOLVENCY-AIMRET","VMM-LEGAL")
d~assessUncured("UNCURED-AIMRET",ev~eventId,"2026-10-07","UNCURED-AIMRET","VMM-LEGAL")
t=d~electTermination("TERM-AIMRET",ev~eventId,"VECTOR_MERIDIAN_MARKETS_LTD","2026-10-07","TERM-AIMRET","VAL-AGENT-AIMRET","VMM-LEGAL")
co=d~determineCloseout("CLOSE-AIMRET",t~terminationId,-500000,"2026-10-10","ISDA-METHOD","MKT-AIMRET","CSA-AIMRET","VMM-VALUATION")
f=ops~finalizeCloseout("FINAL-AIMRET",co~closeoutId,"2026-10-11","VMM-LEGAL")
settle=d~settleCloseout("SETTLE-AIMRET",co~closeoutId,"2026-10-12","BANK-CLOSEOUT-AIMRET","VMM-TREASURY")
ret=ops~instructInitialMarginReturn("RETURN-AIMRET",co~closeoutId,im~transferId,"2026-10-12","RETURN-INSTRUCTION-AIMRET","VMM-COLLATERAL")
ops~acknowledgeCustodyReturn("ACK-AIMRET",ret~returnId,"2026-10-13","CUSTODIAN-ACK-AIMRET","VMM-COLLATERAL")
cs=ops~settleCustodyReturn("CUSTODY-SETTLE-AIMRET",ret~returnId,"2026-10-14","CONTROL-RETURNED-AIMRET","CUSTODIAN-RECEIPT-AIMRET","VMM-COLLATERAL")

eng=.AccountingEngine~new("VECTOR_MERIDIAN_MARKETS_LTD","VMM-STAT","ENTITY_GAAP")
.VMMAccountingPolicy~configureEngine(eng,.AccountingPeriod~new("2026-09","2026-09-01","2026-09-30"))
eng~book~addPeriod(.AccountingPeriod~new("2026-10","2026-10-01","2026-10-31"))
acct=.VMMAccountingService~new(v,eng)
rim=acct~postInitialMarginTransfer(im,"2026-09-01","2026-09")
call assertTrue rim~ok,"initial margin posts at gross carrying value"
call assertEq 100000000,acct~book~balance("1400","JPY")~netDebitMinor,"collateral asset carries gross 1m JPY"
call assertEq -100000000,acct~book~balance("1300","JPY")~netDebitMinor,"trading asset reclassified out at gross carrying value"
rf=acct~postCloseoutFinalization(f,"2026-10-11","2026-10")
rs=acct~postCloseoutFinalSettlement(settle,f,"2026-10-12","2026-10")
call assertTrue rf~ok & rs~ok,"close-out accounting completes without consuming segregated IM"
call assertEq 100000000,acct~book~balance("1400","JPY")~netDebitMinor,"segregated IM remains on collateral account after cash close-out"
rr=acct~postInitialMarginReturn(cs,ret,"2026-10-14","2026-10")
call assertTrue rr~ok,"custodian control evidence drives initial-margin return accounting"
call assertEq 0,acct~book~balance("1400","JPY")~netDebitMinor,"custody return clears collateral carrying value"
call assertEq 0,acct~book~balance("1300","JPY")~netDebitMinor,"same gross carrying value returns to trading assets"
line=rr~entry~lines[1]
call assertEq 95000000,line~dimensions["recognizedRiskValueMinor"],"5 percent haircut remains risk evidence, not carrying-value write-down"
call assertEq "vmm-accounting-artifact/0.11:initial-margin-returned",rr~entry~policyIdentity,"return freezes exact v0.9 accounting policy identity"
say "PASS test_accounting_initial_margin_custody_return"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::routine assertTrue
  use strict arg value,label
  if \value then raise syntax 88.900 array("ASSERT_TRUE",label)
::requires "VMMAccounting.cls"
