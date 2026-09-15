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

r=req("ATM-IOM-001-TSO-301","TERMINAL_SIGN_ON","",301,.directory~new)
r["data"]["softwareVersion"]="0.1.6"; r["data"]["protocolVersion"]="0.1"
x=roundTrip(r,"JMS:V09P:TSO:301"); call assert x["ok"]=.true,"terminal sign-on"

r=req("ATM-IOM-001-LGN-302","LOGON","",302,.directory~new)
r["data"]["cardId"]="4111111111111111"; r["data"]["credentialType"]="DEMO_PIN"; r["data"]["credential"]="1234"
x=roundTrip(r,"JMS:V09P:LGN:302"); call assert x["ok"]=.true,"logon"; sid=x["data"]["sessionId"]

/* Delegated stand-in: actual partial cash may be lower than the authority ceiling. */
stand=req("ATM-IOM-001-OFA-303","GET_OFFLINE_ALLOWANCE",sid,303,.directory~new)
stand["idempotencyKey"]="OFA-PARTIAL-STAND-303"
stand["data"]["accountId"]="GBP-001"; stand["data"]["currency"]="GBP"; stand["data"]["amountMinor"]=10000; stand["data"]["authorityMode"]="DELEGATED_STAND_IN"
x=roundTrip(stand,"JMS:V09P:OFA:303"); call assert x["code"]="OFFLINE_STANDIN_AUTHORITY_ISSUED","stand-in authority issued"
standId=x["data"]["offlineAuthorityId"]

adv=req("ATM-IOM-001-OWA-304","OFFLINE_WITHDRAWAL_ADVICE",sid,304,.directory~new)
adv["idempotencyKey"]="OWA-PARTIAL-STAND-304"
adv["data"]["accountId"]="GBP-001"; adv["data"]["currency"]="GBP"; adv["data"]["amountMinor"]=5000; adv["data"]["requestedAmountMinor"]=10000
adv["data"]["dispensedMinor"]=5000; adv["data"]["offlineAuthorityId"]=standId; adv["data"]["authorityMode"]="DELEGATED_STAND_IN"
adv["data"]["physicalTransactionId"]="PHYS-PARTIAL-STAND-304"; adv["data"]["dispensedAt"]=.DateTime~new~utcIsoDate
x=roundTrip(adv,"JMS:V09P:OWA:304"); call assert x["code"]="OFFLINE_WITHDRAWAL_SETTLED","stand-in partial cash settled"
call assert ledger~balanceMinor("GBP-001")=120000,"stand-in partial settles actual 5000 only"

/* Reserved allowance: v0.9 currently requires hold amount == advice amount. */
call openAccount runtime,"GBP-002","ATM-BRIDGE-PARTIAL-OPEN-2"
call must ledger~postTransfer("ATM-BRIDGE-PARTIAL-SEED-2","FB-SETTLEMENT-GBP","GBP-002",125000,"GBP"),"seed second account"
res=req("ATM-IOM-001-OFA-305","GET_OFFLINE_ALLOWANCE",sid,305,.directory~new)
res["idempotencyKey"]="OFA-PARTIAL-RES-305"
res["data"]["accountId"]="GBP-002"; res["data"]["currency"]="GBP"; res["data"]["amountMinor"]=10000; res["data"]["authorityMode"]="RESERVED_ALLOWANCE"
x=roundTrip(res,"JMS:V09P:OFA:305"); call assert x["code"]="OFFLINE_RESERVED_ALLOWANCE_ISSUED","reserved authority issued"
resId=x["data"]["offlineAuthorityId"]
call assert ledger~availableBalanceMinor("GBP-002")=115000,"reserved hold active before partial advice"

adv2=req("ATM-IOM-001-OWA-306","OFFLINE_WITHDRAWAL_ADVICE",sid,306,.directory~new)
adv2["idempotencyKey"]="OWA-PARTIAL-RES-306"
adv2["data"]["accountId"]="GBP-002"; adv2["data"]["currency"]="GBP"; adv2["data"]["amountMinor"]=5000; adv2["data"]["requestedAmountMinor"]=10000
adv2["data"]["dispensedMinor"]=5000; adv2["data"]["offlineAuthorityId"]=resId; adv2["data"]["authorityMode"]="RESERVED_ALLOWANCE"
adv2["data"]["physicalTransactionId"]="PHYS-PARTIAL-RES-306"; adv2["data"]["dispensedAt"]=.DateTime~new~utcIsoDate
x=roundTrip(adv2,"JMS:V09P:OWA:306")
call assert x["ok"]=.true,"candidate accepts partial reserved hold consumption"
call assert x["code"]="OFFLINE_WITHDRAWAL_SETTLED","partial reserved cash settled"
call assert ledger~balanceMinor("GBP-002")=120000,"partial reserved advice settles actual 5000"
call assert ledger~availableBalanceMinor("GBP-002")=120000,"unused 5000 reservation released with single-use hold"
call assert x["data"]["reservedMinor"]=10000,"settlement reports original reservation"
call assert x["data"]["unusedReservedMinor"]=5000,"settlement reports unused reservation"

/* Physical evidence amount and banking amount must agree. */
call openAccount runtime,"GBP-003","ATM-BRIDGE-PARTIAL-OPEN-3"
call must ledger~postTransfer("ATM-BRIDGE-PARTIAL-SEED-3","FB-SETTLEMENT-GBP","GBP-003",125000,"GBP"),"seed third account"
mis=req("ATM-IOM-001-OFA-307","GET_OFFLINE_ALLOWANCE",sid,307,.directory~new)
mis["idempotencyKey"]="OFA-PARTIAL-MIS-307"; mis["data"]["accountId"]="GBP-003"; mis["data"]["currency"]="GBP"; mis["data"]["amountMinor"]=10000; mis["data"]["authorityMode"]="DELEGATED_STAND_IN"
x=roundTrip(mis,"JMS:V09P:OFA:307"); misId=x["data"]["offlineAuthorityId"]
bad=req("ATM-IOM-001-OWA-308","OFFLINE_WITHDRAWAL_ADVICE",sid,308,.directory~new)
bad["idempotencyKey"]="OWA-PARTIAL-MIS-308"; bad["data"]["accountId"]="GBP-003"; bad["data"]["currency"]="GBP"; bad["data"]["amountMinor"]=5000; bad["data"]["dispensedMinor"]=10000
bad["data"]["offlineAuthorityId"]=misId; bad["data"]["authorityMode"]="DELEGATED_STAND_IN"; bad["data"]["physicalTransactionId"]="PHYS-PARTIAL-MIS-308"; bad["data"]["dispensedAt"]=.DateTime~new~utcIsoDate
x=roundTrip(bad,"JMS:V09P:OWA:308")
call assert x["ok"]=.false,"mismatched physical/banking amount rejected"
call assert x["code"]="ATM_OFFLINE_DISPENSE_AMOUNT_MISMATCH","mismatch has structured code"
call assert ledger~balanceMinor("GBP-003")=125000,"mismatched evidence moves no money"

call jmust bridge~stop,"bridge stop"
say "PASS FederationBank v0.9 partial-reservation candidate: actual cash settles, unused hold released, mismatched evidence rejected"
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
