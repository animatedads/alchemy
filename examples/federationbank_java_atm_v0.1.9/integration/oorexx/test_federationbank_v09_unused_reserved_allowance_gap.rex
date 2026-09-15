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

call openAccount runtime,"GBP-UNUSED","UNUSED-OPEN"
call must ledger~postTransfer("UNUSED-SEED","FB-SETTLEMENT-GBP","GBP-UNUSED",30000,"GBP"),"seed"

login=req("ATM-IOM-001-LGN-300","LOGON","",300,.directory~new)
login["data"]["cardId"]="4111111111111111"; login["data"]["credentialType"]="DEMO_PIN"; login["data"]["credential"]="1234"
x=gateway~handleRequest(login); call assert x["ok"]=.true,"logon"; sid=x["data"]["sessionId"]

ra=req("ATM-IOM-001-OFA-301","GET_OFFLINE_ALLOWANCE",sid,301,.directory~new); ra["idempotencyKey"]="OFA-UNUSED-301"
ra["data"]["accountId"]="GBP-UNUSED"; ra["data"]["currency"]="GBP"; ra["data"]["amountMinor"]=10000; ra["data"]["authorityMode"]="RESERVED_ALLOWANCE"
x=gateway~handleRequest(ra); call assert x["ok"]=.true,"reserved authority issued"
authorityId=x["data"]["offlineAuthorityId"]; holdId=x["data"]["holdId"]
call assert ledger~balanceMinor("GBP-UNUSED")=30000,"issue no book movement"
call assert ledger~availableBalanceMinor("GBP-UNUSED")=20000,"issue reserves availability"
call assert ledger~hold(holdId)~status="ACTIVE","hold active"

/* Customer ends the ATM session without ever dispensing cash. */
lo=req("ATM-IOM-001-LGF-302","LOGOFF",sid,302,.directory~new)
x=gateway~handleRequest(lo); call assert x["ok"]=.true,"logoff accepted"
call assert ledger~hold(holdId)~status="ACTIVE","unused reserved hold survives LOGOFF"
call assert ledger~availableBalanceMinor("GBP-UNUSED")=20000,"unused authority still constrains availability"
call assert gateway~offlineAuthorities~authority(authorityId)["status"]="ACTIVE","authority remains active after logoff"

/* v0.9 exposes no ATM operation that returns an unused authority/hold. */
rel=req("ATM-IOM-001-OFR-303","RELEASE_OFFLINE_ALLOWANCE",sid,303,.directory~new); rel["idempotencyKey"]="OFR-UNUSED-303"
rel["data"]["offlineAuthorityId"]=authorityId
x=gateway~handleRequest(rel)
call assert x["ok"]=.false,"release operation unsupported in stock v0.9"
call assert x["code"]="OPERATION_UNSUPPORTED","unsupported release code"
call assert ledger~hold(holdId)~status="ACTIVE","unsupported release leaves hold active"

say "PASS FederationBank v0.9 gap reproduced: unused RESERVED_ALLOWANCE survives LOGOFF and has no release operation"
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
