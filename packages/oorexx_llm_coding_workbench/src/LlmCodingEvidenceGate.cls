/* Evidence bridge for Intention Service dev9.
 *
 * The LLM does not know ooRexx.  It chooses a semantic coding operation.  This
 * gate publishes controller/runtime/language-contract facts into Intention
 * Service dev9, asks the service to assess the operation's evidence-backed
 * plan, and only returns READY when the operation has enough evidence to be
 * safely handed to the deterministic renderer.
 */

::class LlmCodingEvidenceProvider public
::method init
  expose staged sequence intentionId
  use strict arg intentionIdArg
  staged=.directory~new; sequence=0; intentionId=intentionIdArg~string
::method name
  return "LLM_CODING_EVIDENCE_PROVIDER"
::method stage
  expose staged sequence
  use strict arg operation,args
  sequence+=1
  token="EVID"||sequence
  d=.directory~new; d["operation"]=translate(operation~string); d["args"]=args
  staged[token]=d
  return token
::method propose
  expose staged intentionId
  use arg service,text
  offered=.array~new
  parse var text verb token
  if translate(strip(verb))\=="WORKBENCH_SEMANTIC_EVIDENCE" then return offered
  token=strip(token)
  if token=="" | \staged~hasIndex(token) then return offered
  stagedDecision=staged[token]
  proposal=.IntentionProposal~new(intentionId,1000,self~name,.true,"structured coding operation evidence gate")
  proposal~putSlot("OPERATION",stagedDecision["operation"],.true)
  args=stagedDecision["args"]
  do name over .array~of("source","message","member","target")
    if args~hasIndex(name) then if args[name]\==.nil then proposal~putSlot(translate(name),args[name],.true)
  end
  offered~append(proposal)
  return offered

::class LlmCodingEvidencePlanBuilder public
::method build
  use arg service,registration,proposal
  operation=translate(proposal~slot("OPERATION")~value~string)
  plan=.IntentionPlan~new(registration~id,"Evidence gate for semantic coding operation "||operation)
  plan~sideEffectClass="CODE_PLAN"
  select
    when operation=="GET_NAMED_MEMBER" then do
      sourceSlot=proposal~slot("SOURCE"); source=.nil; if sourceSlot\==.nil then source=sourceSlot~value
      if source\==.nil then plan~requireEvidence(source,"CAPABILITY","KEYED_ACCESS",80,"ADVISORY", -
          source||" must have evidence of keyed access", -
          "Need evidence that "||source||" supports keyed member access before generating code.")
    end
    when operation=="SEND_MESSAGE" then do
      sourceSlot=proposal~slot("SOURCE"); messageSlot=proposal~slot("MESSAGE"); source=.nil; message=.nil; if sourceSlot\==.nil then source=sourceSlot~value; if messageSlot\==.nil then message=messageSlot~value
      if source\==.nil & message\==.nil then plan~requireEvidence(source,"METHOD",translate(message~string),90,"CONTRACT", -
          source||" must have contract/runtime evidence for method "||message, -
          "Need runtime or language-contract evidence that "||source||" supports method "||message||" before generating code.")
    end
    otherwise nop
  end
  plan~addStep(operation,"Apply one semantic coding operation","CODE")
  return plan

::class LlmCodingEvidenceGate public
::attribute service get
::attribute provider get
::method init
  expose service provider published registrationId
  use strict arg serviceArg
  service=serviceArg; published=.directory~new
  if service~bucket("LLM_CODING_EVIDENCE")==.nil then -
    service~registerBucket("LLM_CODING_EVIDENCE",.IntentionBucketPolicy~new("FLEXIBLE",55,8,.false,.false))
  reg=service~registration("WORKBENCH_SEMANTIC_CODING_OPERATION")
  if reg==.nil then reg=service~register("workbench semantic coding operation","WORKBENCH_SEMANTIC_OPERATION","LLM_CODING_EVIDENCE")
  reg~planBuilder(.LlmCodingEvidencePlanBuilder~new)
  registrationId=reg~id
  provider=.LlmCodingEvidenceProvider~new(reg~id)
  service~registerProvider(provider)

::method publishBridgeEvidence
  expose service published
  use strict arg bridge
  do row over bridge~runtimeEvidence
    name=row["name"]; shape=translate(row["shape"]~string); className=row["class_name"]
    confidence=row["confidence"]; source=row["source"]
    authority=self~authorityFor(source)
    self~publish(name,"SHAPE",shape,confidence,source,authority,"workbench:runtime-evidence")
    if className\==.nil then do
      if strip(className~string)<>"" then self~publish(name,"CLASS",className,confidence,source,authority,"workbench:runtime-evidence")
    end
    if wordpos(shape,"DIRECTORY TABLE JSON_OBJECT KEYED_OBJECT")>0 then -
      self~publish(name,"CAPABILITY","KEYED_ACCESS",confidence,source,authority,"workbench:shape")
    if wordpos(shape,"ARRAY COLLECTION LIST SET DIRECTORY TABLE")>0 then -
      self~publish(name,"CAPABILITY","ITERABLE",confidence,source,authority,"workbench:shape")
    if shape=="ARRAY" then self~publish(name,"CAPABILITY","INDEXED_ACCESS",confidence,source,authority,"workbench:shape")
  end
  return self

::method publishMessageEvidence
  use strict arg sourceObject,message,proof
  if proof==.nil then return self
  if \proof~hasIndex("allowed") | \proof["allowed"] then return self
  kind=proof["evidence_kind"]
  if kind=="RUNTIME_HASMETHOD" then do
    self~publish(sourceObject,"METHOD",translate(message~string),100,"RUNTIME_HASMETHOD","OBSERVED","workbench:hasMethod")
    return self
  end
  if kind=="CLASS_CONTRACT" then do
    self~publish(sourceObject,"METHOD",translate(message~string),95,"LANGUAGE_CATALOGUE","CONTRACT","coding-intention:class-contract")
    return self
  end
  return self

::method assessOperation
  expose service provider registrationId
  use strict arg operation,args,bridge
  self~publishBridgeEvidence(bridge)
  op=translate(operation~string)
  if op=="SEND_MESSAGE" then do
    proof=bridge~messageEvidence(args["source"],args["message"])
    self~publishMessageEvidence(args["source"],args["message"],proof)
  end
  refreshed=service~refreshActiveDecision
  if refreshed\==.nil then do
    reg=refreshed~registration
    if reg\==.nil then if reg~id==registrationId then do
      p=refreshed~proposal
      if p\==.nil then do
        slot=p~slot("OPERATION")
        if slot\==.nil then if translate(slot~value~string)==op then return refreshed
      end
    end
  end
  token=provider~stage(op,args)
  decision=service~input("WORKBENCH_SEMANTIC_EVIDENCE "||token)
  return decision

::method evidence
  expose service
  facts=service~evidenceFacts
  out=.array~new
  do f over facts
    d=.directory~new
    d["subject"]=f~subject; d["predicate"]=f~predicate; d["value"]=f~value
    d["confidence"]=f~confidence; d["source"]=f~source; d["authority"]=f~authority; d["provenance"]=f~provenance
    out~append(d)
  end
  return out

::method publish private
  expose service published
  use strict arg subject,predicate,value,confidence,source,authority,provenance
  signature=translate(subject~string)||"|"||translate(predicate~string)||"|"||translate(value~string)||"|"||confidence||"|"||authority||"|"||source
  if published~hasIndex(signature) then return published[signature]
  fact=.IntentionEvidenceFact~new(subject,predicate,value,confidence,source,authority,provenance)
  service~addEvidenceFact(fact); published[signature]=fact
  return fact

::method authorityFor private
  use strict arg sourceArg
  source=translate(sourceArg~string)
  if left(source,8)=="RUNTIME_" then return "OBSERVED"
  if source=="SEMANTIC_CONSTRUCTION" then return "CONTRACT"
  if source=="CLASS_METHOD_CONTRACT" then return "CONTRACT"
  if source=="LANGUAGE_CATALOGUE" then return "CONTRACT"
  if pos("HINT",source)>0 then return "ADVISORY"
  if pos("SEMANTIC_",source)=1 then return "INFERRED"
  return "ADVISORY"

::requires "IntentionService.cls"
::requires "IntentionContext.cls"
