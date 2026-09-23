/* Built-in LLMPA semantic abilities.  Drop-in sibling .cls files may export
 * additional LlmPaAbility subclasses without editing the registry. */

::class LlmPaAbilityCatalogueAbility subclass LlmPaAbility public
::method abilityId
  return "ability.catalogue"
::method version
  return "0.1.0"
::method description
  return "List or filter the named abilities currently loaded by LLMPA."
::method aliases
  return .array~of("abilities", "ability.list")
::method authorityClass
  return "READ_ONLY"
::method requestSchema
  return "llm.pa.ability.catalogue.request/0.1"
::method responseSchema
  return "llm.pa.ability.catalogue/0.1"
::method execute
  use arg context, request
  registry = context~service("ability_registry")
  if registry == .nil then return .LlmPaResult~failure("ABILITY_REGISTRY_SERVICE_REQUIRED")
  filter = ""
  if request~hasIndex("filter") then filter = request["filter"]
  return .LlmPaResult~success(registry~catalog(filter))

::class LlmPaPlanCurrentAbility subclass LlmPaAbility public
::method abilityId
  return "plan.current"
::method version
  return "0.1.0"
::method description
  return "Return the most recent active durable LLMPA plan without requiring the caller to remember its opaque plan id."
::method aliases
  return .array~of("current-plan")
::method authorityClass
  return "READ_ONLY"
::method requestSchema
  return "llm.pa.plan.current.request/0.1"
::method responseSchema
  return "llm.pa.plan.current/0.1"
::method execute
  use arg context, request
  plans = context~service("plans")
  if plans == .nil then return .LlmPaResult~failure("PLANS_NOT_CONFIGURED")
  listed = plans~list
  if \listed~ok then return listed
  selected = .nil
  selectedId = ""
  do plan over listed~value
    if plan["status"] \= "ACTIVE" then iterate
    planId = plan["plan_id"]~string
    if selected == .nil | planId > selectedId then do
      selected = plan
      selectedId = planId
    end
  end
  if selected == .nil then return .LlmPaResult~failure("ACTIVE_PLAN_NOT_FOUND")
  out = .directory~new
  out["plan"] = selected
  out["selection_reason"] = "LATEST_ACTIVE_PLAN_ID"
  out["authority"] = "DURABLE_PLAN_EVENTS"
  return .LlmPaResult~success(out)

::class LlmPaContinuityCurrentAbility subclass LlmPaAbility public
::method abilityId
  return "continuity.current"
::method version
  return "0.2.0"
::method description
  return "Return durable Cognitive Continuity state when configured, plus the legacy human-readable handoff only as an optional regenerable projection cache."
::method aliases
  return .array~of("current-continuity", "handoff.current")
::method authorityClass
  return "READ_ONLY"
::method requestSchema
  return "llm.pa.continuity.current.request/0.2"
::method responseSchema
  return "llm.pa.continuity.current/0.2"
::method execute
  use arg context, request
  out = .directory~new
  runtime = context~service("cognitive_runtime")
  if runtime \== .nil then do
    args = .directory~new
    args["scopeRef"] = context~config("cognitive_scope", runtime~scopeRef)
    cognitive = runtime~service~dispatch("COGNITIVE.CONTINUITY.QUERY", args, runtime~workerActor)
    if \cognitive~ok then return .LlmPaResult~failure(cognitive~code, cognitive~detail)
    out["durable_state"] = cognitive~value
    out["authority"] = "COGNITIVE_CONTINUITY_EVENTS"
    out["cognitive_state_compactable"] = .JSON~false
    out["inference_projection_disposable"] = .JSON~true
  end
  continuity = context~service("continuity")
  if continuity \== .nil then do
    brief = continuity~read
    if brief~ok then do
      projection = .directory~new
      projection["brief"] = brief~value
      projection["authority"] = "PROJECTION_ONLY"
      projection["regenerable"] = .JSON~true
      out["brief_projection"] = projection
    end
  end
  if runtime == .nil & continuity == .nil then return .LlmPaResult~failure("CONTINUITY_NOT_CONFIGURED")
  if runtime == .nil then do
    out["authority"] = "PROJECTION_ONLY"
    out["regenerable"] = .JSON~true
    out["cognitive_state_compactable"] = .JSON~false
    if out~hasIndex("brief_projection") then out["brief"] = out["brief_projection"]["brief"]
  end
  return .LlmPaResult~success(out)

::class LlmPaPackageStageAbility subclass LlmPaAbility public
::method abilityId
  return "package.stage"
::method version
  return "0.1.0"
::method description
  return "Safely stage a package archive into an immutable content-addressed generation using the LLMPA package staging service."
::method aliases
  return .array~of("package_stage")
::method authorityClass
  return "GOVERNED_MUTATION"
::method mutating
  return .true
::method requestSchema
  return "llm.pa.package.stage.request/0.1"
::method responseSchema
  return "llm.pa.package.stage/0.1"
::method primitiveRequirements
  return .array~of("filesystem.capacity", "archive.inspect", "archive.extract", "digest.sha256", "filesystem.atomic_publish")
::method execute
  use arg context, request
  service = context~service("package_stage")
  if service == .nil then return .LlmPaResult~failure("PACKAGE_STAGE_NOT_CONFIGURED")
  if \request~hasIndex("path") then return .LlmPaResult~failure("PACKAGE_PATH_REQUIRED")
  return service~stage(request["path"])

::class LlmPaPackageReleaseAnalyseAbility subclass LlmPaAbility public
::method abilityId
  return "package.release.analyse"
::method version
  return "0.1.0"
::method description
  return "Analyse a release tree for hygiene, public-identity shadows and competing archive cuts without publishing a release."
::method aliases
  return .array~of("package.release-analyse", "package_release_analyse")
::method authorityClass
  return "READ_ONLY"
::method requestSchema
  return "llm.pa.package.release.analyse.request/0.1"
::method responseSchema
  return "llm.pa.package.release.analysis/0.1"
::method primitiveRequirements
  return .array~of("filesystem.walk", "digest.sha256", "archive.inspect")
::method execute
  use arg context, request
  service = context~service("package_release")
  if service == .nil then return .LlmPaResult~failure("PACKAGE_RELEASE_NOT_CONFIGURED")
  if \request~hasIndex("path") then return .LlmPaResult~failure("RELEASE_SOURCE_PATH_REQUIRED")
  decisions = self~decisions(request)
  if \decisions~ok then return decisions
  return service~analyse(request["path"], decisions~value)
::method decisions private
  use arg request
  if \request~hasIndex("decisions_file") | request["decisions_file"]~string~strip = "" then return .LlmPaResult~success(.nil)
  return .LlmPaPackageReleaseDecisionSet~fromFile(request["decisions_file"])

::class LlmPaPackageReleaseAbility subclass LlmPaAbility public
::method abilityId
  return "package.release"
::method version
  return "0.1.0"
::method description
  return "Create a governed immutable release generation after explicit cognitive release decisions resolve all blocking ambiguity."
::method aliases
  return .array~of("package_release")
::method authorityClass
  return "GOVERNED_MUTATION"
::method mutating
  return .true
::method requestSchema
  return "llm.pa.package.release.request/0.1"
::method responseSchema
  return "llm.pa.package.release/0.2"
::method primitiveRequirements
  return .array~of("filesystem.walk", "filesystem.capacity", "archive.create", "archive.inspect", "digest.sha256", "filesystem.atomic_publish")
::method execute
  use arg context, request
  service = context~service("package_release")
  if service == .nil then return .LlmPaResult~failure("PACKAGE_RELEASE_NOT_CONFIGURED")
  if \request~hasIndex("path") then return .LlmPaResult~failure("RELEASE_SOURCE_PATH_REQUIRED")
  decisions = self~decisions(request)
  if \decisions~ok then return decisions
  packageName = ""
  if request~hasIndex("package_name") then packageName = request["package_name"]
  return service~release(request["path"], packageName, decisions~value)
::method decisions private
  use arg request
  if \request~hasIndex("decisions_file") | request["decisions_file"]~string~strip = "" then return .LlmPaResult~success(.nil)
  return .LlmPaPackageReleaseDecisionSet~fromFile(request["decisions_file"])

::requires "LlmPaAbility.cls"
::requires "LlmPaPackageStage.cls"
::requires "LlmPaPackageRelease.cls"
