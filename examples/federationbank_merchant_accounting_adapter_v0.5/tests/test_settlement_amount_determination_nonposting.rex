t=.MBAccountingTest~new
fx=.MBSettlementAccountingFixture~closeOut(1234.69,"CLIENT-ROUND","ROUND")
mb=fx["mb"]; o=fx["obligation"]; scale=fx["scale"]
proj=.FederationBankMerchantAccountingProjectionV1~new~projectSettlementObligation(mb,o,scale,"2026-08-28","2026-08")
a=.FederationBankMerchantAccountingAdapter~new
a~addPeriod("2026-08","2026-08-01","2026-08-31")
posted=a~postSettlementObligation(proj)
t~assertEq("POSTED",posted~status,"contractual Merchant settlement obligation is accounted first")
before=a~book~entryCount

e=.AccountingSettlementRoundingElection~new("GB-GBP-5P-2026","sha256:gb-gbp-5p-2026",a~merchantEntity,"GB","GBP","gb.test.settlement/2026","GB-TEST-5P-2026","GB-TEST-5P",5,.array~of("BANK_TRANSFER"),"2026-01-01")
a~registerSettlementRoundingElection(e)
a~registerSettlementRoundingPolicy(.MerchantTestSettlementPolicy~new("merchant.test.settlement/2026","sha256:merchant-test-settlement-2026","gb.test.settlement/2026","GB-TEST-5P-2026"))
req=.MBAccountingSettlementAmountRequestEvidence~new("ROUND-REQ-001",a~merchantEntity,o~obligationId,"2026-08-28",2,"GB-GBP-5P-2026","BANK_TRANSFER","MB-LEGAL-SETTLEMENT-POLICY",.array~of("LEGAL:EVIDENCE:ROUND-001"))
r=a~determineSettlementAmount(req,scale)
t~assertTrue(r~ok,"settlement amount is determined by configured exact ruleset")
t~assertEq("123469",r~determination~accountedAmountMinor,"request amount comes from already-accounted Merchant obligation")
t~assertEq("123470",r~determination~settledAmountMinor,"rounding determination is exact in minor units")
t~assertEq("1",r~determination~roundingDifferenceMinor,"rounding difference retained separately")
t~assertEq("GB-GBP-5P-2026",r~determination~settlementElectionRef,"exact election ref retained")
t~assertEq("sha256:gb-gbp-5p-2026",r~determination~settlementElectionIdentity,"exact election identity retained")
t~assertEq("GB-TEST-5P-2026",r~determination~rulesetIdentity,"exact ruleset identity retained")
t~assertEq("sha256:merchant-test-settlement-2026",r~determination~settlementPolicyIdentity,"exact executable settlement policy identity retained")
t~assertEq("MERCHANT_SETTLEMENT_AMOUNT_AUTHORITY_REQUIRED",r~determination~postingState,"non-zero difference cannot become Merchant settlement authority")
t~assertEq(before,a~book~entryCount,"settlement amount determination posts no journal")
blocked=a~postSettlementAmountDetermination(r~determination)
t~assertEq("MERCHANT_SETTLEMENT_AMOUNT_AUTHORITY_REQUIRED",blocked~errorCode,"non-zero determination cannot be posted through Merchant adapter")
t~assertEq(before,a~book~entryCount,"blocked determination leaves journal count unchanged")
p=r~determination~projection
t~assertEq("federationbank.merchant.accounting.settlement_amount/0.1",p["contract_generation"],"bounded scalar determination contract exposed")
t~assertEq(o~obligationId,p["obligation_id"],"bounded determination remains obligation-bound")

badScaleReq=.MBAccountingSettlementAmountRequestEvidence~new("ROUND-REQ-002",a~merchantEntity,o~obligationId,"2026-08-28",0,"GB-GBP-5P-2026","BANK_TRANSFER","MB-LEGAL-SETTLEMENT-POLICY")
badScale=a~determineSettlementAmount(badScaleReq,scale)
t~assertEq("ACCOUNTING_SCALE_EXPONENT_MISMATCH",badScale~errorCode,"caller cannot lie about currency minor exponent")
t~assertEq(before,a~book~entryCount,"bad scale request posts nothing")

badTenderReq=.MBAccountingSettlementAmountRequestEvidence~new("ROUND-REQ-003",a~merchantEntity,o~obligationId,"2026-08-28",2,"GB-GBP-5P-2026","PHYSICAL_CASH","MB-LEGAL-SETTLEMENT-POLICY")
badTender=a~determineSettlementAmount(badTenderReq,scale)
t~assertEq("SETTLEMENT_TENDER_NOT_APPLICABLE",badTender~errorCode,"tender applicability is enforced by Accounting Core v0.7")
t~assertEq(before,a~book~entryCount,"inapplicable tender posts nothing")

say "settlement amount nonposting assertions=" t~assertions "failures=" t~failures
if t~failures>0 then exit 1
exit 0

::class MerchantTestSettlementPolicy subclass AccountingSettlementPolicy
::method determine
  use strict arg request,election
  settled=.AccountingSettlementMath~roundToQuantum(request~accountedAmountMinor,election~roundingQuantumMinor,"HALF_UP")
  return .AccountingSettlementPolicyDecision~accept(self~newDetermination(request,election,settled))
::options digits 50
::requires "SettlementAccountingFixture.cls"
::requires "TestSupport.cls"
