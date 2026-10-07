/* Runtime projection of Coding Intention dev13 RexxLanguageKnowledge.
 * The catalogue is exported from the real Coding Intention dependency during
 * build/qualification, avoiding its vendored Intention Service at runtime. */
::class LlmRexxOperationKnowledge public
::method init
  expose row
  use strict arg rowArg
  row=rowArg
::method operation; expose row; return row["operation"]
::method supported; expose row; if row~hasIndex("supported") then return row["supported"]; return .true
::method category; expose row; return row["category"]
::method package; expose row; return row["package"]
::method receiver; expose row; return row["receiver"]
::method method; expose row; return row["method"]
::method form; expose row; return row["form"]
::method resultType; expose row; return row["result_type"]
::method evidence; expose row; return row["evidence"]
::method describe
  expose row
  out=row["operation"]||" ["||row["category"]||"] "||row["form"]
  if row["package"]<>"" then out=out||" REQUIRE "||row["package"]
  if row["result_type"]<>"" then out=out||" -> "||row["result_type"]
  return out

::class LlmRexxLanguageSkill public
::method init
  expose row
  use strict arg rowArg
  row=rowArg
::method id; expose row; return row["id"]
::method purpose; expose row; return row["purpose"]
::method operations; expose row; return row["operations"]~copy

::class LlmRexxMethodContract public
::method init
  expose row
  use strict arg rowArg
  row=rowArg
::method name; expose row; return row["name"]
::method form; expose row; return row["form"]
::method resultType; expose row; return row["result_type"]
::method evidence; expose row; return row["evidence"]
::method asDirectory; expose row; return row~copy

::class LlmRexxClassContract public
::method init
  expose row methodIndex
  use strict arg rowArg
  row=rowArg; methodIndex=.directory~new
  do m over row["methods"]; methodIndex[translate(m["name"]~string)]=m; end
::method id; expose row; return row["id"]
::method package; expose row; return row["package"]
::method evidence; expose row; return row["evidence"]
::method method
  expose methodIndex
  use strict arg nameArg
  m=methodIndex~at(translate(strip(nameArg~string)))
  if m==.nil then return .nil
  return .LlmRexxMethodContract~new(m)
::method methodNames
  expose methodIndex
  return methodIndex~allIndexes
::method asDirectory
  expose row
  return row~copy

::class LlmRexxKnowledgeCatalogue public
::method init
  expose root operationIndex skillIndex classIndex
  use strict arg pathArg
  root=.json~fromJsonFile(pathArg~string)
  if root==.nil then raise syntax 88.900 array("coding knowledge catalogue could not be loaded")
  operationIndex=.directory~new; skillIndex=.directory~new; classIndex=.directory~new
  do row over root["operations"]; operationIndex[translate(row["operation"]~string)]=row; end
  do row over root["skills"]; skillIndex[translate(row["id"]~string)]=row; end
  if root~hasIndex("class_contracts") then do row over root["class_contracts"]; classIndex[translate(row["id"]~string)]=row; end
::method source
  expose root
  if root~hasIndex("source") then return root["source"]
  return ""
::method language
  expose root
  if root~hasIndex("language") then return root["language"]
  return "rexx"
::method capabilityAuthority
  expose root
  if root~hasIndex("capability_authority") then return root["capability_authority"]
  return ""
::method supportsOperation
  expose operationIndex
  use strict arg idArg
  return operationIndex~hasIndex(translate(strip(idArg~string)))
::method resolveOperation
  expose operationIndex
  use strict arg idArg
  row=operationIndex~at(translate(strip(idArg~string)))
  if row==.nil then return .nil
  return .LlmRexxOperationKnowledge~new(row)
::method resolveSkill
  expose skillIndex
  use strict arg idArg
  row=skillIndex~at(translate(strip(idArg~string)))
  if row==.nil then return .nil
  return .LlmRexxLanguageSkill~new(row)
::method resolveClassContract
  expose classIndex
  use strict arg idArg
  row=classIndex~at(translate(strip(idArg~string)))
  if row==.nil then return .nil
  return .LlmRexxClassContract~new(row)
::method resolveMethodContract
  use strict arg classId,methodName
  c=self~resolveClassContract(classId)
  if c==.nil then return .nil
  return c~method(methodName)
::method operations
  expose operationIndex
  out=.array~new; do id over operationIndex; out~append(id); end; return out
::method skills
  expose skillIndex
  out=.array~new; do id over skillIndex; out~append(id); end; return out
::method classContracts
  expose classIndex
  out=.array~new; do id over classIndex; out~append(.LlmRexxClassContract~new(classIndex[id])); end; return out

::requires "json.cls"
