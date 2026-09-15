/*
 * FederationBank Staff Authority v0.1
 *
 * Policy-driven business authority for employees acting through the STAFF
 * channel.  This component does not authenticate passwords, own HR truth,
 * decide customer/product policy, or post to the Ledger.  It answers the
 * narrower institutional question: is this identified staff actor, in this
 * effective role/delegation/session context, entitled to request this exact
 * banking action, and is independent approval required?
 */

::class FederationBankStaffAuthorityBuild public
::constant VERSION "0.2"
::constant API_VERSION "federationbank.staff.authority/0.2"
::constant SCOPE_CUSTOMER "CUSTOMER"
::constant SCOPE_INSTITUTIONAL "INSTITUTIONAL"
::constant PRODUCT "FederationBank Staff Authority"
::constant DEFAULT_POLICY_ID "FB-STAFF-AUTHORITY"
::constant CHANNEL "STAFF"

::class FederationBankStaffCanonical public
::method token class
  use arg value
  if value==.nil then return ""
  return value~string~strip~upper
::method field class
  use arg tag,value=""
  if value==.nil then text="<NIL>"; else text=value~string
  return tag~string||":"||text~length||":"||text
::method copyArray class
  use arg source
  out=.array~new
  if source==.nil then return out
  do item over source; out~append(item); end
  return out
::method copyDirectory class
  use arg source
  out=.directory~new
  if source==.nil then return out
  do key over source; out[key]=source[key]; end
  return out
::method contains class
  use arg source,wanted
  wanted=self~token(wanted)
  if source==.nil then return .false
  do item over source; if self~token(item)=wanted then return .true; end
  return .false
::method dateText class
  use arg value
  if value==.nil then return ""
  return value~utcIsoDate
::method dateValue class
  use arg value
  if value==.nil then return .nil
  text=value~string~strip
  if text="" then return .nil
  if text~right(1)="Z" then text=text~left(text~length-1)
  return .DateTime~fromIsoDate(text)
::method minPositive class
  use arg a,b
  a=a+0; b=b+0
  if a<=0 then return b
  if b<=0 then return a
  return a~min(b)

::class FederationBankStaffAuthorityResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get
::method init
  expose ok code detail value
  use arg okArg,codeArg,detailArg="",valueArg=.nil
  ok=okArg; code=codeArg~string~upper; detail=detailArg~string; value=valueArg
::method success class
  use arg value=.nil,detail=""
  return self~new(.true,"OK",detail,value)
::method failure class
  use arg code,detail="",value=.nil
  return self~new(.false,code,detail,value)

::class FederationBankStaffAlchemyContext public
::attribute sealer get
::attribute authority get
::method init
  expose sealer authority
  use arg sealerArg=.nil,authorityArg=.nil
  sealer=sealerArg; authority=authorityArg

::class FederationBankStaffAlchemyObject subclass AlchemyObject public
::attribute domainObjectKind get
::method initStaffAlchemy protected
  expose domainObjectKind
  use arg kindArg,contextArg=.nil
  kind=.FederationBankStaffCanonical~token(kindArg)
  sealer=.nil; authority=.nil
  if contextArg<>.nil then do
    if \contextArg~isA(.FederationBankStaffAlchemyContext) then raise syntax 88.960 array("FederationBank Staff Alchemy context invalid")
    sealer=contextArg~sealer; authority=contextArg~authority
  end
  meta=.directory~new
  meta["PURPOSE"]="policy-driven staff business authority for FederationBank STAFF-channel actions"
  meta["PACKAGE"]="federationbank_staff_authority"
  meta["PACKAGE_VERSION"]=.FederationBankStaffAuthorityBuild~VERSION
  meta["DOMAIN_OBJECT_KIND"]=kind
  meta["DESIGN_LIMITATIONS"]="Does not own HR/IAM truth, customer policy, legal effect, Core Banking acceptance or Ledger truth."
  self~init:super(meta,sealer,authority)
  domainObjectKind=kind
  self~registerExternalRequirement("library","alchemy_objects","0.8",.true)
  return self

/* Reference to authoritative HR/IAM identity. */
::class FederationBankStaffPrincipalRef subclass FederationBankStaffAlchemyObject public
::attribute staffId get
::attribute sourceSystem get
::attribute sourceRef get
::attribute employmentState get
::attribute legalEntity get
::attribute homeBranchId get
::attribute evidenceRef get
::attribute sealed get
::method init
  expose staffId sourceSystem sourceRef employmentState legalEntity homeBranchId evidenceRef sealed
  use arg staffIdArg,sourceSystemArg,sourceRefArg,employmentStateArg="ACTIVE",legalEntityArg="FEDERATIONBANK-AUSTRALIA-IOM",homeBranchIdArg="",evidenceRefArg="",contextArg=.nil
  self~initStaffAlchemy("STAFFPRINCIPALREF",contextArg)
  staffId=staffIdArg~string; sourceSystem=.FederationBankStaffCanonical~token(sourceSystemArg); sourceRef=sourceRefArg~string
  employmentState=.FederationBankStaffCanonical~token(employmentStateArg); legalEntity=.FederationBankStaffCanonical~token(legalEntityArg); homeBranchId=.FederationBankStaffCanonical~token(homeBranchIdArg); evidenceRef=evidenceRefArg~string; sealed=.false
  if staffId="" | sourceSystem="" | sourceRef="" then raise syntax 88.961 array("Staff principal authoritative reference required")
::method seal
  expose sealed
  sealed=.true; return self
::method active
  expose employmentState sealed
  return sealed & employmentState="ACTIVE"
::method canonicalText
  expose staffId sourceSystem sourceRef employmentState legalEntity homeBranchId evidenceRef sealed
  if \sealed then raise syntax 88.962 array("Staff principal must be sealed")
  text="FB-STAFF-PRINCIPAL/1"
  text||=.FederationBankStaffCanonical~field("STAFF",staffId)
  text||=.FederationBankStaffCanonical~field("SOURCE",sourceSystem)
  text||=.FederationBankStaffCanonical~field("SOURCE_REF",sourceRef)
  text||=.FederationBankStaffCanonical~field("EMPLOYMENT",employmentState)
  text||=.FederationBankStaffCanonical~field("LEGAL_ENTITY",legalEntity)
  text||=.FederationBankStaffCanonical~field("HOME_BRANCH",homeBranchId)
  text||=.FederationBankStaffCanonical~field("EVIDENCE",evidenceRef)
  return text
::method semanticIdentity
  return self~canonicalText
::method queuePersistentType
  return "federationbank.staff.principal/1"
::method queuePersistentState
  expose staffId sourceSystem sourceRef employmentState legalEntity homeBranchId evidenceRef sealed
  if \sealed then raise syntax 88.963 array("Unsealed staff principal cannot cross durable boundary")
  s=.table~new; s["staffId"]=staffId; s["sourceSystem"]=sourceSystem; s["sourceRef"]=sourceRef; s["employmentState"]=employmentState; s["legalEntity"]=legalEntity; s["homeBranchId"]=homeBranchId; s["evidenceRef"]=evidenceRef; return s
::method queueRestoreState
  expose staffId sourceSystem sourceRef employmentState legalEntity homeBranchId evidenceRef sealed
  use arg s
  staffId=s["staffId"]~string; sourceSystem=.FederationBankStaffCanonical~token(s["sourceSystem"]); sourceRef=s["sourceRef"]~string; employmentState=.FederationBankStaffCanonical~token(s["employmentState"]); legalEntity=.FederationBankStaffCanonical~token(s["legalEntity"]); homeBranchId=.FederationBankStaffCanonical~token(s["homeBranchId"]); evidenceRef=s["evidenceRef"]~string; sealed=.true; return self

/* Authenticated session context is supplied by IAM/session infrastructure. */
::class FederationBankStaffSessionContext subclass FederationBankStaffAlchemyObject public
::attribute sessionId get
::attribute staffId get
::attribute branchId get
::attribute deskId get
::attribute workstationId get
::attribute authenticationRef get
::attribute startedAt get
::attribute expiresAt get
::attribute securityContextRef get
::attribute sealed get
::method init
  expose sessionId staffId branchId deskId workstationId authenticationRef startedAt expiresAt securityContextRef sealed
  use arg sessionIdArg,staffIdArg,branchIdArg,deskIdArg,workstationIdArg,authenticationRefArg,startedAtArg=.nil,expiresAtArg=.nil,securityContextRefArg="",contextArg=.nil
  self~initStaffAlchemy("STAFFSESSIONCONTEXT",contextArg)
  sessionId=sessionIdArg~string; staffId=staffIdArg~string; branchId=.FederationBankStaffCanonical~token(branchIdArg); deskId=.FederationBankStaffCanonical~token(deskIdArg); workstationId=workstationIdArg~string; authenticationRef=authenticationRefArg~string
  if startedAtArg==.nil then startedAt=.DateTime~new; else startedAt=startedAtArg
  expiresAt=expiresAtArg; securityContextRef=securityContextRefArg~string; sealed=.false
  if sessionId="" | staffId="" | branchId="" | deskId="" | authenticationRef="" then raise syntax 88.964 array("Staff session identity/context required")
::method activeAt
  expose sealed startedAt expiresAt
  use arg atTime
  if \sealed then return .false
  if atTime<startedAt then return .false
  if expiresAt<>.nil then if atTime>=expiresAt then return .false
  return .true
::method seal
  expose sealed
  sealed=.true; return self
::method canonicalText
  expose sessionId staffId branchId deskId workstationId authenticationRef startedAt expiresAt securityContextRef sealed
  if \sealed then raise syntax 88.965 array("Staff session must be sealed")
  text="FB-STAFF-SESSION/1"
  text||=.FederationBankStaffCanonical~field("SESSION",sessionId)
  text||=.FederationBankStaffCanonical~field("STAFF",staffId)
  text||=.FederationBankStaffCanonical~field("BRANCH",branchId)
  text||=.FederationBankStaffCanonical~field("DESK",deskId)
  text||=.FederationBankStaffCanonical~field("WORKSTATION",workstationId)
  text||=.FederationBankStaffCanonical~field("AUTH_REF",authenticationRef)
  text||=.FederationBankStaffCanonical~field("START",startedAt~utcIsoDate)
  text||=.FederationBankStaffCanonical~field("EXPIRES",.FederationBankStaffCanonical~dateText(expiresAt))
  text||=.FederationBankStaffCanonical~field("SECURITY_REF",securityContextRef)
  return text
::method semanticIdentity
  return self~canonicalText
::method queuePersistentType
  return "federationbank.staff.session/1"
::method queuePersistentState
  expose sessionId staffId branchId deskId workstationId authenticationRef startedAt expiresAt securityContextRef sealed
  if \sealed then raise syntax 88.966 array("Unsealed staff session cannot cross durable boundary")
  s=.table~new; s["sessionId"]=sessionId; s["staffId"]=staffId; s["branchId"]=branchId; s["deskId"]=deskId; s["workstationId"]=workstationId; s["authenticationRef"]=authenticationRef; s["startedAt"]=startedAt~utcIsoDate; s["expiresAt"]=.FederationBankStaffCanonical~dateText(expiresAt); s["securityContextRef"]=securityContextRef; return s
::method queueRestoreState
  expose sessionId staffId branchId deskId workstationId authenticationRef startedAt expiresAt securityContextRef sealed
  use arg s
  sessionId=s["sessionId"]~string; staffId=s["staffId"]~string; branchId=.FederationBankStaffCanonical~token(s["branchId"]); deskId=.FederationBankStaffCanonical~token(s["deskId"]); workstationId=s["workstationId"]~string; authenticationRef=s["authenticationRef"]~string; startedAt=.FederationBankStaffCanonical~dateValue(s["startedAt"]); expiresAt=.FederationBankStaffCanonical~dateValue(s["expiresAt"]); securityContextRef=s["securityContextRef"]~string; sealed=.true; return self

/* Assignment is an organizational fact; policy gives that role consequences. */
::class FederationBankStaffRoleAssignment subclass FederationBankStaffAlchemyObject public
::attribute assignmentId get
::attribute staffId get
::attribute roleClass get
::attribute roleCode get
::attribute branchId get
::attribute maxAmountMinor get
::attribute effectiveFrom get
::attribute effectiveUntil get
::attribute sourceSystem get
::attribute sourceRef get
::attribute sealed get
::method init
  expose assignmentId staffId roleClass roleCode branchId maxAmountMinor effectiveFrom effectiveUntil sourceSystem sourceRef operations sealed
  use arg assignmentIdArg,staffIdArg,roleClassArg,roleCodeArg,branchIdArg="*",maxAmountMinorArg=0,effectiveFromArg=.nil,effectiveUntilArg=.nil,sourceSystemArg="IAM",sourceRefArg="",operationsArg=.nil,contextArg=.nil
  self~initStaffAlchemy("STAFFROLEASSIGNMENT",contextArg)
  assignmentId=assignmentIdArg~string; staffId=staffIdArg~string; roleClass=.FederationBankStaffCanonical~token(roleClassArg); roleCode=.FederationBankStaffCanonical~token(roleCodeArg); branchId=.FederationBankStaffCanonical~token(branchIdArg); maxAmountMinor=maxAmountMinorArg+0
  if effectiveFromArg==.nil then effectiveFrom=.DateTime~new-.TimeSpan~new(0,0,0,0,1); else effectiveFrom=effectiveFromArg
  effectiveUntil=effectiveUntilArg; sourceSystem=.FederationBankStaffCanonical~token(sourceSystemArg); sourceRef=sourceRefArg~string; operations=.FederationBankStaffCanonical~copyArray(operationsArg); sealed=.false
  if assignmentId="" | staffId="" | roleClass="" | roleCode="" | sourceSystem="" then raise syntax 88.967 array("Staff role assignment identity required")
::method operations
  expose operations
  return .FederationBankStaffCanonical~copyArray(operations)
::method activeAt
  expose sealed effectiveFrom effectiveUntil
  use arg atTime
  if \sealed then return .false
  if atTime<effectiveFrom then return .false
  if effectiveUntil<>.nil then if atTime>=effectiveUntil then return .false
  return .true
::method inBranch
  expose branchId
  use arg wanted
  return branchId="*" | branchId=.FederationBankStaffCanonical~token(wanted)
::method permitsOperation
  expose operations
  use arg operation
  if operations~items=0 then return .true
  return .FederationBankStaffCanonical~contains(operations,operation) | .FederationBankStaffCanonical~contains(operations,"*")
::method seal
  expose sealed
  sealed=.true; return self
::method canonicalText
  expose assignmentId staffId roleClass roleCode branchId maxAmountMinor effectiveFrom effectiveUntil sourceSystem sourceRef operations sealed
  if \sealed then raise syntax 88.968 array("Staff role assignment must be sealed")
  text="FB-STAFF-ROLE-ASSIGNMENT/1"
  text||=.FederationBankStaffCanonical~field("ASSIGNMENT",assignmentId); text||=.FederationBankStaffCanonical~field("STAFF",staffId); text||=.FederationBankStaffCanonical~field("ROLE_CLASS",roleClass); text||=.FederationBankStaffCanonical~field("ROLE_CODE",roleCode); text||=.FederationBankStaffCanonical~field("BRANCH",branchId); text||=.FederationBankStaffCanonical~field("MAX_MINOR",maxAmountMinor); text||=.FederationBankStaffCanonical~field("FROM",effectiveFrom~utcIsoDate); text||=.FederationBankStaffCanonical~field("UNTIL",.FederationBankStaffCanonical~dateText(effectiveUntil)); text||=.FederationBankStaffCanonical~field("SOURCE",sourceSystem); text||=.FederationBankStaffCanonical~field("SOURCE_REF",sourceRef)
  ordered=self~operations; ordered~sort; do op over ordered; text||=.FederationBankStaffCanonical~field("OP",.FederationBankStaffCanonical~token(op)); end
  return text
::method semanticIdentity
  return self~canonicalText
::method queuePersistentType
  return "federationbank.staff.role.assignment/1"
::method queuePersistentState
  expose assignmentId staffId roleClass roleCode branchId maxAmountMinor effectiveFrom effectiveUntil sourceSystem sourceRef operations sealed
  if \sealed then raise syntax 88.969 array("Unsealed staff role assignment cannot cross durable boundary")
  s=.table~new; s["assignmentId"]=assignmentId; s["staffId"]=staffId; s["roleClass"]=roleClass; s["roleCode"]=roleCode; s["branchId"]=branchId; s["maxAmountMinor"]=maxAmountMinor~string; s["effectiveFrom"]=effectiveFrom~utcIsoDate; s["effectiveUntil"]=.FederationBankStaffCanonical~dateText(effectiveUntil); s["sourceSystem"]=sourceSystem; s["sourceRef"]=sourceRef; s["operations"]=self~operations; return s
::method queueRestoreState
  expose assignmentId staffId roleClass roleCode branchId maxAmountMinor effectiveFrom effectiveUntil sourceSystem sourceRef operations sealed
  use arg s
  assignmentId=s["assignmentId"]~string; staffId=s["staffId"]~string; roleClass=.FederationBankStaffCanonical~token(s["roleClass"]); roleCode=.FederationBankStaffCanonical~token(s["roleCode"]); branchId=.FederationBankStaffCanonical~token(s["branchId"]); maxAmountMinor=s["maxAmountMinor"]+0; effectiveFrom=.FederationBankStaffCanonical~dateValue(s["effectiveFrom"]); effectiveUntil=.FederationBankStaffCanonical~dateValue(s["effectiveUntil"]); sourceSystem=.FederationBankStaffCanonical~token(s["sourceSystem"]); sourceRef=s["sourceRef"]~string; operations=.FederationBankStaffCanonical~copyArray(s["operations"]); sealed=.true; return self

/* Bounded, effective-dated temporary authority supplied by an authoritative
 * workforce/authority source.  Delegation cannot increase policy ceilings. */
::class FederationBankStaffDelegation subclass FederationBankStaffAlchemyObject public
::attribute delegationId get
::attribute granteeStaffId get
::attribute delegatedRoleClass get
::attribute branchId get
::attribute maximumMinor get
::attribute effectiveFrom get
::attribute effectiveUntil get
::attribute grantedBy get
::attribute authorityEvidenceRef get
::attribute sourceSystem get
::attribute sealed get
::method init
  expose delegationId granteeStaffId delegatedRoleClass branchId maximumMinor effectiveFrom effectiveUntil grantedBy authorityEvidenceRef sourceSystem operations sealed
  use arg delegationIdArg,granteeStaffIdArg,delegatedRoleClassArg,branchIdArg="*",maximumMinorArg=0,effectiveFromArg=.nil,effectiveUntilArg=.nil,grantedByArg="",authorityEvidenceRefArg="",sourceSystemArg="IAM",operationsArg=.nil,contextArg=.nil
  self~initStaffAlchemy("STAFFDELEGATION",contextArg)
  delegationId=delegationIdArg~string; granteeStaffId=granteeStaffIdArg~string; delegatedRoleClass=.FederationBankStaffCanonical~token(delegatedRoleClassArg); branchId=.FederationBankStaffCanonical~token(branchIdArg); maximumMinor=maximumMinorArg+0
  if effectiveFromArg==.nil then effectiveFrom=.DateTime~new; else effectiveFrom=effectiveFromArg
  effectiveUntil=effectiveUntilArg; grantedBy=grantedByArg~string; authorityEvidenceRef=authorityEvidenceRefArg~string; sourceSystem=.FederationBankStaffCanonical~token(sourceSystemArg); operations=.FederationBankStaffCanonical~copyArray(operationsArg); sealed=.false
  if delegationId="" | granteeStaffId="" | delegatedRoleClass="" | grantedBy="" | authorityEvidenceRef="" | sourceSystem="" then raise syntax 88.970 array("Delegation identity and authority evidence required")
::method operations
  expose operations
  return .FederationBankStaffCanonical~copyArray(operations)
::method activeAt
  expose sealed effectiveFrom effectiveUntil
  use arg atTime
  if \sealed then return .false
  if atTime<effectiveFrom then return .false
  if effectiveUntil==.nil then return .false /* delegation must be bounded */
  return atTime<effectiveUntil
::method inBranch
  expose branchId
  use arg wanted
  return branchId="*" | branchId=.FederationBankStaffCanonical~token(wanted)
::method permitsOperation
  expose operations
  use arg operation
  if operations~items=0 then return .false
  return .FederationBankStaffCanonical~contains(operations,operation) | .FederationBankStaffCanonical~contains(operations,"*")
::method seal
  expose sealed effectiveFrom effectiveUntil
  if effectiveUntil==.nil | effectiveUntil<=effectiveFrom then raise syntax 88.971 array("Delegation must have a positive bounded window")
  sealed=.true; return self
::method canonicalText
  expose delegationId granteeStaffId delegatedRoleClass branchId maximumMinor effectiveFrom effectiveUntil grantedBy authorityEvidenceRef sourceSystem operations sealed
  if \sealed then raise syntax 88.972 array("Delegation must be sealed")
  text="FB-STAFF-DELEGATION/1"; text||=.FederationBankStaffCanonical~field("DELEGATION",delegationId); text||=.FederationBankStaffCanonical~field("GRANTEE",granteeStaffId); text||=.FederationBankStaffCanonical~field("ROLE_CLASS",delegatedRoleClass); text||=.FederationBankStaffCanonical~field("BRANCH",branchId); text||=.FederationBankStaffCanonical~field("MAX_MINOR",maximumMinor); text||=.FederationBankStaffCanonical~field("FROM",effectiveFrom~utcIsoDate); text||=.FederationBankStaffCanonical~field("UNTIL",effectiveUntil~utcIsoDate); text||=.FederationBankStaffCanonical~field("GRANTED_BY",grantedBy); text||=.FederationBankStaffCanonical~field("EVIDENCE",authorityEvidenceRef); text||=.FederationBankStaffCanonical~field("SOURCE",sourceSystem)
  ordered=self~operations; ordered~sort; do op over ordered; text||=.FederationBankStaffCanonical~field("OP",.FederationBankStaffCanonical~token(op)); end
  return text
::method semanticIdentity
  return self~canonicalText
::method queuePersistentType
  return "federationbank.staff.delegation/1"
::method queuePersistentState
  expose delegationId granteeStaffId delegatedRoleClass branchId maximumMinor effectiveFrom effectiveUntil grantedBy authorityEvidenceRef sourceSystem operations sealed
  if \sealed then raise syntax 88.973 array("Unsealed delegation cannot cross durable boundary")
  s=.table~new; s["delegationId"]=delegationId; s["granteeStaffId"]=granteeStaffId; s["delegatedRoleClass"]=delegatedRoleClass; s["branchId"]=branchId; s["maximumMinor"]=maximumMinor~string; s["effectiveFrom"]=effectiveFrom~utcIsoDate; s["effectiveUntil"]=effectiveUntil~utcIsoDate; s["grantedBy"]=grantedBy; s["authorityEvidenceRef"]=authorityEvidenceRef; s["sourceSystem"]=sourceSystem; s["operations"]=self~operations; return s
::method queueRestoreState
  expose delegationId granteeStaffId delegatedRoleClass branchId maximumMinor effectiveFrom effectiveUntil grantedBy authorityEvidenceRef sourceSystem operations sealed
  use arg s
  delegationId=s["delegationId"]~string; granteeStaffId=s["granteeStaffId"]~string; delegatedRoleClass=.FederationBankStaffCanonical~token(s["delegatedRoleClass"]); branchId=.FederationBankStaffCanonical~token(s["branchId"]); maximumMinor=s["maximumMinor"]+0; effectiveFrom=.FederationBankStaffCanonical~dateValue(s["effectiveFrom"]); effectiveUntil=.FederationBankStaffCanonical~dateValue(s["effectiveUntil"]); grantedBy=s["grantedBy"]~string; authorityEvidenceRef=s["authorityEvidenceRef"]~string; sourceSystem=.FederationBankStaffCanonical~token(s["sourceSystem"]); operations=.FederationBankStaffCanonical~copyArray(s["operations"]); sealed=.true; return self

/* Break-glass/elevation is distinct from ordinary delegation. */
::class FederationBankStaffElevation subclass FederationBankStaffAlchemyObject public
::attribute elevationId get
::attribute staffId get
::attribute elevationClass get
::attribute branchId get
::attribute maximumMinor get
::attribute effectiveFrom get
::attribute effectiveUntil get
::attribute authorisedBy get
::attribute evidenceRef get
::attribute reason get
::attribute sealed get
::method init
  expose elevationId staffId elevationClass branchId maximumMinor effectiveFrom effectiveUntil authorisedBy evidenceRef reason sealed
  use arg elevationIdArg,staffIdArg,elevationClassArg,branchIdArg="*",maximumMinorArg=0,effectiveFromArg=.nil,effectiveUntilArg=.nil,authorisedByArg="",evidenceRefArg="",reasonArg="",contextArg=.nil
  self~initStaffAlchemy("STAFFELEVATION",contextArg)
  elevationId=elevationIdArg~string; staffId=staffIdArg~string; elevationClass=.FederationBankStaffCanonical~token(elevationClassArg); branchId=.FederationBankStaffCanonical~token(branchIdArg); maximumMinor=maximumMinorArg+0
  if effectiveFromArg==.nil then effectiveFrom=.DateTime~new; else effectiveFrom=effectiveFromArg
  effectiveUntil=effectiveUntilArg; authorisedBy=authorisedByArg~string; evidenceRef=evidenceRefArg~string; reason=reasonArg~string; sealed=.false
  if elevationId="" | staffId="" | elevationClass="" | authorisedBy="" | evidenceRef="" | reason="" then raise syntax 88.974 array("Elevation identity, evidence and reason required")
::method activeAt
  expose sealed effectiveFrom effectiveUntil
  use arg atTime
  if \sealed then return .false
  if atTime<effectiveFrom then return .false
  if effectiveUntil==.nil then return .false
  return atTime<effectiveUntil
::method inBranch
  expose branchId
  use arg wanted
  return branchId="*" | branchId=.FederationBankStaffCanonical~token(wanted)
::method seal
  expose sealed effectiveFrom effectiveUntil
  if effectiveUntil==.nil | effectiveUntil<=effectiveFrom then raise syntax 88.975 array("Elevation must have a positive bounded window")
  sealed=.true; return self
::method canonicalText
  expose elevationId staffId elevationClass branchId maximumMinor effectiveFrom effectiveUntil authorisedBy evidenceRef reason sealed
  if \sealed then raise syntax 88.976 array("Elevation must be sealed")
  text="FB-STAFF-ELEVATION/1"; text||=.FederationBankStaffCanonical~field("ELEVATION",elevationId); text||=.FederationBankStaffCanonical~field("STAFF",staffId); text||=.FederationBankStaffCanonical~field("CLASS",elevationClass); text||=.FederationBankStaffCanonical~field("BRANCH",branchId); text||=.FederationBankStaffCanonical~field("MAX_MINOR",maximumMinor); text||=.FederationBankStaffCanonical~field("FROM",effectiveFrom~utcIsoDate); text||=.FederationBankStaffCanonical~field("UNTIL",effectiveUntil~utcIsoDate); text||=.FederationBankStaffCanonical~field("AUTHORISED_BY",authorisedBy); text||=.FederationBankStaffCanonical~field("EVIDENCE",evidenceRef); text||=.FederationBankStaffCanonical~field("REASON",reason); return text
::method semanticIdentity
  return self~canonicalText
::method queuePersistentType
  return "federationbank.staff.elevation/1"
::method queuePersistentState
  expose elevationId staffId elevationClass branchId maximumMinor effectiveFrom effectiveUntil authorisedBy evidenceRef reason sealed
  if \sealed then raise syntax 88.977 array("Unsealed elevation cannot cross durable boundary")
  s=.table~new; s["elevationId"]=elevationId; s["staffId"]=staffId; s["elevationClass"]=elevationClass; s["branchId"]=branchId; s["maximumMinor"]=maximumMinor~string; s["effectiveFrom"]=effectiveFrom~utcIsoDate; s["effectiveUntil"]=effectiveUntil~utcIsoDate; s["authorisedBy"]=authorisedBy; s["evidenceRef"]=evidenceRef; s["reason"]=reason; return s
::method queueRestoreState
  expose elevationId staffId elevationClass branchId maximumMinor effectiveFrom effectiveUntil authorisedBy evidenceRef reason sealed
  use arg s
  elevationId=s["elevationId"]~string; staffId=s["staffId"]~string; elevationClass=.FederationBankStaffCanonical~token(s["elevationClass"]); branchId=.FederationBankStaffCanonical~token(s["branchId"]); maximumMinor=s["maximumMinor"]+0; effectiveFrom=.FederationBankStaffCanonical~dateValue(s["effectiveFrom"]); effectiveUntil=.FederationBankStaffCanonical~dateValue(s["effectiveUntil"]); authorisedBy=s["authorisedBy"]~string; evidenceRef=s["evidenceRef"]~string; reason=s["reason"]~string; sealed=.true; return self

/* One immutable snapshot of externally authoritative staff context. */
::class FederationBankStaffContextSnapshot subclass FederationBankStaffAlchemyObject public
::attribute snapshotId get
::attribute capturedAt get
::attribute principal get
::attribute session get
::attribute sealed get
::method init
  expose snapshotId capturedAt principal session assignments delegations elevations sealed
  use arg snapshotIdArg,principalArg,sessionArg,assignmentsArg=.nil,delegationsArg=.nil,elevationsArg=.nil,capturedAtArg=.nil,contextArg=.nil
  self~initStaffAlchemy("STAFFCONTEXTSNAPSHOT",contextArg)
  snapshotId=snapshotIdArg~string; principal=principalArg; session=sessionArg; assignments=.FederationBankStaffCanonical~copyArray(assignmentsArg); delegations=.FederationBankStaffCanonical~copyArray(delegationsArg); elevations=.FederationBankStaffCanonical~copyArray(elevationsArg)
  if capturedAtArg==.nil then capturedAt=.DateTime~new; else capturedAt=capturedAtArg
  sealed=.false
  if snapshotId="" | principal==.nil | session==.nil then raise syntax 88.978 array("Staff context snapshot principal/session required")
::method assignments
  expose assignments
  return .FederationBankStaffCanonical~copyArray(assignments)
::method delegations
  expose delegations
  return .FederationBankStaffCanonical~copyArray(delegations)
::method elevations
  expose elevations
  return .FederationBankStaffCanonical~copyArray(elevations)
::method seal
  expose sealed principal session assignments delegations elevations
  if \principal~sealed | \session~sealed then raise syntax 88.979 array("Staff context contains unsealed principal/session")
  if principal~staffId<>session~staffId then raise syntax 88.980 array("Principal/session staff mismatch")
  do a over assignments; if \a~sealed | a~staffId<>principal~staffId then raise syntax 88.981 array("Invalid role assignment in context"); end
  do d over delegations; if \d~sealed | d~granteeStaffId<>principal~staffId then raise syntax 88.982 array("Invalid delegation in context"); end
  do e over elevations; if \e~sealed | e~staffId<>principal~staffId then raise syntax 88.983 array("Invalid elevation in context"); end
  sealed=.true; return self
::method validAt
  expose sealed principal session
  use arg atTime
  return sealed & principal~active & session~activeAt(atTime)
::method canonicalText
  expose snapshotId capturedAt principal session assignments delegations elevations sealed
  if \sealed then raise syntax 88.984 array("Staff context snapshot must be sealed")
  text="FB-STAFF-CONTEXT/1"; text||=.FederationBankStaffCanonical~field("SNAPSHOT",snapshotId); text||=.FederationBankStaffCanonical~field("CAPTURED",capturedAt~utcIsoDate); text||=.FederationBankStaffCanonical~field("PRINCIPAL",principal~semanticIdentity); text||=.FederationBankStaffCanonical~field("SESSION",session~semanticIdentity)
  ids=.array~new; do a over assignments; ids~append(a~semanticIdentity); end; ids~sort; do id over ids; text||=.FederationBankStaffCanonical~field("ASSIGNMENT",id); end
  ids=.array~new; do d over delegations; ids~append(d~semanticIdentity); end; ids~sort; do id over ids; text||=.FederationBankStaffCanonical~field("DELEGATION",id); end
  ids=.array~new; do e over elevations; ids~append(e~semanticIdentity); end; ids~sort; do id over ids; text||=.FederationBankStaffCanonical~field("ELEVATION",id); end
  return text
::method semanticIdentity
  return self~canonicalText
::method queuePersistentType
  return "federationbank.staff.context/1"
::method queuePersistentState
  expose snapshotId capturedAt principal session assignments delegations elevations sealed
  if \sealed then raise syntax 88.985 array("Unsealed staff context cannot cross durable boundary")
  s=.table~new; s["snapshotId"]=snapshotId; s["capturedAt"]=capturedAt~utcIsoDate; s["principal"]=principal; s["session"]=session; s["assignments"]=self~assignments; s["delegations"]=self~delegations; s["elevations"]=self~elevations; return s
::method queueRestoreState
  expose snapshotId capturedAt principal session assignments delegations elevations sealed
  use arg s
  snapshotId=s["snapshotId"]~string; capturedAt=.FederationBankStaffCanonical~dateValue(s["capturedAt"]); principal=s["principal"]; session=s["session"]; assignments=.FederationBankStaffCanonical~copyArray(s["assignments"]); delegations=.FederationBankStaffCanonical~copyArray(s["delegations"]); elevations=.FederationBankStaffCanonical~copyArray(s["elevations"]); sealed=.true; return self

/* Exact banking action the employee is attempting. */
::class FederationBankStaffActionIntent subclass FederationBankStaffAlchemyObject public
::attribute actionId get
::attribute commandId get
::attribute idempotencyKey get
::attribute staffId get
::attribute sessionId get
::attribute operation get
::attribute customerId get
::attribute sourceAccountId get
::attribute targetAccountId get
::attribute currency get
::attribute amountMinor get
::attribute branchId get
::attribute deskId get
::attribute caseId get
::attribute requestedAt get
::attribute authorityScope get
::attribute sealed get
::method init
  expose actionId commandId idempotencyKey staffId sessionId operation customerId sourceAccountId targetAccountId currency amountMinor branchId deskId caseId requestedAt authorityScope details sealed
  use arg actionIdArg,commandIdArg,idempotencyKeyArg,staffIdArg,sessionIdArg,operationArg,customerIdArg,sourceAccountIdArg="",targetAccountIdArg="",currencyArg="",amountMinorArg=0,branchIdArg="",deskIdArg="",caseIdArg="",requestedAtArg=.nil,detailsArg=.nil,contextArg=.nil,authorityScopeArg="CUSTOMER"
  self~initStaffAlchemy("STAFFACTIONINTENT",contextArg)
  actionId=actionIdArg~string; commandId=commandIdArg~string; idempotencyKey=idempotencyKeyArg~string; staffId=staffIdArg~string; sessionId=sessionIdArg~string; operation=.FederationBankStaffCanonical~token(operationArg); customerId=customerIdArg~string; sourceAccountId=sourceAccountIdArg~string; targetAccountId=targetAccountIdArg~string; currency=.FederationBankStaffCanonical~token(currencyArg); amountMinor=amountMinorArg+0; branchId=.FederationBankStaffCanonical~token(branchIdArg); deskId=.FederationBankStaffCanonical~token(deskIdArg); caseId=caseIdArg~string
  if requestedAtArg==.nil then requestedAt=.DateTime~new; else requestedAt=requestedAtArg
  authorityScope=.FederationBankStaffCanonical~token(authorityScopeArg)
  if authorityScope<>.FederationBankStaffAuthorityBuild~SCOPE_CUSTOMER & authorityScope<>.FederationBankStaffAuthorityBuild~SCOPE_INSTITUTIONAL then raise syntax 88.986 array("Staff action authority scope must be CUSTOMER or INSTITUTIONAL")
  details=.FederationBankStaffCanonical~copyDirectory(detailsArg); sealed=.false
  if actionId="" | commandId="" | idempotencyKey="" | staffId="" | sessionId="" | operation="" | customerId="" | branchId="" | deskId="" then raise syntax 88.986 array("Staff action identity/context required")
::method details
  expose details
  return .FederationBankStaffCanonical~copyDirectory(details)
::method seal
  expose sealed
  sealed=.true; return self
::method canonicalText
  expose actionId commandId idempotencyKey staffId sessionId operation customerId sourceAccountId targetAccountId currency amountMinor branchId deskId caseId requestedAt authorityScope details sealed
  if \sealed then raise syntax 88.987 array("Staff action must be sealed")
  text="FB-STAFF-ACTION/2"; text||=.FederationBankStaffCanonical~field("SCOPE",authorityScope); text||=.FederationBankStaffCanonical~field("ACTION",actionId); text||=.FederationBankStaffCanonical~field("COMMAND",commandId); text||=.FederationBankStaffCanonical~field("IDEMPOTENCY",idempotencyKey); text||=.FederationBankStaffCanonical~field("STAFF",staffId); text||=.FederationBankStaffCanonical~field("SESSION",sessionId); text||=.FederationBankStaffCanonical~field("OP",operation); text||=.FederationBankStaffCanonical~field("CUSTOMER",customerId); text||=.FederationBankStaffCanonical~field("SOURCE",sourceAccountId); text||=.FederationBankStaffCanonical~field("TARGET",targetAccountId); text||=.FederationBankStaffCanonical~field("CURRENCY",currency); text||=.FederationBankStaffCanonical~field("AMOUNT",amountMinor); text||=.FederationBankStaffCanonical~field("BRANCH",branchId); text||=.FederationBankStaffCanonical~field("DESK",deskId); text||=.FederationBankStaffCanonical~field("CASE",caseId); text||=.FederationBankStaffCanonical~field("AT",requestedAt~utcIsoDate)
  keys=.array~new; do key over details; keys~append(key~string); end; keys~sort; do key over keys; text||=.FederationBankStaffCanonical~field("DETAIL:"||key,details[key]); end
  return text
::method semanticIdentity
  return self~canonicalText
::method queuePersistentType
  return "federationbank.staff.action/2"
::method queuePersistentState
  expose actionId commandId idempotencyKey staffId sessionId operation customerId sourceAccountId targetAccountId currency amountMinor branchId deskId caseId requestedAt authorityScope details sealed
  if \sealed then raise syntax 88.988 array("Unsealed staff action cannot cross durable boundary")
  s=.table~new; s["actionId"]=actionId; s["commandId"]=commandId; s["idempotencyKey"]=idempotencyKey; s["staffId"]=staffId; s["sessionId"]=sessionId; s["operation"]=operation; s["customerId"]=customerId; s["sourceAccountId"]=sourceAccountId; s["targetAccountId"]=targetAccountId; s["currency"]=currency; s["amountMinor"]=amountMinor~string; s["branchId"]=branchId; s["deskId"]=deskId; s["caseId"]=caseId; s["requestedAt"]=requestedAt~utcIsoDate; s["authorityScope"]=authorityScope; s["details"]=self~details; return s
::method queueRestoreState
  expose actionId commandId idempotencyKey staffId sessionId operation customerId sourceAccountId targetAccountId currency amountMinor branchId deskId caseId requestedAt authorityScope details sealed
  use arg s
  actionId=s["actionId"]~string; commandId=s["commandId"]~string; idempotencyKey=s["idempotencyKey"]~string; staffId=s["staffId"]~string; sessionId=s["sessionId"]~string; operation=.FederationBankStaffCanonical~token(s["operation"]); customerId=s["customerId"]~string; sourceAccountId=s["sourceAccountId"]~string; targetAccountId=s["targetAccountId"]~string; currency=.FederationBankStaffCanonical~token(s["currency"]); amountMinor=s["amountMinor"]+0; branchId=.FederationBankStaffCanonical~token(s["branchId"]); deskId=.FederationBankStaffCanonical~token(s["deskId"]); caseId=s["caseId"]~string; requestedAt=.FederationBankStaffCanonical~dateValue(s["requestedAt"]); if s~hasIndex("authorityScope") then authorityScope=.FederationBankStaffCanonical~token(s["authorityScope"]); else authorityScope=.FederationBankStaffAuthorityBuild~SCOPE_CUSTOMER; details=.FederationBankStaffCanonical~copyDirectory(s["details"]); sealed=.true; return self

::class FederationBankStaffApproval subclass FederationBankStaffAlchemyObject public
::attribute approvalId get
::attribute actionIdentity get
::attribute actionId get
::attribute approverStaffId get
::attribute approverSessionId get
::attribute approvalClass get
::attribute approvedAt get
::attribute evidenceRef get
::attribute decision get
::attribute sealed get
::method init
  expose approvalId actionIdentity actionId approverStaffId approverSessionId approvalClass approvedAt evidenceRef decision sealed
  use arg approvalIdArg,actionArg,approverStaffIdArg,approverSessionIdArg,approvalClassArg,evidenceRefArg,approvedAtArg=.nil,decisionArg="APPROVE",contextArg=.nil
  self~initStaffAlchemy("STAFFAPPROVAL",contextArg)
  approvalId=approvalIdArg~string
  if actionArg==.nil then raise syntax 88.989 array("Approval action required")
  actionIdentity=actionArg~semanticIdentity; actionId=actionArg~actionId; approverStaffId=approverStaffIdArg~string; approverSessionId=approverSessionIdArg~string; approvalClass=.FederationBankStaffCanonical~token(approvalClassArg); evidenceRef=evidenceRefArg~string
  if approvedAtArg==.nil then approvedAt=.DateTime~new; else approvedAt=approvedAtArg
  decision=.FederationBankStaffCanonical~token(decisionArg); sealed=.false
  if approvalId="" | approverStaffId="" | approverSessionId="" | approvalClass="" | evidenceRef="" then raise syntax 88.990 array("Approval identity/evidence required")
::method seal
  expose sealed
  sealed=.true; return self
::method matchesAction
  expose sealed actionIdentity
  use arg action
  return sealed & action<>.nil & actionIdentity=action~semanticIdentity
::method canonicalText
  expose approvalId actionIdentity actionId approverStaffId approverSessionId approvalClass approvedAt evidenceRef decision sealed
  if \sealed then raise syntax 88.991 array("Approval must be sealed")
  text="FB-STAFF-APPROVAL/1"; text||=.FederationBankStaffCanonical~field("APPROVAL",approvalId); text||=.FederationBankStaffCanonical~field("ACTION_ID",actionId); text||=.FederationBankStaffCanonical~field("ACTION_IDENTITY",actionIdentity); text||=.FederationBankStaffCanonical~field("APPROVER",approverStaffId); text||=.FederationBankStaffCanonical~field("SESSION",approverSessionId); text||=.FederationBankStaffCanonical~field("CLASS",approvalClass); text||=.FederationBankStaffCanonical~field("AT",approvedAt~utcIsoDate); text||=.FederationBankStaffCanonical~field("EVIDENCE",evidenceRef); text||=.FederationBankStaffCanonical~field("DECISION",decision); return text
::method semanticIdentity
  return self~canonicalText
::method queuePersistentType
  return "federationbank.staff.approval/1"
::method queuePersistentState
  expose approvalId actionIdentity actionId approverStaffId approverSessionId approvalClass approvedAt evidenceRef decision sealed
  if \sealed then raise syntax 88.992 array("Unsealed approval cannot cross durable boundary")
  s=.table~new; s["approvalId"]=approvalId; s["actionIdentity"]=actionIdentity; s["actionId"]=actionId; s["approverStaffId"]=approverStaffId; s["approverSessionId"]=approverSessionId; s["approvalClass"]=approvalClass; s["approvedAt"]=approvedAt~utcIsoDate; s["evidenceRef"]=evidenceRef; s["decision"]=decision; return s
::method queueRestoreState
  expose approvalId actionIdentity actionId approverStaffId approverSessionId approvalClass approvedAt evidenceRef decision sealed
  use arg s
  approvalId=s["approvalId"]~string; actionIdentity=s["actionIdentity"]~string; actionId=s["actionId"]~string; approverStaffId=s["approverStaffId"]~string; approverSessionId=s["approverSessionId"]~string; approvalClass=.FederationBankStaffCanonical~token(s["approvalClass"]); approvedAt=.FederationBankStaffCanonical~dateValue(s["approvedAt"]); evidenceRef=s["evidenceRef"]~string; decision=.FederationBankStaffCanonical~token(s["decision"]); sealed=.true; return self

::class FederationBankStaffAuthorityRule public
::attribute ruleId get
::attribute roleClass get
::attribute operation get
::attribute branchId get
::attribute makerLimitMinor get
::attribute checkerLimitMinor get
::attribute checkerClass get
::attribute checkerCount get
::attribute distinctMakerChecker get
::attribute delegationAllowed get
::attribute requiredElevationClass get
::attribute rationale get
::attribute authorityScope get
::attribute sealed get
::method init
  expose ruleId roleClass operation branchId makerLimitMinor checkerLimitMinor checkerClass checkerCount distinctMakerChecker delegationAllowed requiredElevationClass rationale authorityScope sealed
  use arg ruleIdArg,roleClassArg,operationArg,branchIdArg="*",makerLimitMinorArg=0,checkerLimitMinorArg=0,checkerClassArg="",checkerCountArg=0,distinctMakerCheckerArg=.true,delegationAllowedArg=.false,requiredElevationClassArg="",rationaleArg="",authorityScopeArg="CUSTOMER"
  ruleId=.FederationBankStaffCanonical~token(ruleIdArg); roleClass=.FederationBankStaffCanonical~token(roleClassArg); operation=.FederationBankStaffCanonical~token(operationArg); branchId=.FederationBankStaffCanonical~token(branchIdArg); makerLimitMinor=makerLimitMinorArg+0; checkerLimitMinor=checkerLimitMinorArg+0; checkerClass=.FederationBankStaffCanonical~token(checkerClassArg); checkerCount=checkerCountArg+0; distinctMakerChecker=distinctMakerCheckerArg; delegationAllowed=delegationAllowedArg; requiredElevationClass=.FederationBankStaffCanonical~token(requiredElevationClassArg); rationale=rationaleArg~string; authorityScope=.FederationBankStaffCanonical~token(authorityScopeArg); sealed=.false
  if authorityScope<>"*" & authorityScope<>.FederationBankStaffAuthorityBuild~SCOPE_CUSTOMER & authorityScope<>.FederationBankStaffAuthorityBuild~SCOPE_INSTITUTIONAL then raise syntax 88.993 array("Staff authority rule scope must be CUSTOMER, INSTITUTIONAL or *")
  if ruleId="" | roleClass="" | operation="" then raise syntax 88.993 array("Staff authority rule identity required")
::method seal
  expose sealed checkerCount checkerClass checkerLimitMinor makerLimitMinor
  if checkerCount>0 & checkerClass="" then raise syntax 88.994 array("Checker class required")
  if checkerCount>0 & checkerLimitMinor>0 & makerLimitMinor>checkerLimitMinor then raise syntax 88.995 array("Maker limit cannot exceed checker limit")
  sealed=.true; return self
::method matches
  expose sealed roleClass operation branchId authorityScope
  use arg roleClassArg,operationArg,branchArg,authorityScopeArg="CUSTOMER"
  if \sealed then return .false
  if roleClass<>"*" & roleClass<>.FederationBankStaffCanonical~token(roleClassArg) then return .false
  if operation<>"*" & operation<>.FederationBankStaffCanonical~token(operationArg) then return .false
  if branchId<>"*" & branchId<>.FederationBankStaffCanonical~token(branchArg) then return .false
  if authorityScope<>"*" & authorityScope<>.FederationBankStaffCanonical~token(authorityScopeArg) then return .false
  return .true
::method specificity
  expose roleClass operation branchId authorityScope
  n=0; if roleClass<>"*" then n+=1; if operation<>"*" then n+=1; if branchId<>"*" then n+=1; if authorityScope<>"*" then n+=1; return n
::method canonicalText
  expose ruleId roleClass operation branchId makerLimitMinor checkerLimitMinor checkerClass checkerCount distinctMakerChecker delegationAllowed requiredElevationClass rationale authorityScope sealed
  if \sealed then raise syntax 88.996 array("Staff authority rule must be sealed")
  text="FB-STAFF-AUTHORITY-RULE/2"; text||=.FederationBankStaffCanonical~field("SCOPE",authorityScope); text||=.FederationBankStaffCanonical~field("RULE",ruleId); text||=.FederationBankStaffCanonical~field("ROLE",roleClass); text||=.FederationBankStaffCanonical~field("OP",operation); text||=.FederationBankStaffCanonical~field("BRANCH",branchId); text||=.FederationBankStaffCanonical~field("MAKER_LIMIT",makerLimitMinor); text||=.FederationBankStaffCanonical~field("CHECKER_LIMIT",checkerLimitMinor); text||=.FederationBankStaffCanonical~field("CHECKER_CLASS",checkerClass); text||=.FederationBankStaffCanonical~field("CHECKER_COUNT",checkerCount); text||=.FederationBankStaffCanonical~field("DISTINCT",distinctMakerChecker); text||=.FederationBankStaffCanonical~field("DELEGATION",delegationAllowed); text||=.FederationBankStaffCanonical~field("ELEVATION",requiredElevationClass); text||=.FederationBankStaffCanonical~field("RATIONALE",rationale); return text
::method semanticIdentity
  return self~canonicalText

::class FederationBankStaffAuthorityPolicy public
::attribute sealed get
::method init
  expose rules sealed
  rules=.array~new; sealed=.false
::method addRule
  expose rules sealed
  use arg rule
  if sealed | rule==.nil | \rule~sealed then return .false
  do r over rules; if r~ruleId=rule~ruleId then return .false; end
  rules~append(rule); return .true
::method rules
  expose rules
  return .FederationBankStaffCanonical~copyArray(rules)
::method seal
  expose sealed
  sealed=.true; return self
::method publicationEligible
  expose sealed rules
  return sealed & rules~items>0
::method resolveRule
  expose sealed rules
  use arg roleClass,operation,branchId,authorityScope="CUSTOMER"
  if \sealed then return .FederationBankStaffAuthorityResult~failure("STAFF_POLICY_NOT_SEALED")
  best=.nil; bestScore=-1
  do r over rules
    if r~matches(roleClass,operation,branchId,authorityScope) then do
      score=r~specificity
      if score>bestScore then do; best=r; bestScore=score; end
      else if score=bestScore then if best<>.nil then if r~ruleId<best~ruleId then best=r
    end
  end
  if best==.nil then return .FederationBankStaffAuthorityResult~failure("STAFF_POLICY_NO_RULE",roleClass||"/"||operation||"/"||branchId||"/"||authorityScope)
  return .FederationBankStaffAuthorityResult~success(best)
::method canonicalText
  expose sealed rules
  ids=.array~new; by=.directory~new
  do r over rules; ids~append(r~ruleId); by[r~ruleId]=r; end
  ids~sort; text="FB-STAFF-AUTHORITY-POLICY/2|SEALED="||sealed
  do id over ids; text||="|"||by[id]~semanticIdentity; end
  return text
::method semanticIdentity
  return self~canonicalText

::class FederationBankStaffAuthorityGate public
::method init
  expose catalog policyId
  use arg catalogArg,policyIdArg="FB-STAFF-AUTHORITY"
  if catalogArg==.nil then raise syntax 88.997 array("Staff authority policy catalog required")
  catalog=catalogArg; policyId=.FederationBankStaffCanonical~token(policyIdArg)
::method resolve
  expose catalog policyId
  use arg atTime
  resolved=catalog~resolve(policyId,atTime)
  if \resolved~ok then return .FederationBankStaffAuthorityResult~failure("STAFF_POLICY_RESOLUTION_FAILED",resolved~code||":"||resolved~detail,resolved)
  release=resolved~value
  if release~payload==.nil then return .FederationBankStaffAuthorityResult~failure("STAFF_POLICY_PAYLOAD_REQUIRED")
  d=.directory~new; d["payload"]=release~payload; d["policyId"]=release~policyId; d["policyVersion"]=release~version; d["policyIdentity"]=release~semanticIdentity; return .FederationBankStaffAuthorityResult~success(d)

::class FederationBankStaffAuthorityDecision public
::attribute ok get
::attribute code get
::attribute detail get
::attribute actionId get
::attribute staffId get
::attribute outcome get
::attribute ruleId get
::attribute policyId get
::attribute policyVersion get
::attribute policyIdentity get
::attribute roleClass get
::attribute assignmentId get
::attribute delegationId get
::attribute makerLimitMinor get
::attribute checkerLimitMinor get
::attribute checkerClass get
::attribute checkerCount get
::attribute evaluatedAt get
::attribute authorityScope get
::method init
  expose ok code detail actionId staffId outcome ruleId policyId policyVersion policyIdentity roleClass assignmentId delegationId makerLimitMinor checkerLimitMinor checkerClass checkerCount approvalIds evaluatedAt authorityScope
  use arg okArg,codeArg,detailArg,actionIdArg,staffIdArg,outcomeArg,ruleIdArg="",policyIdArg="",policyVersionArg="",policyIdentityArg="",roleClassArg="",assignmentIdArg="",delegationIdArg="",makerLimitArg=0,checkerLimitArg=0,checkerClassArg="",checkerCountArg=0,approvalIdsArg=.nil,evaluatedAtArg=.nil,authorityScopeArg="CUSTOMER"
  ok=okArg; code=.FederationBankStaffCanonical~token(codeArg); detail=detailArg~string; actionId=actionIdArg~string; staffId=staffIdArg~string; outcome=.FederationBankStaffCanonical~token(outcomeArg); ruleId=.FederationBankStaffCanonical~token(ruleIdArg); policyId=.FederationBankStaffCanonical~token(policyIdArg); policyVersion=policyVersionArg~string; policyIdentity=policyIdentityArg~string; roleClass=.FederationBankStaffCanonical~token(roleClassArg); assignmentId=assignmentIdArg~string; delegationId=delegationIdArg~string; makerLimitMinor=makerLimitArg+0; checkerLimitMinor=checkerLimitArg+0; checkerClass=.FederationBankStaffCanonical~token(checkerClassArg); checkerCount=checkerCountArg+0; approvalIds=.FederationBankStaffCanonical~copyArray(approvalIdsArg)
  if evaluatedAtArg==.nil then evaluatedAt=.DateTime~new; else evaluatedAt=evaluatedAtArg
  authorityScope=.FederationBankStaffCanonical~token(authorityScopeArg)
::method approvalIds
  expose approvalIds
  return .FederationBankStaffCanonical~copyArray(approvalIds)
::method canonicalText
  expose ok code detail actionId staffId outcome ruleId policyId policyVersion policyIdentity roleClass assignmentId delegationId makerLimitMinor checkerLimitMinor checkerClass checkerCount approvalIds evaluatedAt authorityScope
  text="FB-STAFF-AUTHORITY-DECISION/2"; text||=.FederationBankStaffCanonical~field("SCOPE",authorityScope); text||=.FederationBankStaffCanonical~field("OK",ok); text||=.FederationBankStaffCanonical~field("CODE",code); text||=.FederationBankStaffCanonical~field("DETAIL",detail); text||=.FederationBankStaffCanonical~field("ACTION",actionId); text||=.FederationBankStaffCanonical~field("STAFF",staffId); text||=.FederationBankStaffCanonical~field("OUTCOME",outcome); text||=.FederationBankStaffCanonical~field("RULE",ruleId); text||=.FederationBankStaffCanonical~field("POLICY",policyId||"@"||policyVersion); text||=.FederationBankStaffCanonical~field("POLICY_IDENTITY",policyIdentity); text||=.FederationBankStaffCanonical~field("ROLE",roleClass); text||=.FederationBankStaffCanonical~field("ASSIGNMENT",assignmentId); text||=.FederationBankStaffCanonical~field("DELEGATION",delegationId); text||=.FederationBankStaffCanonical~field("MAKER_LIMIT",makerLimitMinor); text||=.FederationBankStaffCanonical~field("CHECKER_LIMIT",checkerLimitMinor); text||=.FederationBankStaffCanonical~field("CHECKER_CLASS",checkerClass); text||=.FederationBankStaffCanonical~field("CHECKER_COUNT",checkerCount); ordered=self~approvalIds; ordered~sort; do id over ordered; text||=.FederationBankStaffCanonical~field("APPROVAL",id); end; text||=.FederationBankStaffCanonical~field("EVALUATED_AT",evaluatedAt~utcIsoDate); return text
::method semanticIdentity
  return self~canonicalText
::method queuePersistentType
  return "federationbank.staff.authority.decision/2"
::method queuePersistentState
  expose ok code detail actionId staffId outcome ruleId policyId policyVersion policyIdentity roleClass assignmentId delegationId makerLimitMinor checkerLimitMinor checkerClass checkerCount approvalIds evaluatedAt authorityScope
  s=.table~new; if ok then s["ok"]="1"; else s["ok"]="0"; s["authorityScope"]=authorityScope; s["code"]=code; s["detail"]=detail; s["actionId"]=actionId; s["staffId"]=staffId; s["outcome"]=outcome; s["ruleId"]=ruleId; s["policyId"]=policyId; s["policyVersion"]=policyVersion; s["policyIdentity"]=policyIdentity; s["roleClass"]=roleClass; s["assignmentId"]=assignmentId; s["delegationId"]=delegationId; s["makerLimitMinor"]=makerLimitMinor~string; s["checkerLimitMinor"]=checkerLimitMinor~string; s["checkerClass"]=checkerClass; s["checkerCount"]=checkerCount~string; s["approvalIds"]=self~approvalIds; s["evaluatedAt"]=evaluatedAt~utcIsoDate; return s
::method queueRestoreState
  expose ok code detail actionId staffId outcome ruleId policyId policyVersion policyIdentity roleClass assignmentId delegationId makerLimitMinor checkerLimitMinor checkerClass checkerCount approvalIds evaluatedAt authorityScope
  use arg s
  if s~hasIndex("authorityScope") then authorityScope=.FederationBankStaffCanonical~token(s["authorityScope"]); else authorityScope=.FederationBankStaffAuthorityBuild~SCOPE_CUSTOMER
  ok=(s["ok"]~string="1"); code=.FederationBankStaffCanonical~token(s["code"]); detail=s["detail"]~string; actionId=s["actionId"]~string; staffId=s["staffId"]~string; outcome=.FederationBankStaffCanonical~token(s["outcome"]); ruleId=.FederationBankStaffCanonical~token(s["ruleId"]); policyId=.FederationBankStaffCanonical~token(s["policyId"]); policyVersion=s["policyVersion"]~string; policyIdentity=s["policyIdentity"]~string; roleClass=.FederationBankStaffCanonical~token(s["roleClass"]); assignmentId=s["assignmentId"]~string; delegationId=s["delegationId"]~string; makerLimitMinor=s["makerLimitMinor"]+0; checkerLimitMinor=s["checkerLimitMinor"]+0; checkerClass=.FederationBankStaffCanonical~token(s["checkerClass"]); checkerCount=s["checkerCount"]+0; approvalIds=.FederationBankStaffCanonical~copyArray(s["approvalIds"]); evaluatedAt=.FederationBankStaffCanonical~dateValue(s["evaluatedAt"]); return self

/* Positive, immutable grant bound to the exact action identity. */
::class FederationBankStaffAuthorityEnvelope subclass FederationBankStaffAlchemyObject public
::attribute envelopeId get
::attribute actionId get
::attribute actionIdentity get
::attribute staffId get
::attribute sessionId get
::attribute decisionIdentity get
::attribute policyId get
::attribute policyVersion get
::attribute policyIdentity get
::attribute ruleId get
::attribute issuedAt get
::attribute validUntil get
::attribute authorityScope get
::attribute sealed get
::method init
  expose envelopeId actionId actionIdentity staffId sessionId decisionIdentity policyId policyVersion policyIdentity ruleId issuedAt validUntil authorityScope approvalIds sealed
  use arg envelopeIdArg,actionArg,sessionIdArg,decisionArg,validUntilArg=.nil,contextArg=.nil
  self~initStaffAlchemy("STAFFAUTHORITYENVELOPE",contextArg)
  if actionArg==.nil | decisionArg==.nil then raise syntax 88.998 array("Authority envelope action/decision required")
  if \decisionArg~ok | decisionArg~outcome<>"ALLOW" then raise syntax 88.999 array("Only positive ALLOW decision can create authority envelope")
  envelopeId=envelopeIdArg~string; actionId=actionArg~actionId; actionIdentity=actionArg~semanticIdentity; staffId=actionArg~staffId; sessionId=sessionIdArg~string; decisionIdentity=decisionArg~semanticIdentity; policyId=decisionArg~policyId; policyVersion=decisionArg~policyVersion; policyIdentity=decisionArg~policyIdentity; ruleId=decisionArg~ruleId; issuedAt=decisionArg~evaluatedAt; validUntil=validUntilArg; authorityScope=actionArg~authorityScope; approvalIds=decisionArg~approvalIds; sealed=.false
  if envelopeId="" | sessionId="" then raise syntax 88.951 array("Authority envelope identity required")
::method approvalIds
  expose approvalIds
  return .FederationBankStaffCanonical~copyArray(approvalIds)
::method seal
  expose sealed
  sealed=.true; return self
::method validAt
  expose sealed issuedAt validUntil
  use arg atTime
  if \sealed then return .false
  if atTime<issuedAt then return .false
  if validUntil<>.nil then if atTime>=validUntil then return .false
  return .true
::method binds
  expose sealed actionIdentity staffId sessionId
  use arg action
  if \sealed | action==.nil then return .false
  return actionIdentity=action~semanticIdentity & staffId=action~staffId & sessionId=action~sessionId
::method canonicalText
  expose envelopeId actionId actionIdentity staffId sessionId decisionIdentity policyId policyVersion policyIdentity ruleId issuedAt validUntil authorityScope approvalIds sealed
  if \sealed then raise syntax 88.952 array("Authority envelope must be sealed")
  text="FB-STAFF-AUTHORITY-ENVELOPE/2"; text||=.FederationBankStaffCanonical~field("SCOPE",authorityScope); text||=.FederationBankStaffCanonical~field("ENVELOPE",envelopeId); text||=.FederationBankStaffCanonical~field("ACTION",actionId); text||=.FederationBankStaffCanonical~field("ACTION_IDENTITY",actionIdentity); text||=.FederationBankStaffCanonical~field("STAFF",staffId); text||=.FederationBankStaffCanonical~field("SESSION",sessionId); text||=.FederationBankStaffCanonical~field("DECISION",decisionIdentity); text||=.FederationBankStaffCanonical~field("POLICY",policyId||"@"||policyVersion); text||=.FederationBankStaffCanonical~field("POLICY_IDENTITY",policyIdentity); text||=.FederationBankStaffCanonical~field("RULE",ruleId); text||=.FederationBankStaffCanonical~field("ISSUED",issuedAt~utcIsoDate); text||=.FederationBankStaffCanonical~field("VALID_UNTIL",.FederationBankStaffCanonical~dateText(validUntil)); ordered=self~approvalIds; ordered~sort; do id over ordered; text||=.FederationBankStaffCanonical~field("APPROVAL",id); end; return text
::method semanticIdentity
  return self~canonicalText
::method queuePersistentType
  return "federationbank.staff.authority.envelope/2"
::method queuePersistentState
  expose envelopeId actionId actionIdentity staffId sessionId decisionIdentity policyId policyVersion policyIdentity ruleId issuedAt validUntil authorityScope approvalIds sealed
  if \sealed then raise syntax 88.953 array("Unsealed authority envelope cannot cross durable boundary")
  s=.table~new; s["authorityScope"]=authorityScope; s["envelopeId"]=envelopeId; s["actionId"]=actionId; s["actionIdentity"]=actionIdentity; s["staffId"]=staffId; s["sessionId"]=sessionId; s["decisionIdentity"]=decisionIdentity; s["policyId"]=policyId; s["policyVersion"]=policyVersion; s["policyIdentity"]=policyIdentity; s["ruleId"]=ruleId; s["issuedAt"]=issuedAt~utcIsoDate; s["validUntil"]=.FederationBankStaffCanonical~dateText(validUntil); s["approvalIds"]=self~approvalIds; return s
::method queueRestoreState
  expose envelopeId actionId actionIdentity staffId sessionId decisionIdentity policyId policyVersion policyIdentity ruleId issuedAt validUntil authorityScope approvalIds sealed
  use arg s
  if s~hasIndex("authorityScope") then authorityScope=.FederationBankStaffCanonical~token(s["authorityScope"]); else authorityScope=.FederationBankStaffAuthorityBuild~SCOPE_CUSTOMER
  envelopeId=s["envelopeId"]~string; actionId=s["actionId"]~string; actionIdentity=s["actionIdentity"]~string; staffId=s["staffId"]~string; sessionId=s["sessionId"]~string; decisionIdentity=s["decisionIdentity"]~string; policyId=.FederationBankStaffCanonical~token(s["policyId"]); policyVersion=s["policyVersion"]~string; policyIdentity=s["policyIdentity"]~string; ruleId=.FederationBankStaffCanonical~token(s["ruleId"]); issuedAt=.FederationBankStaffCanonical~dateValue(s["issuedAt"]); validUntil=.FederationBankStaffCanonical~dateValue(s["validUntil"]); approvalIds=.FederationBankStaffCanonical~copyArray(s["approvalIds"]); sealed=.true; return self

::class FederationBankStaffAuthorityEngine public
::method init
  expose gate
  use arg gateArg
  if gateArg==.nil then raise syntax 88.954 array("Staff authority gate required")
  gate=gateArg
::method contextFor private
  use arg contexts,staffId
  if contexts==.nil then return .nil
  if contexts~hasIndex(staffId) then return contexts[staffId]
  return .nil
::method makerCandidate private
  use arg context,rule,action
  /* ordinary assignments first; deterministic assignment id order */
  candidates=.array~new
  do a over context~assignments
    if a~activeAt(action~requestedAt) & a~inBranch(action~branchId) & a~permitsOperation(action~operation) & a~roleClass=rule~roleClass then candidates~append(a)
  end
  if candidates~items>0 then do
    ids=.array~new; by=.directory~new; do a over candidates; ids~append(a~assignmentId); by[a~assignmentId]=a; end; ids~sort
    d=.directory~new; d["kind"]="ASSIGNMENT"; d["assignment"]=by[ids[1]]; d["delegation"]=.nil; return d
  end
  if \rule~delegationAllowed then return .nil
  candidates=.array~new
  do d over context~delegations
    if d~activeAt(action~requestedAt) & d~inBranch(action~branchId) & d~permitsOperation(action~operation) & d~delegatedRoleClass=rule~roleClass then candidates~append(d)
  end
  if candidates~items=0 then return .nil
  ids=.array~new; by=.directory~new; do d over candidates; ids~append(d~delegationId); by[d~delegationId]=d; end; ids~sort
  out=.directory~new; out["kind"]="DELEGATION"; out["assignment"]=.nil; out["delegation"]=by[ids[1]]; return out
::method hasElevation private
  use arg context,rule,action
  if rule~requiredElevationClass="" then return .true
  do e over context~elevations
    if e~activeAt(action~requestedAt) & e~inBranch(action~branchId) & e~elevationClass=rule~requiredElevationClass then do
      if e~maximumMinor<=0 | action~amountMinor<=e~maximumMinor then return .true
    end
  end
  return .false
::method approverEligible private
  use arg approval,action,contexts,rule
  if approval==.nil | \approval~sealed | approval~decision<>"APPROVE" then return .false
  if \approval~matchesAction(action) then return .false
  if approval~approvalClass<>rule~checkerClass then return .false
  if rule~distinctMakerChecker & approval~approverStaffId=action~staffId then return .false
  ctx=self~contextFor(contexts,approval~approverStaffId)
  if ctx==.nil | \ctx~validAt(approval~approvedAt) then return .false
  if ctx~session~sessionId<>approval~approverSessionId then return .false
  if ctx~session~branchId<>action~branchId then return .false
  do a over ctx~assignments
    if a~activeAt(approval~approvedAt) & a~inBranch(action~branchId) & a~roleClass=rule~checkerClass then return .true
  end
  return .false
::method decide
  expose gate
  use arg action,contexts,approvals=.nil
  if action==.nil | \action~isA(.FederationBankStaffActionIntent) then return .FederationBankStaffAuthorityResult~failure("STAFF_ACTION_REQUIRED")
  if \action~sealed then return .FederationBankStaffAuthorityResult~failure("STAFF_ACTION_NOT_SEALED")
  maker=self~contextFor(contexts,action~staffId)
  if maker==.nil then return .FederationBankStaffAuthorityResult~failure("STAFF_CONTEXT_NOT_FOUND",action~staffId)
  if \maker~validAt(action~requestedAt) then return .FederationBankStaffAuthorityResult~failure("STAFF_CONTEXT_NOT_EFFECTIVE",action~staffId)
  if maker~session~sessionId<>action~sessionId then return .FederationBankStaffAuthorityResult~failure("STAFF_SESSION_MISMATCH")
  if maker~session~branchId<>action~branchId | maker~session~deskId<>action~deskId then return .FederationBankStaffAuthorityResult~failure("STAFF_WORK_CONTEXT_MISMATCH")
  resolved=gate~resolve(action~requestedAt)
  if \resolved~ok then return resolved
  info=resolved~value; policy=info["payload"]
  /* Identify all candidate role classes from assignment/delegation then choose the most specific rule deterministically. */
  roleClasses=.array~new
  do a over maker~assignments
    if a~activeAt(action~requestedAt) & a~inBranch(action~branchId) & a~permitsOperation(action~operation) then if \.FederationBankStaffCanonical~contains(roleClasses,a~roleClass) then roleClasses~append(a~roleClass)
  end
  do d over maker~delegations
    if d~activeAt(action~requestedAt) & d~inBranch(action~branchId) & d~permitsOperation(action~operation) then if \.FederationBankStaffCanonical~contains(roleClasses,d~delegatedRoleClass) then roleClasses~append(d~delegatedRoleClass)
  end
  if roleClasses~items=0 then return .FederationBankStaffAuthorityResult~failure("STAFF_ROLE_NOT_EFFECTIVE",action~staffId)
  chosenRule=.nil; chosenRole=""; chosenScore=-1
  roleClasses~sort
  do role over roleClasses
    rr=policy~resolveRule(role,action~operation,action~branchId,action~authorityScope)
    if \rr~ok then iterate
    rule=rr~value; score=rule~specificity
    if score>chosenScore then do; chosenRule=rule; chosenRole=role; chosenScore=score; end
    else if score=chosenScore then if chosenRule<>.nil then if rule~ruleId<chosenRule~ruleId then do; chosenRule=rule; chosenRole=role; end
  end
  if chosenRule==.nil then return .FederationBankStaffAuthorityResult~failure("STAFF_POLICY_NO_RULE_FOR_EFFECTIVE_ROLE",action~operation)
  holder=self~makerCandidate(maker,chosenRule,action)
  if holder==.nil then return .FederationBankStaffAuthorityResult~failure("STAFF_ROLE_NOT_AUTHORISED",chosenRole)
  if \self~hasElevation(maker,chosenRule,action) then return .FederationBankStaffAuthorityResult~failure("STAFF_ELEVATION_REQUIRED",chosenRule~requiredElevationClass)
  assignmentId=""; delegationId=""; contextualLimit=0
  if holder["kind"]="ASSIGNMENT" then do; a=holder["assignment"]; assignmentId=a~assignmentId; contextualLimit=a~maxAmountMinor; end
  else do; d=holder["delegation"]; delegationId=d~delegationId; contextualLimit=d~maximumMinor; end
  makerLimit=.FederationBankStaffCanonical~minPositive(chosenRule~makerLimitMinor,contextualLimit)
  checkerLimit=chosenRule~checkerLimitMinor
  if contextualLimit>0 then checkerLimit=.FederationBankStaffCanonical~minPositive(checkerLimit,contextualLimit)
  needChecker=.false
  if makerLimit>0 then if action~amountMinor>makerLimit then needChecker=.true
  if chosenRule~checkerCount>0 & chosenRule~makerLimitMinor=0 & chosenRule~checkerLimitMinor=0 then needChecker=.true
  if needChecker then do
    if chosenRule~checkerCount<=0 then return .FederationBankStaffAuthorityResult~failure("STAFF_AMOUNT_EXCEEDS_MAKER_LIMIT",action~amountMinor||">"||makerLimit)
    if checkerLimit>0 then if action~amountMinor>checkerLimit then return .FederationBankStaffAuthorityResult~failure("STAFF_AMOUNT_EXCEEDS_CHECKER_LIMIT",action~amountMinor||">"||checkerLimit)
    accepted=.array~new; used=.directory~new
    if approvals==.nil then approvals=.array~new
    do approval over approvals
      if self~approverEligible(approval,action,contexts,chosenRule) then do
        if \used~hasIndex(approval~approverStaffId) then do; used[approval~approverStaffId]=.true; accepted~append(approval~approvalId); end
      end
    end
    if accepted~items<chosenRule~checkerCount then do
      decision=.FederationBankStaffAuthorityDecision~new(.false,"APPROVAL_REQUIRED",chosenRule~checkerClass||" x"||chosenRule~checkerCount,action~actionId,action~staffId,"APPROVAL_REQUIRED",chosenRule~ruleId,info["policyId"],info["policyVersion"],info["policyIdentity"],chosenRole,assignmentId,delegationId,makerLimit,checkerLimit,chosenRule~checkerClass,chosenRule~checkerCount,accepted,action~requestedAt,action~authorityScope)
      return .FederationBankStaffAuthorityResult~failure("APPROVAL_REQUIRED",decision~detail,decision)
    end
    decision=.FederationBankStaffAuthorityDecision~new(.true,"ALLOW","maker/checker authority satisfied",action~actionId,action~staffId,"ALLOW",chosenRule~ruleId,info["policyId"],info["policyVersion"],info["policyIdentity"],chosenRole,assignmentId,delegationId,makerLimit,checkerLimit,chosenRule~checkerClass,chosenRule~checkerCount,accepted,action~requestedAt,action~authorityScope)
    return .FederationBankStaffAuthorityResult~success(decision)
  end
  decision=.FederationBankStaffAuthorityDecision~new(.true,"ALLOW","maker authority satisfied",action~actionId,action~staffId,"ALLOW",chosenRule~ruleId,info["policyId"],info["policyVersion"],info["policyIdentity"],chosenRole,assignmentId,delegationId,makerLimit,checkerLimit,chosenRule~checkerClass,chosenRule~checkerCount,.array~new,action~requestedAt,action~authorityScope)
  return .FederationBankStaffAuthorityResult~success(decision)
::method authorise
  use arg envelopeId,action,contexts,approvals=.nil,validUntil=.nil
  decision=self~decide(action,contexts,approvals)
  if \decision~ok then return decision
  env=.FederationBankStaffAuthorityEnvelope~new(envelopeId,action,action~sessionId,decision~value,validUntil)~seal
  d=.directory~new; d["decision"]=decision~value; d["envelope"]=env
  return .FederationBankStaffAuthorityResult~success(d)

/* Verifies an ordinary FederationBankCommand remains exactly the action that
 * was authorised.  It does not invoke Core Banking and never accepts WEB/ATM. */
::class FederationBankStaffCommandBinder public
::method actionMatchesCommand class
  use arg action,command
  if action==.nil | command==.nil then return .false
  if action~authorityScope<>.FederationBankStaffAuthorityBuild~SCOPE_CUSTOMER then return .false
  if command~channel<>.FederationBankStaffAuthorityBuild~CHANNEL then return .false
  if action~commandId<>command~commandId | action~idempotencyKey<>command~idempotencyKey then return .false
  if action~staffId<>command~actorId | action~operation<>command~operation | action~customerId<>command~customerId then return .false
  if action~sourceAccountId<>command~sourceAccountId | action~targetAccountId<>command~targetAccountId then return .false
  if action~currency<>command~currency | action~amountMinor<>command~amountMinor then return .false
  return .true
::method bind class
  use arg action,envelope,command
  if action==.nil | envelope==.nil | command==.nil then return .FederationBankStaffAuthorityResult~failure("STAFF_BINDING_INPUT_REQUIRED")
  if \envelope~binds(action) then return .FederationBankStaffAuthorityResult~failure("STAFF_AUTHORITY_ACTION_MISMATCH")
  if action~authorityScope<>.FederationBankStaffAuthorityBuild~SCOPE_CUSTOMER then return .FederationBankStaffAuthorityResult~failure("STAFF_AUTHORITY_SCOPE_NOT_CORE_BANKING",action~authorityScope)
  if \self~actionMatchesCommand(action,command) then return .FederationBankStaffAuthorityResult~failure("STAFF_AUTHORITY_COMMAND_MISMATCH")
  if \envelope~validAt(command~requestedAt) then return .FederationBankStaffAuthorityResult~failure("STAFF_AUTHORITY_ENVELOPE_EXPIRED")
  details=.FederationBankStaffCanonical~copyDirectory(command~details)
  details["staffAuthorityEnvelopeId"]=envelope~envelopeId
  details["staffAuthorityEnvelopeIdentity"]=envelope~semanticIdentity
  details["staffAuthorityPolicyId"]=envelope~policyId
  details["staffAuthorityPolicyVersion"]=envelope~policyVersion
  details["staffAuthorityPolicyIdentity"]=envelope~policyIdentity
  details["staffAuthorityRuleId"]=envelope~ruleId
  details["staffSessionId"]=action~sessionId
  details["staffBranchId"]=action~branchId
  details["staffDeskId"]=action~deskId
  details["staffActionId"]=action~actionId
  details["staffActionIdentity"]=action~semanticIdentity
  details["staffAuthorityScope"]=action~authorityScope
  details["staffCaseId"]=action~caseId
  return .FederationBankStaffAuthorityResult~success(.FederationBankCommand~new(command~commandId,command~operation,command~idempotencyKey,command~customerId,command~sourceAccountId,command~targetAccountId,command~currency,command~amountMinor,"STAFF",command~actorId,command~requestedAt,command~productCode,command~accountId,command~legalName,command~dateOfBirth,command~postcode,command~addressCountry,command~applicantResidence,command~applicantDomicile,command~applicantSegment,command~applicantRiskTier,details))

::requires "AlchemyObject.cls"
::requires "InstitutionalPolicy.cls"
::requires "FederationBankEngine.cls"
