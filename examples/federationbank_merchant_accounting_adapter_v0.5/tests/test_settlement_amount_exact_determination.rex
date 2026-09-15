t=.MBAccountingTest~new
fx=.MBSettlementAccountingFixture~closeOut(1000,"CLIENT-EXACT","EXACT")
mb=fx["mb"]; o=fx["obligation"]; scale=fx["scale"]
proj=.FederationBankMerchantAccountingProjectionV1~new~projectSettlementObligation(mb,o,scale,"2026-08-28","2026-08")
a=.FederationBankMerchantAccountingAdapter~new
a~addPeriod("2026-08","2026-08-01","2026-08-31")
a~postSettlementObligation(proj)
before=a~book~entryCount

e=.AccountingSettlementRoundingElection~new("GB-GBP-EXACT-2026","sha256:gb-gbp-exact-2026",a~merchantEntity,"GB","GBP","gb.test.exact/2026","GB-TEST-EXACT-2026","EXACT-MINOR-UNIT",1,.array~of("*"),"2026-01-01")
a~registerSettlementRoundingElection(e)
a~registerSettlementRoundingPolicy(.MerchantExactSettlementPolicy~new("merchant.test.exact/2026","sha256:merchant-test-exact-2026","gb.test.exact/2026","GB-TEST-EXACT-2026"))
req=.MBAccountingSettlementAmountRequestEvidence~new("EXACT-REQ-001",a~merchantEntity,o~obligationId,"2026-08-28",2,"GB-GBP-EXACT-2026","BANK_TRANSFER","MB-LEGAL-SETTLEMENT-POLICY")
r=a~determineSettlementAmount(req,scale)
t~assertTrue(r~ok,"exact settlement amount determination succeeds")
t~assertEq("100000",r~determination~settledAmountMinor,"exact determination preserves contractual minor-unit amount")
t~assertEq("0",r~determination~roundingDifferenceMinor,"exact determination has no amount difference")
t~assertEq("MERCHANT_SETTLEMENT_OBSERVATION_REQUIRED",r~determination~postingState,"even exact determination is not cash evidence")
t~assertEq(before,a~book~entryCount,"exact determination still posts nothing")
blocked=a~postSettlementAmountDetermination(r~determination)
t~assertEq("SETTLEMENT_COMPLETION_EVIDENCE_REQUIRED",blocked~errorCode,"exact determination still cannot fabricate cash settlement")
t~assertEq(before,a~book~entryCount,"blocked exact determination leaves journal count unchanged")

unknown=.MBAccountingSettlementAmountRequestEvidence~new("EXACT-REQ-UNKNOWN",a~merchantEntity,"OBL-UNKNOWN","2026-08-28",2,"GB-GBP-EXACT-2026","BANK_TRANSFER","MB-LEGAL-SETTLEMENT-POLICY")
ru=a~determineSettlementAmount(unknown,scale)
t~assertEq("SETTLEMENT_OBLIGATION_NOT_ACCOUNTED",ru~errorCode,"determination cannot be made for an unaccounted obligation")
t~assertEq(before,a~book~entryCount,"unknown obligation posts nothing")

say "settlement amount exact assertions=" t~assertions "failures=" t~failures
if t~failures>0 then exit 1
exit 0

::class MerchantExactSettlementPolicy subclass AccountingSettlementPolicy
::method determine
  use strict arg request,election
  return .AccountingSettlementPolicyDecision~accept(self~newDetermination(request,election,request~accountedAmountMinor))
::options digits 50
::requires "SettlementAccountingFixture.cls"
::requires "TestSupport.cls"
