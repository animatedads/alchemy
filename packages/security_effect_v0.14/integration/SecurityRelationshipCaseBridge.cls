/* SecurityEffect v0.12 optional deterministic Relationship Case referral bridge. */

::class SecurityReviewReferralRule public
::attribute ruleId get
::attribute priority get
::attribute actionType get
::attribute disposition get
::attribute requiredConstraint get
::attribute caseType get
::attribute visibilityClass get
::attribute sealed get
::method init
  expose ruleId priority actionType disposition requiredConstraint caseType visibilityClass sealed
  use arg ruleIdArg, priorityArg, actionTypeArg, dispositionArg, requiredConstraintArg, caseTypeArg, visibilityArg = "RESTRICTED"
  ruleId=ruleIdArg~string~upper; priority=priorityArg+0; actionType=actionTypeArg~string~upper
  disposition=dispositionArg~string~upper; requiredConstraint=requiredConstraintArg~string~upper
  caseType=caseTypeArg~string~upper; visibilityClass=visibilityArg~string~upper; sealed=.false
  if ruleId="" | actionType="" | disposition="" | caseType="" then raise syntax 88.971 array("SecurityReviewReferralRule identity fields required")
::method seal
  expose sealed; sealed=.true; return self
::method matches
  expose actionType disposition requiredConstraint
  use arg assessment
  if assessment==.nil then return .false
  if actionType<>"*" & assessment~action~actionType<>actionType then return .false
  if disposition<>"*" & assessment~disposition<>disposition then return .false
  if requiredConstraint<>"" & requiredConstraint<>"*" then if assessment~containsConstraint(requiredConstraint)=.false then return .false
  return .true
::method canonicalText
  expose ruleId priority actionType disposition requiredConstraint caseType visibilityClass
  text=.SecurityCanonical~field("RULE",ruleId)
  text||=.SecurityCanonical~field("PRIORITY",priority)
  text||=.SecurityCanonical~field("ACTION_TYPE",actionType)
  text||=.SecurityCanonical~field("DISPOSITION",disposition)
  text||=.SecurityCanonical~field("REQUIRED_CONSTRAINT",requiredConstraint)
  text||=.SecurityCanonical~field("CASE_TYPE",caseType)
  text||=.SecurityCanonical~field("VISIBILITY",visibilityClass)
  return text

::class SecurityReviewReferralPolicy public
::attribute policyId get
::attribute version get
::attribute effectiveFrom get
::attribute effectiveUntil get
::attribute authoredBy get
::attribute approvedBy get
::attribute supersedes get
::attribute executionModel get
::attribute sealed get
::method init
  expose policyId version effectiveFrom effectiveUntil authoredBy approvedBy supersedes executionModel sealed rules
  use arg policyIdArg="SECURITY-REVIEW-REFERRAL", versionArg="1", effectiveFromArg=.nil, effectiveUntilArg=.nil, authoredByArg="", approvedByArg="", supersedesArg=""
  policyId=policyIdArg~string~upper; version=versionArg~string
  if effectiveFromArg==.nil then effectiveFrom=.DateTime~new; else effectiveFrom=effectiveFromArg
  if effectiveUntilArg==.nil | effectiveUntilArg~string="" then effectiveUntil=.nil; else effectiveUntil=effectiveUntilArg
  authoredBy=authoredByArg~string; approvedBy=approvedByArg~string; supersedes=supersedesArg~string
  executionModel=.InstitutionalPolicyBuild~EXECUTION_MODEL; sealed=.false; rules=.array~new
::method addRule
  expose rules sealed
  use arg rule
  if sealed | rule==.nil | rule~sealed=.false then return .false
  do existing over rules; if existing~ruleId==rule~ruleId then return .false; end
  rules~append(rule); return .true
::method rules
  expose rules; return .SecurityCanonical~copyArray(rules)
::method activeAt
  expose effectiveFrom effectiveUntil
  use arg moment
  if moment<effectiveFrom then return .false
  if effectiveUntil==.nil then return .true
  return moment<effectiveUntil
::method publicationEligible
  expose sealed authoredBy approvedBy; return sealed & authoredBy<>"" & approvedBy<>""
::method seal
  expose sealed; sealed=.true; return self
::method canonicalText
  expose policyId version effectiveFrom effectiveUntil authoredBy approvedBy supersedes executionModel rules
  text=.SecurityCanonical~field("POLICY_ID",policyId)
  text||=.SecurityCanonical~field("VERSION",version)
  text||=.SecurityCanonical~field("SCHEMA",.SecurityEffectBuild~REVIEW_REFERRAL_SCHEMA)
  text||=.SecurityCanonical~field("EFFECTIVE_FROM",effectiveFrom)
  text||=.SecurityCanonical~field("EFFECTIVE_UNTIL",effectiveUntil)
  text||=.SecurityCanonical~field("AUTHORED_BY",authoredBy)
  text||=.SecurityCanonical~field("APPROVED_BY",approvedBy)
  text||=.SecurityCanonical~field("SUPERSEDES",supersedes)
  text||=.SecurityCanonical~field("EXECUTION_MODEL",executionModel)
  rs=.array~new; do rule over rules; rs~append(rule~canonicalText); end
  text||=.SecurityCanonical~join("RULE",rs)
  return text
::method semanticIdentity
  return self~canonicalText

::class SecurityReviewReferralPolicyCatalog subclass InstitutionalPolicyCatalog public
::method init
  use arg sealer=.nil, authority=.nil, authorityEvaluator=.nil, lifecycleEvaluator=.nil, deploymentEvaluator=.nil
  self~init:super(.SecurityAlchemySupport~metadata("published fixed Security-to-case referral policy catalogue"),sealer,authority,.SecurityResult,authorityEvaluator,lifecycleEvaluator,deploymentEvaluator)

::class SecurityReviewReferralDecision public
::attribute refer get
::attribute code get
::attribute ruleId get
::attribute caseType get
::attribute visibilityClass get
::attribute policyId get
::attribute policyVersion get
::attribute policyIdentity get
::method init
  expose refer code ruleId caseType visibilityClass policyId policyVersion policyIdentity
  use arg referArg, codeArg, ruleIdArg="", caseTypeArg="", visibilityArg="INTERNAL", policyArg=.nil
  refer=referArg; code=codeArg~string~upper; ruleId=ruleIdArg~string~upper; caseType=caseTypeArg~string~upper; visibilityClass=visibilityArg~string~upper
  if policyArg==.nil then do; policyId=""; policyVersion=""; policyIdentity=""; end
  else do; policyId=policyArg~policyId; policyVersion=policyArg~version; policyIdentity=policyArg~semanticIdentity; end
::method canonicalText
  expose refer code ruleId caseType visibilityClass policyId policyVersion policyIdentity
  text=.SecurityCanonical~field("REFER",refer)
  text||=.SecurityCanonical~field("CODE",code)
  text||=.SecurityCanonical~field("RULE",ruleId)
  text||=.SecurityCanonical~field("CASE_TYPE",caseType)
  text||=.SecurityCanonical~field("VISIBILITY",visibilityClass)
  text||=.SecurityCanonical~field("POLICY_ID",policyId)
  text||=.SecurityCanonical~field("POLICY_VERSION",policyVersion)
  text||=.SecurityCanonical~field("POLICY_IDENTITY",policyIdentity)
  return text

::class SecurityReviewReferralEngine public
::method resolvePolicy private
  use arg policySource, atTime, policyId
  if policySource==.nil then return .SecurityResult~failure("REFERRAL_POLICY_REQUIRED")
  if policySource~hasMethod("RESOLVE") then do
    rr=policySource~resolve(policyId,atTime)
    if rr~ok=.false then return .SecurityResult~failure("REFERRAL_POLICY_RESOLUTION_FAILED",rr~code||":"||rr~detail,rr)
    return .SecurityResult~success(rr~value)
  end
  return .SecurityResult~success(policySource)
::method evaluate
  use arg assessment, policySource, policyId="SECURITY-REVIEW-REFERRAL"
  if assessment==.nil then return .SecurityResult~failure("ASSESSMENT_REQUIRED")
  atTime=assessment~action~intendedAt
  resolved=self~resolvePolicy(policySource,atTime,policyId); if resolved~ok=.false then return resolved
  policy=resolved~value
  if policy~sealed=.false then return .SecurityResult~failure("REFERRAL_POLICY_NOT_SEALED")
  gate=.InstitutionalPolicyReplayGuard~operative(policy,atTime); if gate~ok=.false then return .SecurityResult~failure(gate~code,gate~detail)
  candidates=.array~new; do rule over policy~rules; if rule~matches(assessment) then candidates~append(rule); end
  if candidates~items=0 then return .SecurityResult~success(.SecurityReviewReferralDecision~new(.false,"NO_REFERRAL","","","INTERNAL",policy))
  chosen=candidates[1]
  do i=2 to candidates~items
    current=candidates[i]
    if current~priority>chosen~priority then chosen=current
    else if current~priority=chosen~priority & current~ruleId<chosen~ruleId then chosen=current
  end
  return .SecurityResult~success(.SecurityReviewReferralDecision~new(.true,"REFER",chosen~ruleId,chosen~caseType,chosen~visibilityClass,policy))

::class SecurityRelationshipCaseReferral public
::attribute decision get
::attribute caseId get
::attribute assessmentRef get
::attribute caseReply get
::attribute subjectReply get
::attribute assessmentReply get
::attribute policyReply get
::method init
  expose decision caseId assessmentRef caseReply subjectReply assessmentReply policyReply
  use arg decisionArg,caseIdArg,assessmentRefArg,caseReplyArg,subjectReplyArg,assessmentReplyArg,policyReplyArg
  decision=decisionArg; caseId=caseIdArg~string; assessmentRef=assessmentRefArg~string
  caseReply=caseReplyArg; subjectReply=subjectReplyArg; assessmentReply=assessmentReplyArg; policyReply=policyReplyArg

::class SecurityRelationshipCaseBridge public
::method init
  expose referralEngine; referralEngine=.SecurityReviewReferralEngine~new
::method fingerprint private
  use arg assessment
  return .CryptoHash~hashString(assessment~trace~traceIdentity||assessment~outcomeCanonicalText)
::method command private
  use arg service,commandId,commandType,actorId,actorRole,payload,correlationId,causationId,requestedAt
  return service~handle(.RelationshipCaseServiceEnvelope~new(commandId,commandType,actorId,actorRole,payload,correlationId,causationId,requestedAt))
::method refer
  expose referralEngine
  use arg assessment,policySource,caseService,actorId,actorRole,requestedAt=.nil,referralPolicyId="SECURITY-REVIEW-REFERRAL"
  if caseService==.nil then return .SecurityResult~failure("RELATIONSHIP_CASE_SERVICE_REQUIRED")
  if actorId~string="" | actorRole~string="" then return .SecurityResult~failure("REFERRAL_ACTOR_REQUIRED")
  if requestedAt==.nil then requestedAt=.DateTime~new
  rr=referralEngine~evaluate(assessment,policySource,referralPolicyId); if rr~ok=.false then return rr
  decision=rr~value
  if decision~refer=.false then return .SecurityResult~success(.SecurityRelationshipCaseReferral~new(decision,"","",.nil,.nil,.nil,.nil),"NO_REFERRAL")
  fp=self~fingerprint(assessment); short=fp~substr(1,24)~upper
  caseId="SEC-REVIEW-"||short; assessmentRef="SECURITY-ASSESSMENT:"||fp; correlationId="SECREF:"||fp
  openPayload=.directory~new; openPayload["caseId"]=caseId; openPayload["caseType"]=decision~caseType
  openReply=self~command(caseService,"SECREF-OPEN-"||short,"CASE.OPEN",actorId,actorRole,openPayload,correlationId,assessment~action~actionId,requestedAt)
  if openReply~ok=.false then return .SecurityResult~failure("CASE_OPEN_FAILED",openReply~code||":"||openReply~detail,openReply)
  subjectElement=.RelationshipCaseElement~new("SECREF-SUBJECT-"||short,"SUBJECT","SECURITY_SUBJECT","SUBJECT_OF","SECURITY_EFFECT","SECURITY_SUBJECT:"||assessment~action~subjectId,"SECURITY_SUBJECT_REFERENCE",requestedAt,decision~visibilityClass)
  subjectElement~addTag("SECURITY_REVIEW"); subjectElement~seal
  p=.directory~new; p["caseId"]=caseId; p["element"]=subjectElement
  subjectReply=self~command(caseService,"SECREF-SUBJECT-"||short,"CASE.ATTACH_ELEMENT",actorId,actorRole,p,correlationId,"SECREF-OPEN-"||short,requestedAt)
  if subjectReply~ok=.false then return .SecurityResult~failure("CASE_SUBJECT_ATTACH_FAILED",subjectReply~code||":"||subjectReply~detail,subjectReply)
  assessmentElement=.RelationshipCaseElement~new("SECREF-ASSESS-"||short,"ASSESSMENT","SECURITY_ASSESSMENT","TRIGGERED_REVIEW","SECURITY_EFFECT",assessmentRef,"SECURITY_ASSESSMENT_REFERENCE",requestedAt,decision~visibilityClass)
  assessmentElement~addTag(assessment~disposition); assessmentElement~addTag(assessment~action~actionType); assessmentElement~seal
  p=.directory~new; p["caseId"]=caseId; p["element"]=assessmentElement
  assessmentReply=self~command(caseService,"SECREF-ASSESS-"||short,"CASE.ATTACH_ELEMENT",actorId,actorRole,p,correlationId,"SECREF-SUBJECT-"||short,requestedAt)
  if assessmentReply~ok=.false then return .SecurityResult~failure("CASE_ASSESSMENT_ATTACH_FAILED",assessmentReply~code||":"||assessmentReply~detail,assessmentReply)
  policyRef=.CryptoHash~hashString(decision~policyIdentity)
  policyElement=.RelationshipCaseElement~new("SECREF-POLICY-"||short,"POLICY_REFERENCE","SECURITY_REVIEW_REFERRAL_POLICY","REFERRED_UNDER","SECURITY_EFFECT","SECURITY_REFERRAL_POLICY:"||policyRef,"INSTITUTIONAL_POLICY_REFERENCE",requestedAt,decision~visibilityClass)
  policyElement~addTag(decision~ruleId); policyElement~seal
  p=.directory~new; p["caseId"]=caseId; p["element"]=policyElement
  policyReply=self~command(caseService,"SECREF-POLICY-"||short,"CASE.ATTACH_ELEMENT",actorId,actorRole,p,correlationId,"SECREF-ASSESS-"||short,requestedAt)
  if policyReply~ok=.false then return .SecurityResult~failure("CASE_POLICY_ATTACH_FAILED",policyReply~code||":"||policyReply~detail,policyReply)
  return .SecurityResult~success(.SecurityRelationshipCaseReferral~new(decision,caseId,assessmentRef,openReply,subjectReply,assessmentReply,policyReply),"REFERRED")

::requires "SecurityEffect.cls"
::requires "InstitutionalPolicy.cls"
::requires "RelationshipCase.cls"
::requires "RelationshipCaseService.cls"
::requires "crypto.cls"
