::class FBStaffChannelServiceTestSupport public
::method assertTrue class
  use arg condition,message="assertTrue failed"
  if \condition then raise syntax 98.920 array(message)
::method assertFalse class
  use arg condition,message="assertFalse failed"
  if condition then raise syntax 98.921 array(message)
::method assertEq class
  use arg expected,actual,message="assertEq failed"
  if expected~string\=actual~string then raise syntax 98.922 array(message||" expected="||expected||" actual="||actual)
::method pass class
  use arg message
  say "PASS:" message
::method staffEngine class
  return .FederationBankStaffAuthorityEngine~new(.FederationBankStaffAuthorityGate~new(.FederationBankStaffAuthorityPolicyFixtures~publishedCatalog))
::method staffService class
  return .FederationBankStaffAuthorityService~new(self~staffEngine)
::method orchestrator class
  use arg coreEngine,staffService=.nil,corePort=.nil
  if staffService==.nil then staffService=self~staffService
  if corePort==.nil then corePort=.FederationBankStaffChannelEngineCorePort~new(coreEngine)
  gate=.FederationBankStaffChannelGate~new(.FederationBankStaffChannelPolicyFixtures~publishedCatalog)
  staffPort=.FederationBankStaffChannelStaffAuthorityServicePort~new(staffService)
  return .FederationBankStaffChannelOrchestrator~new(gate,staffPort,corePort)
::method service class
  use arg coreEngine,store=.nil,sink=.nil,staffService=.nil,corePort=.nil
  return .FederationBankStaffChannelService~new(self~orchestrator(coreEngine,staffService,corePort),store,sink)
::method principal class
  use arg staffId,branch="DOUGLAS"
  return .FederationBankStaffPrincipalRef~new(staffId,"FB-IAM","IAM:"||staffId,"ACTIVE","FEDERATIONBANK-AUSTRALIA-IOM",branch,"HR:"||staffId)~seal
::method session class
  use arg staffId,sessionId,branch="DOUGLAS",desk="DESK-04"
  start=.DateTime~new-.TimeSpan~new(0,5); expires=.DateTime~new+.TimeSpan~new(1,0)
  return .FederationBankStaffSessionContext~new(sessionId,staffId,branch,desk,"WS:"||desk,"IAM-AUTH:"||sessionId,start,expires,"SEC:"||sessionId)~seal
::method assignment class
  use arg staffId,roleClass,branch="DOUGLAS"
  id="ASSIGN:"||staffId||":"||roleClass
  return .FederationBankStaffRoleAssignment~new(id,staffId,roleClass,roleClass||"_STANDARD",branch,0,.DateTime~new-.TimeSpan~new(0,1),.DateTime~new+.TimeSpan~new(1,0),"FB-IAM","IAM:"||id)~seal
::method context class
  use arg staffId,roleClass,sessionId,branch="DOUGLAS",desk="DESK-04"
  return .FederationBankStaffContextSnapshot~new("CTX:"||staffId,self~principal(staffId,branch),self~session(staffId,sessionId,branch,desk),.array~of(self~assignment(staffId,roleClass,branch)))~seal
::method contexts class
  use arg first,second=.nil,third=.nil
  d=.directory~new
  if first<>.nil then d[first~principal~staffId]=first
  if second<>.nil then d[second~principal~staffId]=second
  if third<>.nil then d[third~principal~staffId]=third
  return d
::method request class
  use arg id,staffId="TELLER-04",sessionId="S-TEL",amountMinor=250000
  now=.DateTime~new
  c=.FederationBankCommand~new("CMD:"||id,"TRANSFER","IDEM:"||id,"CUST-001","GBP-SRC","GBP-DST","GBP",amountMinor,"STAFF",staffId,now)
  snap=.FederationBankStaffChannelCommandSnapshot~fromCommand(c)
  return .FederationBankStaffChannelRequest~new("REQ:"||id,"WORK:"||id,"CUSTOMER_INSTRUCTION",staffId,sessionId,"DOUGLAS","DESK-04",snap,.nil,now)~seal
::method submitEnvelope class
  use arg id,request,contexts,approvals=.nil
  p=.directory~new; p["request"]=request; p["contexts"]=contexts; if approvals<>.nil then p["approvals"]=approvals
  return .FederationBankStaffChannelServiceEnvelope~new(id,"FBSTAFFCH.ACTION.SUBMIT",request~staffId,"STAFF",p)
::method resumeEnvelope class
  use arg id,workId,contexts,approvals
  p=.directory~new; p["workId"]=workId; p["contexts"]=contexts; p["approvals"]=approvals
  return .FederationBankStaffChannelServiceEnvelope~new(id,"FBSTAFFCH.ACTION.RESUME","supervisor","STAFF",p)
::method openAccounts class
  use arg engine,actor="TELLER-04"
  call openOne engine,"GBP-SRC","OPEN-SRC",actor
  call openOne engine,"GBP-DST","OPEN-DST",actor
  return
openOne: procedure
  use arg e,accountId,idem,actor
  c=.FederationBankCommand~new("CMD-"||idem,"OPEN_ACCOUNT",idem,"CUST-001","","","GBP",0,"STAFF",actor,.nil,"OFFSHORE_CURRENT",accountId,"Existing Customer","1980-01-01","SW1A 1AA","GB","GB","GB","RETAIL","STANDARD")
  r=e~handle(c); if \r~ok then raise syntax 98.923 array("open failed "||r~code||":"||r~detail)
  return
::method seed class
  use arg engine,amount=5000000
  r=engine~ledger~postTransfer("SEED:"||amount,"FB-SETTLEMENT-GBP","GBP-SRC",amount,"GBP")
  if \r~ok then raise syntax 98.924 array("seed failed")
  return r

::class FBStaffChannelFailOnceCorePort subclass FederationBankStaffChannelCorePort public
::method init
  expose delegate failFlag
  use arg delegateArg
  delegate=delegateArg; failFlag=.true
::method submit
  expose delegate failFlag
  use arg route,command
  if failFlag then do; failFlag=.false; return .FederationBankStaffChannelResult~failure("CORE_PORT_UNAVAILABLE","simulated transport outage"); end
  return delegate~submit(route,command)

::requires "FederationBankStaffChannelStaffAuthorityServicePort.cls"
::requires "FederationBankStaffChannelPolicyFixtures.cls"
::requires "FederationBankStaffAuthorityPolicyFixtures.cls"
::requires "FederationBankStaffCorePolicyFixtures.cls"
::requires "FederationBankStaffChannelService.cls"
