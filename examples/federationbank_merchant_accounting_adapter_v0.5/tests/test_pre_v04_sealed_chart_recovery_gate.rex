t=.MBAccountingTest~new
old=.AccountingBook~new("FEDERATIONBANK_MERCHANT_BANK","FB-MERCHANT-STAT","IFRS")
old~chart~add(.AccountingAccount~new("1300","Derivative assets","ASSET"))
old~chart~add(.AccountingAccount~new("2300","Derivative liabilities","LIABILITY"))
old~chart~add(.AccountingAccount~new("4100","Derivative fair-value gains","REVENUE"))
old~chart~add(.AccountingAccount~new("5100","Derivative fair-value losses","EXPENSE"))
old~chart~seal
old~addPeriod(.AccountingPeriod~new("2026-08","2026-08-01","2026-08-31"))
a=.FederationBankMerchantAccountingAdapter~new("FEDERATIONBANK_MERCHANT_BANK","FB-MERCHANT-STAT","IFRS",old)
t~assertEq(.false,a~settlementPostingAvailable,"old sealed chart remains recoverable but advertises missing settlement capability")

e=.MBAccountingSettlementObligationEvidence~new("E","FEDERATIONBANK_MERCHANT_BANK","MB:ACCOUNTING:SETTLEMENT_OBLIGATION:O","2026-08-28","2026-08","O","X","CLOSE_OUT","P","CLIENT","FEDERATIONBANK_MERCHANT_BANK","CLIENT","GBP",100,"RECEIVABLE","DERIVATIVE_CLOSE_OUT","AUTH")
r=a~postSettlementObligation(e)
t~assertEq("REJECTED",r~status,"new settlement posting is blocked on legacy sealed chart")
t~assertEq("SETTLEMENT_CHART_UPGRADE_REQUIRED",r~errorCode,"upgrade is explicit rather than silently abusing old accounts")
t~assertEq(0,a~book~entryCount,"legacy recovery gate does not mutate book")

say "pre-v0.4 chart gate assertions=" t~assertions "failures=" t~failures
if t~failures>0 then exit 1
exit 0
::requires "FederationBankMerchantAccountingAdapter.cls"
::requires "TestSupport.cls"
