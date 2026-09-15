/*
 * FederationBank Intermediary Staff Authority v0.1
 *
 * Binds a FederationBank employee's INSTITUTIONAL Staff Authority to an
 * effective RID representative identity and to one exact regulated
 * intermediary request.  It is employee-side authority/attribution evidence;
 * RID remains independently authoritative for regulatory permission,
 * appointment, competence, product approval and customer evidence.
 */
::class FederationBankIntermediaryStaffAuthorityBuild public
::constant VERSION "0.1"
::constant API_VERSION "federationbank.intermediary.staff.authority/0.1"
::constant SCOPE "INSTITUTIONAL"

::class FederationBankIntermediaryStaffResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get
::method init
  expose ok code detail value
  use arg okArg,codeArg,detailArg="",valueArg=.nil
  ok=okArg; code=codeArg~string~strip~upper; detail=detailArg~string; value=valueArg
::method success class
  use arg value=.nil,detail=""
  return self~new(.true,"OK",detail,value)
::method failure class
  use arg code,detail="",value=.nil
  return self~new(.false,code,detail,value)

::class FederationBankIntermediaryStaffCanonical public
::method token class
  use arg value
  if value==.nil then return ""
  return value~string~strip~upper
::method required class
  use arg name,value
  if value==.nil then raise syntax 88.975 array(name||" is required")
  text=value~string~strip
  if text="" then raise syntax 88.975 array(name||" is required")
  return text
::method field class
  use arg tag,value=""
  if value==.nil then text="<NIL>"; else text=value~string
  return tag~string||":"||text~length||":"||text
::method dateText class
  use arg value
  if value==.nil then return ""
  if value~string="" then return ""
  return value~utcIsoDate
::method expectedStaffOperation class
  use arg activity
  select
    when self~token(activity)="INTRODUCE" then return "INTERMEDIARY_INTRODUCE"
    when self~token(activity)="ADVISE" then return "INTERMEDIARY_ADVISE"
    when self~token(activity)="ARRANGE" then return "INTERMEDIARY_ARRANGE"
    otherwise return ""
  end

/* Effective-dated attribution of a bank employee to a RID representative. */
::class FederationBankIntermediaryStaffRepresentativeBinding public
::attribute bindingId get
::attribute staffId get
::attribute firmId get
::attribute representativeId get
::attribute effectiveFrom get
::attribute effectiveUntil get
::attribute sourceSystem get
::attribute sourceRef get
::attribute sealed get
::method init
  expose bindingId staffId firmId representativeId effectiveFrom effectiveUntil sourceSystem sourceRef sealed
  use arg bindingIdArg,staffIdArg,firmIdArg,representativeIdArg,effectiveFromArg=.nil,effectiveUntilArg=.nil,sourceSystemArg="FB-IAM-RID-BINDING",sourceRefArg=""
  bindingId=.FederationBankIntermediaryStaffCanonical~required("bindingId",bindingIdArg)~upper
  staffId=.FederationBankIntermediaryStaffCanonical~required("staffId",staffIdArg)
  firmId=.FederationBankIntermediaryStaffCanonical~required("firmId",firmIdArg)~upper
  representativeId=.FederationBankIntermediaryStaffCanonical~required("representativeId",representativeIdArg)~upper
  if effectiveFromArg==.nil then effectiveFrom=.DateTime~new; else effectiveFrom=effectiveFromArg
  effectiveUntil=effectiveUntilArg
  sourceSystem=.FederationBankIntermediaryStaffCanonical~required("sourceSystem",sourceSystemArg)~upper
  sourceRef=.FederationBankIntermediaryStaffCanonical~required("sourceRef",sourceRefArg)
  sealed=.false
::method seal
  expose sealed
  sealed=.true; return self
::method activeAt
  expose sealed effectiveFrom effectiveUntil
  use arg moment
  if \sealed then return .false
  if moment<effectiveFrom then return .false
  if effectiveUntil==.nil then return .true
  if effectiveUntil~string="" then return .true
  return moment<effectiveUntil
::method matches
  expose sealed staffId firmId representativeId
  use arg staffIdArg,firmIdArg,representativeIdArg,moment
  return sealed & self~activeAt(moment) & staffId=staffIdArg~string & firmId=.FederationBankIntermediaryStaffCanonical~token(firmIdArg) & representativeId=.FederationBankIntermediaryStaffCanonical~token(representativeIdArg)
::method canonicalText
  expose bindingId staffId firmId representativeId effectiveFrom effectiveUntil sourceSystem sourceRef sealed
  if \sealed then raise syntax 88.976 array("Intermediary staff representative binding must be sealed")
  text="FB-INTERMEDIARY-STAFF-REP-BINDING/1"
  text||=.FederationBankIntermediaryStaffCanonical~field("BINDING",bindingId)
  text||=.FederationBankIntermediaryStaffCanonical~field("STAFF",staffId)
  text||=.FederationBankIntermediaryStaffCanonical~field("FIRM",firmId)
  text||=.FederationBankIntermediaryStaffCanonical~field("REP",representativeId)
  text||=.FederationBankIntermediaryStaffCanonical~field("FROM",effectiveFrom~utcIsoDate)
  text||=.FederationBankIntermediaryStaffCanonical~field("UNTIL",.FederationBankIntermediaryStaffCanonical~dateText(effectiveUntil))
  text||=.FederationBankIntermediaryStaffCanonical~field("SOURCE",sourceSystem)
  text||=.FederationBankIntermediaryStaffCanonical~field("REF",sourceRef)
  return text
::method semanticIdentity
  return self~canonicalText

/* Exact proposed regulated-intermediary action presented by a bank employee. */
::class FederationBankIntermediaryStaffRequest public
::attribute requestId get
::attribute staffId get
::attribute staffActionId get
::attribute staffActionIdentity get
::attribute firmId get
::attribute representativeId get
::attribute productRefId get
::attribute productSemanticIdentity get
::attribute productFamily get
::attribute jurisdiction get
::attribute activity get
::attribute adviceMode get
::attribute caseId get
::attribute requestedAt get
::attribute sealed get
::method init
  expose requestId staffId staffActionId staffActionIdentity firmId representativeId productRefId productSemanticIdentity productFamily jurisdiction activity adviceMode caseId requestedAt sealed
  use arg requestIdArg,staffActionArg,firmIdArg,representativeIdArg,productRefIdArg,productSemanticIdentityArg,productFamilyArg,jurisdictionArg,activityArg,adviceModeArg,caseIdArg,requestedAtArg=.nil
  requestId=.FederationBankIntermediaryStaffCanonical~required("requestId",requestIdArg)~upper
  if staffActionArg==.nil | \staffActionArg~isA(.FederationBankStaffActionIntent) then raise syntax 88.977 array("staffAction must be FederationBankStaffActionIntent")
  if \staffActionArg~sealed then raise syntax 88.977 array("staffAction must be sealed")
  staffId=staffActionArg~staffId; staffActionId=staffActionArg~actionId; staffActionIdentity=staffActionArg~semanticIdentity
  firmId=.FederationBankIntermediaryStaffCanonical~required("firmId",firmIdArg)~upper
  representativeId=.FederationBankIntermediaryStaffCanonical~required("representativeId",representativeIdArg)~upper
  productRefId=.FederationBankIntermediaryStaffCanonical~required("productRefId",productRefIdArg)~upper
  productSemanticIdentity=.FederationBankIntermediaryStaffCanonical~required("productSemanticIdentity",productSemanticIdentityArg)
  productFamily=.FederationBankIntermediaryStaffCanonical~required("productFamily",productFamilyArg)~upper
  jurisdiction=.FederationBankIntermediaryStaffCanonical~required("jurisdiction",jurisdictionArg)~upper
  activity=.FederationBankIntermediaryStaffCanonical~required("activity",activityArg)~upper
  adviceMode=.FederationBankIntermediaryStaffCanonical~required("adviceMode",adviceModeArg)~upper
  caseId=.FederationBankIntermediaryStaffCanonical~required("caseId",caseIdArg)~upper
  if requestedAtArg==.nil then requestedAt=staffActionArg~requestedAt; else requestedAt=requestedAtArg
  sealed=.false
::method seal
  expose sealed
  sealed=.true; return self
::method bindsAction
  expose sealed staffId staffActionId staffActionIdentity caseId requestedAt
  use arg action
  if \sealed | action==.nil then return .false
  if \action~isA(.FederationBankStaffActionIntent) | \action~sealed then return .false
  return staffId=action~staffId & staffActionId=action~actionId & staffActionIdentity=action~semanticIdentity & caseId=.FederationBankIntermediaryStaffCanonical~token(action~caseId) & requestedAt=action~requestedAt
::method canonicalText
  expose requestId staffId staffActionId staffActionIdentity firmId representativeId productRefId productSemanticIdentity productFamily jurisdiction activity adviceMode caseId requestedAt sealed
  if \sealed then raise syntax 88.978 array("Intermediary staff request must be sealed")
  text="FB-INTERMEDIARY-STAFF-REQUEST/1"
  text||=.FederationBankIntermediaryStaffCanonical~field("REQUEST",requestId)
  text||=.FederationBankIntermediaryStaffCanonical~field("STAFF",staffId)
  text||=.FederationBankIntermediaryStaffCanonical~field("STAFF_ACTION",staffActionId)
  text||=.FederationBankIntermediaryStaffCanonical~field("STAFF_ACTION_IDENTITY",staffActionIdentity)
  text||=.FederationBankIntermediaryStaffCanonical~field("FIRM",firmId)
  text||=.FederationBankIntermediaryStaffCanonical~field("REP",representativeId)
  text||=.FederationBankIntermediaryStaffCanonical~field("PRODUCT_REF",productRefId)
  text||=.FederationBankIntermediaryStaffCanonical~field("PRODUCT_IDENTITY",productSemanticIdentity)
  text||=.FederationBankIntermediaryStaffCanonical~field("PRODUCT_FAMILY",productFamily)
  text||=.FederationBankIntermediaryStaffCanonical~field("JURISDICTION",jurisdiction)
  text||=.FederationBankIntermediaryStaffCanonical~field("ACTIVITY",activity)
  text||=.FederationBankIntermediaryStaffCanonical~field("ADVICE_MODE",adviceMode)
  text||=.FederationBankIntermediaryStaffCanonical~field("CASE",caseId)
  text||=.FederationBankIntermediaryStaffCanonical~field("AT",requestedAt~utcIsoDate)
  return text
::method semanticIdentity
  return self~canonicalText

/* Employee-side evidence that all exact RID action dimensions were bound. */
::class FederationBankIntermediaryStaffAuthorityEnvelope public
::attribute envelopeId get
::attribute requestId get
::attribute requestIdentity get
::attribute staffId get
::attribute staffActionIdentity get
::attribute staffAuthorityEnvelopeIdentity get
::attribute representativeBindingIdentity get
::attribute firmId get
::attribute representativeId get
::attribute productRefId get
::attribute productSemanticIdentity get
::attribute productFamily get
::attribute jurisdiction get
::attribute activity get
::attribute adviceMode get
::attribute caseId get
::attribute issuedAt get
::attribute validUntil get
::attribute sealed get
::method init
  expose envelopeId requestId requestIdentity staffId staffActionIdentity staffAuthorityEnvelopeIdentity representativeBindingIdentity firmId representativeId productRefId productSemanticIdentity productFamily jurisdiction activity adviceMode caseId issuedAt validUntil sealed
  use arg envelopeIdArg,requestArg,staffAuthorityEnvelopeArg,representativeBindingArg,issuedAtArg=.nil,validUntilArg=.nil
  envelopeId=.FederationBankIntermediaryStaffCanonical~required("envelopeId",envelopeIdArg)~upper
  requestId=requestArg~requestId; requestIdentity=requestArg~semanticIdentity; staffId=requestArg~staffId; staffActionIdentity=requestArg~staffActionIdentity
  staffAuthorityEnvelopeIdentity=staffAuthorityEnvelopeArg~semanticIdentity; representativeBindingIdentity=representativeBindingArg~semanticIdentity
  firmId=requestArg~firmId; representativeId=requestArg~representativeId; productRefId=requestArg~productRefId; productSemanticIdentity=requestArg~productSemanticIdentity; productFamily=requestArg~productFamily; jurisdiction=requestArg~jurisdiction; activity=requestArg~activity; adviceMode=requestArg~adviceMode; caseId=requestArg~caseId
  if issuedAtArg==.nil then issuedAt=requestArg~requestedAt; else issuedAt=issuedAtArg
  validUntil=validUntilArg; sealed=.false
::method seal
  expose sealed
  sealed=.true; return self
::method validAt
  expose sealed issuedAt validUntil
  use arg moment
  if \sealed | moment<issuedAt then return .false
  if validUntil==.nil then return .true
  if validUntil~string="" then return .true
  return moment<validUntil
::method binds
  expose sealed requestIdentity staffActionIdentity firmId representativeId productRefId productSemanticIdentity productFamily jurisdiction activity adviceMode caseId
  use arg request,action,ridCase,product
  if \sealed | request==.nil | action==.nil | ridCase==.nil | product==.nil then return .false
  if requestIdentity<>request~semanticIdentity | staffActionIdentity<>action~semanticIdentity then return .false
  if firmId<>ridCase~firmId | representativeId<>ridCase~representativeId | caseId<>ridCase~caseId then return .false
  if productRefId<>product~productRefId | productSemanticIdentity<>product~productSemanticIdentity | productFamily<>product~productFamily then return .false
  if jurisdiction<>ridCase~jurisdiction | jurisdiction<>product~jurisdiction | adviceMode<>ridCase~adviceMode then return .false
  return activity=request~activity
::method canonicalText
  expose envelopeId requestId requestIdentity staffId staffActionIdentity staffAuthorityEnvelopeIdentity representativeBindingIdentity firmId representativeId productRefId productSemanticIdentity productFamily jurisdiction activity adviceMode caseId issuedAt validUntil sealed
  if \sealed then raise syntax 88.979 array("Intermediary staff authority envelope must be sealed")
  text="FB-INTERMEDIARY-STAFF-AUTHORITY/1"
  text||=.FederationBankIntermediaryStaffCanonical~field("ENVELOPE",envelopeId)
  text||=.FederationBankIntermediaryStaffCanonical~field("REQUEST",requestId)
  text||=.FederationBankIntermediaryStaffCanonical~field("REQUEST_IDENTITY",requestIdentity)
  text||=.FederationBankIntermediaryStaffCanonical~field("STAFF",staffId)
  text||=.FederationBankIntermediaryStaffCanonical~field("STAFF_ACTION_IDENTITY",staffActionIdentity)
  text||=.FederationBankIntermediaryStaffCanonical~field("STAFF_AUTHORITY",staffAuthorityEnvelopeIdentity)
  text||=.FederationBankIntermediaryStaffCanonical~field("REP_BINDING",representativeBindingIdentity)
  text||=.FederationBankIntermediaryStaffCanonical~field("FIRM",firmId)
  text||=.FederationBankIntermediaryStaffCanonical~field("REP",representativeId)
  text||=.FederationBankIntermediaryStaffCanonical~field("PRODUCT_REF",productRefId)
  text||=.FederationBankIntermediaryStaffCanonical~field("PRODUCT_IDENTITY",productSemanticIdentity)
  text||=.FederationBankIntermediaryStaffCanonical~field("PRODUCT_FAMILY",productFamily)
  text||=.FederationBankIntermediaryStaffCanonical~field("JURISDICTION",jurisdiction)
  text||=.FederationBankIntermediaryStaffCanonical~field("ACTIVITY",activity)
  text||=.FederationBankIntermediaryStaffCanonical~field("ADVICE_MODE",adviceMode)
  text||=.FederationBankIntermediaryStaffCanonical~field("CASE",caseId)
  text||=.FederationBankIntermediaryStaffCanonical~field("ISSUED",issuedAt~utcIsoDate)
  text||=.FederationBankIntermediaryStaffCanonical~field("VALID_UNTIL",.FederationBankIntermediaryStaffCanonical~dateText(validUntil))
  return text
::method semanticIdentity
  return self~canonicalText

::class FederationBankIntermediaryStaffAuthorityEngine public
::method authorise
  use arg envelopeId,request,action,staffAuthorityEnvelope,representativeBinding,ridCase,product,intermediaryRegistry,validUntil=.nil
  if request==.nil | \request~isA(.FederationBankIntermediaryStaffRequest) | \request~sealed then return .FederationBankIntermediaryStaffResult~failure("INTERMEDIARY_STAFF_REQUEST_REQUIRED")
  if action==.nil | \action~isA(.FederationBankStaffActionIntent) | \action~sealed then return .FederationBankIntermediaryStaffResult~failure("INTERMEDIARY_STAFF_ACTION_REQUIRED")
  if action~authorityScope<>.FederationBankIntermediaryStaffAuthorityBuild~SCOPE then return .FederationBankIntermediaryStaffResult~failure("INTERMEDIARY_STAFF_SCOPE_REQUIRED",action~authorityScope)
  if \request~bindsAction(action) then return .FederationBankIntermediaryStaffResult~failure("INTERMEDIARY_STAFF_ACTION_MISMATCH")
  if staffAuthorityEnvelope==.nil | \staffAuthorityEnvelope~isA(.FederationBankStaffAuthorityEnvelope) | \staffAuthorityEnvelope~sealed then return .FederationBankIntermediaryStaffResult~failure("INTERMEDIARY_STAFF_AUTHORITY_REQUIRED")
  if staffAuthorityEnvelope~authorityScope<>.FederationBankIntermediaryStaffAuthorityBuild~SCOPE then return .FederationBankIntermediaryStaffResult~failure("INTERMEDIARY_STAFF_AUTHORITY_SCOPE_MISMATCH")
  if \staffAuthorityEnvelope~binds(action) then return .FederationBankIntermediaryStaffResult~failure("INTERMEDIARY_STAFF_AUTHORITY_ACTION_MISMATCH")
  if \staffAuthorityEnvelope~validAt(request~requestedAt) then return .FederationBankIntermediaryStaffResult~failure("INTERMEDIARY_STAFF_AUTHORITY_EXPIRED")
  expected=.FederationBankIntermediaryStaffCanonical~expectedStaffOperation(request~activity)
  if expected="" | action~operation<>expected then return .FederationBankIntermediaryStaffResult~failure("INTERMEDIARY_OPERATION_ACTIVITY_MISMATCH",action~operation||"/"||request~activity)
  if action~caseId<>request~caseId then return .FederationBankIntermediaryStaffResult~failure("INTERMEDIARY_CASE_MISMATCH")
  if representativeBinding==.nil | \representativeBinding~isA(.FederationBankIntermediaryStaffRepresentativeBinding) | \representativeBinding~sealed then return .FederationBankIntermediaryStaffResult~failure("INTERMEDIARY_STAFF_REPRESENTATIVE_BINDING_REQUIRED")
  if \representativeBinding~activeAt(request~requestedAt) then return .FederationBankIntermediaryStaffResult~failure("INTERMEDIARY_STAFF_BINDING_NOT_EFFECTIVE")
  if representativeBinding~staffId<>request~staffId then return .FederationBankIntermediaryStaffResult~failure("INTERMEDIARY_STAFF_IDENTITY_MISMATCH")
  if representativeBinding~firmId<>request~firmId then return .FederationBankIntermediaryStaffResult~failure("INTERMEDIARY_STAFF_FIRM_MISMATCH")
  if representativeBinding~representativeId<>request~representativeId then return .FederationBankIntermediaryStaffResult~failure("INTERMEDIARY_STAFF_REPRESENTATIVE_MISMATCH")
  if ridCase==.nil | \ridCase~isA(.RIDDistributionCase) then return .FederationBankIntermediaryStaffResult~failure("INTERMEDIARY_RID_CASE_REQUIRED")
  if ridCase~caseId<>request~caseId then return .FederationBankIntermediaryStaffResult~failure("INTERMEDIARY_CASE_MISMATCH")
  if ridCase~firmId<>request~firmId then return .FederationBankIntermediaryStaffResult~failure("INTERMEDIARY_FIRM_MISMATCH")
  if ridCase~representativeId<>request~representativeId then return .FederationBankIntermediaryStaffResult~failure("INTERMEDIARY_REPRESENTATIVE_MISMATCH")
  if ridCase~productRefId<>request~productRefId | ridCase~productSemanticIdentity<>request~productSemanticIdentity then return .FederationBankIntermediaryStaffResult~failure("INTERMEDIARY_PRODUCT_IDENTITY_MISMATCH")
  if ridCase~jurisdiction<>request~jurisdiction then return .FederationBankIntermediaryStaffResult~failure("INTERMEDIARY_JURISDICTION_MISMATCH")
  if ridCase~adviceMode<>request~adviceMode then return .FederationBankIntermediaryStaffResult~failure("INTERMEDIARY_ADVICE_MODE_MISMATCH")
  if product==.nil | \product~isA(.RIDProductReference) then return .FederationBankIntermediaryStaffResult~failure("INTERMEDIARY_PRODUCT_REQUIRED")
  if product~productRefId<>request~productRefId | product~productSemanticIdentity<>request~productSemanticIdentity then return .FederationBankIntermediaryStaffResult~failure("INTERMEDIARY_PRODUCT_IDENTITY_MISMATCH")
  if product~productFamily<>request~productFamily then return .FederationBankIntermediaryStaffResult~failure("INTERMEDIARY_PRODUCT_FAMILY_MISMATCH")
  if product~jurisdiction<>request~jurisdiction then return .FederationBankIntermediaryStaffResult~failure("INTERMEDIARY_JURISDICTION_MISMATCH")
  if intermediaryRegistry==.nil | \intermediaryRegistry~isA(.RIDIntermediaryRegistry) then return .FederationBankIntermediaryStaffResult~failure("INTERMEDIARY_REGISTRY_REQUIRED")
  pair=intermediaryRegistry~activePair(request~firmId,request~representativeId)
  if \pair~ok then return .FederationBankIntermediaryStaffResult~failure(pair~code,pair~detail,pair~value)
  env=.FederationBankIntermediaryStaffAuthorityEnvelope~new(envelopeId,request,staffAuthorityEnvelope,representativeBinding,request~requestedAt,validUntil)~seal
  return .FederationBankIntermediaryStaffResult~success(env)

::requires "FederationBankStaffAuthority.cls"
::requires "RegulatedIntermediaryDistribution.cls"
