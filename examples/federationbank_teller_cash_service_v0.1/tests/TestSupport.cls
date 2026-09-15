::class FBTellerCashTestSupport public
::method assertTrue class
  use arg c,m="assertTrue failed"
  if \c then raise syntax 40.900 array(m)
::method assertFalse class
  use arg c,m="assertFalse failed"
  if c then raise syntax 40.900 array(m)
::method assertEq class
  use arg e,a,m="assertEq failed"
  if e~string<>a~string then raise syntax 40.900 array(m||" expected="||e||" actual="||a)
::method pass class
  use arg m
  say "PASS:" m
::method engine class
  return .FederationBankStaffCorePolicyFixtures~engine
::method openCustomerAccount class
  use arg e,accountId="GBP-SRC"
  c=.FederationBankCommand~new("OPEN:"||accountId,"OPEN_ACCOUNT","OPEN:"||accountId,"CUST-001","","","GBP",0,"STAFF","TELLER-04",.nil,"OFFSHORE_CURRENT",accountId,"Existing Customer","1980-01-01","SW1A 1AA","GB","GB","GB","RETAIL","STANDARD")
  r=e~handle(c); if \r~ok then raise syntax 40.900 array("open failed "||r~code||":"||r~detail)
::method seedCustomer class
  use arg e,accountId="GBP-SRC",amount=2000000
  r=e~ledger~postTransfer("SEED:"||accountId||":"||amount,"FB-SETTLEMENT-GBP",accountId,amount,"GBP"); if \r~ok then raise syntax 40.900 array("seed failed "||r~code)
::method principal class
  use arg staffId,branch="DOUGLAS"
  return .FederationBankStaffPrincipalRef~new(staffId,"FB-IAM","IAM:"||staffId,"ACTIVE","FEDERATIONBANK-AUSTRALIA-IOM",branch,"HR:"||staffId)~seal
::method session class
  use arg staffId,sessionId,branch="DOUGLAS",desk="DESK-04"
  return .FederationBankStaffSessionContext~new(sessionId,staffId,branch,desk,"WS:"||desk,"IAM-AUTH:"||sessionId,.DateTime~new-.TimeSpan~new(0,5),.DateTime~new+.TimeSpan~new(1,0),"SEC:"||sessionId)~seal
::method assignment class
  use arg staffId,roleClass,branch="DOUGLAS"
  id="ASSIGN:"||staffId||":"||roleClass
  return .FederationBankStaffRoleAssignment~new(id,staffId,roleClass,roleClass||"_STANDARD",branch,0,.DateTime~new-.TimeSpan~new(0,1),.DateTime~new+.TimeSpan~new(1,0),"FB-IAM","IAM:"||id)~seal
::method context class
  use arg staffId="TELLER-04",role="TELLER",sessionId="S-TEL",branch="DOUGLAS",desk="DESK-04"
  return .FederationBankStaffContextSnapshot~new("CTX:"||staffId,self~principal(staffId,branch),self~session(staffId,sessionId,branch,desk),.array~of(self~assignment(staffId,role,branch)))~seal
::method contexts class
  use arg a,b=.nil
  d=.directory~new; d[a~principal~staffId]=a; if b<>.nil then d[b~principal~staffId]=b; return d
::method custody class
  use arg staffId="TELLER-04",sessionId="S-TEL",tillId="TILL-04",branch="DOUGLAS",desk="DESK-04"
  return .FederationBankTillCustodyContext~new(tillId,branch,staffId,sessionId,"WS:"||desk,"CUSTODY:"||tillId||":"||staffId,.DateTime~new)
::method bundle class
  use arg amountMinor,currency="GBP"
  d=.directory~new
  /* Use one denomination equal to the amount for deterministic test counts. */
  d[amountMinor~string]=1
  return .FederationBankCashBundle~new(currency,d)
::method openTill class
  use arg till,ctx,amount=1000000
  b=self~bundle(amount)
  ap=.FederationBankTillApproval~new("OPEN-AP:"||till~tillId,"OPEN:"||till~tillId,"SUP-01","OPEN:"||till~tillId)
  r=till~open(ctx,b,ap); if \r~ok then raise syntax 40.900 array("till open failed "||r~code)
::method staffService class
  gate=.FederationBankStaffAuthorityGate~new(.FederationBankTellerCashPolicyFixtures~staffCatalog)
  return .FederationBankStaffAuthorityService~new(.FederationBankStaffAuthorityEngine~new(gate))
::method stack class
  use arg engine,till,tillStorePath="",delegateCore=.nil,channelStore=.nil,channelSink=.nil
  staffSvc=self~staffService
  if delegateCore==.nil then delegate=.FederationBankStaffChannelEngineCorePort~new(engine); else delegate=delegateCore
  cashPort=.FederationBankTellerCashDispatchPort~new(delegate)
  tillSvc=.FBTillService~new(till,cashPort~boundCorePort,tillStorePath)
  ignore=cashPort~registerTillService(till~tillId,tillSvc)
  staffPort=.FederationBankStaffChannelStaffAuthorityServicePort~new(staffSvc)
  channelGate=.FederationBankStaffChannelGate~new(.FederationBankTellerCashPolicyFixtures~channelCatalog)
  orch=.FederationBankStaffChannelOrchestrator~new(channelGate,staffPort,cashPort)
  channelSvc=.FederationBankStaffChannelService~new(orch,channelStore,channelSink)
  d=.directory~new; d["staffService"]=staffSvc; d["cashPort"]=cashPort; d["tillService"]=tillSvc; d["channelService"]=channelSvc; return d
::method cashRequest class
  use arg id,direction,amount=10000,staffId="TELLER-04",sessionId="S-TEL",accountId="GBP-SRC",tillId="TILL-04"
  now=.DateTime~new; dir=.FBTellerCashUtil~token(direction)
  details=.directory~new; details["tellerTillId"]=tillId; details["tellerCashDirection"]=dir
  if dir="WITHDRAWAL" then do; op="CASH_WITHDRAWAL"; source=accountId; target=""; end
  else do; op="CASH_DEPOSIT"; source=""; target=accountId; end
  c=.FederationBankCommand~new("CASHCMD:"||id,op,"CASHIDEM:"||id,"CUST-001",source,target,"GBP",amount,"STAFF",staffId,now,"","","","","","","","","RETAIL","STANDARD",details)
  snap=.FederationBankStaffChannelCommandSnapshot~fromCommand(c)
  return .FederationBankStaffChannelRequest~new("CASHREQ:"||id,"STAFFWORK:"||id,"CUSTOMER_INSTRUCTION",staffId,sessionId,"DOUGLAS","DESK-04",snap,.nil,now)~seal
::method instruction class
  use arg id,request,direction,amount=10000,tillId="TILL-04",ctx=.nil,settlement="FB-SETTLEMENT-GBP",approval=.nil
  if ctx==.nil then ctx=self~custody(request~staffId,request~sessionId,tillId)
  return .FederationBankTellerCashInstruction~new("CASHWORK:"||id,request~command~commandId,direction,tillId,settlement,self~bundle(amount),ctx,approval)
::method envelope class
  use arg id,request,instruction,contexts,approvals=.nil
  p=.directory~new; p["request"]=request; p["instruction"]=instruction; p["contexts"]=contexts; if approvals<>.nil then p["approvals"]=approvals
  return .FederationBankTellerCashServiceEnvelope~new("TELCASH:"||id,"FBTELCASH.ACTION.SUBMIT",request~staffId,"STAFF",p)

::requires "FederationBankTellerCashService.cls"
::requires "FederationBankTellerCashPolicyFixtures.cls"
::requires "FederationBankStaffChannelStaffAuthorityServicePort.cls"
::requires "FederationBankStaffCorePolicyFixtures.cls"

/* Additional acceptance helpers for dual-control, recovery and exact binding. */
::class FBTellerCashTestExtensions public
::method staffAction class
  use arg request
  c=request~command
  return .FederationBankStaffActionIntent~new("ACT:"||request~workId,c~commandId,c~idempotencyKey,request~staffId,request~sessionId,c~operation,c~customerId,c~sourceAccountId,c~targetAccountId,c~currency,c~amountMinor,request~branchId,request~deskId,"",c~requestedAt,c~details)~seal
::method staffApproval class
  use arg request,approverId="SUP-01",approverSession="S-SUP"
  action=self~staffAction(request)
  return .FederationBankStaffApproval~new("STAFFAP:"||request~workId,action,approverId,approverSession,"SUPERVISOR","EVIDENCE:"||request~workId)~seal
::method tillAction class
  use arg instruction,request
  c=request~command; accountId=c~sourceAccountId; if instruction~direction="DEPOSIT" then accountId=c~targetAccountId
  return .FederationBankTillAction~new("TILLACT:"||instruction~cashWorkId,instruction~tillOperation,c~amountMinor,c~currency,c~actorId,c~customerId,accountId,"CORE:"||c~commandId,c~requestedAt)
::method tillApproval class
  use arg instruction,request,approverId="SUP-01"
  action=self~tillAction(instruction,request)
  return .FederationBankTillApproval~new("TILLAP:"||instruction~cashWorkId,action~actionId,approverId,action~semanticIdentity)
::method supervisorContext class
  return .FBTellerCashTestSupport~context("SUP-01","SUPERVISOR","S-SUP","DOUGLAS","DESK-SUP")
::method resumeEnvelope class
  use arg id,workId,contexts,approvals
  p=.directory~new; p["workId"]=workId; p["contexts"]=contexts; p["approvals"]=approvals
  return .FederationBankTellerCashServiceEnvelope~new("TELCASH:"||id,"FBTELCASH.ACTION.RESUME","SUP-01","STAFF",p)
::method recoverEnvelope class
  use arg id,workId
  p=.directory~new; p["workId"]=workId
  return .FederationBankTellerCashServiceEnvelope~new("TELCASH:"||id,"FBTELCASH.ACTION.RECOVER","TELLER-04","STAFF",p)
::method getEnvelope class
  use arg id,workId
  p=.directory~new; p["workId"]=workId
  return .FederationBankTellerCashServiceEnvelope~new("TELCASH:"||id,"FBTELCASH.ACTION.GET","TELLER-04","STAFF",p)

::class FBTellerCashFailOnceCorePort subclass FederationBankStaffChannelCorePort public
::method init
  expose delegate failFlag calls
  use arg delegateArg
  delegate=delegateArg; failFlag=.true; calls=0
::method calls
  expose calls
  return calls
::method submit
  expose delegate failFlag calls
  use arg route,command
  calls+=1
  if failFlag then do; failFlag=.false; return .FederationBankStaffChannelResult~failure("CORE_PORT_UNAVAILABLE","simulated Core transport outage"); end
  return delegate~submit(route,command)
