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

call openAccount runtime,"GBP-001","ATM-OPEN-1"
call openAccount runtime,"GBP-002","ATM-OPEN-2"
call must ledger~postTransfer("ATM-SEED","FB-SETTLEMENT-GBP","GBP-001",125000,"GBP"),"seed"

/* exact demo failure and success credentials */
r=req("ATM-IOM-001-LGN-1","LOGON","",1,.directory~new)
r["data"]["cardId"]="1"; r["data"]["credentialType"]="DEMO_PIN"; r["data"]["credential"]="1234"
x=gateway~handleRequest(r); call assert x["ok"]=.false,"card 1 rejected"; call assert x["code"]="AUTHENTICATION_FAILED","structured auth failure"

r=req("ATM-IOM-001-LGN-2","LOGON","",2,.directory~new)
r["data"]["cardId"]="4111111111111111"; r["data"]["credentialType"]="DEMO_PIN"; r["data"]["credential"]="1234"
x=gateway~handleRequest(r); call assert x["ok"]=.true,"demo card accepted"; call assert x["code"]="LOGON_ACCEPTED","logon code"
sid=x["data"]["sessionId"]

r=req("ATM-IOM-001-LAC-3","LIST_ACCOUNTS",sid,3,.directory~new)
x=gateway~handleRequest(r); call assert x["ok"]=.true,"list accounts"; call assert x["data"]["accounts"]~items=2,"only customer accounts returned"

r=req("ATM-IOM-001-BAL-4","GET_BALANCE",sid,4,.directory~new); r["data"]["accountId"]="GBP-001"
x=gateway~handleRequest(r); call assert x["ok"]=.true,"balance"; call assert x["data"]["bookBalanceMinor"]=125000,"book balance"; call assert x["data"]["availableBalanceMinor"]=125000,"available balance"

/* signed rules are exact Java v0.1 shape and proper JSON booleans */
r=req("ATM-IOM-001-RUL-5","GET_RULES","",5,.directory~new)
x=gateway~handleRequest(r); call assert x["ok"]=.true,"rules"; call assert x["data"]["signatureAlgorithm"]="Ed25519","rules algorithm"
json=.JSON~toJSON(x); call assert json~pos('"ok":true')>0,"response boolean is JSON true"; call assert json~pos('"withdrawal":true')>0,"rule boolean is JSON true"
call assert gateway~signer~publicKeySpkiBase64="MCowBQYDK2VwAyEA7ndT6feJnfYbd0LC1yXNu1R3QGwUJsCa/+kuZKUp0MU=","Java X509 public key vector"

/* exact JMS metadata/correlation survives the neutral bridge representation */
r=req("ATM-IOM-001-TSO-6","TERMINAL_SIGN_ON","",6,.directory~new)
props=.directory~new; props["FB_ATM_SCHEMA"]=r["schema"]; props["FB_ATM_OPERATION"]=r["operation"]; props["FB_ATM_TERMINAL_ID"]=r["terminalId"]; props["FB_ATM_RULES_VERSION"]=r["rulesVersion"]
h=.directory~new; h["JMSCORRELATIONID"]=r["commandId"]
m=.JMSBridgeMessage~new("JMS-1","TEXT",.JSON~toJSON(r),h,props,"TEST","FB.ATM.REQUESTS")
br=gateway~processBridgeMessage(m); call jmust br,"bridge request"; out=.JSON~fromJSON(br~value~body); call assert out["code"]="TERMINAL_ACCEPTED","bridge response"; call assert br~value~headers["JMSCORRELATIONID"]=r["commandId"],"correlation preserved"

say "PASS exact Java ATM protocol auth/accounts/balance/rules/JMS metadata"
exit 0

openAccount: procedure expose runtime
  use arg rt,aid,idem
  c=.FederationBankCommand~new("CMD-"||idem,"OPEN_ACCOUNT",idem,"CUST-001","","","GBP",0,"WEB","CUST-001",.nil,"OFFSHORE_CURRENT",aid,"Existing Customer","1980-01-01","SW1A 1AA","GB","GB","GB","RETAIL","STANDARD")
  call qmust rt~submitOpenAccount(c),"submit "||aid; call must rt~processAccountOne,"open "||aid; call must rt~processPaymentsProjectionOne,"payments projection"; call must rt~processLedgerProjectionOne,"ledger projection"; call qmust rt~getAccountResult,"open result"
  return
req: procedure
  use arg commandId,op,session,seq,data
  d=.directory~new; d["schema"]="federationbank.atm.request/0.1"; d["commandId"]=commandId; d["idempotencyKey"]=commandId; d["operation"]=op; d["terminalId"]="ATM-IOM-001"; d["terminalSequence"]=seq; d["sessionId"]=session; d["requestedAt"]=.DateTime~new~utcIsoDate; d["rulesetId"]="FB-ATM-IOM-DEMO"; d["rulesVersion"]=1; d["data"]=data; return d
must: procedure; use arg r,label; if \r~ok then do; say "FAIL" label r~code r~detail; exit 1; end; return
qmust: procedure; use arg r,label; if \r~ok then do; say "FAIL" label r~code r~detail; exit 1; end; return
jmust: procedure; use arg r,label; if \r~ok then do; say "FAIL" label r~code r~detail; exit 1; end; return
assert: procedure; use arg condition,label; if \condition then do; say "FAIL" label; exit 1; end; return
::requires "FederationBankAtmGateway.cls"
::requires "FederationBankFixtures.cls"
