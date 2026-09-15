/*
 * FederationBank Relationship Adapter v0.1
 *
 * Translation boundary between general relationship/case decisions and the
 * FederationBank banking command model.  It intentionally does not own CRM,
 * case, legal, compliance, account or ledger truth.
 */

::class FederationBankRelationshipAdapterBuild public
::constant VERSION "0.1"
::constant API_VERSION "federationbank.relationship.adapter/0.1"
::constant PRODUCT "FederationBank Relationship Adapter"
::constant DEFAULT_POLICY_ID "FB-RELATIONSHIP-BANK-ACTION"
::constant STAFF_CHANNEL "STAFF"

::class FederationBankRelationshipAdapterResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get
::method init
  expose ok code detail value
  use arg okArg,codeArg,detailArg="",valueArg=.nil
  ok=okArg; code=codeArg~string; detail=detailArg~string; value=valueArg
::method success class
  use arg value=.nil,detail=""
  return self~new(.true,"OK",detail,value)
::method failure class
  use arg code,detail="",value=.nil
  return self~new(.false,code,detail,value)

::class FederationBankRelationshipCanonical public
::method token class
  use arg value
  if value==.nil then return ""
  return value~string~strip~upper
::method field class
  use arg tag,value=""
  if value==.nil then rendered="<NIL>"; else rendered=value~string
  return tag~string||":"||rendered~length||":"||rendered
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

::class FederationBankRelationshipAlchemyContext public
::attribute sealer get
::attribute authority get
::method init
  expose sealer authority
  use arg sealerArg=.nil,authorityArg=.nil
  sealer=sealerArg; authority=authorityArg

::class FederationBankRelationshipAlchemyObject subclass AlchemyObject public
::attribute domainObjectKind get
::method initDomainAlchemy protected
  expose domainObjectKind
  use arg kindArg,contextArg=.nil
  kind=.FederationBankRelationshipCanonical~token(kindArg)
  sealer=.nil; authority=.nil
  if contextArg<>.nil then do
    if \contextArg~isA(.FederationBankRelationshipAlchemyContext) then raise syntax 88.900 array("FederationBank Relationship Alchemy context invalid")
    sealer=contextArg~sealer; authority=contextArg~authority
  end
  meta=.directory~new
  meta["PURPOSE"]="typed, policy-driven boundary from relationship decisions to FederationBank commands"
  meta["PACKAGE"]="federationbank_relationship_adapter"
  meta["PACKAGE_VERSION"]=.FederationBankRelationshipAdapterBuild~VERSION
  meta["COMPONENT"]="federationbank_relationship_adapter"
  meta["DOMAIN_OBJECT_KIND"]=kind
  meta["DESIGN_LIMITATIONS"]="Translation never makes CRM/case observations authoritative and never bypasses FederationBank policy/legal/security/Ledger authority."
  self~init:super(meta,sealer,authority)
  domainObjectKind=kind
  self~registerExternalRequirement("library","alchemy_objects","0.8",.true)
  return self

/* This is the authoritative decision reference consumed by the adapter.  The
 * decision content is still owned by authoritySystem; the object is a typed,
 * immutable integration envelope with explicit action semantics. */
::class FederationBankRelationshipDecision subclass FederationBankRelationshipAlchemyObject public
::attribute decisionId get
::attribute caseId get
::attribute caseElementId get
::attribute customerId get
::attribute authoritySystem get
::attribute authorityClass get
::attribute authorityRef get
::attribute actionClass get
::attribute bankOperation get
::attribute policyDecisionRef get
::attribute legalDecisionRef get
::attribute decidedAt get
::attribute validUntil get
::attribute sealed get
::method init
  expose decisionId caseId caseElementId customerId authoritySystem authorityClass authorityRef actionClass bankOperation policyDecisionRef legalDecisionRef decidedAt validUntil tags sealed
  use arg decisionIdArg,caseIdArg,caseElementIdArg,customerIdArg,authoritySystemArg,authorityClassArg,authorityRefArg,actionClassArg,bankOperationArg,policyDecisionRefArg="",legalDecisionRefArg="",decidedAtArg=.nil,validUntilArg=.nil,contextArg=.nil
  self~initDomainAlchemy("RELATIONSHIPBANKDECISION",contextArg)
  decisionId=decisionIdArg~string
  caseId=caseIdArg~string
  caseElementId=caseElementIdArg~string
  customerId=customerIdArg~string
  authoritySystem=.FederationBankRelationshipCanonical~token(authoritySystemArg)
  authorityClass=.FederationBankRelationshipCanonical~token(authorityClassArg)
  authorityRef=authorityRefArg~string
  actionClass=.FederationBankRelationshipCanonical~token(actionClassArg)
  bankOperation=.FederationBankRelationshipCanonical~token(bankOperationArg)
  policyDecisionRef=policyDecisionRefArg~string
  legalDecisionRef=legalDecisionRefArg~string
  if decidedAtArg==.nil then decidedAt=.DateTime~new; else decidedAt=decidedAtArg
  validUntil=validUntilArg
  tags=.array~new; sealed=.false
  if decisionId="" | caseId="" | caseElementId="" | customerId="" | authoritySystem="" | authorityClass="" | authorityRef="" | actionClass="" | bankOperation="" then raise syntax 88.901 array("FederationBankRelationshipDecision identity/action fields required")
  self~registerStateVariable("decisionId","INTERNAL","stable decision envelope identifier")
  self~registerStateVariable("caseId","INTERNAL","coordinating Relationship Case")
  self~registerStateVariable("caseElementId","INTERNAL","DECISION element in coordinating case")
  self~registerStateVariable("customerId","SECRET","FederationBank customer subject")
  self~registerStateVariable("authoritySystem","INTERNAL","authoritative decision source")
  self~registerStateVariable("authorityClass","INTERNAL","authority type")
  self~registerStateVariable("authorityRef","SECRET","opaque authoritative decision reference")
  self~registerStateVariable("actionClass","INTERNAL","institutional action semantics")
  self~registerStateVariable("bankOperation","INTERNAL","requested FederationBank operation or NONE")
::method addTag
  expose tags sealed
  use arg tagArg
  if sealed then return .false
  tag=.FederationBankRelationshipCanonical~token(tagArg)
  if tag="" then return .false
  if \.FederationBankRelationshipCanonical~contains(tags,tag) then tags~append(tag)
  return .true
::method tags
  expose tags
  return .FederationBankRelationshipCanonical~copyArray(tags)
::method hasTag
  expose tags
  use arg tag
  return .FederationBankRelationshipCanonical~contains(tags,tag)
::method seal
  expose sealed
  sealed=.true; return self
::method effectiveAt
  expose decidedAt validUntil
  use arg atTime
  if atTime==.nil then atTime=.DateTime~new
  if atTime<decidedAt then return .false
  if validUntil<>.nil then if atTime>validUntil then return .false
  return .true
::method canonicalText
  expose decisionId caseId caseElementId customerId authoritySystem authorityClass authorityRef actionClass bankOperation policyDecisionRef legalDecisionRef decidedAt validUntil tags sealed
  if \sealed then raise syntax 88.902 array("FederationBankRelationshipDecision must be sealed")
  text="FB-RELATIONSHIP-DECISION/1"
  text||=.FederationBankRelationshipCanonical~field("DECISION_ID",decisionId)
  text||=.FederationBankRelationshipCanonical~field("CASE_ID",caseId)
  text||=.FederationBankRelationshipCanonical~field("CASE_ELEMENT_ID",caseElementId)
  text||=.FederationBankRelationshipCanonical~field("CUSTOMER_ID",customerId)
  text||=.FederationBankRelationshipCanonical~field("AUTHORITY_SYSTEM",authoritySystem)
  text||=.FederationBankRelationshipCanonical~field("AUTHORITY_CLASS",authorityClass)
  text||=.FederationBankRelationshipCanonical~field("AUTHORITY_REF",authorityRef)
  text||=.FederationBankRelationshipCanonical~field("ACTION_CLASS",actionClass)
  text||=.FederationBankRelationshipCanonical~field("BANK_OPERATION",bankOperation)
  text||=.FederationBankRelationshipCanonical~field("POLICY_DECISION_REF",policyDecisionRef)
  text||=.FederationBankRelationshipCanonical~field("LEGAL_DECISION_REF",legalDecisionRef)
  text||=.FederationBankRelationshipCanonical~field("DECIDED_AT",decidedAt~utcIsoDate)
  text||=.FederationBankRelationshipCanonical~field("VALID_UNTIL",.FederationBankRelationshipCanonical~dateText(validUntil))
  ordered=self~tags; ordered~sort
  do tag over ordered; text||=.FederationBankRelationshipCanonical~field("TAG",tag); end
  return text
::method semanticIdentity
  return self~canonicalText
::method queuePersistentType
  return "federationbank.relationship.decision/1"
::method queuePersistentState
  expose decisionId caseId caseElementId customerId authoritySystem authorityClass authorityRef actionClass bankOperation policyDecisionRef legalDecisionRef decidedAt validUntil tags sealed
  if \sealed then raise syntax 88.903 array("Unsealed FederationBankRelationshipDecision cannot cross durable boundary")
  s=.table~new
  s["decisionId"]=decisionId; s["caseId"]=caseId; s["caseElementId"]=caseElementId; s["customerId"]=customerId
  s["authoritySystem"]=authoritySystem; s["authorityClass"]=authorityClass; s["authorityRef"]=authorityRef; s["actionClass"]=actionClass; s["bankOperation"]=bankOperation
  s["policyDecisionRef"]=policyDecisionRef; s["legalDecisionRef"]=legalDecisionRef; s["decidedAt"]=decidedAt~utcIsoDate; s["validUntil"]=.FederationBankRelationshipCanonical~dateText(validUntil); s["tags"]=self~tags
  return s
::method queueRestoreState
  expose decisionId caseId caseElementId customerId authoritySystem authorityClass authorityRef actionClass bankOperation policyDecisionRef legalDecisionRef decidedAt validUntil tags sealed
  use arg s
  decisionId=s["decisionId"]~string; caseId=s["caseId"]~string; caseElementId=s["caseElementId"]~string; customerId=s["customerId"]~string
  authoritySystem=.FederationBankRelationshipCanonical~token(s["authoritySystem"]); authorityClass=.FederationBankRelationshipCanonical~token(s["authorityClass"]); authorityRef=s["authorityRef"]~string
  actionClass=.FederationBankRelationshipCanonical~token(s["actionClass"]); bankOperation=.FederationBankRelationshipCanonical~token(s["bankOperation"])
  policyDecisionRef=s["policyDecisionRef"]~string; legalDecisionRef=s["legalDecisionRef"]~string
  decidedAt=.FederationBankRelationshipCanonical~dateValue(s["decidedAt"]); validUntil=.FederationBankRelationshipCanonical~dateValue(s["validUntil"]); tags=.FederationBankRelationshipCanonical~copyArray(s["tags"]); sealed=.true
  return self

/* Transaction data is an instruction/request, never a decision. */
::class FederationBankRelationshipActionRequest subclass FederationBankRelationshipAlchemyObject public
::attribute requestId get
::attribute commandId get
::attribute idempotencyKey get
::attribute caseId get
::attribute customerId get
::attribute bankOperation get
::attribute actorId get
::attribute actorRole get
::attribute requestedAt get
::attribute sourceAccountId get
::attribute targetAccountId get
::attribute currency get
::attribute amountMinor get
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
::attribute details get
::attribute sealed get
::method init
  expose requestId commandId idempotencyKey caseId customerId bankOperation actorId actorRole requestedAt sourceAccountId targetAccountId currency amountMinor productCode accountId legalName dateOfBirth postcode addressCountry applicantResidence applicantDomicile applicantSegment applicantRiskTier details sealed
  use arg requestIdArg,commandIdArg,idempotencyKeyArg,caseIdArg,customerIdArg,bankOperationArg,actorIdArg,actorRoleArg,requestedAtArg=.nil,sourceAccountIdArg="",targetAccountIdArg="",currencyArg="",amountMinorArg=0,productCodeArg="",accountIdArg="",legalNameArg="",dateOfBirthArg="",postcodeArg="",addressCountryArg="",applicantResidenceArg="",applicantDomicileArg="",applicantSegmentArg="RETAIL",applicantRiskTierArg="STANDARD",detailsArg=.nil,contextArg=.nil
  self~initDomainAlchemy("RELATIONSHIPBANKACTIONREQUEST",contextArg)
  requestId=requestIdArg~string; commandId=commandIdArg~string; idempotencyKey=idempotencyKeyArg~string; caseId=caseIdArg~string; customerId=customerIdArg~string; bankOperation=.FederationBankRelationshipCanonical~token(bankOperationArg)
  actorId=actorIdArg~string; actorRole=.FederationBankRelationshipCanonical~token(actorRoleArg)
  if requestedAtArg==.nil then requestedAt=.DateTime~new; else requestedAt=requestedAtArg
  sourceAccountId=sourceAccountIdArg~string; targetAccountId=targetAccountIdArg~string; currency=.FederationBankRelationshipCanonical~token(currencyArg); amountMinor=amountMinorArg+0
  productCode=.FederationBankRelationshipCanonical~token(productCodeArg); accountId=accountIdArg~string; legalName=legalNameArg~string; dateOfBirth=dateOfBirthArg~string; postcode=postcodeArg~string~upper; addressCountry=.FederationBankRelationshipCanonical~token(addressCountryArg)
  applicantResidence=.FederationBankRelationshipCanonical~token(applicantResidenceArg); applicantDomicile=.FederationBankRelationshipCanonical~token(applicantDomicileArg); applicantSegment=.FederationBankRelationshipCanonical~token(applicantSegmentArg); applicantRiskTier=.FederationBankRelationshipCanonical~token(applicantRiskTierArg)
  details=.FederationBankRelationshipCanonical~copyDirectory(detailsArg); sealed=.false
  if requestId="" | commandId="" | idempotencyKey="" | caseId="" | customerId="" | bankOperation="" | actorId="" | actorRole="" then raise syntax 88.904 array("FederationBankRelationshipActionRequest identity fields required")
::method seal
  expose sealed
  sealed=.true; return self
::method canonicalText
  expose requestId commandId idempotencyKey caseId customerId bankOperation actorId actorRole requestedAt sourceAccountId targetAccountId currency amountMinor productCode accountId sealed
  if \sealed then raise syntax 88.905 array("FederationBankRelationshipActionRequest must be sealed")
  text="FB-RELATIONSHIP-ACTION-REQUEST/1"
  do pair over .array~of("REQUEST_ID",requestId,"COMMAND_ID",commandId,"IDEMPOTENCY_KEY",idempotencyKey,"CASE_ID",caseId,"CUSTOMER_ID",customerId,"BANK_OPERATION",bankOperation,"ACTOR_ID",actorId,"ACTOR_ROLE",actorRole,"REQUESTED_AT",requestedAt~utcIsoDate,"SOURCE_ACCOUNT",sourceAccountId,"TARGET_ACCOUNT",targetAccountId,"CURRENCY",currency,"AMOUNT_MINOR",amountMinor,"PRODUCT_CODE",productCode,"ACCOUNT_ID",accountId)
    nop
  end
  text||=.FederationBankRelationshipCanonical~field("REQUEST_ID",requestId)
  text||=.FederationBankRelationshipCanonical~field("COMMAND_ID",commandId)
  text||=.FederationBankRelationshipCanonical~field("IDEMPOTENCY_KEY",idempotencyKey)
  text||=.FederationBankRelationshipCanonical~field("CASE_ID",caseId)
  text||=.FederationBankRelationshipCanonical~field("CUSTOMER_ID",customerId)
  text||=.FederationBankRelationshipCanonical~field("BANK_OPERATION",bankOperation)
  text||=.FederationBankRelationshipCanonical~field("ACTOR_ID",actorId)
  text||=.FederationBankRelationshipCanonical~field("ACTOR_ROLE",actorRole)
  text||=.FederationBankRelationshipCanonical~field("REQUESTED_AT",requestedAt~utcIsoDate)
  text||=.FederationBankRelationshipCanonical~field("SOURCE_ACCOUNT",sourceAccountId)
  text||=.FederationBankRelationshipCanonical~field("TARGET_ACCOUNT",targetAccountId)
  text||=.FederationBankRelationshipCanonical~field("CURRENCY",currency)
  text||=.FederationBankRelationshipCanonical~field("AMOUNT_MINOR",amountMinor)
  text||=.FederationBankRelationshipCanonical~field("PRODUCT_CODE",productCode)
  text||=.FederationBankRelationshipCanonical~field("ACCOUNT_ID",accountId)
  return text
::method semanticIdentity
  return self~canonicalText
::method queuePersistentType
  return "federationbank.relationship.action.request/1"
::method queuePersistentState
  expose requestId commandId idempotencyKey caseId customerId bankOperation actorId actorRole requestedAt sourceAccountId targetAccountId currency amountMinor productCode accountId legalName dateOfBirth postcode addressCountry applicantResidence applicantDomicile applicantSegment applicantRiskTier details sealed
  if \sealed then raise syntax 88.908 array("Unsealed FederationBankRelationshipActionRequest cannot cross durable boundary")
  s=.table~new
  s["requestId"]=requestId; s["commandId"]=commandId; s["idempotencyKey"]=idempotencyKey; s["caseId"]=caseId; s["customerId"]=customerId; s["bankOperation"]=bankOperation; s["actorId"]=actorId; s["actorRole"]=actorRole; s["requestedAt"]=requestedAt~string
  s["sourceAccountId"]=sourceAccountId; s["targetAccountId"]=targetAccountId; s["currency"]=currency; s["amountMinor"]=amountMinor; s["productCode"]=productCode; s["accountId"]=accountId; s["legalName"]=legalName; s["dateOfBirth"]=dateOfBirth; s["postcode"]=postcode; s["addressCountry"]=addressCountry
  s["applicantResidence"]=applicantResidence; s["applicantDomicile"]=applicantDomicile; s["applicantSegment"]=applicantSegment; s["applicantRiskTier"]=applicantRiskTier; s["details"]=details
  return s
::method queueRestoreState
  expose requestId commandId idempotencyKey caseId customerId bankOperation actorId actorRole requestedAt sourceAccountId targetAccountId currency amountMinor productCode accountId legalName dateOfBirth postcode addressCountry applicantResidence applicantDomicile applicantSegment applicantRiskTier details sealed
  use arg s
  requestId=s["requestId"]~string; commandId=s["commandId"]~string; idempotencyKey=s["idempotencyKey"]~string; caseId=s["caseId"]~string; customerId=s["customerId"]~string; bankOperation=.FederationBankRelationshipCanonical~token(s["bankOperation"]); actorId=s["actorId"]~string; actorRole=.FederationBankRelationshipCanonical~token(s["actorRole"]); requestedAt=.DateTime~fromIsoDate(s["requestedAt"]~string)
  sourceAccountId=s["sourceAccountId"]~string; targetAccountId=s["targetAccountId"]~string; currency=.FederationBankRelationshipCanonical~token(s["currency"]); amountMinor=s["amountMinor"]+0; productCode=.FederationBankRelationshipCanonical~token(s["productCode"]); accountId=s["accountId"]~string; legalName=s["legalName"]~string; dateOfBirth=s["dateOfBirth"]~string; postcode=s["postcode"]~string; addressCountry=.FederationBankRelationshipCanonical~token(s["addressCountry"])
  applicantResidence=.FederationBankRelationshipCanonical~token(s["applicantResidence"]); applicantDomicile=.FederationBankRelationshipCanonical~token(s["applicantDomicile"]); applicantSegment=.FederationBankRelationshipCanonical~token(s["applicantSegment"]); applicantRiskTier=.FederationBankRelationshipCanonical~token(s["applicantRiskTier"]); details=s["details"]; sealed=.true
  return self

::class FederationBankRelationshipActionRule public
::attribute ruleId get
::attribute authorityClass get
::attribute actionClass get
::attribute bankOperation get
::attribute actorRole get
::attribute bankChannel get
::attribute requirePolicyDecision get
::attribute requireLegalDecision get
::attribute allowed get
::attribute rationale get
::method init
  expose ruleId authorityClass actionClass bankOperation actorRole bankChannel requirePolicyDecision requireLegalDecision allowed rationale
  use arg ruleIdArg,authorityClassArg="*",actionClassArg="*",bankOperationArg="*",actorRoleArg="*",bankChannelArg="STAFF",requirePolicyArg=.false,requireLegalArg=.false,allowedArg=.true,rationaleArg=""
  ruleId=.FederationBankRelationshipCanonical~token(ruleIdArg); authorityClass=.FederationBankRelationshipCanonical~token(authorityClassArg); actionClass=.FederationBankRelationshipCanonical~token(actionClassArg); bankOperation=.FederationBankRelationshipCanonical~token(bankOperationArg); actorRole=.FederationBankRelationshipCanonical~token(actorRoleArg); bankChannel=.FederationBankRelationshipCanonical~token(bankChannelArg)
  requirePolicyDecision=requirePolicyArg; requireLegalDecision=requireLegalArg; allowed=allowedArg; rationale=rationaleArg~string
::method matches
  expose authorityClass actionClass bankOperation actorRole
  use arg decision,request
  if authorityClass<>"*" & authorityClass<>decision~authorityClass then return .false
  if actionClass<>"*" & actionClass<>decision~actionClass then return .false
  if bankOperation<>"*" & bankOperation<>decision~bankOperation then return .false
  if actorRole<>"*" & actorRole<>request~actorRole then return .false
  return .true
::method specificity
  expose authorityClass actionClass bankOperation actorRole
  score=0
  if authorityClass<>"*" then score+=1
  if actionClass<>"*" then score+=1
  if bankOperation<>"*" then score+=1
  if actorRole<>"*" then score+=1
  return score
::method canonicalText
  expose ruleId authorityClass actionClass bankOperation actorRole bankChannel requirePolicyDecision requireLegalDecision allowed rationale
  return ruleId||"|"||authorityClass||"|"||actionClass||"|"||bankOperation||"|"||actorRole||"|"||bankChannel||"|"||requirePolicyDecision||"|"||requireLegalDecision||"|"||allowed||"|"||rationale

::class FederationBankRelationshipActionPolicy public
::attribute sealed get
::method init
  expose rules sealed
  rules=.array~new; sealed=.false
::method addRule
  expose rules sealed
  use arg rule
  if sealed | rule==.nil then return .false
  do existing over rules; if existing~ruleId=rule~ruleId then return .false; end
  rules~append(rule); return .true
::method seal
  expose sealed
  sealed=.true; return self
::method publicationEligible
  expose sealed
  return sealed
::method evaluate
  expose rules sealed
  use arg decision,request
  if \sealed then return .FederationBankRelationshipAdapterResult~failure("RELATIONSHIP_BANK_POLICY_NOT_SEALED")
  best=.nil; score=-1
  do rule over rules
    if rule~matches(decision,request) then do
      s=rule~specificity
      if s>score then do; best=rule; score=s; end
      else if s=score & best<>.nil then if rule~ruleId<best~ruleId then best=rule
    end
  end
  if best==.nil then return .FederationBankRelationshipAdapterResult~failure("RELATIONSHIP_BANK_POLICY_NO_RULE",decision~authorityClass||"/"||decision~actionClass||"/"||decision~bankOperation||"/"||request~actorRole)
  if \best~allowed then return .FederationBankRelationshipAdapterResult~failure("RELATIONSHIP_BANK_POLICY_DENIED",best~ruleId||":"||best~rationale,best)
  if best~requirePolicyDecision & decision~policyDecisionRef="" then return .FederationBankRelationshipAdapterResult~failure("POLICY_DECISION_REFERENCE_REQUIRED",best~ruleId)
  if best~requireLegalDecision & decision~legalDecisionRef="" then return .FederationBankRelationshipAdapterResult~failure("LEGAL_DECISION_REFERENCE_REQUIRED",best~ruleId)
  d=.directory~new; d["ruleId"]=best~ruleId; d["bankChannel"]=best~bankChannel; d["rationale"]=best~rationale
  return .FederationBankRelationshipAdapterResult~success(d)
::method canonicalText
  expose rules sealed
  text="FB-RELATIONSHIP-ACTION-POLICY/1|SEALED="||sealed
  do r over rules; text||="|"||r~canonicalText; end
  return text
::method semanticIdentity
  return self~canonicalText

::class FederationBankRelationshipPolicyGate public
::method init
  expose catalog policyId
  use arg catalogArg,policyIdArg="FB-RELATIONSHIP-BANK-ACTION"
  if catalogArg==.nil then raise syntax 88.906 array("FederationBank Relationship policy catalog required")
  catalog=catalogArg; policyId=policyIdArg~string~upper
::method evaluate
  expose catalog policyId
  use arg decision,request
  resolved=catalog~resolve(policyId,request~requestedAt)
  if \resolved~ok then return .FederationBankRelationshipAdapterResult~failure("RELATIONSHIP_BANK_POLICY_RESOLUTION_FAILED",resolved~code||":"||resolved~detail,resolved)
  release=resolved~value; payload=release~payload
  if payload==.nil then return .FederationBankRelationshipAdapterResult~failure("RELATIONSHIP_BANK_POLICY_PAYLOAD_REQUIRED",release~policyId||"@"||release~version)
  result=payload~evaluate(decision,request)
  if \result~ok then return result
  d=result~value; d["policyId"]=release~policyId; d["policyVersion"]=release~version; d["policyIdentity"]=release~semanticIdentity
  return .FederationBankRelationshipAdapterResult~success(d)

::class FederationBankRelationshipTranslation public
::attribute outcome get
::attribute decision get
::attribute request get
::attribute bankCommand get
::attribute policyEvidence get
::method init
  expose outcome decision request bankCommand policyEvidence
  use arg outcomeArg,decisionArg,requestArg,bankCommandArg=.nil,policyEvidenceArg=.nil
  outcome=.FederationBankRelationshipCanonical~token(outcomeArg); decision=decisionArg; request=requestArg; bankCommand=bankCommandArg; policyEvidence=policyEvidenceArg

::class FederationBankRelationshipAdapter public
::method init
  expose gate
  use arg policyGateArg
  if policyGateArg==.nil then raise syntax 88.907 array("FederationBank Relationship policy gate required")
  gate=policyGateArg
::method translate
  expose gate
  use arg decision,request,caseElement=.nil
  if decision==.nil | \decision~isA(.FederationBankRelationshipDecision) then return .FederationBankRelationshipAdapterResult~failure("BANK_ACTION_DECISION_REQUIRED")
  if request==.nil | \request~isA(.FederationBankRelationshipActionRequest) then return .FederationBankRelationshipAdapterResult~failure("BANK_ACTION_REQUEST_REQUIRED")
  if \decision~sealed then return .FederationBankRelationshipAdapterResult~failure("BANK_ACTION_DECISION_NOT_SEALED")
  if \request~sealed then return .FederationBankRelationshipAdapterResult~failure("BANK_ACTION_REQUEST_NOT_SEALED")
  if decision~caseId<>request~caseId then return .FederationBankRelationshipAdapterResult~failure("CASE_SCOPE_MISMATCH",decision~caseId||"<>"||request~caseId)
  if decision~customerId<>request~customerId then return .FederationBankRelationshipAdapterResult~failure("CUSTOMER_SCOPE_MISMATCH",decision~customerId||"<>"||request~customerId)
  if decision~bankOperation<>request~bankOperation then return .FederationBankRelationshipAdapterResult~failure("BANK_OPERATION_MISMATCH",decision~bankOperation||"<>"||request~bankOperation)
  if \decision~effectiveAt(request~requestedAt) then return .FederationBankRelationshipAdapterResult~failure("BANK_ACTION_DECISION_NOT_EFFECTIVE",decision~decisionId)
  if caseElement==.nil then return .FederationBankRelationshipAdapterResult~failure("CASE_DECISION_ELEMENT_REQUIRED",decision~caseElementId)
  checked=.FederationBankRelationshipCaseDecisionVerifier~verify(decision,caseElement)
  if \checked~ok then return checked
  policy=gate~evaluate(decision,request)
  if \policy~ok then return policy
  if decision~bankOperation="NONE" then return .FederationBankRelationshipAdapterResult~success(.FederationBankRelationshipTranslation~new("NO_BANK_ACTION",decision,request,.nil,policy~value),"durable decision requires no Core Banking command")
  command=self~toBankCommand(decision,request,policy~value)
  return .FederationBankRelationshipAdapterResult~success(.FederationBankRelationshipTranslation~new("SUBMIT_BANK_COMMAND",decision,request,command,policy~value))
::method toBankCommand private
  use arg decision,request,policy
  details=.FederationBankRelationshipCanonical~copyDirectory(request~details)
  details["relationshipCaseId"]=decision~caseId
  details["relationshipCaseDecisionElementId"]=decision~caseElementId
  details["relationshipDecisionId"]=decision~decisionId
  details["relationshipAuthoritySystem"]=decision~authoritySystem
  details["relationshipAuthorityClass"]=decision~authorityClass
  details["relationshipAuthorityRef"]=decision~authorityRef
  details["relationshipActionClass"]=decision~actionClass
  details["relationshipPolicyDecisionRef"]=decision~policyDecisionRef
  details["relationshipLegalDecisionRef"]=decision~legalDecisionRef
  details["relationshipAdapterPolicyId"]=policy["policyId"]
  details["relationshipAdapterPolicyVersion"]=policy["policyVersion"]
  details["relationshipAdapterPolicyIdentity"]=policy["policyIdentity"]
  details["relationshipAdapterRuleId"]=policy["ruleId"]
  details["relationshipOriginActorRole"]=request~actorRole
  return .FederationBankCommand~new(request~commandId,request~bankOperation,request~idempotencyKey,request~customerId,request~sourceAccountId,request~targetAccountId,request~currency,request~amountMinor,policy["bankChannel"],request~actorId,request~requestedAt,request~productCode,request~accountId,request~legalName,request~dateOfBirth,request~postcode,request~addressCountry,request~applicantResidence,request~applicantDomicile,request~applicantSegment,request~applicantRiskTier,details)

::class FederationBankRelationshipCaseDecisionVerifier public
::method verify class
  use arg decision,caseElement
  if decision==.nil then return .FederationBankRelationshipAdapterResult~failure("BANK_ACTION_DECISION_REQUIRED")
  if caseElement==.nil then return .FederationBankRelationshipAdapterResult~failure("CASE_DECISION_ELEMENT_REQUIRED")
  if \caseElement~hasMethod("ELEMENTTYPE") then return .FederationBankRelationshipAdapterResult~failure("CASE_DECISION_ELEMENT_REQUIRED")
  if \caseElement~sealed then return .FederationBankRelationshipAdapterResult~failure("CASE_DECISION_ELEMENT_NOT_SEALED",caseElement~elementId)
  if caseElement~elementType<>"DECISION" then return .FederationBankRelationshipAdapterResult~failure("CASE_ELEMENT_NOT_DECISION",caseElement~elementType)
  if caseElement~elementId<>decision~caseElementId then return .FederationBankRelationshipAdapterResult~failure("CASE_DECISION_ELEMENT_ID_MISMATCH",caseElement~elementId||"<>"||decision~caseElementId)
  if caseElement~sourceSystem<>decision~authoritySystem then return .FederationBankRelationshipAdapterResult~failure("CASE_DECISION_SOURCE_MISMATCH",caseElement~sourceSystem||"<>"||decision~authoritySystem)
  if caseElement~sourceRef<>decision~authorityRef then return .FederationBankRelationshipAdapterResult~failure("CASE_DECISION_REFERENCE_MISMATCH",caseElement~sourceRef||"<>"||decision~authorityRef)
  if caseElement~authorityClass<>decision~authorityClass then return .FederationBankRelationshipAdapterResult~failure("CASE_DECISION_AUTHORITY_MISMATCH",caseElement~authorityClass||"<>"||decision~authorityClass)
  return .FederationBankRelationshipAdapterResult~success(caseElement)

::requires "AlchemyObject.cls"
::requires "InstitutionalPolicy.cls"
::requires "RelationshipCase.cls"
::requires "FederationBankEngine.cls"
