/*
 * FederationBank Staff Channel v0.1
 *
 * Backend orchestration semantics for staff-originated banking work.  This is
 * deliberately not a UI component.  It coordinates already-authoritative
 * relationship decisions (where required), exact staff authority and ordinary
 * FederationBank Core Banking submission without becoming any of those
 * authorities itself.
 */

::class FederationBankStaffChannelBuild public
::constant VERSION "0.1"
::constant API_VERSION "federationbank.staff.channel/0.1"
::constant PRODUCT "FederationBank Staff Channel"
::constant DEFAULT_POLICY_ID "FB-STAFF-CHANNEL"
::constant CHANNEL "STAFF"

::class FederationBankStaffChannelCanonical public
::method token class
  use arg value
  if value==.nil then return ""
  return value~string~strip~upper
::method field class
  use arg tag,value=""
  if value==.nil then text="<NIL>"; else text=value~string
  return tag~string||":"||text~length||":"||text
::method copyDirectory class
  use arg source
  out=.directory~new
  if source==.nil then return out
  do key over source; out[key]=source[key]; end
  return out
::method copyArray class
  use arg source
  out=.array~new
  if source==.nil then return out
  do item over source; out~append(item); end
  return out
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
::method detailsText class
  use arg details
  if details==.nil then return ""
  keys=.array~new
  do key over details; keys~append(key~string); end
  keys~sort
  text=""
  do key over keys; text||=self~field("DETAIL:"||key,details[key]); end
  return text

::class FederationBankStaffChannelResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get
::method init
  expose ok code detail value
  use arg okArg,codeArg,detailArg="",valueArg=.nil
  ok=okArg; code=.FederationBankStaffChannelCanonical~token(codeArg); detail=detailArg~string; value=valueArg
::method success class
  use arg value=.nil,detail=""
  return self~new(.true,"OK",detail,value)
::method failure class
  use arg code,detail="",value=.nil
  return self~new(.false,code,detail,value)

::class FederationBankStaffChannelAlchemyContext public
::attribute sealer get
::attribute authority get
::method init
  expose sealer authority
  use arg sealerArg=.nil,authorityArg=.nil
  sealer=sealerArg; authority=authorityArg

::class FederationBankStaffChannelAlchemyObject subclass AlchemyObject public
::attribute domainObjectKind get
::method initChannelAlchemy protected
  expose domainObjectKind
  use arg kindArg,contextArg=.nil
  kind=.FederationBankStaffChannelCanonical~token(kindArg)
  sealer=.nil; authority=.nil
  if contextArg<>.nil then do
    if \contextArg~isA(.FederationBankStaffChannelAlchemyContext) then raise syntax 88.970 array("FederationBank Staff Channel Alchemy context invalid")
    sealer=contextArg~sealer; authority=contextArg~authority
  end
  meta=.directory~new
  meta["PURPOSE"]="backend orchestration of FederationBank STAFF-channel work"
  meta["PACKAGE"]="federationbank_staff_channel"
  meta["PACKAGE_VERSION"]=.FederationBankStaffChannelBuild~VERSION
  meta["DOMAIN_OBJECT_KIND"]=kind
  meta["DESIGN_LIMITATIONS"]="Does not decide relationship facts, workforce authority, customer/product policy, legal effect or Ledger truth."
  self~init:super(meta,sealer,authority)
  domainObjectKind=kind
  self~registerExternalRequirement("library","alchemy_objects","0.8",.true)
  return self

/* Durable exact snapshot of an ordinary FederationBankCommand.  Core's command
 * object predates Queue Fabric graph persistence, so the channel snapshots it
 * rather than teaching Core Banking about orchestration persistence. */
::class FederationBankStaffChannelCommandSnapshot subclass FederationBankStaffChannelAlchemyObject public
::attribute commandId get
::attribute operation get
::attribute idempotencyKey get
::attribute customerId get
::attribute sourceAccountId get
::attribute targetAccountId get
::attribute currency get
::attribute amountMinor get
::attribute channel get
::attribute actorId get
::attribute requestedAt get
::attribute productCode get
::attribute accountId get
::attribute legalName get
::attribute dateOfBirth get
::attribute postcode get
::attribute addressCountry get
::attribute applicantResidence get
::attribute applicantDomicile get
::attribute applicantSegment get
::attribute applicantRiskTier get
::attribute sealed get
::method init
  expose commandId operation idempotencyKey customerId sourceAccountId targetAccountId currency amountMinor channel actorId requestedAt productCode accountId legalName dateOfBirth postcode addressCountry applicantResidence applicantDomicile applicantSegment applicantRiskTier details sealed
  use arg commandIdArg,operationArg,idempotencyKeyArg,customerIdArg,sourceAccountIdArg="",targetAccountIdArg="",currencyArg="",amountMinorArg=0,channelArg="STAFF",actorIdArg="",requestedAtArg=.nil,productCodeArg="",accountIdArg="",legalNameArg="",dateOfBirthArg="",postcodeArg="",addressCountryArg="",applicantResidenceArg="",applicantDomicileArg="",applicantSegmentArg="RETAIL",applicantRiskTierArg="STANDARD",detailsArg=.nil,contextArg=.nil
  self~initChannelAlchemy("BANKCOMMANDSNAPSHOT",contextArg)
  commandId=commandIdArg~string; operation=.FederationBankStaffChannelCanonical~token(operationArg); idempotencyKey=idempotencyKeyArg~string; customerId=customerIdArg~string
  sourceAccountId=sourceAccountIdArg~string; targetAccountId=targetAccountIdArg~string; currency=.FederationBankStaffChannelCanonical~token(currencyArg); amountMinor=amountMinorArg+0; channel=.FederationBankStaffChannelCanonical~token(channelArg); actorId=actorIdArg~string
  if requestedAtArg==.nil then requestedAt=.DateTime~new; else requestedAt=requestedAtArg
  productCode=.FederationBankStaffChannelCanonical~token(productCodeArg); accountId=accountIdArg~string; legalName=legalNameArg~string; dateOfBirth=dateOfBirthArg~string; postcode=postcodeArg~string~upper; addressCountry=.FederationBankStaffChannelCanonical~token(addressCountryArg); applicantResidence=.FederationBankStaffChannelCanonical~token(applicantResidenceArg); applicantDomicile=.FederationBankStaffChannelCanonical~token(applicantDomicileArg); applicantSegment=.FederationBankStaffChannelCanonical~token(applicantSegmentArg); applicantRiskTier=.FederationBankStaffChannelCanonical~token(applicantRiskTierArg); details=.FederationBankStaffChannelCanonical~copyDirectory(detailsArg); sealed=.false
  if commandId="" | operation="" | idempotencyKey="" | customerId="" | actorId="" then raise syntax 88.971 array("Staff Channel command identity required")
::method details
  expose details
  return .FederationBankStaffChannelCanonical~copyDirectory(details)
::method seal
  expose sealed
  sealed=.true; return self
::method fromCommand class
  use arg command,contextArg=.nil
  if command==.nil then return .nil
  return self~new(command~commandId,command~operation,command~idempotencyKey,command~customerId,command~sourceAccountId,command~targetAccountId,command~currency,command~amountMinor,command~channel,command~actorId,command~requestedAt,command~productCode,command~accountId,command~legalName,command~dateOfBirth,command~postcode,command~addressCountry,command~applicantResidence,command~applicantDomicile,command~applicantSegment,command~applicantRiskTier,command~details,contextArg)~seal
::method toCommand
  expose commandId operation idempotencyKey customerId sourceAccountId targetAccountId currency amountMinor channel actorId requestedAt productCode accountId legalName dateOfBirth postcode addressCountry applicantResidence applicantDomicile applicantSegment applicantRiskTier sealed
  if \sealed then raise syntax 88.972 array("Staff Channel command snapshot must be sealed")
  return .FederationBankCommand~new(commandId,operation,idempotencyKey,customerId,sourceAccountId,targetAccountId,currency,amountMinor,channel,actorId,requestedAt,productCode,accountId,legalName,dateOfBirth,postcode,addressCountry,applicantResidence,applicantDomicile,applicantSegment,applicantRiskTier,self~details)
::method canonicalText
  expose commandId operation idempotencyKey customerId sourceAccountId targetAccountId currency amountMinor channel actorId requestedAt productCode accountId legalName dateOfBirth postcode addressCountry applicantResidence applicantDomicile applicantSegment applicantRiskTier details sealed
  if \sealed then raise syntax 88.973 array("Staff Channel command snapshot must be sealed")
  text="FB-STAFF-CHANNEL-COMMAND/1"
  text||=.FederationBankStaffChannelCanonical~field("COMMAND",commandId); text||=.FederationBankStaffChannelCanonical~field("OP",operation); text||=.FederationBankStaffChannelCanonical~field("IDEMPOTENCY",idempotencyKey); text||=.FederationBankStaffChannelCanonical~field("CUSTOMER",customerId); text||=.FederationBankStaffChannelCanonical~field("SOURCE",sourceAccountId); text||=.FederationBankStaffChannelCanonical~field("TARGET",targetAccountId); text||=.FederationBankStaffChannelCanonical~field("CURRENCY",currency); text||=.FederationBankStaffChannelCanonical~field("AMOUNT",amountMinor); text||=.FederationBankStaffChannelCanonical~field("CHANNEL",channel); text||=.FederationBankStaffChannelCanonical~field("ACTOR",actorId); text||=.FederationBankStaffChannelCanonical~field("AT",requestedAt~utcIsoDate)
  text||=.FederationBankStaffChannelCanonical~field("PRODUCT",productCode); text||=.FederationBankStaffChannelCanonical~field("ACCOUNT",accountId); text||=.FederationBankStaffChannelCanonical~field("LEGAL_NAME",legalName); text||=.FederationBankStaffChannelCanonical~field("DOB",dateOfBirth); text||=.FederationBankStaffChannelCanonical~field("POSTCODE",postcode); text||=.FederationBankStaffChannelCanonical~field("ADDRESS_COUNTRY",addressCountry); text||=.FederationBankStaffChannelCanonical~field("RESIDENCE",applicantResidence); text||=.FederationBankStaffChannelCanonical~field("DOMICILE",applicantDomicile); text||=.FederationBankStaffChannelCanonical~field("SEGMENT",applicantSegment); text||=.FederationBankStaffChannelCanonical~field("RISK",applicantRiskTier); text||=.FederationBankStaffChannelCanonical~detailsText(details)
  return text
::method semanticIdentity
  return self~canonicalText
::method queuePersistentType
  return "federationbank.staff.channel.command/1"
::method queuePersistentState
  expose commandId operation idempotencyKey customerId sourceAccountId targetAccountId currency amountMinor channel actorId requestedAt productCode accountId legalName dateOfBirth postcode addressCountry applicantResidence applicantDomicile applicantSegment applicantRiskTier sealed
  if \sealed then raise syntax 88.974 array("Unsealed Staff Channel command cannot cross durable boundary")
  s=.table~new; s["commandId"]=commandId; s["operation"]=operation; s["idempotencyKey"]=idempotencyKey; s["customerId"]=customerId; s["sourceAccountId"]=sourceAccountId; s["targetAccountId"]=targetAccountId; s["currency"]=currency; s["amountMinor"]=amountMinor~string; s["channel"]=channel; s["actorId"]=actorId; s["requestedAt"]=requestedAt~utcIsoDate; s["productCode"]=productCode; s["accountId"]=accountId; s["legalName"]=legalName; s["dateOfBirth"]=dateOfBirth; s["postcode"]=postcode; s["addressCountry"]=addressCountry; s["applicantResidence"]=applicantResidence; s["applicantDomicile"]=applicantDomicile; s["applicantSegment"]=applicantSegment; s["applicantRiskTier"]=applicantRiskTier; s["details"]=self~details; return s
::method queueRestoreState
  expose commandId operation idempotencyKey customerId sourceAccountId targetAccountId currency amountMinor channel actorId requestedAt productCode accountId legalName dateOfBirth postcode addressCountry applicantResidence applicantDomicile applicantSegment applicantRiskTier details sealed
  use arg s
  commandId=s["commandId"]~string; operation=.FederationBankStaffChannelCanonical~token(s["operation"]); idempotencyKey=s["idempotencyKey"]~string; customerId=s["customerId"]~string; sourceAccountId=s["sourceAccountId"]~string; targetAccountId=s["targetAccountId"]~string; currency=.FederationBankStaffChannelCanonical~token(s["currency"]); amountMinor=s["amountMinor"]+0; channel=.FederationBankStaffChannelCanonical~token(s["channel"]); actorId=s["actorId"]~string; requestedAt=.FederationBankStaffChannelCanonical~dateValue(s["requestedAt"]); productCode=.FederationBankStaffChannelCanonical~token(s["productCode"]); accountId=s["accountId"]~string; legalName=s["legalName"]~string; dateOfBirth=s["dateOfBirth"]~string; postcode=s["postcode"]~string; addressCountry=.FederationBankStaffChannelCanonical~token(s["addressCountry"]); applicantResidence=.FederationBankStaffChannelCanonical~token(s["applicantResidence"]); applicantDomicile=.FederationBankStaffChannelCanonical~token(s["applicantDomicile"]); applicantSegment=.FederationBankStaffChannelCanonical~token(s["applicantSegment"]); applicantRiskTier=.FederationBankStaffChannelCanonical~token(s["applicantRiskTier"]); details=.FederationBankStaffChannelCanonical~copyDirectory(s["details"]); sealed=.true; return self

/* Durable evidence that a Relationship Adapter has already translated a
 * Relationship Case decision.  The channel never reconstructs authority from
 * CRM text, external signals or a case label. */
::class FederationBankStaffChannelRelationshipEvidence subclass FederationBankStaffChannelAlchemyObject public
::attribute outcome get
::attribute caseId get
::attribute decisionId get
::attribute decisionIdentity get
::attribute commandIdentity get
::attribute policyId get
::attribute policyVersion get
::attribute policyIdentity get
::attribute ruleId get
::attribute sealed get
::method init
  expose outcome caseId decisionId decisionIdentity commandIdentity policyId policyVersion policyIdentity ruleId sealed
  use arg outcomeArg,caseIdArg,decisionIdArg,decisionIdentityArg,commandIdentityArg="",policyIdArg="",policyVersionArg="",policyIdentityArg="",ruleIdArg="",contextArg=.nil
  self~initChannelAlchemy("RELATIONSHIPAUTHORITYEVIDENCE",contextArg)
  outcome=.FederationBankStaffChannelCanonical~token(outcomeArg); caseId=caseIdArg~string; decisionId=decisionIdArg~string; decisionIdentity=decisionIdentityArg~string; commandIdentity=commandIdentityArg~string; policyId=.FederationBankStaffChannelCanonical~token(policyIdArg); policyVersion=policyVersionArg~string; policyIdentity=policyIdentityArg~string; ruleId=.FederationBankStaffChannelCanonical~token(ruleIdArg); sealed=.false
  if outcome="" | caseId="" | decisionId="" | decisionIdentity="" then raise syntax 88.975 array("Relationship authority evidence identity required")
::method fromTranslation class
  use arg translation,contextArg=.nil
  if translation==.nil | \translation~hasMethod("OUTCOME") then return .FederationBankStaffChannelResult~failure("RELATIONSHIP_TRANSLATION_REQUIRED")
  decision=translation~decision; if decision==.nil then return .FederationBankStaffChannelResult~failure("RELATIONSHIP_DECISION_REQUIRED")
  commandIdentity=""
  if translation~outcome="SUBMIT_BANK_COMMAND" then do
    if translation~bankCommand==.nil then return .FederationBankStaffChannelResult~failure("RELATIONSHIP_TRANSLATED_COMMAND_REQUIRED")
    commandIdentity=.FederationBankStaffChannelCommandSnapshot~fromCommand(translation~bankCommand)~semanticIdentity
  end
  policy=translation~policyEvidence; policyId=""; policyVersion=""; policyIdentity=""; ruleId=""
  if policy<>.nil then do
    if policy~hasIndex("policyId") then policyId=policy["policyId"]
    if policy~hasIndex("policyVersion") then policyVersion=policy["policyVersion"]
    if policy~hasIndex("policyIdentity") then policyIdentity=policy["policyIdentity"]
    if policy~hasIndex("ruleId") then ruleId=policy["ruleId"]
  end
  e=self~new(translation~outcome,decision~caseId,decision~decisionId,decision~semanticIdentity,commandIdentity,policyId,policyVersion,policyIdentity,ruleId,contextArg)~seal
  return .FederationBankStaffChannelResult~success(e)
::method seal
  expose sealed
  sealed=.true; return self
::method canonicalText
  expose outcome caseId decisionId decisionIdentity commandIdentity policyId policyVersion policyIdentity ruleId sealed
  if \sealed then raise syntax 88.976 array("Relationship authority evidence must be sealed")
  text="FB-STAFF-CHANNEL-RELATIONSHIP-EVIDENCE/1"; text||=.FederationBankStaffChannelCanonical~field("OUTCOME",outcome); text||=.FederationBankStaffChannelCanonical~field("CASE",caseId); text||=.FederationBankStaffChannelCanonical~field("DECISION",decisionId); text||=.FederationBankStaffChannelCanonical~field("DECISION_IDENTITY",decisionIdentity); text||=.FederationBankStaffChannelCanonical~field("COMMAND_IDENTITY",commandIdentity); text||=.FederationBankStaffChannelCanonical~field("POLICY",policyId||"@"||policyVersion); text||=.FederationBankStaffChannelCanonical~field("POLICY_IDENTITY",policyIdentity); text||=.FederationBankStaffChannelCanonical~field("RULE",ruleId); return text
::method semanticIdentity
  return self~canonicalText
::method queuePersistentType
  return "federationbank.staff.channel.relationship.evidence/1"
::method queuePersistentState
  expose outcome caseId decisionId decisionIdentity commandIdentity policyId policyVersion policyIdentity ruleId sealed
  if \sealed then raise syntax 88.977 array("Unsealed relationship evidence cannot cross durable boundary")
  s=.table~new; s["outcome"]=outcome; s["caseId"]=caseId; s["decisionId"]=decisionId; s["decisionIdentity"]=decisionIdentity; s["commandIdentity"]=commandIdentity; s["policyId"]=policyId; s["policyVersion"]=policyVersion; s["policyIdentity"]=policyIdentity; s["ruleId"]=ruleId; return s
::method queueRestoreState
  expose outcome caseId decisionId decisionIdentity commandIdentity policyId policyVersion policyIdentity ruleId sealed
  use arg s
  outcome=.FederationBankStaffChannelCanonical~token(s["outcome"]); caseId=s["caseId"]~string; decisionId=s["decisionId"]~string; decisionIdentity=s["decisionIdentity"]~string; commandIdentity=s["commandIdentity"]~string; policyId=.FederationBankStaffChannelCanonical~token(s["policyId"]); policyVersion=s["policyVersion"]~string; policyIdentity=s["policyIdentity"]~string; ruleId=.FederationBankStaffChannelCanonical~token(s["ruleId"]); sealed=.true; return self

::class FederationBankStaffChannelRequest subclass FederationBankStaffChannelAlchemyObject public
::attribute requestId get
::attribute workId get
::attribute originClass get
::attribute staffId get
::attribute sessionId get
::attribute branchId get
::attribute deskId get
::attribute requestedAt get
::attribute sealed get
::method init
  expose requestId workId originClass staffId sessionId branchId deskId command relationshipEvidence requestedAt metadata sealed
  use arg requestIdArg,workIdArg,originClassArg,staffIdArg,sessionIdArg,branchIdArg,deskIdArg,commandArg=.nil,relationshipEvidenceArg=.nil,requestedAtArg=.nil,metadataArg=.nil,contextArg=.nil
  self~initChannelAlchemy("STAFFCHANNELREQUEST",contextArg)
  requestId=requestIdArg~string; workId=workIdArg~string; originClass=.FederationBankStaffChannelCanonical~token(originClassArg); staffId=staffIdArg~string; sessionId=sessionIdArg~string; branchId=.FederationBankStaffChannelCanonical~token(branchIdArg); deskId=.FederationBankStaffChannelCanonical~token(deskIdArg); command=commandArg; relationshipEvidence=relationshipEvidenceArg
  if requestedAtArg==.nil then do; if command<>.nil then requestedAt=command~requestedAt; else requestedAt=.DateTime~new; end; else requestedAt=requestedAtArg
  metadata=.FederationBankStaffChannelCanonical~copyDirectory(metadataArg); sealed=.false
  if requestId="" | workId="" | originClass="" | staffId="" | sessionId="" | branchId="" | deskId="" then raise syntax 88.978 array("Staff Channel request identity/context required")
::method command
  expose command
  return command
::method relationshipEvidence
  expose relationshipEvidence
  return relationshipEvidence
::method metadata
  expose metadata
  return .FederationBankStaffChannelCanonical~copyDirectory(metadata)
::method seal
  expose sealed command relationshipEvidence
  if command<>.nil then if \command~sealed then raise syntax 88.979 array("Staff Channel command snapshot must be sealed")
  if relationshipEvidence<>.nil then if \relationshipEvidence~sealed then raise syntax 88.980 array("Relationship evidence must be sealed")
  sealed=.true; return self
::method operation
  expose command relationshipEvidence
  if command<>.nil then return command~operation
  if relationshipEvidence<>.nil then if relationshipEvidence~outcome="NO_BANK_ACTION" then return "NONE"
  return ""
::method canonicalText
  expose requestId workId originClass staffId sessionId branchId deskId command relationshipEvidence requestedAt metadata sealed
  if \sealed then raise syntax 88.981 array("Staff Channel request must be sealed")
  text="FB-STAFF-CHANNEL-REQUEST/1"; text||=.FederationBankStaffChannelCanonical~field("REQUEST",requestId); text||=.FederationBankStaffChannelCanonical~field("WORK",workId); text||=.FederationBankStaffChannelCanonical~field("ORIGIN",originClass); text||=.FederationBankStaffChannelCanonical~field("STAFF",staffId); text||=.FederationBankStaffChannelCanonical~field("SESSION",sessionId); text||=.FederationBankStaffChannelCanonical~field("BRANCH",branchId); text||=.FederationBankStaffChannelCanonical~field("DESK",deskId); text||=.FederationBankStaffChannelCanonical~field("AT",requestedAt~utcIsoDate)
  if command<>.nil then text||=.FederationBankStaffChannelCanonical~field("COMMAND",command~semanticIdentity)
  if relationshipEvidence<>.nil then text||=.FederationBankStaffChannelCanonical~field("RELATIONSHIP",relationshipEvidence~semanticIdentity)
  text||=.FederationBankStaffChannelCanonical~detailsText(metadata); return text
::method semanticIdentity
  return self~canonicalText
::method queuePersistentType
  return "federationbank.staff.channel.request/1"
::method queuePersistentState
  expose requestId workId originClass staffId sessionId branchId deskId command relationshipEvidence requestedAt metadata sealed
  if \sealed then raise syntax 88.982 array("Unsealed Staff Channel request cannot cross durable boundary")
  s=.table~new; s["requestId"]=requestId; s["workId"]=workId; s["originClass"]=originClass; s["staffId"]=staffId; s["sessionId"]=sessionId; s["branchId"]=branchId; s["deskId"]=deskId; s["command"]=command; s["relationshipEvidence"]=relationshipEvidence; s["requestedAt"]=requestedAt~utcIsoDate; s["metadata"]=self~metadata; return s
::method queueRestoreState
  expose requestId workId originClass staffId sessionId branchId deskId command relationshipEvidence requestedAt metadata sealed
  use arg s
  requestId=s["requestId"]~string; workId=s["workId"]~string; originClass=.FederationBankStaffChannelCanonical~token(s["originClass"]); staffId=s["staffId"]~string; sessionId=s["sessionId"]~string; branchId=.FederationBankStaffChannelCanonical~token(s["branchId"]); deskId=.FederationBankStaffChannelCanonical~token(s["deskId"]); command=s["command"]; relationshipEvidence=s["relationshipEvidence"]; requestedAt=.FederationBankStaffChannelCanonical~dateValue(s["requestedAt"]); metadata=.FederationBankStaffChannelCanonical~copyDirectory(s["metadata"]); sealed=.true; return self

::class FederationBankStaffChannelRule public
::attribute ruleId get
::attribute originClass get
::attribute operation get
::attribute relationshipMode get
::attribute coreRoute get
::attribute rationale get
::attribute sealed get
::method init
  expose ruleId originClass operation relationshipMode coreRoute rationale sealed
  use arg ruleIdArg,originClassArg,operationArg,relationshipModeArg="NONE",coreRouteArg="NONE",rationaleArg=""
  ruleId=.FederationBankStaffChannelCanonical~token(ruleIdArg); originClass=.FederationBankStaffChannelCanonical~token(originClassArg); operation=.FederationBankStaffChannelCanonical~token(operationArg); relationshipMode=.FederationBankStaffChannelCanonical~token(relationshipModeArg); coreRoute=.FederationBankStaffChannelCanonical~token(coreRouteArg); rationale=rationaleArg~string; sealed=.false
  if ruleId="" | originClass="" | operation="" then raise syntax 88.983 array("Staff Channel rule identity required")
::method seal
  expose relationshipMode coreRoute sealed
  if relationshipMode<>"NONE" & relationshipMode<>"REQUIRED" then raise syntax 88.984 array("Staff Channel relationship mode invalid",relationshipMode)
  if coreRoute<>"NONE" & coreRoute<>"ACCOUNT" & coreRoute<>"PAYMENTS" then raise syntax 88.985 array("Staff Channel core route invalid",coreRoute)
  sealed=.true; return self
::method matches
  expose sealed originClass operation
  use arg originArg,operationArg
  return sealed & (originClass="*" | originClass=.FederationBankStaffChannelCanonical~token(originArg)) & (operation="*" | operation=.FederationBankStaffChannelCanonical~token(operationArg))
::method specificity
  expose originClass operation
  n=0; if originClass<>"*" then n+=1; if operation<>"*" then n+=1; return n
::method semanticIdentity
  expose ruleId originClass operation relationshipMode coreRoute rationale sealed
  if \sealed then raise syntax 88.986 array("Staff Channel rule must be sealed")
  return "FB-STAFF-CHANNEL-RULE/1"||.FederationBankStaffChannelCanonical~field("RULE",ruleId)||.FederationBankStaffChannelCanonical~field("ORIGIN",originClass)||.FederationBankStaffChannelCanonical~field("OP",operation)||.FederationBankStaffChannelCanonical~field("REL",relationshipMode)||.FederationBankStaffChannelCanonical~field("ROUTE",coreRoute)||.FederationBankStaffChannelCanonical~field("RATIONALE",rationale)

::class FederationBankStaffChannelPolicy public
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
  return .FederationBankStaffChannelCanonical~copyArray(rules)
::method seal
  expose sealed
  sealed=.true; return self
::method publicationEligible
  expose sealed rules
  return sealed & rules~items>0
::method resolveRule
  expose sealed rules
  use arg originClass,operation
  if \sealed then return .FederationBankStaffChannelResult~failure("CHANNEL_POLICY_NOT_SEALED")
  best=.nil; score=-1
  do r over rules
    if r~matches(originClass,operation) then do
      s=r~specificity
      if s>score then do; best=r; score=s; end
      else if s=score then if best<>.nil then if r~ruleId<best~ruleId then best=r
    end
  end
  if best==.nil then return .FederationBankStaffChannelResult~failure("CHANNEL_POLICY_NO_RULE",originClass||"/"||operation)
  return .FederationBankStaffChannelResult~success(best)
::method semanticIdentity
  expose sealed rules
  ids=.array~new; by=.directory~new
  do r over rules; ids~append(r~ruleId); by[r~ruleId]=r; end; ids~sort
  text="FB-STAFF-CHANNEL-POLICY/1|SEALED="||sealed
  do id over ids; text||="|"||by[id]~semanticIdentity; end
  return text

::class FederationBankStaffChannelGate public
::method init
  expose catalog policyId
  use arg catalogArg,policyIdArg="FB-STAFF-CHANNEL"
  if catalogArg==.nil then raise syntax 88.987 array("Staff Channel policy catalog required")
  catalog=catalogArg; policyId=.FederationBankStaffChannelCanonical~token(policyIdArg)
::method resolve
  expose catalog policyId
  use arg atTime,originClass,operation
  r=catalog~resolve(policyId,atTime)
  if \r~ok then return .FederationBankStaffChannelResult~failure("CHANNEL_POLICY_RESOLUTION_FAILED",r~code||":"||r~detail)
  release=r~value; if release~payload==.nil then return .FederationBankStaffChannelResult~failure("CHANNEL_POLICY_PAYLOAD_REQUIRED")
  rr=release~payload~resolveRule(originClass,operation); if \rr~ok then return rr
  d=.directory~new; d["rule"]=rr~value; d["policyId"]=release~policyId; d["policyVersion"]=release~version; d["policyIdentity"]=release~semanticIdentity; return .FederationBankStaffChannelResult~success(d)

/* Work is coordination state.  It is not itself staff authority or a Core
 * Banking receipt. */
::class FederationBankStaffChannelWorkItem public
::attribute workId get
::attribute requestIdentity get
::attribute originClass get
::attribute state get
::attribute outcomeCode get
::attribute detail get
::attribute route get
::attribute policyId get
::attribute policyVersion get
::attribute policyIdentity get
::attribute ruleId get
::attribute createdAt get
::attribute updatedAt get
::attribute revision get
::method init
  expose workId requestIdentity originClass request command action boundCommand relationshipEvidence state outcomeCode detail route policyId policyVersion policyIdentity ruleId staffDecision staffEnvelope coreCode coreDetail coreValue createdAt updatedAt revision
  use arg requestArg,policyEvidenceArg=.nil
  if requestArg==.nil | \requestArg~sealed then raise syntax 88.988 array("Sealed Staff Channel request required")
  request=requestArg; workId=requestArg~workId; requestIdentity=requestArg~semanticIdentity; originClass=requestArg~originClass; command=requestArg~command; relationshipEvidence=requestArg~relationshipEvidence; action=.nil; boundCommand=.nil; state="RECEIVED"; outcomeCode=""; detail=""; route=""; staffDecision=.nil; staffEnvelope=.nil; coreCode=""; coreDetail=""; coreValue=.nil; createdAt=requestArg~requestedAt; updatedAt=createdAt; revision=1
  policyId=""; policyVersion=""; policyIdentity=""; ruleId=""
  if policyEvidenceArg<>.nil then do; policyId=policyEvidenceArg["policyId"]; policyVersion=policyEvidenceArg["policyVersion"]; policyIdentity=policyEvidenceArg["policyIdentity"]; ruleId=policyEvidenceArg["rule"]~ruleId; route=policyEvidenceArg["rule"]~coreRoute; end
::method request
  expose request
  return request
::method command
  expose command
  return command
::method action
  expose action
  return action
::method boundCommand
  expose boundCommand
  return boundCommand
::method relationshipEvidence
  expose relationshipEvidence
  return relationshipEvidence
::method staffDecision
  expose staffDecision
  return staffDecision
::method staffEnvelope
  expose staffEnvelope
  return staffEnvelope
::method coreCode
  expose coreCode
  return coreCode
::method coreDetail
  expose coreDetail
  return coreDetail
::method coreValue
  expose coreValue
  return coreValue
::method touch private
  expose updatedAt revision
  updatedAt=.DateTime~new; revision+=1
::method setAction
  expose action
  use arg actionArg
  action=actionArg; self~touch; return self
::method approvalRequired
  expose state outcomeCode detail staffDecision
  use arg decisionArg,detailArg=""
  state="APPROVAL_REQUIRED"; outcomeCode="APPROVAL_REQUIRED"; detail=detailArg~string; staffDecision=decisionArg; self~touch; return self
::method reject
  expose state outcomeCode detail staffDecision
  use arg codeArg,detailArg="",decisionArg=.nil
  state="REJECTED"; outcomeCode=.FederationBankStaffChannelCanonical~token(codeArg); detail=detailArg~string; staffDecision=decisionArg; self~touch; return self
::method noBankAction
  expose state outcomeCode detail
  use arg detailArg=""
  state="NO_BANK_ACTION"; outcomeCode="NO_BANK_ACTION"; detail=detailArg~string; self~touch; return self
::method authorised
  expose state outcomeCode detail staffDecision staffEnvelope
  use arg decisionArg,envelopeArg
  state="STAFF_AUTHORISED"; outcomeCode="STAFF_AUTHORISED"; detail=""; staffDecision=decisionArg; staffEnvelope=envelopeArg; self~touch; return self
::method readyForCore
  expose state outcomeCode detail boundCommand
  use arg boundCommandArg
  boundCommand=boundCommandArg; state="READY_FOR_CORE"; outcomeCode="READY_FOR_CORE"; detail=""; self~touch; return self
::method completeCore
  expose state outcomeCode detail coreCode coreDetail coreValue
  use arg okArg,codeArg,detailArg="",valueArg=.nil
  coreCode=.FederationBankStaffChannelCanonical~token(codeArg); coreDetail=detailArg~string; coreValue=valueArg
  if okArg then do; state="COMPLETED"; outcomeCode="CORE_ACCEPTED"; detail=coreCode; end
  else do; state="CORE_REJECTED"; outcomeCode="CORE_REJECTED"; detail=coreCode||":"||coreDetail; end
  self~touch; return self
::method queuePersistentType
  return "federationbank.staff.channel.work/1"
::method queuePersistentState
  expose workId requestIdentity originClass request command action boundCommand relationshipEvidence state outcomeCode detail route policyId policyVersion policyIdentity ruleId staffDecision staffEnvelope coreCode coreDetail coreValue createdAt updatedAt revision
  s=.table~new; s["workId"]=workId; s["requestIdentity"]=requestIdentity; s["originClass"]=originClass; s["request"]=request; s["command"]=command; s["action"]=action; s["boundCommand"]=boundCommand; s["relationshipEvidence"]=relationshipEvidence; s["state"]=state; s["outcomeCode"]=outcomeCode; s["detail"]=detail; s["route"]=route; s["policyId"]=policyId; s["policyVersion"]=policyVersion; s["policyIdentity"]=policyIdentity; s["ruleId"]=ruleId; s["staffDecision"]=staffDecision; s["staffEnvelope"]=staffEnvelope; s["coreCode"]=coreCode; s["coreDetail"]=coreDetail; s["coreValue"]=coreValue; s["createdAt"]=createdAt~utcIsoDate; s["updatedAt"]=updatedAt~utcIsoDate; s["revision"]=revision~string; return s
::method queueRestoreState
  expose workId requestIdentity originClass request command action boundCommand relationshipEvidence state outcomeCode detail route policyId policyVersion policyIdentity ruleId staffDecision staffEnvelope coreCode coreDetail coreValue createdAt updatedAt revision
  use arg s
  workId=s["workId"]~string; requestIdentity=s["requestIdentity"]~string; originClass=.FederationBankStaffChannelCanonical~token(s["originClass"]); request=s["request"]; command=s["command"]; action=s["action"]; boundCommand=s["boundCommand"]; relationshipEvidence=s["relationshipEvidence"]; state=.FederationBankStaffChannelCanonical~token(s["state"]); outcomeCode=.FederationBankStaffChannelCanonical~token(s["outcomeCode"]); detail=s["detail"]~string; route=.FederationBankStaffChannelCanonical~token(s["route"]); policyId=.FederationBankStaffChannelCanonical~token(s["policyId"]); policyVersion=s["policyVersion"]~string; policyIdentity=s["policyIdentity"]~string; ruleId=.FederationBankStaffChannelCanonical~token(s["ruleId"]); staffDecision=s["staffDecision"]; staffEnvelope=s["staffEnvelope"]; coreCode=.FederationBankStaffChannelCanonical~token(s["coreCode"]); coreDetail=s["coreDetail"]~string; coreValue=s["coreValue"]; createdAt=.FederationBankStaffChannelCanonical~dateValue(s["createdAt"]); updatedAt=.FederationBankStaffChannelCanonical~dateValue(s["updatedAt"]); revision=s["revision"]+0; return self

::class FederationBankStaffChannelStaffAuthorityPort public
::method authorise abstract

::class FederationBankStaffChannelLocalStaffAuthorityPort subclass FederationBankStaffChannelStaffAuthorityPort public
::method init
  expose engine
  use arg engineArg
  engine=engineArg
::method authorise
  expose engine
  use arg envelopeId,action,contexts,approvals=.nil
  return engine~authorise(envelopeId,action,contexts,approvals)

::class FederationBankStaffChannelCorePort public
::method submit abstract

::class FederationBankStaffChannelEngineCorePort subclass FederationBankStaffChannelCorePort public
::method init
  expose engine
  use arg engineArg
  engine=engineArg
::method submit
  expose engine
  use arg route,command
  route=.FederationBankStaffChannelCanonical~token(route)
  op=command~operation
  if route="ACCOUNT" then do
    if op<>"OPEN_ACCOUNT" & op<>"ADD_BENEFICIARY" & op<>"AMEND_BENEFICIARY" & op<>"SUSPEND_BENEFICIARY" then return .FederationBankStaffChannelResult~failure("CORE_ROUTE_OPERATION_MISMATCH",route||"/"||op)
  end
  else if route="PAYMENTS" then do
    if op<>"TRANSFER" then return .FederationBankStaffChannelResult~failure("CORE_ROUTE_OPERATION_MISMATCH",route||"/"||op)
  end
  else return .FederationBankStaffChannelResult~failure("CORE_ROUTE_INVALID",route)
  r=engine~handle(command)
  if r~ok then return .FederationBankStaffChannelResult~new(.true,r~code,r~detail,r~value)
  return .FederationBankStaffChannelResult~new(.false,r~code,r~detail,r~value)

::class FederationBankStaffChannelOrchestrator public
::method init
  expose gate staffPort corePort
  use arg gateArg,staffPortArg,corePortArg
  if gateArg==.nil | staffPortArg==.nil | corePortArg==.nil then raise syntax 88.989 array("Staff Channel gate/staff/core ports required")
  gate=gateArg; staffPort=staffPortArg; corePort=corePortArg
::method actionFromRequest private
  use arg request
  cmd=request~command; if cmd==.nil then return .FederationBankStaffChannelResult~failure("BANK_COMMAND_REQUIRED")
  return .FederationBankStaffChannelResult~success(.FederationBankStaffActionIntent~new("ACT:"||request~workId,cmd~commandId,cmd~idempotencyKey,request~staffId,request~sessionId,cmd~operation,cmd~customerId,cmd~sourceAccountId,cmd~targetAccountId,cmd~currency,cmd~amountMinor,request~branchId,request~deskId,request~relationshipEvidence~caseId,cmd~requestedAt,cmd~details)~seal)
::method directActionFromRequest private
  use arg request
  cmd=request~command; if cmd==.nil then return .FederationBankStaffChannelResult~failure("BANK_COMMAND_REQUIRED")
  return .FederationBankStaffChannelResult~success(.FederationBankStaffActionIntent~new("ACT:"||request~workId,cmd~commandId,cmd~idempotencyKey,request~staffId,request~sessionId,cmd~operation,cmd~customerId,cmd~sourceAccountId,cmd~targetAccountId,cmd~currency,cmd~amountMinor,request~branchId,request~deskId,"",cmd~requestedAt,cmd~details)~seal)
::method validateRequest private
  expose gate
  use arg request
  if request==.nil | \request~isA(.FederationBankStaffChannelRequest) | \request~sealed then return .FederationBankStaffChannelResult~failure("STAFF_CHANNEL_REQUEST_REQUIRED")
  op=request~operation; if op="" then return .FederationBankStaffChannelResult~failure("STAFF_CHANNEL_OPERATION_REQUIRED")
  resolved=gate~resolve(request~requestedAt,request~originClass,op); if \resolved~ok then return resolved
  rule=resolved~value["rule"]; cmd=request~command; rel=request~relationshipEvidence
  if op="NONE" then do
    if rule~coreRoute<>"NONE" then return .FederationBankStaffChannelResult~failure("NO_ACTION_ROUTE_INVALID")
  end
  else do
    if cmd==.nil then return .FederationBankStaffChannelResult~failure("BANK_COMMAND_REQUIRED")
    if cmd~channel<>.FederationBankStaffChannelBuild~CHANNEL then return .FederationBankStaffChannelResult~failure("STAFF_CHANNEL_COMMAND_CHANNEL_INVALID",cmd~channel)
    if cmd~actorId<>request~staffId then return .FederationBankStaffChannelResult~failure("STAFF_CHANNEL_ACTOR_MISMATCH")
    if cmd~requestedAt<>request~requestedAt then return .FederationBankStaffChannelResult~failure("STAFF_CHANNEL_REQUEST_TIME_MISMATCH")
  end
  if rule~relationshipMode="REQUIRED" then do
    if rel==.nil | \rel~sealed then return .FederationBankStaffChannelResult~failure("RELATIONSHIP_AUTHORITY_REQUIRED")
    if op="NONE" then do; if rel~outcome<>"NO_BANK_ACTION" then return .FederationBankStaffChannelResult~failure("RELATIONSHIP_NO_ACTION_EVIDENCE_REQUIRED"); end
    else do
      if rel~outcome<>"SUBMIT_BANK_COMMAND" then return .FederationBankStaffChannelResult~failure("RELATIONSHIP_BANK_COMMAND_EVIDENCE_REQUIRED")
      if rel~commandIdentity<>cmd~semanticIdentity then return .FederationBankStaffChannelResult~failure("RELATIONSHIP_COMMAND_IDENTITY_MISMATCH")
    end
  end
  else if rule~relationshipMode="NONE" then do
    if rel<>.nil then return .FederationBankStaffChannelResult~failure("RELATIONSHIP_AUTHORITY_NOT_EXPECTED",request~originClass)
  end
  return resolved
::method contextFor private
  use arg contexts,staffId
  if contexts==.nil then return .nil
  if contexts~hasIndex(staffId) then return contexts[staffId]
  return .nil
::method validateContext private
  use arg request,contexts
  ctx=self~contextFor(contexts,request~staffId); if ctx==.nil then return .FederationBankStaffChannelResult~failure("STAFF_CONTEXT_NOT_FOUND",request~staffId)
  if \ctx~validAt(request~requestedAt) then return .FederationBankStaffChannelResult~failure("STAFF_CONTEXT_NOT_EFFECTIVE",request~staffId)
  if ctx~session~sessionId<>request~sessionId then return .FederationBankStaffChannelResult~failure("STAFF_SESSION_MISMATCH")
  if ctx~session~branchId<>request~branchId | ctx~session~deskId<>request~deskId then return .FederationBankStaffChannelResult~failure("STAFF_WORK_CONTEXT_MISMATCH")
  return .FederationBankStaffChannelResult~success(ctx)
::method bindOnly private
  use arg work,decision,envelope
  work~authorised(decision,envelope)
  bind=.FederationBankStaffCommandBinder~bind(work~action,envelope,work~command~toCommand)
  if \bind~ok then return .FederationBankStaffChannelResult~failure("STAFF_COMMAND_BINDING_FAILED",bind~code||":"||bind~detail,work)
  work~readyForCore(.FederationBankStaffChannelCommandSnapshot~fromCommand(bind~value))
  return .FederationBankStaffChannelResult~success(work)
::method execute
  expose corePort
  use arg work
  if work==.nil | \work~isA(.FederationBankStaffChannelWorkItem) then return .FederationBankStaffChannelResult~failure("STAFF_CHANNEL_WORK_REQUIRED")
  if work~state<>"READY_FOR_CORE" then return .FederationBankStaffChannelResult~failure("STAFF_CHANNEL_WORK_NOT_EXECUTABLE",work~state)
  if work~boundCommand==.nil then return .FederationBankStaffChannelResult~failure("BOUND_BANK_COMMAND_REQUIRED")
  core=corePort~submit(work~route,work~boundCommand~toCommand)
  if \core~ok then do
    if core~code~left(10)="CORE_PORT_" | core~code~left(14)="CORE_DELIVERY_" then return .FederationBankStaffChannelResult~failure(core~code,core~detail,work)
  end
  if core~ok then work~completeCore(.true,core~code,core~detail,.nil)
  else work~completeCore(.false,core~code,core~detail,.nil)
  return .FederationBankStaffChannelResult~success(work)
::method prepare
  expose staffPort
  use arg request,contexts,approvals=.nil,envelopeId=""
  valid=self~validateRequest(request); if \valid~ok then return valid
  work=.FederationBankStaffChannelWorkItem~new(request,valid~value)
  rule=valid~value["rule"]
  if request~operation="NONE" then do; work~noBankAction("Relationship authority concluded no Core Banking action"); return .FederationBankStaffChannelResult~success(work); end
  ctx=self~validateContext(request,contexts); if \ctx~ok then return ctx
  if rule~relationshipMode="REQUIRED" then ar=self~actionFromRequest(request); else ar=self~directActionFromRequest(request)
  if \ar~ok then return ar
  action=ar~value; work~setAction(action)
  if envelopeId="" then envelopeId="STAFFENV:"||work~workId
  auth=staffPort~authorise(envelopeId,action,contexts,approvals)
  if \auth~ok then do
    if auth~code="APPROVAL_REQUIRED" then do; work~approvalRequired(auth~value,auth~detail); return .FederationBankStaffChannelResult~success(work); end
    work~reject(auth~code,auth~detail,auth~value); return .FederationBankStaffChannelResult~success(work)
  end
  return self~bindOnly(work,auth~value["decision"],auth~value["envelope"])
::method prepareResume
  expose staffPort
  use arg work,contexts,approvals=.nil,envelopeId=""
  if work==.nil | \work~isA(.FederationBankStaffChannelWorkItem) then return .FederationBankStaffChannelResult~failure("STAFF_CHANNEL_WORK_REQUIRED")
  if work~state<>"APPROVAL_REQUIRED" then return .FederationBankStaffChannelResult~failure("STAFF_CHANNEL_WORK_NOT_RESUMABLE",work~state)
  request=work~request; ctx=self~validateContext(request,contexts); if \ctx~ok then return ctx
  if envelopeId="" then envelopeId="STAFFENV:"||work~workId
  auth=staffPort~authorise(envelopeId,work~action,contexts,approvals)
  if \auth~ok then do
    if auth~code="APPROVAL_REQUIRED" then do; work~approvalRequired(auth~value,auth~detail); return .FederationBankStaffChannelResult~success(work); end
    work~reject(auth~code,auth~detail,auth~value); return .FederationBankStaffChannelResult~success(work)
  end
  return self~bindOnly(work,auth~value["decision"],auth~value["envelope"])
::method begin
  use arg request,contexts,approvals=.nil,envelopeId=""
  r=self~prepare(request,contexts,approvals,envelopeId); if \r~ok then return r
  if r~value~state="READY_FOR_CORE" then return self~execute(r~value)
  return r
::method resume
  use arg work,contexts,approvals=.nil,envelopeId=""
  r=self~prepareResume(work,contexts,approvals,envelopeId); if \r~ok then return r
  if r~value~state="READY_FOR_CORE" then return self~execute(r~value)
  return r

::requires "AlchemyObject.cls"
::requires "InstitutionalPolicy.cls"
::requires "FederationBankEngine.cls"
::requires "FederationBankStaffAuthority.cls"
