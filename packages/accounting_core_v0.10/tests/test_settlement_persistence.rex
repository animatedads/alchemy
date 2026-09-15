t=.AccountingTest~new
numeric digits 50
path="./tests/tmp_accounting_settlement_store_v07.jsonl"
store=.AccountingFileStore~new(path)
book=store~createBook("SETTLEMENT_PERSIST_CO","STAT","ENTITY_GAAP")
book~addAccount(.AccountingAccount~new("1000","Cash","ASSET"))
book~addAccount(.AccountingAccount~new("1100","Receivable","ASSET"))
book~addAccount(.AccountingAccount~new("7900","Settlement rounding gain","REVENUE"))
book~sealChart
book~addPeriod(.AccountingPeriod~new("2026","2026-01-01","2026-12-31"))
e=.AccountingEngine~new(book~legalEntityId,book~bookId,book~reportingBasis,book)
e~scopes~registerSettlementElection(.AccountingSettlementRoundingElection~new("SEK-ALL-2026","sha256:sek-all-2026",book~legalEntityId,"SE","SEK","se.settlement/2026","SE-RULESET-PERSIST","SE-ORE-ROUNDING",100,.array~of("*"),"2026-01-01"))
e~registerSettlementPolicy(.PersistSettlementPolicy~new("se.settlement/persist","sha256:se-policy-persist","se.settlement/2026","SE-RULESET-PERSIST"))
e~registerPolicy(.PersistSettlementAccounting~new("settlement.accounting/persist","sha256:settlement-accounting-persist",book~legalEntityId,"SETTLEMENT_ROUNDING_DETERMINED","2026-01-01"))
d=.directory~new; d[.AccountingDimensionKeys~MATTER_REF]="000777"
r=.AccountingSettlementRequest~new("PAY:000001",book~legalEntityId,"2026-08-28","SEK",2,"558469","SEK-ALL-2026","BANK_TRANSFER","INV:000001","CLIENT","PAYMENTS",.array~of("BANK:EVIDENCE:0001"),d)
first=e~transactSettlement(r)
t~assertTrue(first~ok,"durable settlement posts")
t~assertEq("31",first~determination~roundingDifferenceMinor,"durable settlement difference")
t~assertEq("sha256:sek-all-2026",first~entry~lines[3]~dimensions[.AccountingDimensionKeys~SETTLEMENT_ELECTION_IDENTITY],"settlement identity persisted")
t~assertEq("000777",first~entry~lines[3]~dimensions[.AccountingDimensionKeys~MATTER_REF],"opaque matter persists")
recovered=store~recoverBook
t~assertEq("1",recovered~entryCount,"settlement journal recovered")
t~assertEq("558500",recovered~balance("1000","SEK")~debitMinor,"settled cash exact after restart")
t~assertEq("558469",recovered~balance("1100","SEK")~creditMinor,"receivable exact after restart")
t~assertEq("31",recovered~balance("7900","SEK")~creditMinor,"rounding gain exact after restart")
re=.AccountingEngine~new(recovered~legalEntityId,recovered~bookId,recovered~reportingBasis,recovered)
/* no election/policy restored: replay must be recognized from durable journal first */
dup=re~transactSettlement(r)
t~assertEq("DUPLICATE",dup~status,"durable settlement replay before policy dispatch")
changed=.AccountingSettlementRequest~new("PAY:000001",book~legalEntityId,"2026-08-28","SEK",2,"558468","SEK-ALL-2026","BANK_TRANSFER","INV:000001")
t~assertEq("SOURCE_SETTLEMENT_EVENT_CONFLICT",re~transactSettlement(changed)~errorCode,"changed durable settlement conflicts")
rd=recovered~entries[1]~lines[3]~dimensions
t~assertEq("SEK-ALL-2026",rd[.AccountingDimensionKeys~SETTLEMENT_ELECTION_REF],"settlement ref survives restart")
t~assertEq("000777",rd[.AccountingDimensionKeys~MATTER_REF],"leading-zero matter survives restart")
say "settlement persistence assertions=" t~assertions "failures=" t~failures
if t~failures>0 then exit 1
exit 0

::class PersistSettlementPolicy subclass AccountingSettlementPolicy
::method determine
  use arg request,election
  settled=.AccountingSettlementMath~roundToQuantum(request~accountedAmountMinor,election~roundingQuantumMinor,"HALF_UP")
  return .AccountingSettlementPolicyDecision~accept(self~newDetermination(request,election,settled))
::class PersistSettlementAccounting subclass AccountingPolicy
::method propose
  use arg event,book
  numeric digits 50
  a=event~value("accountedAmountMinor"); s=event~value("settledAmountMinor"); diff=event~value("roundingDifferenceMinor"); c=event~value("currency"); dims=event~value("accountingDimensions")
  d=self~newDraft(event,book,event~eventDate,"Durable settlement rounding")
  d~addLine(.AccountingJournalLine~new("1000",c,s,0,"Cash",dims))
  d~addLine(.AccountingJournalLine~new("1100",c,0,a,"Receivable",dims))
  d~addLine(.AccountingJournalLine~new("7900",c,0,diff,"Rounding gain",dims))
  return .AccountingPolicyDecision~accept(d)
::options digits 50
::requires "AccountingPersistence.cls"
::requires "AccountingEngine.cls"
::requires "TestSupport.cls"
