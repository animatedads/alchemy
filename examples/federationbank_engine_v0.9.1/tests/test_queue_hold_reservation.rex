parse source . . script
root=value("FB_TEST_QUEUE_ROOT",,"ENVIRONMENT")
if root="" then do; say "FAIL FB_TEST_QUEUE_ROOT required"; exit 1; end
manager=.ObjectQueueManager~new(root,.QueueGraphPayloadCodec~new,.FederationBankServiceTopology~ADMIN_PRINCIPAL)
topology=.FederationBankServiceTopology~new(manager)
usage=.FederationBankPaymentsUsageProjection~new(topology~topics)
aenv=.FederationBankFixtures~freshAccountEnvironment
accountEngine=.FederationBankAccountEngine~new(aenv["authority"])
profiles=.FederationBankRegulatoryProfileRegistry~standard
pCustomers=.FederationBankCustomerRegistry~new
pAccounts=.FederationBankLedger~new
payments=.FederationBankPaymentsEngine~new(pCustomers,pAccounts,profiles,.FederationBankPolicyGate~new(.FederationBankFixtures~limitCatalog),.FederationBankLegalGate~new(.FederationBankFixtures~legalRegistry),.FederationBankBouncer~new(.FederationBankBouncer~standardFramework),usage)
executor=.FederationBankFixtureSqlExecutor~new
db=.FederationBankFixtures~database(executor)
store=.FederationBankSqlLedgerStore~new(db,3,15)
ledger=.FederationBankLedger~new(store)
profile=profiles~byCurrency("USD")
call must ledger~addAccount(.FederationBankAccount~new("FB-SETTLEMENT-USD","FEDERATIONBANK","USD","INTERNAL_SETTLEMENT","IOM",profile~profileId,.true,.true)),"settlement"
ledgerEngine=.FederationBankLedgerEngine~new(ledger,profiles)
runtime=.FederationBankBackendRuntime~new(topology,accountEngine,payments,ledgerEngine)

call openAccount runtime,"QH-SRC","QH-OPEN-1"
call openAccount runtime,"QH-DST","QH-OPEN-2"
call must ledger~postTransfer("QH-SEED","FB-SETTLEMENT-USD","QH-SRC",1000000,"USD"),"seed"

/* Channel asks Payments. Payments applies Bouncer/Policy/Legal, but cannot
   alter either the book or available balance before Ledger commits. */
details=.directory~new; details["holdId"]="QH-HOLD-1"
hold=.FederationBankCommand~new("QH-CMD-H1","PLACE_HOLD","QH-IDEM-H1","CUST-QH","QH-SRC","","USD",300000,"WEB","CUST-QH",.nil,"","","","","","","","","RETAIL","STANDARD",details)
call qmust runtime~submitHold(hold),"submit hold"
auth=runtime~processPaymentsOne
call must auth,"Payments authorises hold"
call assert auth~code="HOLD_AUTHORISED","hold authority stops at Payments"
call assert ledger~balanceMinor("QH-SRC")=1000000,"authorisation no book mutation"
call assert ledger~availableBalanceMinor("QH-SRC")=1000000,"authorisation no reservation mutation"
call must runtime~processLedgerOne,"Ledger places hold"
call assert ledger~balanceMinor("QH-SRC")=1000000,"hold no book posting"
call assert ledger~availableBalanceMinor("QH-SRC")=700000,"Ledger reservation reduces availability"
complete=runtime~processPaymentsCompletionOne
call must complete,"Payments completes hold"
call assert complete~code="HOLD_PLACED","channel outcome is hold placed"
holdResult=runtime~getPaymentsResult
call qmust holdResult,"channel gets hold result"
call assert holdResult~value~payload["availableBalanceMinor"]=700000,"available balance projected"

/* Corporate policy lets this transfer through, but Ledger refuses because
   300000 is reserved. */
pay=.FederationBankCommand~new("QH-PAY-1","TRANSFER","QH-TX-1","CUST-QH","QH-SRC","QH-DST","USD",800000,"WEB","CUST-QH")
call qmust runtime~submitTransfer(pay),"submit over-available transfer"
call must runtime~processPaymentsOne,"Payments authority transfer"
posted=runtime~processLedgerOne
call assert posted~ok=.false,"Ledger blocks spending held money"
call assert posted~code="INSUFFICIENT_AVAILABLE_FUNDS","reservation enforcement explicit"
completion=runtime~processPaymentsCompletionOne
call assert completion~ok=.false,"failed Ledger result remains failure"
call qmust runtime~getPaymentsResult,"channel gets blocked transfer result"
call assert ledger~balanceMinor("QH-SRC")=1000000,"blocked transfer no monetary movement"

releaseDetails=.directory~new; releaseDetails["holdId"]="QH-HOLD-1"
release=.FederationBankCommand~new("QH-CMD-H2","RELEASE_HOLD","QH-IDEM-H2","CUST-QH","QH-SRC","","USD",0,"WEB","CUST-QH",.nil,"","","","","","","","","RETAIL","STANDARD",releaseDetails)
call qmust runtime~submitHold(release),"submit release"
call must runtime~processPaymentsOne,"Payments authorises release"
call must runtime~processLedgerOne,"Ledger releases hold"
call must runtime~processPaymentsCompletionOne,"Payments completes release"
call qmust runtime~getPaymentsResult,"channel gets release"
call assert ledger~balanceMinor("QH-SRC")=1000000,"release no book posting"
call assert ledger~availableBalanceMinor("QH-SRC")=1000000,"release restores availability"

say "PASS queue-authorised Ledger-owned hold/release + available-balance enforcement"
exit 0

openAccount: procedure expose runtime
  use arg r,accountId,idem
  c=.FederationBankCommand~new("CMD-"||idem,"OPEN_ACCOUNT",idem,"CUST-QH","","","USD",0,"WEB","CUST-QH",.nil,"OFFSHORE_CURRENT",accountId,"Hold Customer","1980-01-01","SW1A 1AA","GB","GB","GB","RETAIL","STANDARD")
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
