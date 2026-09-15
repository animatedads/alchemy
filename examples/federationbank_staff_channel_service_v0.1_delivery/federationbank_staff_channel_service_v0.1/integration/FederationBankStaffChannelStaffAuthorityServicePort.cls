/* Service-to-service adapter.  Staff Channel does not copy Staff Authority
 * rules: it loads authoritative context/approval evidence into the existing
 * Staff Authority Service and asks that service for the exact-action grant. */
::class FederationBankStaffChannelStaffAuthorityServicePort subclass FederationBankStaffChannelStaffAuthorityPort public
::method init
  expose service
  use arg serviceArg
  if serviceArg==.nil then raise syntax 98.911 array("Staff Authority Service required")
  service=serviceArg
::method putContexts private
  expose service
  use arg contexts
  if contexts==.nil then return .FederationBankStaffAuthorityResult~failure("STAFF_CONTEXT_REQUIRED")
  do staffId over contexts
    ctx=contexts[staffId]
    p=.directory~new; p["context"]=ctx
    cmdId="FBSTAFFCH:CTX:"||ctx~snapshotId
    reply=service~handle(.FederationBankStaffServiceEnvelope~new(cmdId,"FBSTAFF.CONTEXT.PUT","fb-staff-channel-service","SYSTEM",p))
    if \reply~ok then return .FederationBankStaffAuthorityResult~failure(reply~code,reply~detail,reply~value)
  end
  return .FederationBankStaffAuthorityResult~success(contexts)
::method recordApprovals private
  expose service
  use arg action,approvals
  if approvals==.nil then return .FederationBankStaffAuthorityResult~success(.array~new)
  do approval over approvals
    p=.directory~new; p["action"]=action; p["approval"]=approval
    cmdId="FBSTAFFCH:AP:"||approval~approvalId
    reply=service~handle(.FederationBankStaffServiceEnvelope~new(cmdId,"FBSTAFF.APPROVAL.RECORD","fb-staff-channel-service","SYSTEM",p))
    if \reply~ok then return .FederationBankStaffAuthorityResult~failure(reply~code,reply~detail,reply~value)
  end
  return .FederationBankStaffAuthorityResult~success(approvals)
::method authCommandId private
  use arg action,approvals
  ids=.array~new
  if approvals<>.nil then do a over approvals; ids~append(a~approvalId); end
  ids~sort; text="FBSTAFFCH:AUTH:"||action~actionId
  if ids~items=0 then return text||":NONE"
  do id over ids; text||=":"||id; end
  return text
::method authorise
  expose service
  use arg envelopeId,action,contexts,approvals=.nil
  r=self~putContexts(contexts); if \r~ok then return r
  r=self~recordApprovals(action,approvals); if \r~ok then return r
  p=.directory~new; p["action"]=action; p["envelopeId"]=envelopeId
  reply=service~handle(.FederationBankStaffServiceEnvelope~new(self~authCommandId(action,approvals),"FBSTAFF.ACTION.AUTHORISE",action~staffId,"STAFF_CHANNEL",p))
  if \reply~ok then return .FederationBankStaffAuthorityResult~failure(reply~code,reply~detail,reply~value)
  rec=reply~value; d=.directory~new; d["decision"]=rec~decision; d["envelope"]=rec~envelope
  return .FederationBankStaffAuthorityResult~success(d)
::requires "FederationBankStaffAuthorityService.cls"
::requires "FederationBankStaffChannel.cls"
