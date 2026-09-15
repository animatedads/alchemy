numeric digits 50
entity="NORDIC_SERVICES_AB"
e=.AccountingEngine~new(entity,"STAT")
e~book~addAccount(.AccountingAccount~new("1000","Cash","ASSET"))
e~book~addAccount(.AccountingAccount~new("1100","Receivable","ASSET"))
e~book~addAccount(.AccountingAccount~new("2200","VAT payable","LIABILITY"))
e~book~addAccount(.AccountingAccount~new("4000","Revenue","REVENUE"))
e~book~addAccount(.AccountingAccount~new("7900","Settlement rounding gain","REVENUE"))
e~book~sealChart
e~book~addPeriod(.AccountingPeriod~new("2026","2026-01-01","2026-12-31"))

/* Invoice accounting is already fixed: VAT is not recalculated by settlement. */
d=.AccountingJournalDraft~new("INV:SE:001","2026-08-28","2026","invoice.accounting/1","Invoice before settlement")
d~addLine(.AccountingJournalLine~new("1100","SEK",558469,0,"Invoice receivable"))
d~addLine(.AccountingJournalLine~new("4000","SEK",0,446775,"Revenue"))
d~addLine(.AccountingJournalLine~new("2200","SEK",0,111694,"VAT already determined"))
call assertPosted e~post(d)

election=.AccountingSettlementRoundingElection~new("SEK-ALL-2026","sha256:sek-all-2026",entity,"SE","SEK","se.settlement.rules/2026","SE-RULESET-2026","SE-ORE-ROUNDING",100,.array~of("*"),"2026-01-01")
e~scopes~registerSettlementElection(election)
e~registerSettlementPolicy(.ExampleSettlementPolicy~new("se.settlement/2026","sha256:se-settlement-impl","se.settlement.rules/2026","SE-RULESET-2026"))
e~registerPolicy(.ExampleSettlementAccounting~new("settlement.accounting/0.7","sha256:settlement-accounting",entity,"SETTLEMENT_ROUNDING_DETERMINED","2026-01-01"))

request=.AccountingSettlementRequest~new("PAY:SE:001",entity,"2026-08-28","SEK",2,558469,"SEK-ALL-2026","BANK_TRANSFER","INV:SE:001")
r=e~transactSettlement(request)
call assertPosted r
say "invoice VAT remains minor units=" 111694
say "accounted invoice total=" r~determination~accountedAmountMinor
say "settled total=" r~determination~settledAmountMinor
say "settlement rounding difference=" r~determination~roundingDifferenceMinor
say "tender=" r~determination~tenderClass
say "election identity=" r~determination~settlementElectionIdentity
exit 0

::routine assertPosted
  use arg r
  if \r~ok then do
    say "FAILED:" r~errorCode r~message
    exit 1
  end

::class ExampleSettlementPolicy subclass AccountingSettlementPolicy
::method determine
  use arg request,election
  settled=.AccountingSettlementMath~roundToQuantum(request~accountedAmountMinor,election~roundingQuantumMinor,"HALF_UP")
  return .AccountingSettlementPolicyDecision~accept(self~newDetermination(request,election,settled))

::class ExampleSettlementAccounting subclass AccountingPolicy
::method propose
  use arg event,book
  a=event~value("accountedAmountMinor"); s=event~value("settledAmountMinor"); diff=event~value("roundingDifferenceMinor"); c=event~value("currency"); dims=event~value("accountingDimensions")
  d=self~newDraft(event,book,event~eventDate,"Settlement rounding")
  d~addLine(.AccountingJournalLine~new("1000",c,s,0,"Cash received",dims))
  d~addLine(.AccountingJournalLine~new("1100",c,0,a,"Receivable cleared",dims))
  if diff>0 then d~addLine(.AccountingJournalLine~new("7900",c,0,diff,"Settlement rounding gain",dims))
  return .AccountingPolicyDecision~accept(d)
::options digits 50
::requires "AccountingEngine.cls"
