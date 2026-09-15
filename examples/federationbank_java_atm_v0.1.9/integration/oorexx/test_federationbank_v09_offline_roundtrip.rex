/* FederationBank v0.9 offline ATM authority through JMS-shaped Queue Fabric.
 *
 * The physical dispense itself occurs while disconnected and therefore cannot
 * traverse JMS. This test proves the surrounding bank-owned authority facts:
 *   online GET_OFFLINE_ALLOWANCE -> retained Ledger-backed authority
 *   disconnected physical cash (represented only by later evidence)
 *   reconnect OFFLINE_WITHDRAWAL_ADVICE -> one monetary settlement
 *   replay/new advice protection.
 */
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
call openAccount runtime,"GBP-001","ATM-BRIDGE-OFFLINE-OPEN-1"
call must ledger~postTransfer("ATM-BRIDGE-OFFLINE-SEED","FB-SETTLEMENT-GBP","GBP-001",125000,"GBP"),"seed"

call qmust manager~createQueue("FB.ATM.BRIDGE.IN","TEMPORARY","ATM",0,"bridge"),"create bridge in"
call qmust manager~createQueue("FB.ATM.BRIDGE.OUT","TEMPORARY","ATM",0,"bridge"),"create bridge out"
config=.JMSBridgeConfig~new("fb-atm-v09-test","GENERIC","","","FB.ATM.REQUESTS","FB.ATM.REPLIES.ATM-IOM-001","","","","FB.ATM.BRIDGE.IN","FB.ATM.BRIDGE.OUT","bridge",.true,0,"REJECT","","CLIENT_ACKNOWLEDGE","ADMINISTERED")
provider=.CaptureJMSProvider~new("CLIENT_ACKNOWLEDGE")
bridge=.JMSQueueBridgeService~new(manager,provider,config)
call jmust bridge~start,"bridge start"

r=req("ATM-IOM-001-TSO-101","TERMINAL_SIGN_ON","",101,.directory~new)
r["data"]["softwareVersion"]="0.1.6"; r["data"]["protocolVersion"]="0.1"
x=roundTrip(r,"JMS:V09:TSO:101")
call assert x["ok"]=.true,"terminal sign-on"

r=req("ATM-IOM-001-LGN-102","LOGON","",102,.directory~new)
r["data"]["cardId"]="4111111111111111"; r["data"]["credentialType"]="DEMO_PIN"; r["data"]["credential"]="1234"
x=roundTrip(r,"JMS:V09:LGN:102")
call assert x["ok"]=.true,"logon"
sid=x["data"]["sessionId"]

allow=req("ATM-IOM-001-OFA-103","GET_OFFLINE_ALLOWANCE",sid,103,.directory~new)
allow["idempotencyKey"]="OFA-BRIDGE-103"
allow["data"]["accountId"]="GBP-001"; allow["data"]["currency"]="GBP"; allow["data"]["amountMinor"]=10000; allow["data"]["authorityMode"]="RESERVED_ALLOWANCE"
beforePostings=ledger~postings~items
x=roundTrip(allow,"JMS:V09:OFA:103")
call assert x["code"]="OFFLINE_RESERVED_ALLOWANCE_ISSUED","reserved allowance issued"
authorityId=x["data"]["offlineAuthorityId"]
call assert x["data"]["terminalId"]="ATM-IOM-001","authority terminal bound"
call assert x["data"]["accountId"]="GBP-001","authority account bound"
call assert ledger~balanceMinor("GBP-001")=125000,"authority does not move book balance"
call assert ledger~availableBalanceMinor("GBP-001")=115000,"authority hold reduces available balance"
call assert ledger~postings~items=beforePostings,"hold creates no postings"

/* No message is sent during disconnected physical dispense.  The next message
 * is the retained physical fact after connectivity returns. */
advice=req("ATM-IOM-001-OWA-104","OFFLINE_WITHDRAWAL_ADVICE",sid,104,.directory~new)
advice["idempotencyKey"]="OWA-BRIDGE-104"
advice["data"]["accountId"]="GBP-001"; advice["data"]["currency"]="GBP"; advice["data"]["amountMinor"]=10000
advice["data"]["dispensedMinor"]=10000; advice["data"]["offlineAuthorityId"]=authorityId; advice["data"]["authorityMode"]="RESERVED_ALLOWANCE"
advice["data"]["physicalTransactionId"]="PHYS-OFFLINE-BRIDGE-104"; advice["data"]["dispensedAt"]=.DateTime~new~utcIsoDate
x=roundTrip(advice,"JMS:V09:OWA:104")
call assert x["code"]="OFFLINE_WITHDRAWAL_SETTLED","offline cash settled"
call assert ledger~balanceMinor("GBP-001")=115000,"physical offline cash debited once"
call assert ledger~availableBalanceMinor("GBP-001")=115000,"reservation consumed"
postAdvice=ledger~postings~items

/* Lost reply / new JMS delivery with the same business idempotency is harmless. */
x=roundTrip(advice,"JMS:V09:OWA:104-NEW-DELIVERY")
call assert x["code"]="OFFLINE_WITHDRAWAL_SETTLED","offline advice replay stable"
call assert ledger~balanceMinor("GBP-001")=115000,"offline advice replay no duplicate debit"
call assert ledger~postings~items=postAdvice,"offline advice replay no duplicate postings"

/* The authority cannot be repurposed for a new physical fact/idempotency key. */
again=req("ATM-IOM-001-OWA-105","OFFLINE_WITHDRAWAL_ADVICE",sid,105,.directory~new)
again["idempotencyKey"]="OWA-BRIDGE-105"
again["data"]["accountId"]="GBP-001"; again["data"]["currency"]="GBP"; again["data"]["amountMinor"]=10000
again["data"]["dispensedMinor"]=10000; again["data"]["offlineAuthorityId"]=authorityId; again["data"]["authorityMode"]="RESERVED_ALLOWANCE"
again["data"]["physicalTransactionId"]="PHYS-OFFLINE-BRIDGE-105"; again["data"]["dispensedAt"]=.DateTime~new~utcIsoDate
x=roundTrip(again,"JMS:V09:OWA:105")
call assert x["ok"]=.false,"second physical fact refused"
call assert x["code"]="ATM_OFFLINE_AUTHORITY_ALREADY_CONSUMED","single-use authority protected"
call assert ledger~balanceMinor("GBP-001")=115000,"refused reuse moves no money"

call jmust bridge~stop,"bridge stop"
say "PASS FederationBank v0.9 JMS-shaped reserved offline authority -> physical advice -> single settlement"
exit 0

roundTrip: procedure expose bridge manager gateway provider
  use arg request,jmsId
  props=wireProperties(request); headers=wireHeaders(request)
  msg=.JMSBridgeMessage~new(jmsId,"TEXT",.JSON~toJSON(request),headers,props,"TEST","FB.ATM.REQUESTS")
  delivery=.JMSBridgeInboundDelivery~new("jms:fb-atm-v09-test:"||jmsId,msg)
  provider~enqueue(delivery)
  call jmust bridge~pumpInbound(0),"pump inbound "||request["operation"]
  claimed=manager~claim("FB.ATM.BRIDGE.IN","bridge"); call qmust claimed,"claim bridge input"
  package=claimed~value
  processed=gateway~processBridgeMessage(package~payload); call jmust processed,"bank process "||request["operation"]
  call qmust manager~ack("FB.ATM.BRIDGE.IN",package~packageId,package~claimToken,"bridge"),"ack bridge input"
  options=.table~new; options["persistent"]=.true; options["correlationId"]=processed~value~headers["JMSCORRELATIONID"]
  call qmust manager~put("FB.ATM.BRIDGE.OUT",processed~value,options,"bridge"),"queue bank response"
  call jmust bridge~pumpOutbound,"pump outbound "||request["operation"]
  sent=provider~lastSentPackage
  if sent==.nil then do; say "FAIL no captured outbound package"; exit 1; end
  return .JSON~fromJSON(sent~payload~body)

wireProperties: procedure
  use arg request
  p=.directory~new; p["FB_ATM_SCHEMA"]=request["schema"]; p["FB_ATM_OPERATION"]=request["operation"]; p["FB_ATM_TERMINAL_ID"]=request["terminalId"]; p["FB_ATM_RULES_VERSION"]=request["rulesVersion"]
  return p
wireHeaders: procedure
  use arg request
  h=.directory~new; h["JMSCORRELATIONID"]=request["commandId"]; h["JMSREPLYTO"]="FB.ATM.REPLIES.ATM-IOM-001"
  return h
openAccount: procedure
  use arg rt,aid,idem
  c=.FederationBankCommand~new("CMD-"||idem,"OPEN_ACCOUNT",idem,"CUST-001","","","GBP",0,"WEB","CUST-001",.nil,"OFFSHORE_CURRENT",aid,"Existing Customer","1980-01-01","SW1A 1AA","GB","GB","GB","RETAIL","STANDARD")
  call qmust rt~submitOpenAccount(c),"submit "||aid; call must rt~processAccountOne,"open "||aid; call must rt~processPaymentsProjectionOne,"payments projection"; call must rt~processLedgerProjectionOne,"ledger projection"; call qmust rt~getAccountResult,"open result"
  return
req: procedure
  use arg commandId,op,session,seq,data
  d=.directory~new; d["schema"]="federationbank.atm.request/0.1"; d["commandId"]=commandId; d["idempotencyKey"]=commandId; d["operation"]=op
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
