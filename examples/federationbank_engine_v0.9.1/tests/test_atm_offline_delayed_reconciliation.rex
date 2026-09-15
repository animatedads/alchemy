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

call openAccount runtime,"GBP-DELAY","DELAY-OPEN"
call must ledger~postTransfer("DELAY-SEED","FB-SETTLEMENT-GBP","GBP-DELAY",4000,"GBP"),"seed delayed account"

login=req("ATM-IOM-001-LGN-300","LOGON","",300,.directory~new)
login["data"]["cardId"]="4111111111111111"; login["data"]["credentialType"]="DEMO_PIN"; login["data"]["credential"]="1234"
x=gateway~handleRequest(login); call assert x["ok"]=.true,"logon"; sid=x["data"]["sessionId"]

/* Bank-issued authority expired at the bank before network recovery, but the
   terminal's durable physical event occurred while the authority was valid. */
now=.DateTime~new
issued=now-spanSeconds(700)
r=gateway~offlineAuthorities~issue("OFFAUTH-DELAY-1","DELEGATED_STAND_IN","ATM-IOM-001","CUST-001","GBP-DELAY","GBP",18000,"","FB-ATM-IOM-DEMO",1,issued,600,.nil,sid,300,900,5)
call must r,"issue delayed authority"

logout=req("ATM-IOM-001-LGF-301","LOGOFF",sid,301,.directory~new)
x=gateway~handleRequest(logout); call assert x["ok"]=.true,"interactive session logged off before recovery"

/* Prove the recovery evidence is really durable rather than an in-memory
   exception: both the authenticated session history and the bank-issued
   authority are reconstructed from retained Queue Fabric topics. */
gateway=.FederationBankAtmGateway~new(topology,runtime,ledgerEngine)
a=gateway~offlineAuthorities~authority("OFFAUTH-DELAY-1")
call assert a<>.nil,"authority rebuilt after gateway restart"
call assert a["sessionId"]=sid,"authority retained issuing session"
call assert a["issuedTerminalSequence"]=300,"authority retained issuing sequence"

advice=req("ATM-IOM-001-OWA-302","OFFLINE_WITHDRAWAL_ADVICE",sid,302,.directory~new); advice["idempotencyKey"]="OWA-DELAY-1"
advice["data"]["offlineAuthorityId"]="OFFAUTH-DELAY-1"; advice["data"]["accountId"]="GBP-DELAY"; advice["data"]["currency"]="GBP"; advice["data"]["amountMinor"]=18000
advice["data"]["physicalTransactionId"]="PHYS-DELAY-1"; advice["data"]["dispensedMinor"]=18000; advice["data"]["authorityMode"]="DELEGATED_STAND_IN"
advice["data"]["dispensedAt"]=(now-spanSeconds(200))~utcIsoDate
before=ledger~postings~items
x=gateway~handleRequest(advice); if x["ok"]=.false then say "DEBUG DELAY" .JSON~toJSON(x)
call assert x["ok"]=.true,"delayed advice accepted after logoff"
call assert ledger~balanceMinor("GBP-DELAY")=-14000,"delayed physical cash settled once"
call assert ledger~postings~items=before+2,"delayed settlement exactly two legs"
a=gateway~offlineAuthorities~authority("OFFAUTH-DELAY-1")
call assert a["status"]="CONSUMED","delayed authority consumed"
call assert a["evidenceDisposition"]="ATM_OFFLINE_DELAYED_EVIDENCE_ACCEPTED","delayed evidence disposition retained"
call assert a["dispensedAt"]~string<>"","physical dispense time retained with authority"

/* Ledger/payment evidence keeps both terminal and bank clock facts. */
receipt=store~recoverReceipt("OWA-DELAY-1")
call must receipt,"recover delayed settlement receipt"
ev=receipt~value
call assert ev<>.nil,"durable delayed settlement receipt present"
call assert ev["dispensedAt"]~string<>"","ledger receipt retains physical dispense time"
call assert ev["adviceReceivedAt"]~string<>"","ledger receipt retains bank receipt time"
call assert ev["authorityIssuedTerminalSequence"]=300,"ledger receipt retains authority sequence boundary"
call assert ev["reconciliationWindowSeconds"]=900,"ledger receipt retains reconciliation window"
call assert ev["terminalClockSkewSeconds"]=5,"ledger receipt retains clock-skew tolerance"
call assert ev["offlineEvidenceDisposition"]="ATM_OFFLINE_DELAYED_EVIDENCE_ACCEPTED","ledger receipt retains delayed disposition"

/* Lost bank reply remains a replay, not another cash event. */
postCount=ledger~postings~items
x=gateway~handleRequest(advice); call assert x["ok"]=.true,"delayed advice replay accepted"
call assert ledger~postings~items=postCount,"delayed replay no second posting"
call assert ledger~balanceMinor("GBP-DELAY")=-14000,"delayed replay no second debit"

/* A later interactive login cannot appropriate an authority issued to the
   earlier authenticated session, even on the same physical terminal. */
login2=req("ATM-IOM-001-LGN-305","LOGON","",305,.directory~new)
login2["data"]["cardId"]="4111111111111111"; login2["data"]["credentialType"]="DEMO_PIN"; login2["data"]["credential"]="1234"
x=gateway~handleRequest(login2); call assert x["ok"]=.true,"second logon"; sid2=x["data"]["sessionId"]
issuedX=.DateTime~new-spanSeconds(700)
r=gateway~offlineAuthorities~issue("OFFAUTH-SESSION-BIND","DELEGATED_STAND_IN","ATM-IOM-001","CUST-001","GBP-DELAY","GBP",1000,"","FB-ATM-IOM-DEMO",1,issuedX,600,.nil,sid,300,900,5)
call must r,"issue session-binding authority"
cross=req("ATM-IOM-001-OWA-306","OFFLINE_WITHDRAWAL_ADVICE",sid2,306,.directory~new); cross["idempotencyKey"]="OWA-SESSION-BIND"
cross["data"]["offlineAuthorityId"]="OFFAUTH-SESSION-BIND"; cross["data"]["accountId"]="GBP-DELAY"; cross["data"]["currency"]="GBP"; cross["data"]["amountMinor"]=1000
cross["data"]["physicalTransactionId"]="PHYS-SESSION-BIND"; cross["data"]["dispensedMinor"]=1000; cross["data"]["authorityMode"]="DELEGATED_STAND_IN"; cross["data"]["dispensedAt"]=(.DateTime~new-spanSeconds(200))~utcIsoDate
preCross=ledger~postings~items
x=gateway~handleRequest(cross); call assert x["ok"]=.false,"different session cannot consume authority"; call assert x["code"]="ATM_OFFLINE_AUTHORITY_SESSION_MISMATCH","session-binding evidence code"
call assert ledger~postings~items=preCross,"cross-session advice creates no monetary truth"

/* A terminal cannot simply backdate cash which actually falls outside the
   validity interval (apart from the explicitly bounded 5 second clock skew). */
issued2=.DateTime~new-spanSeconds(700)
r=gateway~offlineAuthorities~issue("OFFAUTH-BACKDATE","DELEGATED_STAND_IN","ATM-IOM-001","CUST-001","GBP-DELAY","GBP",1000,"","FB-ATM-IOM-DEMO",1,issued2,600,.nil,sid,310,900,5)
call must r,"issue backdate probe authority"
bad=req("ATM-IOM-001-OWA-311","OFFLINE_WITHDRAWAL_ADVICE",sid,311,.directory~new); bad["idempotencyKey"]="OWA-BACKDATE"
bad["data"]["offlineAuthorityId"]="OFFAUTH-BACKDATE"; bad["data"]["accountId"]="GBP-DELAY"; bad["data"]["currency"]="GBP"; bad["data"]["amountMinor"]=1000
bad["data"]["physicalTransactionId"]="PHYS-BACKDATE"; bad["data"]["dispensedMinor"]=1000; bad["data"]["authorityMode"]="DELEGATED_STAND_IN"
bad["data"]["dispensedAt"]=(.DateTime~new-spanSeconds(50))~utcIsoDate
preBad=ledger~postings~items
x=gateway~handleRequest(bad); call assert x["ok"]=.false,"post-expiry dispense rejected"; call assert x["code"]="ATM_OFFLINE_DISPENSE_OUTSIDE_AUTHORITY","post-expiry evidence code"
call assert ledger~postings~items=preBad,"backdated evidence creates no monetary truth"

/* Even genuine in-window physical evidence has a bounded reconciliation
   lifetime; an authority cannot become a forever-settle bearer token. */
issued3=.DateTime~new-spanSeconds(2000)
r=gateway~offlineAuthorities~issue("OFFAUTH-TOO-LATE","DELEGATED_STAND_IN","ATM-IOM-001","CUST-001","GBP-DELAY","GBP",1000,"","FB-ATM-IOM-DEMO",1,issued3,600,.nil,sid,320,600,5)
call must r,"issue stale evidence authority"
stale=req("ATM-IOM-001-OWA-321","OFFLINE_WITHDRAWAL_ADVICE",sid,321,.directory~new); stale["idempotencyKey"]="OWA-TOO-LATE"
stale["data"]["offlineAuthorityId"]="OFFAUTH-TOO-LATE"; stale["data"]["accountId"]="GBP-DELAY"; stale["data"]["currency"]="GBP"; stale["data"]["amountMinor"]=1000
stale["data"]["physicalTransactionId"]="PHYS-TOO-LATE"; stale["data"]["dispensedMinor"]=1000; stale["data"]["authorityMode"]="DELEGATED_STAND_IN"
stale["data"]["dispensedAt"]=(issued3+spanSeconds(500))~utcIsoDate
x=gateway~handleRequest(stale); call assert x["ok"]=.false,"stale reconciliation rejected"; call assert x["code"]="ATM_OFFLINE_RECONCILIATION_WINDOW_EXPIRED","stale reconciliation code"

/* Terminal sequence is part of the physical evidence chain. */
current=.DateTime~new
r=gateway~offlineAuthorities~issue("OFFAUTH-SEQUENCE","DELEGATED_STAND_IN","ATM-IOM-001","CUST-001","GBP-DELAY","GBP",1000,"","FB-ATM-IOM-DEMO",1,current,600,.nil,sid,400,900,5)
call must r,"issue sequence authority"
seq=req("ATM-IOM-001-OWA-399","OFFLINE_WITHDRAWAL_ADVICE",sid,399,.directory~new); seq["idempotencyKey"]="OWA-SEQUENCE"
seq["data"]["offlineAuthorityId"]="OFFAUTH-SEQUENCE"; seq["data"]["accountId"]="GBP-DELAY"; seq["data"]["currency"]="GBP"; seq["data"]["amountMinor"]=1000
seq["data"]["physicalTransactionId"]="PHYS-SEQUENCE"; seq["data"]["dispensedMinor"]=1000; seq["data"]["authorityMode"]="DELEGATED_STAND_IN"; seq["data"]["dispensedAt"]=current~utcIsoDate
x=gateway~handleRequest(seq); call assert x["ok"]=.false,"non-forward terminal sequence rejected"; call assert x["code"]="ATM_OFFLINE_AUTHORITY_SEQUENCE_INVALID","sequence evidence code"

say "PASS bounded delayed ATM evidence: expiry stops new cash but does not erase prior physical dispense"
exit 0

spanSeconds: procedure
  use arg totalArg
  total=totalArg+0; days=total%86400; rest=total//86400; hours=rest%3600; rest=rest//3600; minutes=rest%60; seconds=rest//60
  return .TimeSpan~new(days,hours,minutes,seconds,0)
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
