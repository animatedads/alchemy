/*
 * FederationBank ATM deterministic queue/JMS-shaped integration acceptance.
 *
 * Path under test:
 *   fake JMS delivery
 *     -> JMSQueueBridgeService
 *     -> durable Queue Fabric ATM.IN
 *     -> FederationBankAtmGateway
 *     -> Queue Fabric ATM.OUT
 *     -> JMSQueueBridgeService
 *     -> captured outbound JMS-shaped package
 *
 * This is deliberately below the live BSF4ooRexx/JMS provider binding.  It
 * proves the neutral bridge, Queue Fabric, exact ATM JSON protocol and real
 * bank monetary path as one composed system.
 */
root=value("FB_TEST_QUEUE_ROOT",,"ENVIRONMENT")
if root="" then do; say "FAIL FB_TEST_QUEUE_ROOT required"; exit 1; end

/* Bank topology/runtime. */
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
call openAccount runtime,"GBP-001","ATM-BRIDGE-OPEN-1"
call must ledger~postTransfer("ATM-BRIDGE-SEED","FB-SETTLEMENT-GBP","GBP-001",125000,"GBP"),"seed"

/* Separate transport queues.  The bank's internal service queues remain owned
 * by FederationBankServiceTopology; the bridge principal gets only its edge. */
call qmust manager~createQueue("FB.ATM.BRIDGE.IN","TEMPORARY","ATM",0,"bridge"),"create bridge in"
call qmust manager~createQueue("FB.ATM.BRIDGE.OUT","TEMPORARY","ATM",0,"bridge"),"create bridge out"
config=.JMSBridgeConfig~new("fb-atm-test","GENERIC","","","FB.ATM.REQUESTS","FB.ATM.REPLIES.ATM-IOM-001","","","","FB.ATM.BRIDGE.IN","FB.ATM.BRIDGE.OUT","bridge",.true,0,"REJECT","","CLIENT_ACKNOWLEDGE","ADMINISTERED")
provider=.CaptureJMSProvider~new("CLIENT_ACKNOWLEDGE")
bridge=.JMSQueueBridgeService~new(manager,provider,config)
call jmust bridge~start,"bridge start"

/* Terminal sign-on through the complete neutral transport path. */
r=req("ATM-IOM-001-TSO-001","TERMINAL_SIGN_ON","",1,.directory~new)
r["data"]["softwareVersion"]="0.1.2"; r["data"]["protocolVersion"]="0.1"
x=roundTrip(r,"JMS:TSO:1")
call assert x["ok"]=.true,"terminal sign-on"
call assert x["code"]="TERMINAL_ACCEPTED","terminal accepted"
call assert lastCorrelation=r["commandId"],"reply correlation preserved"

/* Authentication and session are bank-owned even though client transports the
 * card/PIN demo credential. */
r=req("ATM-IOM-001-LGN-002","LOGON","",2,.directory~new)
r["data"]["cardId"]="4111111111111111"; r["data"]["credentialType"]="DEMO_PIN"; r["data"]["credential"]="1234"
x=roundTrip(r,"JMS:LGN:2")
call assert x["ok"]=.true,"logon"
sid=x["data"]["sessionId"]

/* Book and available balances traverse JMS-shaped transport rather than direct
 * gateway calls. */
r=req("ATM-IOM-001-BAL-003","GET_BALANCE",sid,3,.directory~new); r["data"]["accountId"]="GBP-001"
x=roundTrip(r,"JMS:BAL:3")
call assert x["data"]["bookBalanceMinor"]=125000,"initial book balance"
call assert x["data"]["availableBalanceMinor"]=125000,"initial available balance"

/* Authorise: hold only, no book posting. */
a=req("ATM-IOM-001-WDA-004","WITHDRAW_AUTHORISE",sid,4,.directory~new); a["idempotencyKey"]="WDA-BRIDGE-004"
a["data"]["accountId"]="GBP-001"; a["data"]["currency"]="GBP"; a["data"]["amountMinor"]=10000
before=ledger~postings~items
x=roundTrip(a,"JMS:WDA:4")
call assert x["code"]="WITHDRAW_AUTHORISED","withdraw authorised"
authId=x["data"]["authorizationId"]; holdId=x["data"]["holdId"]
call assert ledger~balanceMinor("GBP-001")=125000,"authorise no book movement"
call assert ledger~availableBalanceMinor("GBP-001")=115000,"hold reduces availability"
call assert ledger~postings~items=before,"hold creates no postings"

/* Commit represents the already-completed physical dispense. */
c=req("ATM-IOM-001-WDM-005","WITHDRAW_COMMIT",sid,5,.directory~new); c["idempotencyKey"]="WDM-BRIDGE-005"
c["data"]["accountId"]="GBP-001"; c["data"]["currency"]="GBP"; c["data"]["amountMinor"]=10000
c["data"]["authorizationId"]=authId; c["data"]["holdId"]=holdId; c["data"]["physicalTransactionId"]="PHYS-BRIDGE-DISP-005"; c["data"]["dispensedMinor"]=10000
x=roundTrip(c,"JMS:WDM:5")
if x["code"]<>"WITHDRAW_COMMITTED" then say "DEBUG COMMIT" .JSON~toJSON(x)
call assert x["code"]="WITHDRAW_COMMITTED","withdraw committed"
call assert ledger~balanceMinor("GBP-001")=115000,"withdraw debit"
postCommit=ledger~postings~items

/* A *new* JMS delivery of the same bank command simulates the classic lost
 * reply case.  Queue Fabric cannot suppress it by transfer id; bank durable
 * idempotency must suppress it by WDM idempotencyKey. */
x=roundTrip(c,"JMS:WDM:5-REDELIVERED-AS-NEW-MESSAGE")
call assert x["code"]="WITHDRAW_COMMITTED","bank replay result stable"
call assert ledger~balanceMinor("GBP-001")=115000,"no duplicate debit"
call assert ledger~postings~items=postCommit,"no duplicate postings"

/* Broker redelivery with the *same* transfer id is suppressed one layer
 * earlier by Queue Fabric.  No second ATM.IN package should appear. */
props=wireProperties(c); headers=wireHeaders(c)
m=.JMSBridgeMessage~new("ID:WDM-DUP","TEXT",.JSON~toJSON(c),headers,props,"TEST","FB.ATM.REQUESTS")
d=.JMSBridgeInboundDelivery~new("jms:fb-atm-test:ID:WDM-DUP",m)
provider~enqueue(d); call jmust bridge~pumpInbound(0),"first transfer-id delivery"
claimed=manager~claim("FB.ATM.BRIDGE.IN","bridge"); call qmust claimed,"claim first transfer-id delivery"
call qmust manager~ack("FB.ATM.BRIDGE.IN",claimed~value~packageId,claimed~value~claimToken,"bridge"),"ack first transfer-id delivery"
provider~enqueue(.JMSBridgeInboundDelivery~new("jms:fb-atm-test:ID:WDM-DUP",m))
call jmust bridge~pumpInbound(0),"duplicate transfer-id delivery"
depth=manager~depth("FB.ATM.BRIDGE.IN","bridge")
call qmust depth,"depth after duplicate"
call assert depth~value["ready"]=0,"Queue Fabric suppresses same JMS transfer id"
call assert bridge~inboundDuplicates>=1,"bridge records duplicate"

/* Deposit: physical cash fact enters the same edge and posts exactly once. */
dep=req("ATM-IOM-001-DPM-006","DEPOSIT_COMMIT",sid,6,.directory~new); dep["idempotencyKey"]="DPM-BRIDGE-006"
dep["data"]["accountId"]="GBP-001"; dep["data"]["currency"]="GBP"; dep["data"]["amountMinor"]=20000; dep["data"]["physicalTransactionId"]="PHYS-BRIDGE-DEP-006"
x=roundTrip(dep,"JMS:DPM:6")
call assert x["code"]="DEPOSIT_COMMITTED","deposit committed"
call assert ledger~balanceMinor("GBP-001")=135000,"deposit balance"
postDeposit=ledger~postings~items
x=roundTrip(dep,"JMS:DPM:6-NEW-DELIVERY")
call assert x["code"]="DEPOSIT_COMMITTED","deposit replay result stable"
call assert ledger~balanceMinor("GBP-001")=135000,"deposit no duplicate credit"
call assert ledger~postings~items=postDeposit,"deposit no duplicate postings"

call jmust bridge~stop,"bridge stop"
say "PASS ATM JMS-shaped Queue Fabric -> FederationBank roundtrip + dual idempotency"
exit 0

roundTrip: procedure expose bridge manager gateway provider lastCorrelation
  use arg request,jmsId
  props=wireProperties(request); headers=wireHeaders(request)
  msg=.JMSBridgeMessage~new(jmsId,"TEXT",.JSON~toJSON(request),headers,props,"TEST","FB.ATM.REQUESTS")
  delivery=.JMSBridgeInboundDelivery~new("jms:fb-atm-test:"||jmsId,msg)
  provider~enqueue(delivery)
  call jmust bridge~pumpInbound(0),"pump inbound "||request["operation"]
  claimed=manager~claim("FB.ATM.BRIDGE.IN","bridge"); call qmust claimed,"claim bridge input"
  package=claimed~value
  processed=gateway~processBridgeMessage(package~payload); call jmust processed,"bank process "||request["operation"]
  call qmust manager~ack("FB.ATM.BRIDGE.IN",package~packageId,package~claimToken,"bridge"),"ack bridge input"
  options=.table~new
  options["persistent"]=.true
  options["correlationId"]=processed~value~headers["JMSCORRELATIONID"]
  call qmust manager~put("FB.ATM.BRIDGE.OUT",processed~value,options,"bridge"),"queue bank response"
  call jmust bridge~pumpOutbound,"pump outbound "||request["operation"]
  sent=provider~lastSentPackage
  if sent==.nil then do; say "FAIL no captured outbound package"; exit 1; end
  outmsg=sent~payload
  lastCorrelation=outmsg~headers["JMSCORRELATIONID"]
  return .JSON~fromJSON(outmsg~body)

wireProperties: procedure
  use arg request
  p=.directory~new
  p["FB_ATM_SCHEMA"]=request["schema"]
  p["FB_ATM_OPERATION"]=request["operation"]
  p["FB_ATM_TERMINAL_ID"]=request["terminalId"]
  p["FB_ATM_RULES_VERSION"]=request["rulesVersion"]
  return p

wireHeaders: procedure
  use arg request
  h=.directory~new
  h["JMSCORRELATIONID"]=request["commandId"]
  h["JMSREPLYTO"]="FB.ATM.REPLIES.ATM-IOM-001"
  return h

openAccount: procedure
  use arg rt,aid,idem
  c=.FederationBankCommand~new("CMD-"||idem,"OPEN_ACCOUNT",idem,"CUST-001","","","GBP",0,"WEB","CUST-001",.nil,"OFFSHORE_CURRENT",aid,"Existing Customer","1980-01-01","SW1A 1AA","GB","GB","GB","RETAIL","STANDARD")
  call qmust rt~submitOpenAccount(c),"submit "||aid; call must rt~processAccountOne,"open "||aid; call must rt~processPaymentsProjectionOne,"payments projection"; call must rt~processLedgerProjectionOne,"ledger projection"; call qmust rt~getAccountResult,"open result"
  return

req: procedure
  use arg commandId,op,session,seq,data
  d=.directory~new
  d["schema"]="federationbank.atm.request/0.1"; d["commandId"]=commandId; d["idempotencyKey"]=commandId; d["operation"]=op
  d["terminalId"]="ATM-IOM-001"; d["terminalSequence"]=seq; d["sessionId"]=session; d["requestedAt"]=.DateTime~new~utcIsoDate
  d["rulesetId"]="FB-ATM-IOM-DEMO"; d["rulesVersion"]=1; d["data"]=data
  return d

must: procedure
  use arg r,label
  if r~ok=.false then do; say "FAIL" label r~code r~detail; exit 1; end
  return
qmust: procedure
  use arg r,label
  if r~ok=.false then do; say "FAIL" label r~code r~detail; exit 1; end
  return
jmust: procedure
  use arg r,label
  if r~ok=.false then do; say "FAIL" label r~code r~detail; exit 1; end
  return
assert: procedure
  use arg condition,label
  if \condition then do; say "FAIL" label; exit 1; end
  return

::requires "FederationBankAtmGateway.cls"
::requires "FederationBankFixtures.cls"
::requires "JMSQueueBridge.cls"
::requires "CaptureJMSProvider.cls"
