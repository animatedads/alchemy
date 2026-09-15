/* Full channel -> Payments -> Ledger -> Payments queue path for FX. */
root=value("FB_TEST_QUEUE_ROOT",,"ENVIRONMENT")
if root="" then do; say "FAIL FB_TEST_QUEUE_ROOT required"; exit 1; end
manager=.ObjectQueueManager~new(root,.QueueGraphPayloadCodec~new,.FederationBankServiceTopology~ADMIN_PRINCIPAL)
topology=.FederationBankServiceTopology~new(manager)
usage=.FederationBankPaymentsUsageProjection~new(topology~topics)
aenv=.FederationBankFixtures~freshAccountEnvironment
accountEngine=.FederationBankAccountEngine~new(aenv["authority"])
profiles=.FederationBankRegulatoryProfileRegistry~standard
pCustomers=.FederationBankCustomerRegistry~new; pAccounts=.FederationBankLedger~new
payments=.FederationBankPaymentsEngine~new(pCustomers,pAccounts,profiles,.FederationBankPolicyGate~new(.FederationBankFixtures~limitCatalog),.FederationBankLegalGate~new(.FederationBankFixtures~legalRegistry),.FederationBankBouncer~new(.FederationBankBouncer~standardFramework),usage,.nil,.FederationBankFeePolicyGate~new(.FederationBankFixtures~feeCatalog),.FederationBankFxPolicyGate~new(.FederationBankFixtures~fxCatalog),.FederationBankFixtureFxQuotePort~new)
executor=.FederationBankFixtureSqlExecutor~new; db=.FederationBankFixtures~database(executor); store=.FederationBankSqlLedgerStore~new(db,3,15)
ledger=.FederationBankLedger~new(store)
pgbp=profiles~byCurrency("GBP")
call must ledger~addAccount(.FederationBankAccount~new("FB-SETTLEMENT-GBP","FEDERATIONBANK","GBP","INTERNAL_SETTLEMENT","IOM",pgbp~profileId,.true,.true)),"settlement"
ledgerEngine=.FederationBankLedgerEngine~new(ledger,profiles)
runtime=.FederationBankBackendRuntime~new(topology,accountEngine,payments,ledgerEngine)

call openAccount runtime,"QFX-GBP","GBP","QFX-OPEN-1"
call openAccount runtime,"QFX-USD","USD","QFX-OPEN-2"
call must ledger~postTransfer("QFX-SEED","FB-SETTLEMENT-GBP","QFX-GBP",100000,"GBP"),"seed"

d=.directory~new; d["targetCurrency"]="USD"
cmd=.FederationBankCommand~new("QFX-CMD","FX_CONVERT","QFX-IDEM","CUST-QFX","QFX-GBP","QFX-USD","GBP",10000,"WEB","CUST-QFX",.nil,"","","","","","","","","RETAIL","STANDARD",d)
call qmust runtime~submitTransfer(cmd),"submit FX"
auth=runtime~processPaymentsOne
call must auth,"Payments FX authority"
call assert auth~value["schema"]="federationbank.ledger.fx/0.7","FX Ledger queue contract"
call assert auth~value["targetAmountMinor"]=12475,"target amount derived before Ledger"
call assert ledger~balanceMinor("QFX-USD")=0,"Payments cannot create target money"
posted=runtime~processLedgerOne
call must posted,"Ledger FX commit"
call assert ledger~balanceMinor("QFX-GBP")=90000,"queue FX source debit"
call assert ledger~balanceMinor("QFX-USD")=12475,"queue FX target credit"
completed=runtime~processPaymentsCompletionOne
call must completed,"Payments FX completion"
call assert completed~code="FX_COMMITTED","structured FX completion"
call assert usage~usedMinor("CUST-QFX","GBP",cmd~requestedAt)=10000,"source-currency usage projected after commit only"
call qmust runtime~getPaymentsResult,"channel receives FX result"

say "PASS Queue Fabric channel -> Payments FX authority -> currency-balanced Ledger -> completion"
exit 0
openAccount: procedure expose runtime
  use arg r,accountId,currency,idem
  c=.FederationBankCommand~new("CMD-"||idem,"OPEN_ACCOUNT",idem,"CUST-QFX","","",currency,0,"WEB","CUST-QFX",.nil,"OFFSHORE_CURRENT",accountId,"FX Customer","1980-01-01","SW1A 1AA","GB","GB","GB","RETAIL","STANDARD")
  call qmust r~submitOpenAccount(c),"submit "||accountId
  call must r~processAccountOne,"open "||accountId
  call must r~processPaymentsProjectionOne,"payments projection "||accountId
  call must r~processLedgerProjectionOne,"ledger projection "||accountId
  call qmust r~getAccountResult,"result "||accountId
  return
must: procedure
  use arg r,label
  if r~ok=.false then do; say "FAIL" label r~code r~detail; exit 1; end
  return
qmust: procedure
  use arg r,label
  if r~ok=.false then do; say "FAIL" label r~code r~detail; exit 1; end
  return
assert: procedure
  use arg condition,label
  if \condition then do; say "FAIL" label; exit 1; end
  return
::requires "FederationBankServices.cls"
::requires "FederationBankFixtures.cls"
