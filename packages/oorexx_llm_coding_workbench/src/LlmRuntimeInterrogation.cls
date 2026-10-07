/* Controller-owned runtime evidence inspired by Coding Intention dev13.
 * Runtime observation is confidence 100 and outranks advisory class hints.
 * This class deliberately does not load Coding Intention itself at runtime,
 * avoiding its vendored Intention Service collision.  Exact class/method
 * contracts come from the dev13-exported LlmRexxKnowledgeCatalogue. */
::class LlmRuntimeObjectEvidence public
::method init
  expose name shape className confidence source
  use strict arg nameArg,shapeArg,classNameArg,confidenceArg=100,sourceArg="RUNTIME_INTERROGATION"
  name=nameArg~string; shape=translate(shapeArg~string); className=classNameArg~string; confidence=confidenceArg; source=sourceArg~string
::attribute name get
::attribute shape get
::attribute className get
::attribute confidence get
::attribute source get
::method asDirectory
  expose name shape className confidence source
  d=.directory~new; d["name"]=name; d["shape"]=shape; d["class_name"]=className; d["confidence"]=confidence; d["source"]=source; return d

::class LlmRuntimeEvidenceRegistry public
::method init
  expose witnesses evidence knowledge classHints
  use strict arg knowledgeArg
  witnesses=.directory~new; evidence=.directory~new; classHints=.directory~new; knowledge=knowledgeArg

::method bind
  expose witnesses evidence
  use strict arg nameArg,value,sourceArg="RUNTIME_INTERROGATION"
  name=nameArg~string
  witnesses[name]=value
  e=.LlmRuntimeObjectEvidence~new(name,self~shapeOf(value),self~classNameOf(value),100,sourceArg)
  evidence[name]=e
  return e

::method rememberEvidence
  expose evidence
  use strict arg nameArg,shapeArg="UNKNOWN",classNameArg="",confidenceArg=85,sourceArg="SEMANTIC_EVIDENCE"
  name=nameArg~string
  current=evidence~at(name)
  if current\==.nil then if current~confidence>confidenceArg then return current
  e=.LlmRuntimeObjectEvidence~new(name,shapeArg,classNameArg,confidenceArg,sourceArg)
  evidence[name]=e
  return e

::method hintClass
  expose evidence classHints
  use strict arg nameArg,classNameArg,sourceArg="CLASS_CONTRACT_HINT"
  name=nameArg~string; className=classNameArg~string; classHints[name]=className
  current=evidence~at(name)
  if current\==.nil then do
    if current~confidence>=100 then return current
    shape=current~shape
  end
  else shape="UNKNOWN"
  return self~rememberEvidence(name,shape,className,85,sourceArg)

::method hintShape
  expose evidence classHints
  use strict arg nameArg,shapeArg,confidenceArg=85,sourceArg="SHAPE_HINT"
  name=nameArg~string
  current=evidence~at(name)
  className=""
  if current\==.nil then do
    if current~confidence>=100 then return current
    className=current~className
  end
  if className=="" then if classHints~hasIndex(name) then className=classHints[name]
  return self~rememberEvidence(name,shapeArg,className,confidenceArg,sourceArg)

::method hasWitness
  expose witnesses
  use strict arg nameArg
  return witnesses~hasIndex(nameArg~string)
::method witness
  expose witnesses
  use strict arg nameArg
  if witnesses~hasIndex(nameArg~string) then return witnesses[nameArg~string]
  return .nil
::method evidenceFor
  expose evidence
  use strict arg nameArg
  return evidence~at(nameArg~string)
::method allEvidence
  expose evidence
  out=.array~new
  do name over evidence; out~append(evidence[name]~asDirectory); end
  return out

::method propagateMember
  expose witnesses
  use strict arg sourceName,memberName,targetName
  if \witnesses~hasIndex(sourceName~string) then return .nil
  source=witnesses[sourceName~string]
  child=source[memberName]
  return self~bind(targetName,child,"RUNTIME_MEMBER_INTERROGATION")

::method propagateCollectionSample
  expose witnesses
  use strict arg sourceName,targetName
  if \witnesses~hasIndex(sourceName~string) then return .nil
  source=witnesses[sourceName~string]
  if \source~hasMethod("items") then return .nil
  if source~items=0 then return .nil
  if source~hasMethod("at") then child=source~at(1)
  else return .nil
  return self~bind(targetName,child,"RUNTIME_COLLECTION_SAMPLE")

::method checkKeyed
  expose evidence
  use strict arg sourceName
  r=.directory~new; r["source_object"]=sourceName~string
  e=evidence~at(sourceName~string)
  if e==.nil then do; r["allowed"]=.false; r["reason"]="no shape evidence for keyed access"; return r; end
  shape=e~shape
  r["shape"]=shape; r["confidence"]=e~confidence; r["source"]=e~source
  r["allowed"]=wordpos(shape,"DIRECTORY TABLE JSON_OBJECT KEYED_OBJECT")>0
  if r["allowed"] then r["reason"]="shape evidence permits keyed access"
  else r["reason"]="shape evidence "||shape||" does not permit keyed access"
  return r

::method checkCollection
  expose evidence
  use strict arg sourceName
  r=.directory~new; r["source_object"]=sourceName~string
  e=evidence~at(sourceName~string)
  if e==.nil then do; r["allowed"]=.false; r["reason"]="no shape evidence for collection iteration"; return r; end
  shape=e~shape
  r["shape"]=shape; r["confidence"]=e~confidence; r["source"]=e~source
  r["allowed"]=wordpos(shape,"ARRAY COLLECTION LIST SET DIRECTORY TABLE")>0
  if r["allowed"] then r["reason"]="shape evidence permits collection iteration"
  else r["reason"]="shape evidence "||shape||" does not permit collection iteration"
  return r

::method checkSequence
  expose evidence
  use strict arg sourceName
  r=.directory~new; r["source_object"]=sourceName~string
  e=evidence~at(sourceName~string)
  if e==.nil then do; r["allowed"]=.false; r["reason"]="no shape evidence for sequence operation"; return r; end
  shape=e~shape
  r["shape"]=shape; r["confidence"]=e~confidence; r["source"]=e~source
  r["allowed"]=wordpos(shape,"ARRAY COLLECTION LIST")>0
  if r["allowed"] then r["reason"]="shape evidence permits sequence operation"
  else r["reason"]="shape evidence "||shape||" does not permit sequence operation"
  return r

::method propagateMethodResult
  expose witnesses evidence knowledge classHints
  use strict arg sourceName,messageName,targetName
  sourceName=sourceName~string; messageName=messageName~string; targetName=targetName~string
  className=""
  if witnesses~hasIndex(sourceName) then className=self~classNameOf(witnesses[sourceName])
  else do
    e=evidence~at(sourceName)
    if e\==.nil then className=e~className
    if className=="" then if classHints~hasIndex(sourceName) then className=classHints[sourceName]
  end
  if className=="" then return self~rememberEvidence(targetName,"UNKNOWN","",50,"METHOD_RESULT_UNKNOWN")
  contract=knowledge~resolveMethodContract(className,messageName)
  if contract==.nil then return self~rememberEvidence(targetName,"UNKNOWN","",50,"METHOD_RESULT_UNKNOWN")
  shape=self~resultShape(contract~resultType)
  resultClass=self~resultClass(contract~resultType)
  confidence=95
  if shape=="UNKNOWN" then confidence=50
  return self~rememberEvidence(targetName,shape,resultClass,confidence,"CLASS_METHOD_CONTRACT")

::method resultShape private
  use strict arg resultTypeArg
  resultType=translate(strip(resultTypeArg~string))
  select
    when resultType=="INTEGER" | resultType=="NUMBER" | resultType=="INDEX" then return "NUMBER"
    when resultType=="ARRAY" | resultType==".ARRAY" then return "ARRAY"
    when resultType=="DIRECTORY" | resultType==".DIRECTORY" | resultType=="JSON_OBJECT" then return "DIRECTORY"
    when resultType=="STRING" then return "STRING"
    when resultType=="LOGICAL" | resultType=="BOOLEAN" then return "LOGICAL"
    otherwise return "UNKNOWN"
  end

::method resultClass private
  use strict arg resultTypeArg
  resultType=translate(strip(resultTypeArg~string))
  select
    when resultType=="ARRAY" | resultType==".ARRAY" then return "Array"
    when resultType=="DIRECTORY" | resultType==".DIRECTORY" | resultType=="JSON_OBJECT" then return "Directory"
    when resultType=="INTEGER" | resultType=="NUMBER" | resultType=="INDEX" | resultType=="STRING" | resultType=="LOGICAL" | resultType=="BOOLEAN" then return "String"
    otherwise return ""
  end

::method checkMessage
  expose witnesses evidence knowledge classHints
  use strict arg sourceName,messageName
  sourceName=sourceName~string; messageName=messageName~string
  r=.directory~new; r["source_object"]=sourceName; r["message"]=messageName
  if witnesses~hasIndex(sourceName) then do
    value=witnesses[sourceName]
    r["evidence_kind"]="RUNTIME_HASMETHOD"
    r["class_name"]=self~classNameOf(value)
    r["allowed"]=value~hasMethod(messageName)
    if r["allowed"] then r["reason"]="runtime object has method "||messageName
    else r["reason"]="runtime object class "||r["class_name"]||" does not have method "||messageName
    return r
  end
  e=evidence~at(sourceName)
  if e\==.nil then className=e~className
  else if classHints~hasIndex(sourceName) then className=classHints[sourceName]
  else className=""
  if className<>"" then do
    r["evidence_kind"]="CLASS_CONTRACT"
    r["class_name"]=className
    contract=knowledge~resolveMethodContract(className,messageName)
    r["allowed"]=contract\==.nil
    if contract\==.nil then do; r["reason"]=contract~evidence; r["contract"]=contract~asDirectory; end
    else r["reason"]="no Coding Intention dev13 contract evidence for "||className||"~"||messageName
    return r
  end
  r["evidence_kind"]="NONE"; r["class_name"]=""; r["allowed"]=.false; r["reason"]="no runtime or class-contract evidence for source object"
  return r

::method shapeOf private
  use strict arg value
  if value==.nil then return "NIL"
  if value~isA(.Directory) then return "DIRECTORY"
  if value~isA(.Array) then return "ARRAY"
  if value~isA(.Table) then return "TABLE"
  if value~isA(.Set) then return "SET"
  if value~isA(.List) then return "LIST"
  if value~isA(.String) then do; if datatype(value,"N") then return "NUMBER"; return "STRING"; end
  return translate(self~classNameOf(value))
::method classNameOf private
  use strict arg value
  if value==.nil then return "NilObject"
  return value~class~id
