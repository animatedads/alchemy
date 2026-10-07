/* SpecialistBootstrap.cls
   Loader for durable one-time specialist bootstrap knowledge.

   A logical specialist may have many qualified package revisions.  The registry
   retains every revision and exposes one current profile per logical specialist.
*/

::class DFQualifiedSpecialistRegistry public
::method init
  expose entries revisions sourceSchema generatedAt
  entries = .Directory~new
  revisions = .Directory~new
  sourceSchema = ""
  generatedAt = ""
::attribute sourceSchema
::attribute generatedAt
::method current
  expose entries
  use strict arg specialistId
  return entries~at(translate(specialistId))
::method all
  expose entries
  return entries~allItems
::method count
  expose entries
  return entries~items
::method revisionCount
  expose revisions
  count = 0
  do history over revisions~allItems
    count += history~items
  end
  return count
::method revisionsFor
  expose revisions
  use strict arg specialistId
  history = revisions~at(translate(specialistId))
  if history == .nil then return .Array~new
  return history~copy
::method fromRegistryFile class
  use strict arg path
  if stream(path, "c", "query exists") == "" then raise syntax 93.900 array("Specialist registry file does not exist", path)
  f = .stream~new(path)
  f~open("READ")
  text = f~charIn(, f~chars)
  f~close
  raw = .json~fromJson(text)
  if \raw~isA(.Directory) then raise syntax 93.900 array("Specialist registry root must be a JSON object")
  answer = .DFQualifiedSpecialistRegistry~new
  answer~loadDirectory(raw)
  return answer
::method loadDirectory
  expose entries revisions
  use strict arg raw
  schema = raw~at("schema")
  if schema <> "development.floor.specialist-registry/0.1" then raise syntax 93.900 array("Unsupported specialist registry schema", schema)
  self~sourceSchema = self~valueOr(raw, "source_schema", "")
  self~generatedAt = self~valueOr(raw, "generated_at", "")
  specialists = raw~at("specialists")
  if specialists == .nil then raise syntax 93.900 array("Specialist registry missing specialists")
  do item over specialists
    status = translate(self~valueOr(item,"bootstrap_status",""))
    if status <> "COMPLETE" then raise syntax 93.900 array("Specialist bootstrap is not complete", self~valueOr(item,"specialist_id",""))
    specialistId = item["specialist_id"]
    packageId = self~valueOr(item,"package_name","")
    primaryLanguage = self~valueOr(item,"primary_language","")
    profile = .DFSpecialistProfile~new(specialistId, packageId, primaryLanguage)
    rules = item~at("domain_rules")
    if rules <> .nil then do rule over rules
      ruleText = rule~at("rule")
      if ruleText <> .nil then profile~addDomainRule(ruleText)
    end
    profile~metadata["registration_id"] = self~valueOr(item,"registration_id","")
    profile~metadata["title"] = self~valueOr(item,"specialist_title","")
    profile~metadata["bootstrap_status"] = status
    profile~metadata["archive_name"] = self~valueOr(item,"archive_name","")
    profile~metadata["archive_sha256"] = self~valueOr(item,"archive_sha256","")
    profile~metadata["domain_purpose"] = self~valueOr(item,"domain_purpose","")
    profile~metadata["language_counts"] = item~at("languages")
    profile~metadata["authoritative_boundaries"] = item~at("authoritative_boundaries")
    profile~metadata["current"] = self~valueOr(item,"current",.false)
    key = translate(specialistId)
    history = revisions~at(key)
    if history == .nil then do
      history = .Array~new
      revisions[key] = history
    end
    history~append(profile)
    if profile~metadata["current"] then entries[key] = profile
  end
  do key over revisions
    if entries~at(key) == .nil then raise syntax 93.900 array("Logical specialist has no current revision", key)
  end
  return self
::method valueOr private
  use strict arg directory, key, defaultValue
  value = directory~at(key)
  if value == .nil then return defaultValue
  return value

::requires "DevelopmentFloor.cls"
::requires "json.cls"
