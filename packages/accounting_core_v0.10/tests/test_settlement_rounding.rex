t = .AccountingTest~new
numeric digits 50

/* Half-even parity is now a neutral arithmetic primitive. */
t~assertEq("2", .AccountingTaxMath~roundRatio(25, 10, "HALF_EVEN"), "2.5 rounds to even 2")
t~assertEq("4", .AccountingTaxMath~roundRatio(35, 10, "HALF_EVEN"), "3.5 rounds to even 4")
t~assertEq("-2", .AccountingTaxMath~roundRatio(-25, 10, "HALF_EVEN"), "negative half-even is symmetric")
t~assertEq("558500", .AccountingSettlementMath~roundToQuantum("558469", "100", "HALF_UP"), "SEK settlement rounds to whole krona")
t~assertEq("1230", .AccountingSettlementMath~roundToQuantum("1232", "5", "HALF_UP"), "five-cent settlement quantum rounds independently")

entity = "NORDIC_GLOBAL_SERVICES_AB"
e = makeEngine(entity)
se = .AccountingSettlementRoundingElection~new("SETTLE-SE-SEK-2026", "sha256:settle-se-sek-2026", entity, "SE", "SEK", "se.settlement.rules/2026", "SE-SETTLEMENT-RULESET-2026", "SE-ORE-ROUNDING", "100", .array~of("*"), "2026-01-01")
e~scopes~registerSettlementElection(se)
cash = .AccountingSettlementRoundingElection~new("SETTLE-CA-CASH-2026", "sha256:settle-ca-cash-2026", entity, "CA", "CAD", "ca.cash.rules/2026", "CA-CASH-RULESET-2026", "CA-5C-CASH", "5", .array~of("PHYSICAL_CASH"), "2026-01-01")
e~scopes~registerSettlementElection(cash)
e~registerSettlementPolicy(.DemoSettlementPolicy~new("se.settlement/2026", "sha256:se-settlement-code", "se.settlement.rules/2026", "SE-SETTLEMENT-RULESET-2026", "HALF_UP"))
e~registerSettlementPolicy(.DemoSettlementPolicy~new("ca.cash/2026", "sha256:ca-cash-code", "ca.cash.rules/2026", "CA-CASH-RULESET-2026", "HALF_UP"))
e~registerPolicy(.SettlementAccountingPolicy~new("settlement.accounting/0.7", "sha256:settlement-accounting-07", entity, "SETTLEMENT_ROUNDING_DETERMINED", "2026-01-01"))

req = .AccountingSettlementRequest~new("PAY:SE:001", entity, "2026-08-28", "SEK", 2, "558469", "SETTLE-SE-SEK-2026", "BANK_TRANSFER", "INV:SE:001", "CLIENT-SE", "PAYMENTS")
r = e~determineSettlement(req)
t~assertTrue(r~ok, "Swedish-style all-tender settlement determines for bank transfer")
t~assertEq("558500", r~determination~settledAmountMinor, "settled SEK amount")
t~assertEq("31", r~determination~roundingDifferenceMinor, "settlement difference kept separate from tax")
t~assertEq("SETTLE-SE-SEK-2026", r~determination~settlementElectionRef, "settlement election retained")
t~assertEq("sha256:settle-se-sek-2026", r~determination~settlementElectionIdentity, "exact settlement election identity retained")
t~assertEq("SE-ORE-ROUNDING", r~determination~roundingAlgorithmRef, "jurisdiction algorithm ref retained")
t~assertEq("100", r~determination~roundingQuantumMinor, "rounding quantum retained")
reqProjection=.AccountingSettlementRequestCodec~toProjection(req)
reqRoundTrip=.AccountingSettlementRequestCodec~fromProjection(reqProjection)
t~assertEq(req~fingerprint, reqRoundTrip~fingerprint, "settlement request projection round-trips")
detProjection=.AccountingSettlementDeterminationCodec~toProjection(r~determination)
detRoundTrip=.AccountingSettlementDeterminationCodec~fromProjection(detProjection)
t~assertEq(r~determination~fingerprint, detRoundTrip~fingerprint, "settlement determination projection round-trips")
t~assertTrue(e~determineSettlementProjection(reqProjection)~ok, "settlement request projection determines")

post = e~transactSettlement(req)
t~assertTrue(post~ok, "settlement determination accounts")
t~assertEq("POSTED", post~status, "settlement journal posts")
t~assertEq("558500", post~entry~lines[1]~debitMinor, "cash reflects settled amount")
t~assertEq("558469", post~entry~lines[2]~creditMinor, "receivable clears exact invoice amount")
t~assertEq("31", post~entry~lines[3]~creditMinor, "rounding gain is separate accounting consequence")
dims = post~entry~lines[3]~dimensions
t~assertEq("SETTLE-SE-SEK-2026", dims[.AccountingDimensionKeys~SETTLEMENT_ELECTION_REF], "journal retains settlement election")
t~assertEq("sha256:settle-se-sek-2026", dims[.AccountingDimensionKeys~SETTLEMENT_ELECTION_IDENTITY], "journal retains exact settlement election identity")

dup = e~transactSettlement(req)
t~assertTrue(dup~ok, "settlement replay accepted")
t~assertEq("DUPLICATE", dup~status, "settlement replay is idempotent")
changed = .AccountingSettlementRequest~new("PAY:SE:001", entity, "2026-08-28", "SEK", 2, "558468", "SETTLE-SE-SEK-2026", "BANK_TRANSFER", "INV:SE:001", "CLIENT-SE", "PAYMENTS")
t~assertEq("SOURCE_SETTLEMENT_EVENT_CONFLICT", e~transactSettlement(changed)~errorCode, "changed settlement replay conflicts")

cashReq = .AccountingSettlementRequest~new("PAY:CA:001", entity, "2026-08-28", "CAD", 2, "1232", "SETTLE-CA-CASH-2026", "PHYSICAL_CASH")
cashR = e~determineSettlement(cashReq)
t~assertTrue(cashR~ok, "cash-only election applies to physical cash")
t~assertEq("1230", cashR~determination~settledAmountMinor, "cash-only quantum applied")
t~assertEq("-2", cashR~determination~roundingDifferenceMinor, "cash-only rounding loss retained")
cardReq = .AccountingSettlementRequest~new("PAY:CA:002", entity, "2026-08-28", "CAD", 2, "1232", "SETTLE-CA-CASH-2026", "CARD")
t~assertEq("SETTLEMENT_TENDER_NOT_APPLICABLE", e~determineSettlement(cardReq)~errorCode, "cash election cannot silently round card settlement")
wrongCurrency = .AccountingSettlementRequest~new("PAY:SE:002", entity, "2026-08-28", "EUR", 2, "1000", "SETTLE-SE-SEK-2026", "BANK_TRANSFER")
t~assertEq("SETTLEMENT_CURRENCY_MISMATCH", e~determineSettlement(wrongCurrency)~errorCode, "settlement election currency enforced")

t~assertTrue(disjointTenderElectionsAllowed(), "same jurisdiction/currency can have disjoint tender elections")
t~assertTrue(overlappingTenderElectionsRejected(), "overlapping tender elections are rejected")

say "settlement rounding assertions=" t~assertions "failures=" t~failures
if t~failures > 0 then exit 1
exit 0

::routine makeEngine
  use arg entity
  e=.AccountingEngine~new(entity,"STAT")
  e~book~addAccount(.AccountingAccount~new("1000","Cash","ASSET"))
  e~book~addAccount(.AccountingAccount~new("1100","Receivable","ASSET"))
  e~book~addAccount(.AccountingAccount~new("6900","Settlement rounding loss","EXPENSE"))
  e~book~addAccount(.AccountingAccount~new("7900","Settlement rounding gain","REVENUE"))
  e~book~sealChart
  e~book~addPeriod(.AccountingPeriod~new("2026","2026-01-01","2026-12-31"))
  return e

::routine disjointTenderElectionsAllowed
  s=.AccountingScopeRegistry~new("E")
  signal on syntax name bad
  s~registerSettlementElection(.AccountingSettlementRoundingElection~new("A","id:A","E","XX","XXX","r","ri1","A",5,.array~of("PHYSICAL_CASH"),"2026-01-01"))
  s~registerSettlementElection(.AccountingSettlementRoundingElection~new("B","id:B","E","XX","XXX","r","ri2","B",1,.array~of("CARD"),"2026-01-01"))
  return .true
bad: return .false

::routine overlappingTenderElectionsRejected
  s=.AccountingScopeRegistry~new("E")
  s~registerSettlementElection(.AccountingSettlementRoundingElection~new("A","id:A","E","XX","XXX","r","ri1","A",5,.array~of("*"),"2026-01-01"))
  signal on syntax name caught
  s~registerSettlementElection(.AccountingSettlementRoundingElection~new("B","id:B","E","XX","XXX","r","ri2","B",1,.array~of("CARD"),"2026-01-01"))
  return .false
caught: return .true

::class DemoSettlementPolicy subclass AccountingSettlementPolicy
::attribute primitive get
::method init
  expose primitive
  use arg refArg, identityArg, rulesRefArg, rulesIdentityArg, primitiveArg
  primitive=primitiveArg~string~upper
  self~init:super(refArg, identityArg, rulesRefArg, rulesIdentityArg)
::method determine
  expose primitive
  use arg request, election
  settled=.AccountingSettlementMath~roundToQuantum(request~accountedAmountMinor, election~roundingQuantumMinor, primitive)
  return .AccountingSettlementPolicyDecision~accept(self~newDetermination(request,election,settled))

::class SettlementAccountingPolicy subclass AccountingPolicy
::method propose
  use arg event, book
  numeric digits 50
  accounted=.AccountingUtil~requireWholeSigned(event~value("accountedAmountMinor"),"accounted")
  settled=.AccountingUtil~requireWholeSigned(event~value("settledAmountMinor"),"settled")
  diff=.AccountingUtil~requireWholeSigned(event~value("roundingDifferenceMinor"),"difference")
  if accounted < 0 | settled < 0 then return .AccountingPolicyDecision~reject("NEGATIVE_SETTLEMENT_NOT_IN_DEMO")
  c=event~value("currency")
  dims=event~value("accountingDimensions")
  d=self~newDraft(event,book,event~eventDate,"Settlement with separately accounted rounding")
  d~addLine(.AccountingJournalLine~new("1000",c,settled,0,"Cash settled",dims))
  d~addLine(.AccountingJournalLine~new("1100",c,0,accounted,"Receivable cleared",dims))
  if diff > 0 then d~addLine(.AccountingJournalLine~new("7900",c,0,diff,"Settlement rounding gain",dims))
  else if diff < 0 then d~addLine(.AccountingJournalLine~new("6900",c,-diff,0,"Settlement rounding loss",dims))
  return .AccountingPolicyDecision~accept(d)

::options digits 50
::requires "AccountingEngine.cls"
::requires "TestSupport.cls"
