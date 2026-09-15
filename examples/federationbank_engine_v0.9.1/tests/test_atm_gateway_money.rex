root=value("FB_TEST_QUEUE_ROOT",,"ENVIRONMENT")
if root="" then do; say "FAIL FB_TEST_QUEUE_ROOT required"; exit 1; end
manager=.ObjectQueueManager~new(root,.QueueGraphPayloadCodec~new,.FederationBankServiceTopology~ADMIN_PRINCIPAL)
topology=.FederationBankServiceTopology~new(manager)
usage=.FederationBankPaymentsUsageProjection~new(topology~topics)
aenv=.FederationBankFixtures~freshAccountEnvironment
accountEngine=.FederationBankAccountEngine~new(aenv["authority"])
profiles=.FederationBankRegulatoryProfileRegistry~standard
pCustomers=.FederationBankCustomerRegistry~new; pAccounts=.FederationBankLedger~new
payments=.FederationBankPaymentsEngine~new(pCustomers,pAccounts,profiles,.FederationBankPolicyGate~new(.FederationBankFixtures~limitCatalog),.FederationBankLegalGate~new(.FederationBankFixtures~legalRegistry),.FederationBankBouncer~new(.FederationBankBouncer~standardFramework),usage)
executor=.FederationBankFixtureSqlExecutor~new; db=.FederationBankFixtures~database(executor); store=.FederationBankSqlLedgerStore~new(db,3,15)
ledger=.FederationBankLedger~new(store); p=profiles~byCurrency("GBP")
call must ledger~addAccount(.FederationBankAccount~new("FB-SETTLEMENT-GBP","FEDERATIONBANK","GBP","INTERNAL_SETTLEMENT","IOM",p~profileId,.true,.true)),"settlement"
ledgerEngine=.FederationBankLedgerEngine~new(ledger,profiles)
runtime=.FederationBankBackendRuntime~new(topology,accountEngine,payments,ledgerEngine)
gateway=.FederationBankAtmGateway~new(topology,runtime,ledgerEngine)

call openAccount runtime,"GBP-001","ATM-MONEY-OPEN-1"
call must ledger~postTransfer("ATM-MONEY-SEED","FB-SETTLEMENT-GBP","GBP-001",125000,"GBP"),"seed"

/* Log on using the exact Java ATM demo card. */
r=req("ATM-IOM-001-LGN-100","LOGON","",100,.directory~new)
r["data"]["cardId"]="4111111111111111"; r["data"]["credentialType"]="DEMO_PIN"; r["data"]["credential"]="1234"
x=gateway~handleRequest(r); call assert x["ok"]=.true,"logon"; sid=x["data"]["sessionId"]

/* Authorisation creates only a Ledger-owned reservation. */
auth=req("ATM-IOM-001-WDA-101","WITHDRAW_AUTHORISE",sid,101,.directory~new)
auth["idempotencyKey"]="WDA-ATM-IOM-001-101"
auth["data"]["accountId"]="GBP-001"; auth["data"]["currency"]="GBP"; auth["data"]["amountMinor"]=10000
before=ledger~postings~items
x=gateway~handleRequest(auth); if x["ok"]=.false then say "DEBUG AUTH" .JSON~toJSON(x); call assert x["ok"]=.true,"withdraw authorise"; call assert x["code"]="WITHDRAW_AUTHORISED","authorise code"
authorizationId=x["data"]["authorizationId"]; holdId=x["data"]["holdId"]
call assert ledger~balanceMinor("GBP-001")=125000,"authorise does not debit book"
call assert ledger~availableBalanceMinor("GBP-001")=115000,"authorise reserves available funds"
call assert ledger~postings~items=before,"authorise creates no postings"
call assert ledger~hold(holdId)~status="ACTIVE","hold active"

/* The Java client allocates a distinct WDM identity before physical dispense. */
commit=req("ATM-IOM-001-WDM-102","WITHDRAW_COMMIT",sid,102,.directory~new)
commit["idempotencyKey"]="WDM-ATM-IOM-001-102"
commit["data"]["sessionId"]=sid; commit["data"]["customerId"]="CUST-001"; commit["data"]["accountId"]="GBP-001"; commit["data"]["currency"]="GBP"; commit["data"]["amountMinor"]=10000
commit["data"]["authorizationId"]=authorizationId; commit["data"]["holdId"]=holdId; commit["data"]["physicalTransactionId"]="PHYS-DISP-102"; commit["data"]["dispensedMinor"]=10000
x=gateway~handleRequest(commit); call assert x["ok"]=.true,"withdraw commit"; call assert x["code"]="WITHDRAW_COMMITTED","commit code"
call assert ledger~balanceMinor("GBP-001")=115000,"withdrawal debits once"
call assert ledger~availableBalanceMinor("GBP-001")=115000,"consumed hold no longer subtracts availability"
call assert ledger~hold(holdId)~status="RELEASED","hold consumed/released"
call assert ledger~postings~items=before+2,"withdrawal exactly two monetary legs"
cashId=ledgerEngine~atmCashAccountId("ATM-IOM-001","GBP")
call assert ledger~balanceMinor(cashId)=10000,"ATM cash settlement credited"

/* Lost JMS reply / duplicate WDM commit must recover the durable result. */
postCommitCount=ledger~postings~items
x=gateway~handleRequest(commit); call assert x["ok"]=.true,"withdraw replay"; call assert x["code"]="WITHDRAW_COMMITTED","replay external code stable"
call assert ledger~balanceMinor("GBP-001")=115000,"replay no second customer debit"
call assert ledger~balanceMinor(cashId)=10000,"replay no second cash credit"
call assert ledger~postings~items=postCommitCount,"replay no second postings"

/* Transaction status is recovered from durable Ledger receipt. */
status=req("ATM-IOM-001-STS-103","GET_TRANSACTION_STATUS",sid,103,.directory~new)
status["data"]["idempotencyKey"]="WDM-ATM-IOM-001-102"
x=gateway~handleRequest(status); call assert x["ok"]=.true,"transaction status"; call assert x["code"]="TRANSACTION_COMMITTED","status code"
call assert x["data"]["bankTransactionId"]="WDM-ATM-IOM-001-102","status durable tx"

/* A second authorisation may be cancelled when the physical dispenser fails. */
auth2=req("ATM-IOM-001-WDA-104","WITHDRAW_AUTHORISE",sid,104,.directory~new); auth2["idempotencyKey"]="WDA-ATM-IOM-001-104"
auth2["data"]["accountId"]="GBP-001"; auth2["data"]["currency"]="GBP"; auth2["data"]["amountMinor"]=5000
x=gateway~handleRequest(auth2); call assert x["ok"]=.true,"second authorise"; hold2=x["data"]["holdId"]; authId2=x["data"]["authorizationId"]
call assert ledger~availableBalanceMinor("GBP-001")=110000,"second hold reserves funds"
cancel=req("ATM-IOM-001-WDC-105","WITHDRAW_CANCEL",sid,105,.directory~new); cancel["idempotencyKey"]="WDC-ATM-IOM-001-105"
cancel["data"]["authorizationId"]=authId2; cancel["data"]["holdId"]=hold2; cancel["data"]["physicalTransactionId"]="PHYS-DISP-FAILED-105"
x=gateway~handleRequest(cancel); call assert x["ok"]=.true,"withdraw cancel"; call assert x["code"]="WITHDRAW_CANCELLED","cancel code"
call assert ledger~hold(hold2)~status="RELEASED","failed dispense releases hold"
call assert ledger~balanceMinor("GBP-001")=115000,"cancel no book movement"
call assert ledger~availableBalanceMinor("GBP-001")=115000,"cancel restores availability"

/* Physical cash deposit is committed once and may be safely retransmitted. */
dep=req("ATM-IOM-001-DPM-106","DEPOSIT_COMMIT",sid,106,.directory~new); dep["idempotencyKey"]="DPM-ATM-IOM-001-106"
dep["data"]["sessionId"]=sid; dep["data"]["customerId"]="CUST-001"; dep["data"]["accountId"]="GBP-001"; dep["data"]["currency"]="GBP"; dep["data"]["amountMinor"]=20000; dep["data"]["physicalTransactionId"]="PHYS-DEP-106"
preDeposit=ledger~postings~items
x=gateway~handleRequest(dep); call assert x["ok"]=.true,"deposit commit"; call assert x["code"]="DEPOSIT_COMMITTED","deposit code"
call assert ledger~balanceMinor("GBP-001")=135000,"deposit customer credit"
call assert ledger~balanceMinor(cashId)=-10000,"ATM cash position reflects net physical cash"
call assert ledger~postings~items=preDeposit+2,"deposit exactly two legs"
postDeposit=ledger~postings~items
x=gateway~handleRequest(dep); call assert x["ok"]=.true,"deposit replay"
call assert ledger~balanceMinor("GBP-001")=135000,"deposit replay no second credit"
call assert ledger~postings~items=postDeposit,"deposit replay no extra legs"

say "PASS Java ATM hold/dispense/commit/cancel/deposit + durable replay"
exit 0

openAccount: procedure expose runtime
  use arg rt,aid,idem
  c=.FederationBankCommand~new("CMD-"||idem,"OPEN_ACCOUNT",idem,"CUST-001","","","GBP",0,"WEB","CUST-001",.nil,"OFFSHORE_CURRENT",aid,"Existing Customer","1980-01-01","SW1A 1AA","GB","GB","GB","RETAIL","STANDARD")
  call qmust rt~submitOpenAccount(c),"submit "||aid; call must rt~processAccountOne,"open "||aid; call must rt~processPaymentsProjectionOne,"payments projection"; call must rt~processLedgerProjectionOne,"ledger projection"; call qmust rt~getAccountResult,"open result"
  return
req: procedure
  use arg commandId,op,session,seq,data
  d=.directory~new; d["schema"]="federationbank.atm.request/0.1"; d["commandId"]=commandId; d["idempotencyKey"]=commandId; d["operation"]=op; d["terminalId"]="ATM-IOM-001"; d["terminalSequence"]=seq; d["sessionId"]=session; d["requestedAt"]=.DateTime~new~utcIsoDate; d["rulesetId"]="FB-ATM-IOM-DEMO"; d["rulesVersion"]=1; d["data"]=data; return d
must: procedure; use arg r,label; if r~ok=.false then do; say "FAIL" label r~code r~detail; exit 1; end; return
qmust: procedure; use arg r,label; if r~ok=.false then do; say "FAIL" label r~code r~detail; exit 1; end; return
assert: procedure; use arg condition,label; if \condition then do; say "FAIL" label; exit 1; end; return
::requires "FederationBankAtmGateway.cls"
::requires "FederationBankFixtures.cls"
