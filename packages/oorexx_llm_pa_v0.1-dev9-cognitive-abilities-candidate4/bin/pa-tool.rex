/* LLMPA governed named-ability command surface.
 *
 * Canonical form:
 *   pa-tool abilities [FILTER]
 *   pa-tool ability ABILITY_ID [JSON_OBJECT]
 *
 * Compatibility forms are retained for the existing package commands and
 * the most useful continuity/plan reads.  All of them resolve through the
 * same directory-loaded registry.
 */
parse source . . scriptHere
scriptDir = filespec("L", scriptHere)
packageRoot = scriptDir
if packageRoot~right(4) = "bin/" then packageRoot = packageRoot~left(packageRoot~length - 4)

parse arg raw
raw = raw~strip
parse var raw command rest
command = command~strip~lower
rest = rest~strip
usage = "usage: pa-tool abilities [FILTER] | pa-tool ability ID [JSON] | pa-tool plan current | pa-tool continuity current | pa-tool package stage ZIP | pa-tool package release-analyse DIR [DECISIONS.json] | pa-tool package release DIR [DECISIONS.json]"
if command = "" then do
  say .JSON~toJSON(errorResult("NAMED_ABILITY_REQUIRED", usage))
  exit 2
end

storeRoot = value("LLMPA_STORE_ROOT", , "ENVIRONMENT")
if storeRoot = "" then storeRoot = "/tmp/llmpa"
abilityDir = value("LLMPA_ABILITY_DIR", , "ENVIRONMENT")
if abilityDir = "" then abilityDir = packageRoot || "/abilities.d"
continuityPath = value("LLMPA_CONTINUITY_PATH", , "ENVIRONMENT")
if continuityPath = "" then continuityPath = storeRoot || "/continuity.brief"
planPath = value("LLMPA_PLAN_PATH", , "ENVIRONMENT")
if planPath = "" then planPath = storeRoot || "/plans.journal"
releaseSourceRoot = value("LLMPA_RELEASE_SOURCE_ROOT", , "ENVIRONMENT")
if releaseSourceRoot = "" then releaseSourceRoot = directory()
releaseRoot = value("LLMPA_RELEASE_ROOT", , "ENVIRONMENT")
if releaseRoot = "" then releaseRoot = storeRoot || "/releases"
stageRoot = value("LLMPA_STAGE_ROOT", , "ENVIRONMENT")
if stageRoot = "" then stageRoot = storeRoot || "/staging"
cognitiveJournal = value("LLMPA_COGNITIVE_JOURNAL", , "ENVIRONMENT")
if cognitiveJournal = "" then cognitiveJournal = storeRoot || "/cognitive.journal.jsonl"
cognitiveScope = value("LLMPA_COGNITIVE_SCOPE", , "ENVIRONMENT")
if cognitiveScope = "" then cognitiveScope = "project:llmpa"
cognitiveRuntime = .LlmPaCognitiveRuntime~new(cognitiveJournal, cognitiveScope)

context = .LlmPaAbilityContext~new
ignore = context~setService("plans", .LlmPaPlanManager~new(.LlmPaPlanStore~new(planPath)))
ignore = context~setService("continuity", .LlmPaContinuityBrief~new(continuityPath))
ignore = context~setService("package_stage", .LlmPaPackageStage~new(stageRoot))
ignore = context~setService("package_release", .LlmPaPackageRelease~new(releaseRoot, .nil, .nil, .nil, releaseSourceRoot))
ignore = context~setService("cognitive_runtime", cognitiveRuntime)
ignore = context~setService("cognitive_service", cognitiveRuntime~service)
ignore = context~setService("cognitive_adapter", cognitiveRuntime~adapter)
ignore = context~setConfig("cognitive_scope", cognitiveScope)
registry = .LlmPaAbilityRegistry~new(abilityDir, context)
loaded = registry~load
if \loaded~ok then do
  say .JSON~toJSON(errorResult(loaded~code, loaded~detail))
  exit 3
end
ignore = context~setService("ability_registry", registry)

request = .directory~new
abilityName = ""
select
  when command = "abilities" | command = "ability-list" | command = "ability_list" then do
    abilityName = "ability.catalogue"
    request["filter"] = unquote(rest)
  end
  when command = "ability" | command = "invoke" then do
    parse var rest abilityName requestJson
    abilityName = abilityName~strip~lower
    requestJson = requestJson~strip
    if abilityName = "" then do
      say .JSON~toJSON(errorResult("ABILITY_NAME_REQUIRED", usage))
      exit 2
    end
    if requestJson <> "" then do
      parsed = parseJsonObject(requestJson)
      if \parsed~ok then do
        say .JSON~toJSON(errorResult(parsed~code, parsed~detail))
        exit 2
      end
      request = parsed~value
    end
  end
  when command = "plan" then do
    if rest~lower <> "current" then do
      say .JSON~toJSON(errorResult("NAMED_ABILITY_REQUIRED", "usage: pa-tool plan current"))
      exit 2
    end
    abilityName = "plan.current"
  end
  when command = "continuity" | command = "handoff" then do
    if rest <> "" & rest~lower <> "current" then do
      say .JSON~toJSON(errorResult("NAMED_ABILITY_REQUIRED", "usage: pa-tool continuity current"))
      exit 2
    end
    abilityName = "continuity.current"
  end
  when command = "package" then do
    parse var rest operation remainder
    operation = operation~strip~lower
    parse var remainder path decisionsFile
    path = unquote(path)
    decisionsFile = unquote(decisionsFile)
    if path = "" then do
      say .JSON~toJSON(errorResult("PACKAGE_PATH_REQUIRED", usage))
      exit 2
    end
    request["path"] = path
    if decisionsFile <> "" then request["decisions_file"] = decisionsFile
    select
      when operation = "stage" then abilityName = "package.stage"
      when operation = "release-analyse" | operation = "release_analyse" then abilityName = "package.release.analyse"
      when operation = "release" then abilityName = "package.release"
      otherwise do
        say .JSON~toJSON(errorResult("NAMED_ABILITY_REQUIRED", usage))
        exit 2
      end
    end
  end
  otherwise do
    /* A canonical ability id may be invoked directly for terse Codex use. */
    abilityName = command
    if rest <> "" then do
      parsed = parseJsonObject(rest)
      if \parsed~ok then do
        say .JSON~toJSON(errorResult(parsed~code, parsed~detail))
        exit 2
      end
      request = parsed~value
    end
  end
end

outcome = registry~invoke(abilityName, request)
if \outcome~ok then do
  say .JSON~toJSON(errorResult(outcome~code, outcome~detail))
  exit 1
end
answer = .directory~new
answer["ok"] = .JSON~true
answer["value"] = outcome~value
say .JSON~toJSON(answer)
exit 0

parseJsonObject: procedure
  use arg text
  signal on syntax name invalidJson
  value = .JSON~fromJSON(text)
  signal off syntax
  if \value~isa(.Directory) then return .LlmPaResult~failure("ABILITY_REQUEST_INVALID", "request must be a JSON object")
  return .LlmPaResult~success(value)
invalidJson:
  signal off syntax
  return .LlmPaResult~failure("ABILITY_REQUEST_JSON_INVALID", condition("D"))

unquote: procedure
  use arg textArg
  text = textArg~string~strip
  if text~length >= 2 then do
    if (text~left(1) = '"' & text~right(1) = '"') | (text~left(1) = "'" & text~right(1) = "'") then text = text~substr(2, text~length - 2)
  end
  return text

errorResult: procedure
  use arg code, detail = ""
  error = .directory~new
  error["ok"] = .JSON~false
  error["code"] = code
  if detail <> "" then error["detail"] = detail
  return error

::requires "LlmPaAbility.cls"
::requires "LlmPaPlan.cls"
::requires "LlmPaContinuity.cls"
::requires "LlmPaPackageStage.cls"
::requires "LlmPaPackageRelease.cls"
::requires "LlmPaCognitiveRuntime.cls"
::requires "json.cls"
