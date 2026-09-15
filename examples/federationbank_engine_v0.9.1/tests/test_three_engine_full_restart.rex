parse source . . script
root=value("FB_TEST_QUEUE_ROOT",,"ENVIRONMENT")
if root="" then do; say "FAIL FB_TEST_QUEUE_ROOT required"; exit 1; end

profiles=.FederationBankRegulatoryProfileRegistry~standard
lexecutor=.FederationBankFixtureSqlExecutor~new
ldb=.FederationBankFixtures~database(lexecutor)

manager=.ObjectQueueManager~new(root,.QueueGraphPayloadCodec~new,.FederationBankServiceTopology~ADMIN_PRINCIPAL)
topology=.FederationBankServiceTopology~new(manager)
usage=.FederationBankPaymentsUsageProjection~new(topology~topics)
aenv=.FederationBankFixtures~freshAccountEnvironment
accountEngine=.FederationBankAccountEngine~new(aenv["authority"])
pCustomers=.FederationBankCustomerRegistry~new
pAccounts=.FederationBankLedger~new
payments=.FederationBankPaymentsEngine~new(pCustomers,pAccounts,profiles,.FederationBankPolicyGate~new(.FederationBankFixtures~limitCatalog),.FederationBankLegalGate~new(.FederationBankFixtures~legalRegistry),.FederationBankBouncer~new(.FederationBankBouncer~standardFramework),usage)
lstore=.FederationBankSqlLedgerStore~new(ldb,3,15)
lledger=.FederationBankLedger~new(lstore)
profile=profiles~byCurrency("USD")
call must lledger~addAccount(.FederationBankAccount~new("FB-SETTLEMENT-USD","FEDERATIONBANK","USD","INTERNAL_SETTLEMENT","IOM",profile~profileId,.true,.true)),"settlement"
ledgerEngine=.FederationBankLedgerEngine~new(lledger,profiles)
runtime=.FederationBankBackendRuntime~new(topology,accountEngine,payments,ledgerEngine)

call openAccount runtime,"FR-SRC","FR-OPEN-1"
call openAccount runtime,"FR-DST","FR-OPEN-2"
call must lledger~postTransfer("FR-SEED","FB-SETTLEMENT-USD","FR-SRC",10000000,"USD"),"seed"
pay1=.FederationBankCommand~new("FR-PAY-1","TRANSFER","FR-TX-1","CUST-FR","FR-SRC","FR-DST","USD",4000000,"WEB","CUST-FR")
call qmust runtime~submitTransfer(pay1),"submit first"
call must runtime~processPaymentsOne,"authorise first"
call must runtime~processLedgerOne,"ledger first"
call must runtime~processPaymentsCompletionOne,"complete first"
call qmust runtime~getPaymentsResult,"consume first result"
call assert lledger~balanceMinor("FR-SRC")=6000000,"pre-restart source"
call assert lledger~balanceMinor("FR-DST")=4000000,"pre-restart target"

/* Entire Payments + Ledger worker state disappears. Queue Fabric retained
   projections and Ledger SQL are the only recovery sources. */
manager2=.ObjectQueueManager~new(root,.QueueGraphPayloadCodec~new,.FederationBankServiceTopology~ADMIN_PRINCIPAL)
topology2=.FederationBankServiceTopology~new(manager2)
usage2=.FederationBankPaymentsUsageProjection~new(topology2~topics)
newCustomers=.FederationBankCustomerRegistry~new
newAccounts=.FederationBankLedger~new
payments2=.FederationBankPaymentsEngine~new(newCustomers,newAccounts,profiles,.FederationBankPolicyGate~new(.FederationBankFixtures~limitCatalog),.FederationBankLegalGate~new(.FederationBankFixtures~legalRegistry),.FederationBankBouncer~new(.FederationBankBouncer~standardFramework),usage2)
call must payments2~rebuildAccountProjections(topology2~topics),"Payments account recovery"

lstore2=.FederationBankSqlLedgerStore~new(ldb,3,15)
lledger2=.FederationBankLedger~new(lstore2)
call must lledger2~addAccount(.FederationBankAccount~new("FB-SETTLEMENT-USD","FEDERATIONBANK","USD","INTERNAL_SETTLEMENT","IOM",profile~profileId,.true,.true)),"restart settlement"
ledger2=.FederationBankLedgerEngine~new(lledger2,profiles)
call must ledger2~rebuildAccountProjections(topology2~topics),"Ledger account recovery"
call must lledger2~hydratePostingsFromStore,"Ledger SQL posting recovery"
call assert lledger2~balanceMinor("FR-SRC")=6000000,"source balance recovered from SQL"
call assert lledger2~balanceMinor("FR-DST")=4000000,"target balance recovered from SQL"
call assert usage2~usedMinor("CUST-FR","USD",pay1~requestedAt)=4000000,"Payments usage recovered from retained facts"

runtime2=.FederationBankBackendRuntime~new(topology2,.nil,payments2,ledger2)
pay2=.FederationBankCommand~new("FR-PAY-2","TRANSFER","FR-TX-2","CUST-FR","FR-SRC","FR-DST","USD",1000000,"WEB","CUST-FR")
call qmust runtime2~submitTransfer(pay2),"submit after restart"
call must runtime2~processPaymentsOne,"authorise after restart"
call must runtime2~processLedgerOne,"ledger after restart"
call must runtime2~processPaymentsCompletionOne,"complete after restart"
call qmust runtime2~getPaymentsResult,"result after restart"
call assert lledger2~balanceMinor("FR-SRC")=5000000,"new debit uses recovered balance"
call assert lledger2~balanceMinor("FR-DST")=5000000,"new credit uses recovered balance"
call assert usage2~usedMinor("CUST-FR","USD",pay2~requestedAt)=5000000,"usage continues after restart"
say "PASS full Payments/Ledger restart: retained projections + SQL monetary hydration"
exit 0

openAccount: procedure expose runtime
  use arg r,accountId,idem
  c=.FederationBankCommand~new("CMD-"||idem,"OPEN_ACCOUNT",idem,"CUST-FR","","","USD",0,"WEB","CUST-FR",.nil,"OFFSHORE_CURRENT",accountId,"Full Restart Customer","1980-01-01","SW1A 1AA","GB","GB","GB","RETAIL","STANDARD")
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
