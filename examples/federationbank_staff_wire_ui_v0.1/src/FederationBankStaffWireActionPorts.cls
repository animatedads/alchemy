/* Mutation ports for FederationBank Staff Wire UI v0.1. */
::class FederationBankStaffWireResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get
::method init
  expose ok code detail value
  use arg okArg,codeArg,detailArg="",valueArg=.nil
  ok=okArg; code=codeArg~string~upper; detail=detailArg~string; value=valueArg
::method success class
  use arg value=.nil,code="OK",detail=""
  return self~new(.true,code,detail,value)
::method failure class
  use arg code,detail="",value=.nil
  return self~new(.false,code,detail,value)

::class FederationBankStaffWireMethodPermissionPort public
::method admit abstract

::class FederationBankStaffWireMethodPermissionBoundaryPort subclass FederationBankStaffWireMethodPermissionPort public
::method init
  expose boundary ingress agentPath
  use strict arg boundaryArg,ingressArg,agentPathArg
  boundary=boundaryArg; ingress=ingressArg; agentPath=agentPathArg~string
  if boundary==.nil | ingress==.nil | agentPath="" then raise syntax 88.994 array("Staff Wire method permission boundary configuration required")
::method admit
  expose boundary ingress agentPath
  use strict arg payloadIdentity
  r=boundary~admit(ingress,payloadIdentity,agentPath)
  if \r~ok then return .FederationBankStaffWireResult~failure(r~code,r~detail,r~value)
  return .FederationBankStaffWireResult~success(r~value,"METHOD_PERMISSION_ADMITTED")

::class FederationBankStaffWireActionPort public
::method submitTransfer abstract

::class FederationBankStaffWireChannelActionPort subclass FederationBankStaffWireActionPort public
::method init
  expose service contexts staffId channelSessionId branchId deskId
  use strict arg serviceArg,contextsArg,staffIdArg,channelSessionIdArg,branchIdArg,deskIdArg
  if serviceArg==.nil | contextsArg==.nil then raise syntax 88.994 array("Staff Channel service and contexts required")
  service=serviceArg; contexts=contextsArg; staffId=staffIdArg~string; channelSessionId=channelSessionIdArg~string; branchId=branchIdArg~string~upper; deskId=deskIdArg~string~upper
  if staffId="" | channelSessionId="" | branchId="" | deskId="" then raise syntax 88.994 array("Staff Wire server-owned context required")
::method submitTransfer
  expose service contexts staffId channelSessionId branchId deskId
  use strict arg requestId,detail,admission
  if admission==.nil | \admission~isA(.FederationBankStaffMethodPermissionAdmission) then return .FederationBankStaffWireResult~failure("METHOD_PERMISSION_ADMISSION_REQUIRED")
  if admission~staffId<>staffId | admission~sessionId<>channelSessionId then return .FederationBankStaffWireResult~failure("METHOD_PERMISSION_SESSION_MISMATCH")
  customerId=detail["customerId"]~string; source=detail["sourceAccountId"]~string; target=detail["targetAccountId"]~string; currency=detail["currency"]~string~upper; amount=detail["amountMinor"]+0
  now=.DateTime~new
  cmd=.FederationBankCommand~new("UI-CMD:"||requestId,"TRANSFER","UI-IDEM:"||requestId,customerId,source,target,currency,amount,"STAFF",staffId,now)
  snap=.FederationBankStaffChannelCommandSnapshot~fromCommand(cmd)
  req=.FederationBankStaffChannelRequest~new("UI-REQ:"||requestId,"UI-WORK:"||requestId,"CUSTOMER_INSTRUCTION",staffId,channelSessionId,branchId,deskId,snap,.nil,now)~seal
  p=.directory~new; p["request"]=req; p["contexts"]=contexts; p["envelopeId"]="UI-STAFFENV:"||requestId
  env=.FederationBankStaffChannelServiceEnvelope~new("UI-SUBMIT:"||requestId,"FBSTAFFCH.ACTION.SUBMIT",staffId,"STAFF_WIRE_UI",p,requestId,"",now)
  reply=service~handle(env)
  if \reply~ok then return .FederationBankStaffWireResult~failure(reply~code,reply~detail,reply~value)
  return .FederationBankStaffWireResult~success(reply~value,reply~code,reply~detail)

::requires "FederationBankStaffChannelService.cls"
::requires "FederationBankStaffMethodPermissions.cls"
