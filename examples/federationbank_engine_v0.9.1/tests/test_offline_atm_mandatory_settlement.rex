/* Cash already physically dispensed under bounded delegated authority is a
 * settlement fact.  It may drive the customer past the normal overdraft floor;
 * subsequent ordinary withdrawals/debits remain funds-gated. */
profiles=.FederationBankRegulatoryProfileRegistry~standard
pgbp=profiles~byCurrency("GBP")
customers=.FederationBankCustomerRegistry~new
call must customers~add(.FederationBankCustomer~new("CUST-ATM","RETAIL","GB","GB","STANDARD")),"customer"
paccounts=.FederationBankLedger~new
call must paccounts~addAccount(.FederationBankAccount~new("ATM-GBP","CUST-ATM","GBP","OFFSHORE_CURRENT","IOM",pgbp~profileId,.false,.false,10000)),"payments account"
payments=.FederationBankPaymentsEngine~new(customers,paccounts,profiles,.FederationBankPolicyGate~new(.FederationBankFixtures~limitCatalog),.FederationBankLegalGate~new(.FederationBankFixtures~legalRegistry),.FederationBankBouncer~new(.FederationBankBouncer~standardFramework),.FederationBankUsageTracker~new)

details=.directory~new
details["terminalId"]="ATM-IOM-001"; details["atmNetworkId"]="FB-ATM-IOM"
details["offlineAuthorityId"]="OFFAUTH-17"; details["rulesetId"]="FB-ATM-IOM"; details["rulesVersion"]="17"
details["physicalTransactionId"]="ATM-IOM-001-DISP-884"; details["terminalSequence"]="884"
details["dispensedMinor"]=18000; details["authorityMode"]="DELEGATED_STAND_IN"
cmd=.FederationBankCommand~new("ATM-ADV-1","OFFLINE_WITHDRAWAL_ADVICE","ATM-IDEM-1","CUST-ATM","ATM-GBP","","GBP",18000,"ATM","ATM-IOM-001",.nil,"","","","","","","","","RETAIL","STANDARD",details)
auth=payments~authorizeOfflineCashAdvice(cmd)
call must auth,"offline ATM advice authority"
call assert auth~value["debitAuthority"]=.FederationBankDebitAuthority~SETTLEMENT_MUST_POST,"explicit mandatory settlement authority"

executor=.FederationBankFixtureSqlExecutor~new
db=.FederationBankFixtures~database(executor); store=.FederationBankSqlLedgerStore~new(db,3,15)
ledger=.FederationBankLedger~new(store)
call must ledger~addAccount(.FederationBankAccount~new("FB-SETTLEMENT-GBP","FEDERATIONBANK","GBP","INTERNAL_SETTLEMENT","IOM",pgbp~profileId,.true,.true)),"settlement"
call must ledger~addAccount(.FederationBankAccount~new("ATM-GBP","CUST-ATM","GBP","OFFSHORE_CURRENT","IOM",pgbp~profileId,.false,.false,10000)),"customer account"
call must ledger~addAccount(.FederationBankAccount~new("ATM-DEST","CUST-ATM","GBP","OFFSHORE_CURRENT","IOM",pgbp~profileId)),"ordinary destination"
call must ledger~postTransfer("ATM-SEED","FB-SETTLEMENT-GBP","ATM-GBP",4000,"GBP"),"seed"
engine=.FederationBankLedgerEngine~new(ledger,profiles)

settled=engine~postOfflineCashAdvice(auth~value)
call must settled,"mandatory cash settlement"
call assert ledger~balanceMinor("ATM-GBP")=-14000,"cash already dispensed posts beyond normal overdraft floor"
fs=ledger~fundsState("ATM-GBP")
call assert fs["authorisedOverdraftMinor"]=10000,"overdraft allowance retained"
call assert fs["unauthorisedExcessMinor"]=4000,"excess below authorised floor identified"
call assert fs["fundsState"]="UNAUTHORISED_EXCESS","post-settlement account state explicit"
call assert fs["withdrawalsBlocked"]=.true,"withdrawal restriction projected"
call assert ledger~transactionPostings("ATM-IDEM-1")~items=2,"mandatory settlement remains balanced two-leg monetary truth"

ordinary=ledger~postTransfer("ATM-NORMAL-1","ATM-GBP","ATM-DEST",1,"GBP")
call assert ordinary~ok=.false,"ordinary debit does not inherit mandatory settlement privilege"
call assert ordinary~code="INSUFFICIENT_AVAILABLE_FUNDS","ordinary debit blocked by funds rule"
call assert ledger~balanceMinor("ATM-GBP")=-14000,"rejected ordinary debit leaves balance unchanged"

/* Restart/redelivery must recover the original physical settlement, not debit again. */
ledger2=.FederationBankLedger~new(store)
call must ledger2~addAccount(.FederationBankAccount~new("ATM-GBP","CUST-ATM","GBP","OFFSHORE_CURRENT","IOM",pgbp~profileId,.false,.false,10000)),"restart account"
engine2=.FederationBankLedgerEngine~new(ledger2,profiles)
replay=engine2~postOfflineCashAdvice(auth~value)
call must replay,"offline settlement restart replay"
call assert replay~value["code"]="ATM_SETTLEMENT_REPLAY_RECOVERED","durable cash settlement receipt recovered"
call assert ledger2~balanceMinor("ATM-GBP")=-14000,"restart does not double debit"
call assert ledger2~transactionPostings("ATM-IDEM-1")~items=2,"restart recovers original two legs only"

say "PASS delegated offline ATM mandatory settlement can exceed overdraft; ordinary debits remain blocked"
exit 0
must: procedure
  use arg r,label
  if r~ok=.false then do; say "FAIL" label r~code r~detail; exit 1; end
  return
assert: procedure
  use arg condition,label
  if \condition then do; say "FAIL" label; exit 1; end
  return
::requires "FederationBankServices.cls"
::requires "FederationBankFixtures.cls"
