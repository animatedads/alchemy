::class FBStaffWireTestSupport public
::method assertTrue class
  use arg value,label="assertTrue failed"
  if \value then raise syntax 98.900 array(label)
::method assertFalse class
  use arg value,label="assertFalse failed"
  if value then raise syntax 98.900 array(label)
::method assertEq class
  use arg expected,actual,label="assertEq failed"
  if expected~string<>actual~string then raise syntax 98.900 array(label||" expected="||expected||" actual="||actual)
::method ok class
  use arg result
  if \result~ok then raise syntax 98.900 array(result~code,result~detail)
  return result~value

::class FBStaffWireFakeState public
::method init
  expose works
  works=.directory~new
::method works
  expose works
  d=.directory~new; do k over works; d[k]=works[k]; end; return d
::method work
  expose works
  use arg id
  if works~hasIndex(id) then return works[id]
  return .nil
::method putWork
  expose works
  use arg work
  works[work~workId]=work; return work

::class FBStaffWireFakeService public
::attribute lastEnvelope get
::method init
  expose state lastEnvelope
  state=.FBStaffWireFakeState~new; lastEnvelope=.nil
::method state
  expose state
  return state
::method seedWork
  expose state
  use arg id,stateName="COMPLETED",amount=250000,staffId="TELLER-04",sessionId="S-TEL",branch="DOUGLAS",desk="DESK-04"
  now=.DateTime~new
  cmd=.FederationBankCommand~new("CMD:"||id,"TRANSFER","IDEM:"||id,"CUST-001","GBP-SRC","GBP-DST","GBP",amount,"STAFF",staffId,now)
  snap=.FederationBankStaffChannelCommandSnapshot~fromCommand(cmd)
  req=.FederationBankStaffChannelRequest~new("REQ:"||id,"WORK:"||id,"CUSTOMER_INSTRUCTION",staffId,sessionId,branch,desk,snap,.nil,now)~seal
  w=.FederationBankStaffChannelWorkItem~new(req)
  select
    when stateName="APPROVAL_REQUIRED" then w~approvalRequired(.nil,"checker required")
    when stateName="READY_FOR_CORE" then w~readyForCore(snap)
    when stateName="COMPLETED" then w~completeCore(.true,"CORE_OK")
    when stateName="CORE_REJECTED" then w~completeCore(.false,"CORE_DENIED","fixture")
    when stateName="REJECTED" then w~reject("STAFF_DENIED","fixture")
    when stateName="NO_BANK_ACTION" then w~noBankAction("fixture no action")
    otherwise nop
  end
  state~putWork(w); return w
::method handle
  expose state lastEnvelope
  use arg env
  lastEnvelope=env
  req=env~payload["request"]
  w=.FederationBankStaffChannelWorkItem~new(req)
  state~putWork(w)
  return .FederationBankStaffChannelServiceReply~new(env~commandId,env~correlationId,.true,"RECEIVED","",w~workId,w)

::class FBStaffWireAllowPermissionPort subclass FederationBankStaffWireMethodPermissionPort public
::method init
  expose staffId sessionId calls lastPayload
  use arg staffIdArg="TELLER-04",sessionIdArg="S-TEL"
  staffId=staffIdArg; sessionId=sessionIdArg; calls=0; lastPayload=""
::method admit
  expose staffId sessionId calls lastPayload
  use arg payload
  calls+=1; lastPayload=payload
  a=.FederationBankStaffMethodPermissionAdmission~new("ADM:"||calls,"FB-STAFF-WIRE-ACTION","STAFF_BANKING",staffId,sessionId,"PRINCIPAL:"||staffId,"OBJECT:WIRE-INGRESS","ADMIT",payload,"PERM-DECISION","PERM-POLICY","SEC-POLICY","SEC-TRACE","HMAC-SHA256","wire-test-key","deadbeef")~seal
  return .FederationBankStaffWireResult~success(a,"METHOD_PERMISSION_ADMITTED")
::method calls
  expose calls
  return calls
::method lastPayload
  expose lastPayload
  return lastPayload

::class FBStaffWireDenyPermissionPort subclass FederationBankStaffWireMethodPermissionPort public
::method admit
  use arg payload
  return .FederationBankStaffWireResult~failure("METHOD_PERMISSION_DENIED","fixture deny")

::class FBStaffWireRealPermissionFixture public
::method build class
  use arg staffId="TELLER-04",principalId="PRINCIPAL:TELLER-04",sessionId="S-TEL",endpointId="FB-STAFF-WIRE-ACTION"
  now=.DateTime~new
  session=.FederationBankStaffSessionContext~new(sessionId,staffId,"DOUGLAS","DESK-04","WS-DESK-04","AUTHN:WIRE",now-.TimeSpan~new(0,0,0,0,1),now+.TimeSpan~new(0,0,0,1,0),"SECURITY:WIRE")~seal
  binding=.FederationBankStaffPermissionPrincipalBinding~new("BIND:WIRE",staffId,principalId,"IAM","IAM-PAIR:WIRE",now-.TimeSpan~new(0,0,0,0,1),now+.TimeSpan~new(0,0,0,1,0))~seal
  principal=.AccessPrincipal~new(principalId,"staff-wire-proof")~seal
  snapshot=.SecuritySnapshot~new("SNAP:WIRE",principalId,now)~seal
  framework=.SecurityPolicyFramework~new("FB-STAFF-WIRE-SECURITY","1",now-.TimeSpan~new(0,0,0,0,1),.nil,"FederationBank Security","FederationBank Risk")~seal
  ingress=.FederationBankStaffMethodPermissionIngress~new(endpointId,"STAFF_BANKING")
  policy=.FederationBankStaffMethodPermissionPolicyFactory~exactIngressPolicy("FB-STAFF-WIRE-METHOD-PERMISSION","1",principalId,ingress,framework)
  ring=.CryptoMacKeyRing~new; ring~addKey("staff-wire-proof","00112233445566778899aabbccddeeff")
  signer=.AccessPermissionsSigner~new(ring,"staff-wire-proof")
  authority=.PermissionAuthority~new(signer)
  resolver=.FederationBankStaffMethodSecurityEffectResolver~new(binding,session,snapshot,framework)
  boundary=.FederationBankStaffMethodPermissionBoundary~new(binding,session,principal,policy,authority,resolver,ring,.AlchemySecurityRuntimeProfile~observedR13196)
  d=.directory~new; d["session"]=session; d["ingress"]=ingress; d["boundary"]=boundary; return d

::class FBStaffWireTestFixtures public
::method catalogue class
  return .FBStaffWireTestSupport~ok(.FederationBankStaffWireRuntimeFactory~compileCatalogue)
::method app class
  use arg service,permission=.nil,staffId="TELLER-04",channelSessionId="S-TEL",branch="DOUGLAS",desk="DESK-04",catalogue=.nil
  if permission==.nil then permission=.FBStaffWireAllowPermissionPort~new(staffId,channelSessionId)
  contexts=.directory~new
  actionPort=.FederationBankStaffWireChannelActionPort~new(service,contexts,staffId,channelSessionId,branch,desk)
  readModel=.FederationBankStaffWireReadModel~new(service)
  if catalogue==.nil then r=.FederationBankStaffWireRuntimeFactory~build("FB-STAFF-APP","WIRE-S1","WEB-1",readModel,permission,actionPort,staffId,channelSessionId,branch,desk,"ACCESS:STAFF-BANKING:1")
  else r=.FederationBankStaffWireRuntimeFactory~buildFromCatalogue("FB-STAFF-APP","WIRE-S1","WEB-1",readModel,permission,actionPort,staffId,channelSessionId,branch,desk,"ACCESS:STAFF-BANKING:1",catalogue)
  return .FBStaffWireTestSupport~ok(r)
::method action class
  use arg app,instance,semantic,detail=.nil,context=.nil,messageId="MSG-1"
  if detail==.nil then detail=.directory~new
  if context<>.nil then detail["workspaceContext"]=context
  m=.directory~new; m["type"]="UI_ACTION"; m["applicationId"]="FB-STAFF-APP"; m["sessionId"]="WIRE-S1"; m["accessPointId"]="WEB-1"; m["viewRef"]=app~view~viewRef; m["renderedRevision"]=app~view~revision; m["elementInstance"]=instance; m["action"]=semantic; m["detail"]=detail; m["messageId"]=messageId
  return m
::method selectWork class
  use arg app,workId,messageId="MSG-SELECT"
  d=.directory~new; d["selectedIds"]=.array~of(workId); d["scopeRevision"]=app~workspaceQuery("FB.STAFF.WORK")~scopeRevision
  return app~receive(self~action(app,"work-query","WORK.SELECT",d,.nil,messageId))
::method transferDetail class
  use arg amount=125000
  d=.directory~new; d["customerId"]="CUST-001"; d["sourceAccountId"]="GBP-SRC"; d["targetAccountId"]="GBP-DST"; d["currency"]="GBP"; d["amountMinor"]=amount
  return d

::requires "FederationBankStaffWireUIApplication.cls"
