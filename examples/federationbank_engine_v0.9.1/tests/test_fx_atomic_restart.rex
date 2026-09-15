/* FX is one atomic multi-currency banking event.  It balances independently
 * in each currency through Ledger-owned position accounts and survives retry. */
profiles=.FederationBankRegulatoryProfileRegistry~standard
pgbp=profiles~byCurrency("GBP"); pusd=profiles~byCurrency("USD")

customers=.FederationBankCustomerRegistry~new
call must customers~add(.FederationBankCustomer~new("CUST-FX","RETAIL","GB","GB","STANDARD")),"customer"
paccounts=.FederationBankLedger~new
call must paccounts~addAccount(.FederationBankAccount~new("FX-GBP","CUST-FX","GBP","OFFSHORE_CURRENT","IOM",pgbp~profileId)),"payments GBP"
call must paccounts~addAccount(.FederationBankAccount~new("FX-USD","CUST-FX","USD","OFFSHORE_CURRENT","IOM",pusd~profileId)),"payments USD"
payments=.FederationBankPaymentsEngine~new(customers,paccounts,profiles,.FederationBankPolicyGate~new(.FederationBankFixtures~limitCatalog),.FederationBankLegalGate~new(.FederationBankFixtures~legalRegistry),.FederationBankBouncer~new(.FederationBankBouncer~standardFramework),.FederationBankUsageTracker~new,.nil,.FederationBankFeePolicyGate~new(.FederationBankFixtures~feeCatalog),.FederationBankFxPolicyGate~new(.FederationBankFixtures~fxCatalog),.FederationBankFixtureFxQuotePort~new)

details=.directory~new; details["targetCurrency"]="USD"
cmd=.FederationBankCommand~new("FX-CMD-1","FX_CONVERT","FX-IDEM-1","CUST-FX","FX-GBP","FX-USD","GBP",10000,"WEB","CUST-FX",.nil,"","","","","","","","","RETAIL","STANDARD",details)
auth=payments~authorizeFx(cmd)
call must auth,"FX authority"
call assert auth~value["targetAmountMinor"]=12475,"GBP 100.00 at 1.25 less 20bp fixture markup -> USD 124.75"
call assert auth~value["regulatoryProfileId"]="FB-IOM-GBP","source GBP legal/regulatory profile"
call assert auth~value["targetRegulatoryProfileId"]="FB-IOM-USD","target USD legal/regulatory profile"

executor=.FederationBankFixtureSqlExecutor~new
db=.FederationBankFixtures~database(executor)
store=.FederationBankSqlLedgerStore~new(db,3,15)
ledger=.FederationBankLedger~new(store)
call must ledger~addAccount(.FederationBankAccount~new("FB-SETTLEMENT-GBP","FEDERATIONBANK","GBP","INTERNAL_SETTLEMENT","IOM",pgbp~profileId,.true,.true)),"settlement"
call must ledger~addAccount(.FederationBankAccount~new("FX-GBP","CUST-FX","GBP","OFFSHORE_CURRENT","IOM",pgbp~profileId)),"ledger GBP"
call must ledger~addAccount(.FederationBankAccount~new("FX-USD","CUST-FX","USD","OFFSHORE_CURRENT","IOM",pusd~profileId)),"ledger USD"
call must ledger~postTransfer("FX-SEED","FB-SETTLEMENT-GBP","FX-GBP",100000,"GBP"),"seed"
ledgerEngine=.FederationBankLedgerEngine~new(ledger,profiles)

before=ledger~postings~items
executor~failNext
failed=ledgerEngine~postFx(auth~value)
call assert failed~ok=.false,"injected SQL failure rejects FX"
call assert failed~code="LEDGER_DATABASE_ROLLBACK","FX rollback explicit"
call assert ledger~postings~items=before,"failed FX exposes zero partial position/customer legs"
call assert ledger~balanceMinor("FX-GBP")=100000,"failed FX source unchanged"
call assert ledger~balanceMinor("FX-USD")=0,"failed FX target unchanged"
call assert \ledger~hasTransaction("FX-IDEM-1"),"failed FX identity remains retryable"

ok=ledgerEngine~postFx(auth~value)
call must ok,"retry FX"
call assert ledger~balanceMinor("FX-GBP")=90000,"source debited once"
call assert ledger~balanceMinor("FX-USD")=12475,"target credited once"
ps=ledger~transactionPostings("FX-IDEM-1")
call assert ps~items=4,"FX commits four postings"
sums=.directory~new; roles=.directory~new
do p over ps
  cur=p~currency; n=0; if sums~hasIndex(cur) then n=sums[cur]
  sums[cur]=n+p~amountMinor; roles[p~postingRole]=.true
end
call assert sums["GBP"]=0,"GBP journal subtotal balances"
call assert sums["USD"]=0,"USD journal subtotal balances"
call assert roles~hasIndex("FX_SOURCE_DEBIT") & roles~hasIndex("FX_SOURCE_POSITION_CREDIT") & roles~hasIndex("FX_TARGET_POSITION_DEBIT") & roles~hasIndex("FX_TARGET_CREDIT"),"FX posting roles explicit"

/* Fresh Ledger process must recover monetary truth and the original receipt. */
ledger2=.FederationBankLedger~new(store)
call must ledger2~addAccount(.FederationBankAccount~new("FX-GBP","CUST-FX","GBP","OFFSHORE_CURRENT","IOM",pgbp~profileId)),"restart GBP"
call must ledger2~addAccount(.FederationBankAccount~new("FX-USD","CUST-FX","USD","OFFSHORE_CURRENT","IOM",pusd~profileId)),"restart USD"
engine2=.FederationBankLedgerEngine~new(ledger2,profiles)
replay=engine2~postFx(auth~value)
call must replay,"restart FX replay"
call assert replay~value["code"]="FX_REPLAY_RECOVERED","durable FX receipt recovered"
call assert replay~value["recoveredFromDurableReceipt"]="true","recovery provenance explicit"
call assert ledger2~transactionPostings("FX-IDEM-1")~items=4,"restart hydrates only original four FX postings"
call assert ledger2~balanceMinor("FX-GBP")=90000,"restart source balance recovered"
call assert ledger2~balanceMinor("FX-USD")=12475,"restart target balance recovered"

say "PASS FX dual-legal authority + per-currency atomic ledger + rollback/restart replay"
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
