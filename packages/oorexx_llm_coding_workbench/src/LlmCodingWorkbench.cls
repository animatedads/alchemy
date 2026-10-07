/* ooRexx LLM Coding Workbench v0.1-dev13
 *
 * Orchestrates one semantic coding action per model turn without flattening
 * SCCD/Development Desk source objects or model-supplied method bodies into
 * command prose.  Existing authorities remain authoritative:
 *   - Semantic Source Store / Development Desk owns source state
 *   - Intention Service owns interpretation/policy/commit
 *   - API Client owns outbound HTTP/TLS
 */

::class LlmCodingWorkbenchBuild public
::constant VERSION "0.1-dev13"
::constant API "llm.coding.workbench/0.1"

::class LlmCodingTurn public
::attribute id get
::attribute challenge get
::attribute target get
::attribute semanticContext get
::attribute controls get
::attribute observations get
::attribute rules get
::attribute workflow get

::method init
  expose id challenge target semanticContext controls observations rules workflow
  use strict arg idArg, challengeArg, targetArg, semanticContextArg, controlsArg, observationsArg=.nil
  id=idArg~string
  challenge=challengeArg~string
  target=targetArg
  semanticContext=semanticContextArg
  controls=controlsArg
  if observationsArg==.nil then observations=.array~new
  else observations=observationsArg
  rules=.array~new
  rules~append("ONE_ACTION_PER_TURN")
  rules~append("INSPECT_SEMANTIC_OBJECTS_NOT_FILES")
  rules~append("WRITE_METHOD_BODY_ONLY")
  rules~append("NO_SOURCE_FILE_REPLACEMENT")
  rules~append("CONTROLLER_OWNS_PACKAGE_PATH_AND_ACTOR")
  rules~append("WAIT_FOR_ACTION_RESULT")
  rules~append("USE_VERIFICATION_EVIDENCE_BEFORE_REPORT")
  workflow=.array~new
  workflow~append("Inspect the supplied semantic class and method objects.")
  workflow~append("Choose exactly one allowed action.")
  workflow~append("For WRITE_METHOD supply only Rexx statements for the method body.")
  workflow~append("Wait for the next turn containing authoritative action and verification evidence.")
  workflow~append("Repair from structured verification evidence when a compile/test fails.")
  workflow~append("REPORT only when the coding challenge is complete and evidence supports completion.")

::method asDirectory
  expose id challenge target semanticContext controls observations rules workflow
  d=.directory~new
  d["schema"]="oorexx.llm-coding.turn/0.2"
  d["turn_id"]=id
  d["challenge"]=challenge
  d["target"]=target
  d["semantic_context"]=semanticContext
  d["controls"]=controls
  d["observations"]=observations
  d["rules"]=rules
  d["workflow"]=workflow
  return d

::class LlmCodingDecision public
::attribute action get
::attribute args get
::attribute report get
::attribute raw get

::method init
  expose action args report raw
  use strict arg actionArg,argsArg=.nil,reportArg="",rawArg=.nil
  action=translate(strip(actionArg~string))
  if argsArg==.nil then args=.directory~new
  else args=argsArg
  report=reportArg~string
  raw=rawArg

::class LlmCodingJsonCodec public
::method encodeTurn
  use strict arg turn
  return .json~toJson(turn~asDirectory)

::method decodeDecision
  use strict arg text
  parsed=.json~fromJson(text~string)
  if parsed==.nil then raise syntax 88.900 array("model response was not JSON")
  if \parsed~isA(.directory) then raise syntax 88.900 array("model response must be one JSON object")
  if \parsed~hasIndex("action") then raise syntax 88.900 array("model response missing action")
  action=translate(strip(parsed["action"]~string))
  if action=="" then raise syntax 88.900 array("model response action is empty")
  args=.directory~new
  if parsed~hasIndex("args") then do
    if parsed["args"]==.nil then nop
    else if parsed["args"]~isA(.directory) then args=parsed["args"]
    else raise syntax 88.900 array("model response args must be an object")
  end
  report=""
  if parsed~hasIndex("report") then do
    if parsed["report"]\==.nil then report=parsed["report"]~string
  end
  return .LlmCodingDecision~new(action,args,report,parsed)

::class LlmCodingDeskSession public
::attribute desk get
::attribute memberPath get
::attribute packageObjectId get
::attribute projectId get
::attribute actor get
::attribute instrumentation

::method init
  expose desk memberPath packageObjectId projectId actor instrumentation
  use strict arg deskArg,memberPathArg,packageObjectIdArg,projectIdArg="llm-coding",actorArg="llm-coding-workbench",instrumentationArg=.nil
  if deskArg==.nil then raise syntax 88.900 array("Development Desk object is required")
  desk=deskArg
  memberPath=memberPathArg~string
  packageObjectId=packageObjectIdArg~string
  projectId=projectIdArg~string
  actor=actorArg~string
  instrumentation=instrumentationArg

::method controls
  expose desk
  d=.directory~new
  d["buttons"]=desk~buttons
  d["class_file_model"]=desk~classFileModel
  d["action_contracts"]=self~actionContracts
  return d

::method actionContracts
  contracts=.array~new
  contracts~append(self~contract("LIST_CLASSES",.array~new,.array~of("member_path"),"Inspect package classes."))
  contracts~append(self~contract("VIEW_CLASS",.array~of("class_name"),.array~new,"Inspect one class semantic object."))
  contracts~append(self~contract("VIEW_METHOD",.array~of("class_name","method_name"),.array~new,"Inspect one method semantic object and projection."))
  contracts~append(self~contract("VIEW_ATTRIBUTE",.array~of("class_name","attribute_name"),.array~new,"Inspect one attribute semantic object."))
  contracts~append(self~contract("CREATE_CLASS",.array~of("class_name","ordinal"),.array~of("package_object_id","member_path","actor"),"Create a class semantic object."))
  contracts~append(self~contract("ADD_REQUIRES",.array~of("requires_target","ordinal"),.array~of("package_object_id","member_path","actor"),"Add one package-level ::requires semantic object."))
  contracts~append(self~contract("ADD_ATTRIBUTE",.array~of("class_name","attribute_name","ordinal"),.array~of("package_object_id","member_path","actor"),"Add one attribute semantic object."))
  contracts~append(self~contract("ADD_METHOD",.array~of("class_name","method_name","ordinal"),.array~of("package_object_id","member_path","actor"),"Add one method semantic object with an empty body."))
  contracts~append(self~contract("WRITE_METHOD",.array~of("class_name","method_name","method_body"),.array~of("package_object_id","member_path","actor"),"Replace one existing method body only."))
  contracts~append(self~contract("MATERIALISE",.array~new,.array~of("package_object_id","project_id"),"Reconstruct conventional source for verification."))
  contracts~append(self~contract("REPORT",.array~new,.array~new,"Report completion after verification evidence."))
  return contracts

::method contract private
  use strict arg action,modelArgs,controllerArgs,purpose
  d=.directory~new
  d["action"]=action
  d["model_args"]=modelArgs
  d["controller_args"]=controllerArgs
  d["purpose"]=purpose
  return d

::method viewClass
  expose desk
  use strict arg className
  req=.directory~new; req["class_name"]=className
  return desk~press("VIEW_CLASS",req)

::method viewMethod
  expose desk
  use strict arg className,methodName
  req=.directory~new; req["class_name"]=className; req["method_name"]=methodName
  return desk~press("VIEW_METHOD",req)

::method execute
  expose desk memberPath packageObjectId projectId actor instrumentation
  use strict arg actionArg,args
  action=translate(actionArg~string)
  request=.directory~new
  select
    when action=="LIST_CLASSES" then request["member_path"]=memberPath
    when action=="VIEW_CLASS" then request["class_name"]=self~required(args,"class_name")
    when action=="VIEW_METHOD" then do
      request["class_name"]=self~required(args,"class_name")
      request["method_name"]=self~required(args,"method_name")
    end
    when action=="VIEW_ATTRIBUTE" then do
      request["class_name"]=self~required(args,"class_name")
      request["attribute_name"]=self~required(args,"attribute_name")
    end
    when action=="CREATE_CLASS" then do
      request["package_object_id"]=packageObjectId
      request["member_path"]=memberPath
      request["class_name"]=self~required(args,"class_name")
      request["ordinal"]=self~requiredWhole(args,"ordinal")
      request["actor"]=actor
    end
    when action=="ADD_REQUIRES" then do
      request["package_object_id"]=packageObjectId
      request["member_path"]=memberPath
      request["requires_target"]=self~required(args,"requires_target")
      request["ordinal"]=self~requiredWhole(args,"ordinal")
      request["actor"]=actor
    end
    when action=="ADD_ATTRIBUTE" then do
      request["package_object_id"]=packageObjectId
      request["member_path"]=memberPath
      request["class_name"]=self~required(args,"class_name")
      request["attribute_name"]=self~required(args,"attribute_name")
      request["ordinal"]=self~requiredWhole(args,"ordinal")
      request["actor"]=actor
    end
    when action=="ADD_METHOD" then do
      request["package_object_id"]=packageObjectId
      request["member_path"]=memberPath
      request["class_name"]=self~required(args,"class_name")
      request["method_name"]=self~required(args,"method_name")
      request["ordinal"]=self~requiredWhole(args,"ordinal")
      request["actor"]=actor
    end
    when action=="WRITE_METHOD" then do
      request["package_object_id"]=packageObjectId
      request["member_path"]=memberPath
      request["class_name"]=self~required(args,"class_name")
      request["method_name"]=self~required(args,"method_name")
      request["method_body"]=self~required(args,"method_body")
      self~assertMethodBody(request["method_body"])
      request["actor"]=actor
    end
    when action=="MATERIALISE" then do
      request["package_object_id"]=packageObjectId
      request["project_id"]=projectId
    end
    otherwise raise syntax 88.900 array("unsupported coding action: "||action)
  end
  if instrumentation\==.nil then ignored=instrumentation~record("TOOL_CALL",action,request,desk)
  result=desk~press(action,request)
  if instrumentation\==.nil then ignored=instrumentation~record("TOOL_RESULT",action,result,request)
  return result

::method required private
  use strict arg args,name
  if \args~hasIndex(name) then raise syntax 88.900 array("missing model action argument "||name)
  value=args[name]
  if value==.nil | strip(value~string)=="" then raise syntax 88.900 array("empty model action argument "||name)
  return value

::method requiredWhole private
  use strict arg args,name
  value=self~required(args,name)
  if \datatype(value~string,"W") then raise syntax 88.900 array(name||" must be a whole number")
  return value

::method assertMethodBody private
  use strict arg bodyArg
  remaining=bodyArg~string || "0a"x
  do while remaining\==""
    parse var remaining line "0a"x remaining
    line=strip(line,"T","0d"x)
    if left(strip(line),2)=="::" then raise syntax 88.900 array("WRITE_METHOD accepts method body only; directives are not allowed")
  end
  return

::class LlmCodingWorkbench public
::attribute session get
::attribute intentions get
::attribute transport get
::attribute codec get
::attribute turnSequence get private
::attribute observations get private
::attribute semanticBridges get private
::attribute hintBridge get private
::attribute evidenceGate get private
::attribute instrumentation get
::attribute boundary get

::method init
  expose session intentions transport codec turnSequence observations semanticBridges hintBridge evidenceGate instrumentation boundary
  use strict arg sessionArg,intentionsArg,transportArg=.nil,hintBridgeArg=.nil,instrumentationArg=.nil,boundaryArg=.nil
  session=sessionArg
  intentions=intentionsArg
  transport=transportArg
  codec=.LlmCodingJsonCodec~new
  turnSequence=0
  observations=.array~new
  semanticBridges=.directory~new
  hintBridge=hintBridgeArg
  if hintBridge\==.nil then hintBridge~registerWith(intentions~service)
  evidenceGate=.nil
  if intentions~hasMethod("service") then evidenceGate=.LlmCodingEvidenceGate~new(intentions~service)
  if instrumentationArg==.nil then instrumentation=.LlmCodingInstrumentation~new
  else instrumentation=instrumentationArg
  if boundaryArg==.nil then boundary=.LlmCodingBoundaryAdapter~new
  else boundary=boundaryArg
  if session~hasMethod("instrumentation=") then session~instrumentation=instrumentation

::method prepareMethodTurn
  expose session turnSequence observations semanticBridges hintBridge evidenceGate instrumentation
  use strict arg challenge,className,methodName
  turnSequence+=1
  target=.directory~new
  target["member_path"]=session~memberPath
  target["class_name"]=className
  target["method_name"]=methodName
  semantic=.directory~new
  classObject=session~viewClass(className)
  methodObject=session~viewMethod(className,methodName)
  semantic["class"]=classObject
  semantic["method"]=methodObject
  ignored=instrumentation~record("OBJECT_READ","VIEW_CLASS",classObject,session~desk)
  ignored=instrumentation~record("OBJECT_READ","VIEW_METHOD",methodObject,classObject)
  key=className||"::"||methodName
  if semanticBridges~at(key)==.nil then semanticBridges[key]=.LlmSemanticCodingBridge~new(className,methodName)
  coding=.directory~new
  coding["mode"]="SEMANTIC_STEPS_PREFERRED"
  coding["steps"]=semanticBridges[key]~describeSteps
  coding["rendered_method_body"]=semanticBridges[key]~renderMethodBody
  coding["available_skills"]=semanticBridges[key]~availableSkills
  coding["available_operations"]=semanticBridges[key]~availableOperations
  if evidenceGate\==.nil then evidenceGate~publishBridgeEvidence(semanticBridges[key])
  coding["runtime_evidence"]=semanticBridges[key]~runtimeEvidence
  if evidenceGate\==.nil then coding["intention_evidence"]=evidenceGate~evidence
  coding["raw_write_method"]="ESCAPE_HATCH_ONLY"
  semantic["coding_intention"]=coding
  if hintBridge\==.nil then semantic["hints"]=hintBridge~advise(self~hintStateTags)
  turn=.LlmCodingTurn~new("turn-"||turnSequence,challenge,target,semantic,session~controls,observations)
  ignored=instrumentation~record("WORKBENCH","PREPARE_METHOD_TURN",turn,semantic)
  return turn

::method hintStateTags private
  expose observations
  tags=.array~of("SEMANTIC_METHOD_TARGET")
  do e over observations
    if e~isA(.directory) then do
      if e~hasIndex("kind") then if e["kind"]=="VERIFICATION" then do
        if e["status"]=="FAIL" then tags~append("VERIFICATION_FAILED")
        if e["status"]=="PASS" then tags~append("VERIFICATION_PASSED")
      end
      if e~hasIndex("model_action") then do
        a=translate(e["model_action"]~string)
        if a=="WRITE_METHOD" | a=="CODING_APPLY_METHOD" then tags~append("METHOD_CHANGED")
      end
    end
  end
  return tags

::method ask
  expose transport codec instrumentation boundary
  use strict arg turn
  if transport==.nil then raise syntax 88.900 array("LLM transport is not configured")
  ignored=instrumentation~record("API_CALL","MODEL_INVOKE",turn,transport)
  if transport~hasMethod("INVOKETURN") then raw=transport~invokeTurn(turn,boundary)
  else raw=transport~invoke(boundary~turnDirectory(turn))
  decision=codec~decodeDecision(raw)
  ignored=instrumentation~record("API_RESULT","MODEL_INVOKE",decision,raw)
  return decision

::method observe
  expose observations instrumentation
  use strict arg evidence
  if evidence==.nil then return self
  observations~append(evidence)
  ignored=instrumentation~record("EVIDENCE","OBSERVE",evidence,self)
  return self

::method recordVerification
  expose observations instrumentation
  use strict arg stage,status,details=.nil
  evidence=.directory~new
  evidence["schema"]="oorexx.llm-coding.verification/0.1"
  evidence["kind"]="VERIFICATION"
  evidence["stage"]=translate(stage~string)
  evidence["status"]=translate(status~string)
  if details==.nil then details=.directory~new
  evidence["details"]=details
  observations~append(evidence)
  ignored=instrumentation~record("EVIDENCE","VERIFICATION",evidence,details)
  return evidence

::method semanticBridge
  expose semanticBridges
  use strict arg className,methodName
  key=className||"::"||methodName
  bridge=semanticBridges~at(key)
  if bridge==.nil then do
    bridge=.LlmSemanticCodingBridge~new(className,methodName)
    semanticBridges[key]=bridge
  end
  return bridge

::method bindRuntimeObject
  use strict arg className,methodName,objectName,value,source="RUNTIME_INTERROGATION"
  bridge=self~semanticBridge(className,methodName)
  return bridge~bindRuntimeObject(objectName,value,source)

::method hintObjectClass
  use strict arg className,methodName,objectName,contractClass,source="CLASS_CONTRACT_HINT"
  bridge=self~semanticBridge(className,methodName)
  return bridge~hintObjectClass(objectName,contractClass,source)

::method hintObjectShape
  use strict arg className,methodName,objectName,shape,confidence=85,source="SHAPE_HINT"
  bridge=self~semanticBridge(className,methodName)
  return bridge~hintObjectShape(objectName,shape,confidence,source)

::method applySemanticStep
  expose session intentions observations evidenceGate
  use strict arg modelDecision
  args=modelDecision~args
  className=self~requiredDecisionArg(args,"class_name")
  methodName=self~requiredDecisionArg(args,"method_name")
  bridge=self~semanticBridge(className,methodName)
  action=modelDecision~action
  select
    when action=="CODING_RETURN_IF_ALREADY" then bridge~addReturnIfAlready(self~requiredDecisionArg(args,"attribute_name"),self~requiredDecisionArg(args,"condition"),self~requiredDecisionArg(args,"return_value"))
    when action=="CODING_SET_ATTRIBUTE" then bridge~addSetAttribute(self~requiredDecisionArg(args,"attribute_name"),self~requiredDecisionArg(args,"value"))
    when action=="CODING_LOAD_JSON_FILE" then bridge~addLoadJsonFile(self~requiredDecisionArg(args,"filename"),self~requiredDecisionArg(args,"target_object"))
    when action=="CODING_GET_NAMED_MEMBER" then bridge~addGetNamedMember(self~requiredDecisionArg(args,"source_object"),self~requiredDecisionArg(args,"member"),self~requiredDecisionArg(args,"target_object"))
    when action=="CODING_OPERATION" then do
      opArgs=.directory~new
      do name over .array~of("target","source","value","member","message","filename","index","names")
        if args~hasIndex(name) then if args[name]\==.nil then opArgs[name]=args[name]
      end
      operation=self~requiredDecisionArg(args,"operation")
      if evidenceGate\==.nil then do
        gateDecision=evidenceGate~assessOperation(operation,opArgs,bridge)
        if gateDecision~status\=="READY" then do
          outcome=.directory~new
          outcome["model_action"]=action
          outcome["semantic_step_status"]="EVIDENCE_"||gateDecision~status
          outcome["intention_status"]=gateDecision~status
          outcome["question"]=gateDecision~question
          if gateDecision~proposedPlan\==.nil then outcome["plan_executable"]=gateDecision~planExecutable
          outcome["semantic_steps"]=bridge~describeSteps
          observations~append(outcome)
          return outcome
        end
      end
      bridge~addOperation(operation,opArgs)
      if evidenceGate\==.nil then evidenceGate~publishBridgeEvidence(bridge)
    end
    when action=="CODING_CLEAR_STEPS" then bridge~clear
    when action=="CODING_APPLY_METHOD" then do
      generated=.directory~new
      generated["class_name"]=className
      generated["method_name"]=methodName
      generated["method_body"]=bridge~renderMethodBody
      generatedDecision=.LlmCodingDecision~new("WRITE_METHOD",generated,"",modelDecision~raw)
      outcome=self~apply(generatedDecision)
      outcome["semantic_steps"]=bridge~describeSteps
      outcome["generated_method_body"]=generated["method_body"]
      return outcome
    end
    otherwise raise syntax 88.900 array("unsupported semantic coding action: "||action)
  end
  outcome=.directory~new
  outcome["model_action"]=action
  outcome["semantic_step_status"]="ACCEPTED"
  outcome["semantic_steps"]=bridge~describeSteps
  outcome["generated_method_body"]=bridge~renderMethodBody
  observations~append(outcome)
  return outcome

::method requiredDecisionArg private
  use strict arg args,name
  if \args~hasIndex(name) then raise syntax 88.900 array("missing semantic coding argument "||name)
  if args[name]==.nil then raise syntax 88.900 array("nil semantic coding argument "||name)
  return args[name]

::method apply
  expose session intentions observations instrumentation
  use strict arg modelDecision
  if left(modelDecision~action,7)=="CODING_" then return self~applySemanticStep(modelDecision)
  if modelDecision~action=="REPORT" then do
    if \self~hasPassingVerification then do
      outcome=.directory~new
      outcome["model_action"]="REPORT"
      outcome["workbench_status"]="VERIFY_REQUIRED"
      outcome["intention_status"]="NOT_SUBMITTED"
      outcome["question"]="Verification PASS is required before REPORT"
      observations~append(outcome)
      return outcome
    end
  end
  ignored=instrumentation~record("WORKBENCH","APPLY_DECISION",modelDecision,self)
  intentionDecision=intentions~interpret(modelDecision)
  ignored=instrumentation~record("INTENTION","INTERPRET",intentionDecision,modelDecision)
  outcome=.directory~new
  outcome["model_action"]=modelDecision~action
  outcome["intention_status"]=intentionDecision~status
  outcome["question"]=intentionDecision~question
  if intentionDecision~status\=="READY" then do
    observations~append(outcome)
    return outcome
  end
  dispatched=intentions~commit(intentionDecision)
  if translate(dispatched~string)\==modelDecision~action then -
    raise syntax 88.900 array("Intention dispatch mismatch: "||dispatched||" vs "||modelDecision~action)
  outcome["dispatch"]=dispatched
  if modelDecision~action=="REPORT" then do
    outcome["report"]=modelDecision~report
    outcome["workbench_status"]="COMPLETE"
    observations~append(outcome)
    return outcome
  end
  deskResult=session~execute(modelDecision~action,modelDecision~args)
  outcome["desk_result"]=deskResult
  ignored=instrumentation~record("WORKBENCH","DESK_APPLIED",deskResult,outcome)
  observations~append(outcome)
  return outcome


::method hasPassingVerification private
  expose observations
  do e over observations
    if e~isA(.directory) then do
      if e~hasIndex("kind") then if e["kind"]=="VERIFICATION" then do
        if e~hasIndex("status") then if translate(e["status"]~string)=="PASS" then return .true
      end
    end
  end
  return .false

::requires "LlmSemanticCodingBridge.cls"
::requires "LlmCodingInstrumentation.cls"
::requires "LlmCodingBoundaryAdapter.cls"
::requires "LlmCodingEvidenceGate.cls"
::requires "json.cls"

::requires "LlmCodingHintBridge.cls"
