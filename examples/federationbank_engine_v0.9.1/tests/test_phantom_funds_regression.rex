/* PHANTOM_FUNDS: a transfer that did not durably commit may never become
 * spendable credit, even if a later offline physical-cash fact must settle. */
profiles=.FederationBankRegulatoryProfileRegistry~standard
p=profiles~byCurrency("AUD")
executor=.FederationBankFixtureSqlExecutor~new
db=.FederationBankFixtures~database(executor); store=.FederationBankSqlLedgerStore~new(db,3,15)
ledger=.FederationBankLedger~new(store)
call must ledger~addAccount(.FederationBankAccount~new("FB-SETTLEMENT-AUD","FEDERATIONBANK","AUD","INTERNAL_SETTLEMENT","IOM",p~profileId,.true,.true)),"settlement"
call must ledger~addAccount(.FederationBankAccount~new("PH-CREDIT","CUST-PH","AUD","OFFSHORE_CREDIT","IOM",p~profileId,.false,.false,100000)),"credit source"
call must ledger~addAccount(.FederationBankAccount~new("PH-SAVINGS","CUST-PH","AUD","OFFSHORE_SAVINGS","IOM",p~profileId)),"savings"
call must ledger~postTransfer("PH-SEED-C","FB-SETTLEMENT-AUD","PH-CREDIT",100000,"AUD"),"seed credit source"
call must ledger~postTransfer("PH-SEED-S","FB-SETTLEMENT-AUD","PH-SAVINGS",2000,"AUD"),"seed savings"

/* Simulate the dangerous window: request accepted far enough to attempt SQL,
 * but the monetary transaction fails.  No target credit is publishable. */
before=ledger~postings~items
executor~failNext
failed=ledger~postTransfer("PH-TRANSFER-1","PH-CREDIT","PH-SAVINGS",50000,"AUD")
call assert failed~ok=.false,"synthetic internal transfer DB failure"
call assert failed~code="LEDGER_DATABASE_ROLLBACK","failed transfer rolled back atomically"
call assert ledger~postings~items=before,"failed transfer creates no debit or credit leg"
call assert ledger~balanceMinor("PH-SAVINGS")=2000,"target has only real committed funds, no phantom credit"
call assert \ledger~hasTransaction("PH-TRANSFER-1"),"ambiguous request never becomes Ledger truth"

/* Cash later dispensed under delegated offline authority is a different fact:
 * it must settle against the real balance, not the phantom failed transfer. */
cash=.FederationBankAccount~new("FB-ATM-CASH-ATM_IOM_009-AUD","FEDERATIONBANK","AUD","INTERNAL_ATM_CASH","IOM",p~profileId,.true,.true)
call must ledger~addAccount(cash),"ATM cash account"
e=.directory~new
e["debitAuthority"]=.FederationBankDebitAuthority~SETTLEMENT_MUST_POST
e["terminalId"]="ATM-IOM-009"; e["atmNetworkId"]="FB-ATM-IOM"; e["offlineAuthorityId"]="OFFAUTH-PH"
e["rulesetId"]="FB-ATM-IOM"; e["rulesVersion"]="19"; e["physicalTransactionId"]="PH-DISP-1"; e["terminalSequence"]="991"
r=.directory~new
r["commandId"]="PH-ATM-1"; r["idempotencyKey"]="PH-ATM-IDEM-1"; r["operation"]="OFFLINE_WITHDRAWAL_ADVICE"; r["outcome"]="ACCEPTED"; r["customerId"]="CUST-PH"; r["accountId"]="PH-SAVINGS"; r["transactionId"]="PH-ATM-IDEM-1"; r["currency"]="AUD"; r["amountMinor"]=5000; r["createdAt"]=.DateTime~new~utcIsoDate
settled=ledger~postMandatoryCashSettlement("PH-ATM-IDEM-1","PH-SAVINGS",cash~accountId,5000,"AUD",.DateTime~new,e,r)
call must settled,"real offline cash fact settles"
call assert ledger~balanceMinor("PH-SAVINGS")=-3000,"settlement uses actual committed 20.00 balance, not failed 500.00 phantom credit"
call assert ledger~fundsState("PH-SAVINGS")["withdrawalsBlocked"]=.true,"negative unauthorised state blocks further ordinary withdrawals"

say "PASS PHANTOM_FUNDS failed transfer credit never becomes spendable; real offline cash still settles"
exit 0
must: procedure
  use arg x,label
  if x~ok=.false then do; say "FAIL" label x~code x~detail; exit 1; end
  return
assert: procedure
  use arg condition,label
  if \condition then do; say "FAIL" label; exit 1; end
  return
::requires "FederationBankFixtures.cls"
