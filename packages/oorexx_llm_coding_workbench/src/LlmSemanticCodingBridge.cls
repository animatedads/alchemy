/* LLM semantic coding bridge v0.1-dev13.
 * Consumes a build-time structured projection of Coding Intention dev13 RexxLanguageKnowledge.
 * Runtime witnesses and class contracts can prove message sends before source is emitted.
 * Luna selects semantic operations; this class owns deterministic ooRexx spelling.
 */
::class LlmSemanticCodingStep public
::attribute kind get
::attribute attributeName get
::attribute value get
::attribute condition get
::attribute returnValue get
::method init
  expose kind attributeName value condition returnValue
  use strict arg kindArg,attributeNameArg="",valueArg="",conditionArg="",returnValueArg=""
  kind=translate(kindArg~string); attributeName=attributeNameArg~string; value=valueArg; condition=conditionArg; returnValue=returnValueArg
::method describe
  expose kind attributeName value condition returnValue
  d=.directory~new; d["kind"]=kind; d["attribute_name"]=attributeName; d["value"]=value; d["condition"]=condition; d["return_value"]=returnValue; return d

::class LlmSemanticOperationStep public
::attribute operation get
::attribute args get
::attribute knowledge get
::method init
  expose operation args knowledge
  use strict arg operationArg,argsArg,knowledgeArg
  operation=translate(operationArg~string); args=argsArg; knowledge=knowledgeArg
::method describe
  expose operation knowledge
  return operation||" => "||knowledge~describe

::class LlmSemanticCodingBridge public
::attribute className get
::attribute methodName get
::attribute steps get

::method init
  expose className methodName steps operations knowledge runtimeEvidence
  use strict arg classNameArg, methodNameArg, knowledgeArg=.nil
  className=classNameArg~string; methodName=methodNameArg~string
  steps=.array~new; operations=.array~new
  if knowledgeArg==.nil then do
    path=value("LLM_CODING_CATALOGUE",,"ENVIRONMENT")
    if path=="" then raise syntax 88.900 array("LLM_CODING_CATALOGUE must point to the exported Coding Intention language catalogue")
    knowledge=.LlmRexxKnowledgeCatalogue~new(path)
  end
  else knowledge=knowledgeArg
  runtimeEvidence=.LlmRuntimeEvidenceRegistry~new(knowledge)

::method availableSkills
  expose knowledge
  out=.array~new
  do id over knowledge~skills
    s=knowledge~resolveSkill(id)
    d=.directory~new; d["id"]=s~id; d["purpose"]=s~purpose; d["operations"]=s~operations
    out~append(d)
  end
  return out
::method availableOperations
  expose knowledge
  out=.array~new
  do id over knowledge~operations
    k=knowledge~resolveOperation(id)
    d=.directory~new; d["operation"]=id; d["language_supported"]=knowledge~supportsOperation(id); d["category"]=k~category; d["form"]=k~form; d["result_type"]=k~resultType; d["package"]=k~package; d["capability_evidence"]=k~evidence
    d["renderable"]=self~isRenderable(id)
    out~append(d)
  end
  return out

::method bindRuntimeObject
  expose runtimeEvidence
  use strict arg objectName,value,source="RUNTIME_INTERROGATION"
  return runtimeEvidence~bind(objectName,value,source)
::method hintObjectClass
  expose runtimeEvidence
  use strict arg objectName,className,source="CLASS_CONTRACT_HINT"
  return runtimeEvidence~hintClass(objectName,className,source)
::method hintObjectShape
  expose runtimeEvidence
  use strict arg objectName,shape,confidence=85,source="SHAPE_HINT"
  return runtimeEvidence~hintShape(objectName,shape,confidence,source)
::method runtimeEvidence
  expose runtimeEvidence
  return runtimeEvidence~allEvidence
::method objectEvidence
  expose runtimeEvidence
  use strict arg objectName
  e=runtimeEvidence~evidenceFor(objectName)
  if e==.nil then return .nil
  return e~asDirectory
::method messageEvidence
  expose runtimeEvidence
  use strict arg sourceObject,message
  return runtimeEvidence~checkMessage(sourceObject,message)

::method addReturnIfAlready
  expose className methodName steps
  use strict arg attributeName,condition,returnValue
  step=.LlmSemanticCodingStep~new("RETURN_IF_ALREADY",attributeName,"",condition,returnValue)
  steps~append(step); return step
::method addSetAttribute
  expose className methodName steps
  use strict arg attributeName,value
  step=.LlmSemanticCodingStep~new("SET_ATTRIBUTE",attributeName,value,"","")
  steps~append(step); return step
::method addLoadJsonFile
  use strict arg filename,targetObject
  a=.directory~new; a["filename"]=filename; a["target"]=targetObject
  return self~addOperation("LOAD_JSON_FILE",a)
::method addGetNamedMember
  use strict arg sourceObject,member,targetObject
  a=.directory~new; a["source"]=sourceObject; a["member"]=member; a["target"]=targetObject
  return self~addOperation("GET_NAMED_MEMBER",a)

::method supportsOperation
  expose knowledge
  use strict arg operationArg
  return knowledge~supportsOperation(operationArg)

::method addOperation
  expose operations knowledge runtimeEvidence
  use strict arg operationArg,argsArg
  operation=translate(strip(operationArg~string))
  if \knowledge~supportsOperation(operation) then raise syntax 88.900 array("Selected ooRexx language authority has no implementation contract for semantic operation "||operation)
  k=knowledge~resolveOperation(operation)
  if \self~isRenderable(operation) then raise syntax 88.900 array("Coding operation is known but not safely renderable yet: "||operation)
  self~validateOperation(operation,argsArg)
  if operation=="SEND_MESSAGE" then do
    proof=runtimeEvidence~checkMessage(argsArg["source"],argsArg["message"])
    if \proof["allowed"] then raise syntax 88.900 array("SEND_MESSAGE rejected: "||proof["reason"])
    argsArg["message_evidence"]=proof
  end
  if operation=="SEND_MESSAGE" then do
    if argsArg~hasIndex("target") then do
      if argsArg["target"]\==.nil then do
        if strip(argsArg["target"]~string)<>"" then ignored=runtimeEvidence~propagateMethodResult(argsArg["source"],argsArg["message"],argsArg["target"])
      end
    end
  end
  if operation=="GET_NAMED_MEMBER" | operation=="GET_KEYS" | operation=="CONTAINS_KEY" then do
    proof=runtimeEvidence~checkKeyed(argsArg["source"])
    if \proof["allowed"] then raise syntax 88.900 array(operation||" rejected: "||proof["reason"])
    argsArg["shape_evidence"]=proof
  end
  if operation=="GET_COLLECTION_SIZE" then do
    proof=runtimeEvidence~checkCollection(argsArg["source"])
    if \proof["allowed"] then raise syntax 88.900 array("GET_COLLECTION_SIZE rejected: "||proof["reason"])
    argsArg["shape_evidence"]=proof
  end
  if operation=="APPEND_ITEM" then do
    proof=runtimeEvidence~checkSequence(argsArg["source"])
    if \proof["allowed"] then raise syntax 88.900 array("APPEND_ITEM rejected: "||proof["reason"])
    argsArg["shape_evidence"]=proof
  end
  step=.LlmSemanticOperationStep~new(operation,argsArg,k)
  operations~append(step)
  if operation=="CREATE_DIRECTORY" then runtimeEvidence~rememberEvidence(argsArg["target"],"DIRECTORY","Directory",100,"SEMANTIC_CONSTRUCTION")
  if operation=="CREATE_ARRAY" then runtimeEvidence~rememberEvidence(argsArg["target"],"ARRAY","Array",100,"SEMANTIC_CONSTRUCTION")
  if operation=="OPEN_CSV_STREAM" then runtimeEvidence~rememberEvidence(argsArg["target"],"CSVSTREAM","CsvStream",100,"SEMANTIC_CONSTRUCTION")
  if operation=="LOAD_JSON_FILE" | operation=="PARSE_JSON_TEXT" then runtimeEvidence~rememberEvidence(argsArg["target"],"JSON_VALUE","",60,"SEMANTIC_OPERATION_RESULT")
  if operation=="LOAD_YAML_FILE" | operation=="PARSE_YAML_TEXT" then runtimeEvidence~rememberEvidence(argsArg["target"],"YAML_VALUE","",60,"SEMANTIC_OPERATION_RESULT")
  if operation=="GET_NAMED_MEMBER" then do
    child=runtimeEvidence~propagateMember(argsArg["source"],argsArg["member"],argsArg["target"])
    if child==.nil then runtimeEvidence~rememberEvidence(argsArg["target"],"UNKNOWN","",50,"SEMANTIC_MEMBER_RESULT")
  end
  if operation=="GET_COLLECTION_SIZE" then runtimeEvidence~rememberEvidence(argsArg["target"],"NUMBER","String",95,"PORTABLE_SEMANTIC_CONTRACT")
  if operation=="GET_KEYS" then runtimeEvidence~rememberEvidence(argsArg["target"],"ARRAY","Array",95,"PORTABLE_SEMANTIC_CONTRACT")
  if operation=="CONTAINS_KEY" then runtimeEvidence~rememberEvidence(argsArg["target"],"LOGICAL","String",95,"PORTABLE_SEMANTIC_CONTRACT")
  return step

::method clear
  expose steps operations
  steps=.array~new; operations=.array~new; return self

::method renderMethodBody
  expose steps operations knowledge
  exposed=.array~new; body=""
  do step over steps
    if step~kind=="RETURN_IF_ALREADY" | step~kind=="SET_ATTRIBUTE" then ignored=self~remember(exposed,step~attributeName)
  end
  if exposed~items>0 then body=body||"expose "||self~join(exposed," ")||.endOfLine
  do step over steps
    if step~kind=="RETURN_IF_ALREADY" then body=body||"if "||step~attributeName||" == "||self~literal(step~condition)||" then return "||self~boolean(step~returnValue)||.endOfLine
  end
  mutated=.false
  do step over steps
    if step~kind=="SET_ATTRIBUTE" then do; body=body||step~attributeName||" = "||self~valueExpr(step~value)||.endOfLine; mutated=.true; end
  end
  do opStep over operations
    body=body||self~renderOperation(opStep)||.endOfLine
  end
  if mutated then body=body||"return .true"||.endOfLine
  if body<>"" then if right(body,1)==.endOfLine then body=left(body,length(body)-1)
  return body

::method requiredPackages
  expose operations
  packages=.array~new
  do opStep over operations
    p=opStep~knowledge~package
    if p<>"" then ignored=self~remember(packages,p)
  end
  return packages

::method describeSteps
  expose steps operations
  out=.array~new
  do step over steps; out~append(step~describe); end
  do step over operations; out~append(step~describe); end
  return out

::method isRenderable private
  use strict arg opArg
  op=translate(opArg~string)
  return wordpos(op,"ACCEPT_ARGUMENTS ASSIGN_VALUE RETURN_VALUE SEND_MESSAGE GET_COLLECTION_SIZE GET_KEYS APPEND_ITEM CONTAINS_KEY CREATE_ARRAY APPEND_ARRAY GET_ARRAY_ITEM SET_ARRAY_ITEM CREATE_DIRECTORY GET_NAMED_MEMBER SET_NAMED_MEMBER OPEN_STREAM_READ OPEN_STREAM_WRITE_REPLACE READ_ALL_STREAM WRITE_STREAM_TEXT CLOSE_STREAM LOAD_JSON_FILE SAVE_JSON_FILE PARSE_JSON_TEXT ENCODE_JSON_TEXT LOAD_YAML_FILE SAVE_YAML_FILE PARSE_YAML_TEXT ENCODE_YAML_TEXT OPEN_CSV_STREAM READ_CSV_ROW")>0

::method validateOperation private
  use strict arg op,a
  select
    when op=="ACCEPT_ARGUMENTS" then self~need(a,"names")
    when op=="ASSIGN_VALUE" then do; self~need(a,"target"); self~need(a,"value"); end
    when op=="RETURN_VALUE" then self~need(a,"value")
    when op=="SEND_MESSAGE" then do; self~need(a,"source"); self~need(a,"message"); end
    when op=="GET_COLLECTION_SIZE" | op=="GET_KEYS" then do; self~need(a,"source"); self~need(a,"target"); end
    when op=="APPEND_ITEM" then do; self~need(a,"source"); self~need(a,"value"); end
    when op=="CONTAINS_KEY" then do; self~need(a,"source"); self~need(a,"member"); self~need(a,"target"); end
    when op=="CREATE_ARRAY" | op=="CREATE_DIRECTORY" then self~need(a,"target")
    when op=="APPEND_ARRAY" then do; self~need(a,"target"); self~need(a,"value"); end
    when op=="GET_ARRAY_ITEM" then do; self~need(a,"source"); self~need(a,"index"); self~need(a,"target"); end
    when op=="SET_ARRAY_ITEM" then do; self~need(a,"target"); self~need(a,"index"); self~need(a,"value"); end
    when op=="GET_NAMED_MEMBER" then do; self~need(a,"source"); self~need(a,"member"); self~need(a,"target"); end
    when op=="SET_NAMED_MEMBER" then do; self~need(a,"target"); self~need(a,"member"); self~need(a,"value"); end
    when op=="OPEN_STREAM_READ" | op=="OPEN_STREAM_WRITE_REPLACE" | op=="LOAD_JSON_FILE" | op=="LOAD_YAML_FILE" | op=="OPEN_CSV_STREAM" then do; self~need(a,"filename"); self~need(a,"target"); end
    when op=="READ_ALL_STREAM" | op=="READ_CSV_ROW" then do; self~need(a,"source"); self~need(a,"target"); end
    when op=="WRITE_STREAM_TEXT" then do; self~need(a,"source"); self~need(a,"value"); end
    when op=="CLOSE_STREAM" then self~need(a,"source")
    when op=="SAVE_JSON_FILE" | op=="SAVE_YAML_FILE" then do; self~need(a,"filename"); self~need(a,"source"); end
    when op=="PARSE_JSON_TEXT" | op=="PARSE_YAML_TEXT" then do; self~need(a,"source"); self~need(a,"target"); end
    when op=="ENCODE_JSON_TEXT" | op=="ENCODE_YAML_TEXT" then do; self~need(a,"source"); self~need(a,"target"); end
    otherwise nop
  end
  return .true

::method renderOperation private
  use strict arg s
  op=s~operation; a=s~args
  select
    when op=="ACCEPT_ARGUMENTS" then return "use arg "||a["names"]
    when op=="ASSIGN_VALUE" then return a["target"]||" = "||self~valueExpr(a["value"])
    when op=="RETURN_VALUE" then return "return "||self~valueExpr(a["value"])
    when op=="SEND_MESSAGE" then do
      expr=a["source"]||"~"||a["message"]
      if a~hasIndex("target") then if a["target"]\==.nil & strip(a["target"]~string)<>"" then return a["target"]||" = "||expr
      return expr
    end
    when op=="GET_COLLECTION_SIZE" then return a["target"]||" = "||a["source"]||"~items"
    when op=="GET_KEYS" then return a["target"]||" = "||a["source"]||"~allIndexes"
    when op=="APPEND_ITEM" then return a["source"]||"~append("||self~valueExpr(a["value"])||")"
    when op=="CONTAINS_KEY" then return a["target"]||" = "||a["source"]||"~hasIndex("||self~literal(a["member"])||")"
    when op=="CREATE_ARRAY" then return a["target"]||" = .Array~new"
    when op=="APPEND_ARRAY" then return a["target"]||"~append("||self~valueExpr(a["value"])||")"
    when op=="GET_ARRAY_ITEM" then return a["target"]||" = "||a["source"]||"["||a["index"]||"]"
    when op=="SET_ARRAY_ITEM" then return a["target"]||"["||a["index"]||"] = "||self~valueExpr(a["value"])
    when op=="CREATE_DIRECTORY" then return a["target"]||" = .Directory~new"
    when op=="GET_NAMED_MEMBER" then return a["target"]||" = "||a["source"]||"["||self~literal(a["member"])||"]"
    when op=="SET_NAMED_MEMBER" then return a["target"]||"["||self~literal(a["member"])||"] = "||self~valueExpr(a["value"])
    when op=="OPEN_STREAM_READ" then return a["target"]||" = .stream~new("||self~literal(a["filename"])||")~~open("||self~literal("read")||")"
    when op=="OPEN_STREAM_WRITE_REPLACE" then return a["target"]||" = .stream~new("||self~literal(a["filename"])||")~~open("||self~literal("write replace")||")"
    when op=="READ_ALL_STREAM" then return a["target"]||" = "||a["source"]||"~charIn(1, "||a["source"]||"~chars)"
    when op=="WRITE_STREAM_TEXT" then return a["source"]||"~charOut("||self~valueExpr(a["value"])||")"
    when op=="CLOSE_STREAM" then return a["source"]||"~close"
    when op=="LOAD_JSON_FILE" then return a["target"]||" = .json~fromJsonFile("||self~literal(a["filename"])||")"
    when op=="SAVE_JSON_FILE" then return ".json~toJsonFile("||self~literal(a["filename"])||", "||a["source"]||")"
    when op=="PARSE_JSON_TEXT" then return a["target"]||" = .json~fromJSON("||a["source"]||")"
    when op=="ENCODE_JSON_TEXT" then return a["target"]||" = .json~toJSON("||a["source"]||")"
    when op=="LOAD_YAML_FILE" then return a["target"]||" = .Yaml~new~parseFile("||self~literal(a["filename"])||")"
    when op=="SAVE_YAML_FILE" then return ".Yaml~toYamlFile("||a["source"]||", "||self~literal(a["filename"])||")"
    when op=="PARSE_YAML_TEXT" then return a["target"]||" = .Yaml~new~parseString("||a["source"]||")"
    when op=="ENCODE_YAML_TEXT" then return a["target"]||" = .Yaml~toYaml("||a["source"]||")"
    when op=="OPEN_CSV_STREAM" then return a["target"]||" = .CsvStream~new("||self~literal(a["filename"])||")"
    when op=="READ_CSV_ROW" then return a["target"]||" = "||a["source"]||"~csvLineIn"
    otherwise raise syntax 88.900 array("no deterministic renderer for "||op)
  end

::method need private
  use strict arg a,n
  if \a~hasIndex(n) then raise syntax 88.900 array("missing semantic operand "||n)
  if a[n]==.nil | strip(a[n]~string)=="" then raise syntax 88.900 array("empty semantic operand "||n)
  return a[n]
::method remember private
  use strict arg values,value
  do v over values; if v==value then return values; end
  values~append(value); return values
::method join private
  use strict arg values,separator
  out=""; do v over values; if out<>"" then out=out||separator; out=out||v; end; return out
::method literal private
  use strict arg value
  return '"'||changestr('"',value~string,'""')||'"'
::method boolean private
  use strict arg value
  upper=translate(strip(value~string)); if upper=="FALSE" | upper==".FALSE" then return ".false"; if upper=="TRUE" | upper==".TRUE" then return ".true"; return value
::method valueExpr private
  use strict arg value
  v=strip(value~string)
  if datatype(v,"N") then return v
  u=translate(v); if u=="TRUE" | u==".TRUE" then return ".true"; if u=="FALSE" | u==".FALSE" then return ".false"; if left(v,1)=="$" then return substr(v,2)
  return self~literal(v)

::requires "LlmRexxKnowledgeCatalogue.cls"
::requires "LlmRuntimeInterrogation.cls"
