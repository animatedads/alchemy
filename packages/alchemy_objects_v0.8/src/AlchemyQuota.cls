/* AlchemyQuota.cls - Alchemy Objects v0.8
 * Execution-context quota gate for ooRexx Security Manager checkpoints.
 *
 * The quota set is owned by the Security Manager / hosted execution context.
 * Rules can nevertheless bucket consumption by context, method, object, class,
 * or object+method.  This deliberately keeps quota authority out of customer
 * objects while allowing per-object accounting when desired.
 */

::class AlchemyExecutionQuotaDecision public
::attribute allowed get
::attribute reason get
::attribute evidence get
::method init
  expose allowed reason evidence
  use strict arg allowed, reason = "", evidence = .nil
  allowed = allowed
  reason = reason~string
  if evidence == .nil then evidence = .array~new
  evidence = evidence


::class AlchemyExecutionQuotaRule public
::attribute checkpoint get
::attribute namePattern get
::attribute classPattern get
::attribute limit get
::attribute scope get

::method init
  expose checkpoint namePattern classPattern limit scope contextUsed methodUsed classMethodUsed objectUsed objectMethodUsed
  use strict arg checkpoint, namePattern = "*", classPattern = "*", limit, scope = "OBJECT_METHOD"
  checkpoint = checkpoint~string~translate
  namePattern = namePattern~string~translate
  classPattern = classPattern~string~translate
  if \datatype(limit~string, "W") | limit < 1 then raise syntax 88.900 array("Execution quota limit must be a positive whole number")
  limit = limit + 0
  scope = scope~string~translate
  validScopes = " CONTEXT METHOD CLASS_METHOD OBJECT OBJECT_METHOD "
  if pos(" " || scope || " ", validScopes) = 0 then raise syntax 88.900 array("Execution quota scope must be CONTEXT, METHOD, CLASS_METHOD, OBJECT, or OBJECT_METHOD")
  contextUsed = 0
  methodUsed = .directory~new
  classMethodUsed = .directory~new
  objectUsed = .table~new
  objectMethodUsed = .table~new

::method matches public
  expose checkpoint namePattern classPattern
  use strict arg checkpointName, info
  if checkpoint \= checkpointName~string~translate then return .false
  targetName = ""
  targetClass = ""
  if info~hasIndex("NAME") then targetName = info["NAME"]~string~translate
  if checkpoint = "COMMAND" & info~hasIndex("COMMAND") then targetName = info["COMMAND"]~string~translate
  if info~hasIndex("OBJECT") then do
    obj = info["OBJECT"]
    if obj \== .nil then targetClass = obj~class~id~translate
  end
  if \self~wild(targetName, namePattern) then return .false
  if \self~wild(targetClass, classPattern) then return .false
  return .true

::method preview public
  expose limit
  use strict arg checkpointName, info
  if \self~matches(checkpointName, info) then return .nil
  used = self~usedFor(info)
  d = self~evidenceFor(info, used)
  d["allowed"] = used < limit
  return d

::method commit public
  expose limit
  use strict arg info
  used = self~usedFor(info)
  if used >= limit then return self~evidenceFor(info, used)
  self~setUsedFor(info, used + 1)
  return self~evidenceFor(info, used + 1)

::method usedFor private
  expose scope contextUsed methodUsed classMethodUsed objectUsed objectMethodUsed
  use strict arg info
  targetName = self~targetName(info)
  targetClass = self~targetClass(info)
  obj = self~targetObject(info)
  if scope = "CONTEXT" then return contextUsed
  if scope = "METHOD" then do
    n = methodUsed~at(targetName)
    if n == .nil then n = 0
    return n
  end
  if scope = "CLASS_METHOD" then do
    key = targetClass || "::" || targetName
    n = classMethodUsed~at(key)
    if n == .nil then n = 0
    return n
  end
  if obj == .nil then return 0
  if scope = "OBJECT" then do
    n = objectUsed~at(obj)
    if n == .nil then n = 0
    return n
  end
  perObject = objectMethodUsed~at(obj)
  if perObject == .nil then return 0
  n = perObject~at(targetName)
  if n == .nil then n = 0
  return n

::method setUsedFor private
  expose scope contextUsed methodUsed classMethodUsed objectUsed objectMethodUsed
  use strict arg info, used
  targetName = self~targetName(info)
  targetClass = self~targetClass(info)
  obj = self~targetObject(info)
  if scope = "CONTEXT" then do
    contextUsed = used
    return
  end
  if scope = "METHOD" then do
    methodUsed[targetName] = used
    return
  end
  if scope = "CLASS_METHOD" then do
    classMethodUsed[targetClass || "::" || targetName] = used
    return
  end
  if obj == .nil then raise syntax 98.948 array("Object-scoped quota checkpoint has no target object")
  if scope = "OBJECT" then do
    objectUsed[obj] = used
    return
  end
  perObject = objectMethodUsed~at(obj)
  if perObject == .nil then do
    perObject = .directory~new
    objectMethodUsed[obj] = perObject
  end
  perObject[targetName] = used

::method evidenceFor private
  expose checkpoint namePattern classPattern limit scope
  use strict arg info, used
  d = .directory~new
  d["checkpoint"] = checkpoint
  d["name_pattern"] = namePattern
  d["class_pattern"] = classPattern
  d["scope"] = scope
  d["limit"] = limit
  d["used"] = used
  d["remaining"] = limit - used
  if d["remaining"] < 0 then d["remaining"] = 0
  d["target_name"] = self~targetName(info)
  d["target_class"] = self~targetClass(info)
  obj = self~targetObject(info)
  if obj \== .nil then do
    d["target_identity_hash"] = obj~identityHash~string
    if obj~hasMethod("ALCHEMYOBJECTID") then d["target_object_id"] = obj~alchemyObjectId
  end
  return d

::method targetName private
  use strict arg info
  if info~hasIndex("NAME") then return info["NAME"]~string~translate
  if info~hasIndex("COMMAND") then return info["COMMAND"]~string~translate
  return ""

::method targetClass private
  use strict arg info
  obj = self~targetObject(info)
  if obj == .nil then return ""
  return obj~class~id~translate

::method targetObject private
  use strict arg info
  if \info~hasIndex("OBJECT") then return .nil
  return info["OBJECT"]

::method wild private
  use strict arg value, pattern
  if pattern = "*" then return .true
  star = pattern~pos("*")
  if star = 0 then return value = pattern
  before = pattern~left(star - 1)
  after = pattern~substr(star + 1)
  if before \= "" then if value~left(before~length) \= before then return .false
  if after \= "" then if value~right(after~length) \= after then return .false
  return .true


::class AlchemyExecutionQuotaSet public
::method init
  expose rules
  rules = .array~new

::method addRule public
  expose rules
  use strict arg rule
  if rule == .nil | \rule~isA(.AlchemyExecutionQuotaRule) then raise syntax 88.900 array("Execution quota rule required")
  rules~append(rule)
  return self

::method limitMethod public
  use strict arg namePattern = "*", classPattern = "*", limit, scope = "OBJECT_METHOD"
  return self~addRule(.AlchemyExecutionQuotaRule~new("METHOD", namePattern, classPattern, limit, scope))

::method consume public
  expose rules
  use strict arg checkpoint, info
  guard on
  matched = .array~new
  previews = .array~new
  do rule over rules
    preview = rule~preview(checkpoint, info)
    if preview == .nil then iterate
    matched~append(rule)
    previews~append(preview)
    if \preview["allowed"] then return .AlchemyExecutionQuotaDecision~new(.false, "execution quota exhausted", previews)
  end
  if matched~items = 0 then return .AlchemyExecutionQuotaDecision~new(.true, "no matching quota", previews)
  committed = .array~new
  do rule over matched
    committed~append(rule~commit(info))
  end
  return .AlchemyExecutionQuotaDecision~new(.true, "execution quota consumed", committed)
