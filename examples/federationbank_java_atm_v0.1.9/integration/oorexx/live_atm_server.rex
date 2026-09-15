/* FederationBank live ATM server qualification harness.
 * Real BSF4ooRexx + ActiveMQ edge, real Queue Fabric, real FederationBank v0.8
 * ATM Gateway/Payments/Ledger. The only test fixture is the seeded customer account. */
signal on syntax name failed
parse arg brokerUrl maxRequests idleLimit
if brokerUrl = "" then brokerUrl = "tcp://127.0.0.1:61626"
if maxRequests = "" then maxRequests = 20
if idleLimit = "" then idleLimit = 12
root = value("FB_TEST_QUEUE_ROOT",,"ENVIRONMENT")
if root = "" then do; say "FAIL FB_TEST_QUEUE_ROOT required"; exit 2; end

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
call openAccount runtime,"GBP-001","ATM-LIVE-OPEN-1"
call must ledger~postTransfer("ATM-LIVE-SEED","FB-SETTLEMENT-GBP","GBP-001",125000,"GBP"),"seed"

call qmust manager~createQueue("FB.ATM.LIVE.IN","TEMPORARY","ATM",0,"bridge"),"create live in"
call qmust manager~createQueue("FB.ATM.LIVE.OUT","TEMPORARY","ATM",0,"bridge"),"create live out"
config=.JMSBridgeConfig~new("fb-atm-live","GENERIC",brokerUrl,"ConnectionFactory", -
  "dynamicQueues/FB.ATM.REQUESTS","dynamicQueues/FB.ATM.REPLIES.ATM-IOM-001","","","", -
  "FB.ATM.LIVE.IN","FB.ATM.LIVE.OUT","bridge",.true,1000,"REJECT", -
  "org.apache.activemq.jndi.ActiveMQInitialContextFactory","CLIENT_ACKNOWLEDGE","ADMINISTERED")
provider=.JMSBSFProvider~new(config,.nil)
bridge=.JMSQueueBridgeService~new(manager,provider,config)
call jmust bridge~start,"bridge start"
say "FB LIVE ATM SERVER READY" brokerUrl
call lineout value("FB_LIVE_READY_FILE",,"ENVIRONMENT"), "READY"

handled=0; idle=0
do while handled < maxRequests & idle < idleLimit
  incoming=bridge~pumpInbound(1000)
  if \incoming~ok then do
    say "FAIL inbound" incoming~code incoming~detail
    leave
  end
  if incoming~value == .nil then do
    idle += 1
    iterate
  end
  idle=0
  claimed=manager~claim("FB.ATM.LIVE.IN","bridge")
  call qmust claimed,"claim live input"
  package=claimed~value
  processed=gateway~processBridgeMessage(package~payload)
  if \processed~ok then do
    say "FAIL bank process" processed~code processed~detail
    leave
  end
  call qmust manager~ack("FB.ATM.LIVE.IN",package~packageId,package~claimToken,"bridge"),"ack live input"
  options=.table~new
  options["persistent"]=.true
  options["correlationId"]=processed~value~headers["JMSCORRELATIONID"]
  call qmust manager~put("FB.ATM.LIVE.OUT",processed~value,options,"bridge"),"queue live response"
  sent=bridge~pumpOutbound
  call jmust sent,"live outbound"
  handled += 1
  say "HANDLED" handled package~payload~properties["FB_ATM_OPERATION"] package~correlationId
end

call jmust bridge~stop,"bridge stop"
say "FB LIVE ATM SERVER STOP handled="handled "book="ledger~balanceMinor("GBP-001") "available="ledger~availableBalanceMinor("GBP-001")
exit 0

openAccount: procedure
  use arg rt,aid,idem
  c=.FederationBankCommand~new("CMD-"||idem,"OPEN_ACCOUNT",idem,"CUST-001","","","GBP",0,"WEB","CUST-001",.nil,"OFFSHORE_CURRENT",aid,"Existing Customer","1980-01-01","SW1A 1AA","GB","GB","GB","RETAIL","STANDARD")
  call qmust rt~submitOpenAccount(c),"submit "||aid; call must rt~processAccountOne,"open "||aid; call must rt~processPaymentsProjectionOne,"payments projection"; call must rt~processLedgerProjectionOne,"ledger projection"; call qmust rt~getAccountResult,"open result"
  return
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
failed:
  say "FAIL syntax:" condition("D")
  if .BSF_ERROR_MESSAGE \== .nil then say .BSF_ERROR_MESSAGE
  exit 1

::requires "FederationBankAtmGateway.cls"
::requires "FederationBankFixtures.cls"
::requires "JMSQueueBridgeBSF.cls"
