::class FederationBankStaffPrincipalFactory public
::method newBlank
  return .FederationBankStaffPrincipalRef~new("RESTORE","RESTORE","RESTORE")
::class FederationBankStaffSessionFactory public
::method newBlank
  return .FederationBankStaffSessionContext~new("RESTORE","RESTORE","RESTORE","RESTORE","RESTORE","RESTORE")
::class FederationBankStaffRoleAssignmentFactory public
::method newBlank
  return .FederationBankStaffRoleAssignment~new("RESTORE","RESTORE","RESTORE","RESTORE")
::class FederationBankStaffDelegationFactory public
::method newBlank
  now=.DateTime~new
  return .FederationBankStaffDelegation~new("RESTORE","RESTORE","RESTORE","*",0,now,now+.TimeSpan~new(0,1),"RESTORE","RESTORE","RESTORE",.array~of("*"))
::class FederationBankStaffElevationFactory public
::method newBlank
  now=.DateTime~new
  return .FederationBankStaffElevation~new("RESTORE","RESTORE","RESTORE","*",0,now,now+.TimeSpan~new(0,1),"RESTORE","RESTORE","RESTORE")
::class FederationBankStaffContextFactory public
::method newBlank
  p=.FederationBankStaffPrincipalRef~new("RESTORE","RESTORE","RESTORE")~seal
  s=.FederationBankStaffSessionContext~new("RESTORE","RESTORE","RESTORE","RESTORE","RESTORE","RESTORE")~seal
  return .FederationBankStaffContextSnapshot~new("RESTORE",p,s)
::class FederationBankStaffActionFactory public
::method newBlank
  return .FederationBankStaffActionIntent~new("RESTORE","RESTORE","RESTORE","RESTORE","RESTORE","RESTORE","RESTORE","","","",0,"RESTORE","RESTORE")
::class FederationBankStaffApprovalFactory public
::method newBlank
  a=.FederationBankStaffActionIntent~new("RESTORE","RESTORE","RESTORE","RESTORE","RESTORE","RESTORE","RESTORE","","","",0,"RESTORE","RESTORE")~seal
  return .FederationBankStaffApproval~new("RESTORE",a,"RESTORE","RESTORE","RESTORE","RESTORE")
::class FederationBankStaffDecisionFactory public
::method newBlank
  return .FederationBankStaffAuthorityDecision~new(.false,"RESTORE","","RESTORE","RESTORE","DENY")
::class FederationBankStaffEnvelopeFactory public
::method newBlank
  a=.FederationBankStaffActionIntent~new("RESTORE","RESTORE","RESTORE","RESTORE","RESTORE","RESTORE","RESTORE","","","",0,"RESTORE","RESTORE")~seal
  d=.FederationBankStaffAuthorityDecision~new(.true,"ALLOW","","RESTORE","RESTORE","ALLOW","RESTORE","RESTORE","1","RESTORE","RESTORE")
  return .FederationBankStaffAuthorityEnvelope~new("RESTORE",a,"RESTORE",d)
::class FederationBankStaffServiceEnvelopeFactory public
::method newBlank
  return .FederationBankStaffServiceEnvelope~new("RESTORE","RESTORE","RESTORE","RESTORE")
::class FederationBankStaffServiceReplyFactory public
::method newBlank
  return .FederationBankStaffServiceReply~new("RESTORE","RESTORE",.false,"RESTORE")
::class FederationBankStaffAuthorityRecordFactory public
::method newBlank
  a=.FederationBankStaffActionIntent~new("RESTORE","RESTORE","RESTORE","RESTORE","RESTORE","RESTORE","RESTORE","","","",0,"RESTORE","RESTORE")~seal
  d=.FederationBankStaffAuthorityDecision~new(.false,"RESTORE","","RESTORE","RESTORE","DENY")
  return .FederationBankStaffAuthorityRecord~new(a,d,.nil,"RESTORE")
::class FederationBankStaffServiceEventFactory public
::method newBlank
  return .FederationBankStaffServiceEvent~new("RESTORE","RESTORE","RESTORE","RESTORE","RESTORE","RESTORE","RESTORE",.DateTime~new,0)
::class FederationBankStaffServiceReceiptFactory public
::method newBlank
  return .FederationBankStaffServiceReceipt~new("RESTORE","RESTORE")
::class FederationBankStaffServiceStateFactory public
::method newBlank
  return .FederationBankStaffAuthorityServiceState~new

::class FederationBankStaffAuthorityServicePersistenceSupport public
::method registerTypes class
  use arg codec
  if codec==.nil | \codec~hasMethod("TYPEREGISTRY") then return .false
  r=codec~typeRegistry
  ignore=r~register("federationbank.staff.principal/1",.FederationBankStaffPrincipalFactory~new)
  ignore=r~register("federationbank.staff.session/1",.FederationBankStaffSessionFactory~new)
  ignore=r~register("federationbank.staff.role.assignment/1",.FederationBankStaffRoleAssignmentFactory~new)
  ignore=r~register("federationbank.staff.delegation/1",.FederationBankStaffDelegationFactory~new)
  ignore=r~register("federationbank.staff.elevation/1",.FederationBankStaffElevationFactory~new)
  ignore=r~register("federationbank.staff.context/1",.FederationBankStaffContextFactory~new)
  ignore=r~register("federationbank.staff.action/1",.FederationBankStaffActionFactory~new)
  ignore=r~register("federationbank.staff.action/2",.FederationBankStaffActionFactory~new)
  ignore=r~register("federationbank.staff.approval/1",.FederationBankStaffApprovalFactory~new)
  ignore=r~register("federationbank.staff.authority.decision/1",.FederationBankStaffDecisionFactory~new)
  ignore=r~register("federationbank.staff.authority.decision/2",.FederationBankStaffDecisionFactory~new)
  ignore=r~register("federationbank.staff.authority.envelope/1",.FederationBankStaffEnvelopeFactory~new)
  ignore=r~register("federationbank.staff.authority.envelope/2",.FederationBankStaffEnvelopeFactory~new)
  ignore=r~register("federationbank.staff.authority.service.command/1",.FederationBankStaffServiceEnvelopeFactory~new)
  ignore=r~register("federationbank.staff.authority.service.reply/1",.FederationBankStaffServiceReplyFactory~new)
  ignore=r~register("federationbank.staff.authority.service.record/1",.FederationBankStaffAuthorityRecordFactory~new)
  ignore=r~register("federationbank.staff.authority.service.event/1",.FederationBankStaffServiceEventFactory~new)
  ignore=r~register("federationbank.staff.authority.service.receipt/1",.FederationBankStaffServiceReceiptFactory~new)
  ignore=r~register(.FederationBankStaffAuthorityServiceBuild~LEGACY_STATE_FORMAT,.FederationBankStaffServiceStateFactory~new)
  ignore=r~register(.FederationBankStaffAuthorityServiceBuild~STATE_FORMAT,.FederationBankStaffServiceStateFactory~new)
  return .true
::method newCodec class
  codec=.QueueGraphPayloadCodec~new; ignore=self~registerTypes(codec); return codec

::class FederationBankStaffAuthorityServiceStore public
::method init
  expose root durableStore codec
  use arg rootArg,codecArg=.nil,recordProtector=.nil,recoveryMode="STRICT"
  root=rootArg~string
  if codecArg==.nil then codec=.FederationBankStaffAuthorityServicePersistenceSupport~newCodec
  else do; codec=codecArg; ignore=.FederationBankStaffAuthorityServicePersistenceSupport~registerTypes(codec); end
  durableStore=.QueueDurableStore~new(root,recordProtector,recoveryMode)
::method save
  expose durableStore codec
  use arg state
  signal on syntax name saveFailure
  graph=codec~encode(state); ignore=durableStore~appendJournal("FBSTAFFSTATE",.array~of(.FederationBankStaffAuthorityServiceBuild~STATE_FORMAT,graph)); signal off syntax
  return .FederationBankStaffServiceResult~success(state)
saveFailure:
  signal off syntax
  return .FederationBankStaffServiceResult~failure("STATE_SAVE_FAILED",condition("D"))
::method load
  expose durableStore codec
  signal on syntax name loadFailure
  rows=durableStore~readJournal; graph=""
  do row over rows
    if row~items>=3 then if row[1]="FBSTAFFSTATE" then if row[2]=.FederationBankStaffAuthorityServiceBuild~STATE_FORMAT | row[2]=.FederationBankStaffAuthorityServiceBuild~LEGACY_STATE_FORMAT then graph=row[3]
  end
  if graph="" then return .FederationBankStaffServiceResult~success(.FederationBankStaffAuthorityServiceState~new,"new store")
  state=codec~decode(graph)
  if \state~isA(.FederationBankStaffAuthorityServiceState) then return .FederationBankStaffServiceResult~failure("STATE_TYPE_INVALID")
  signal off syntax
  return .FederationBankStaffServiceResult~success(state)
loadFailure:
  signal off syntax
  return .FederationBankStaffServiceResult~failure("STATE_LOAD_FAILED",condition("D"))

::requires "FederationBankStaffAuthorityService.cls"
::requires "ObjectQueueFabric.cls"
