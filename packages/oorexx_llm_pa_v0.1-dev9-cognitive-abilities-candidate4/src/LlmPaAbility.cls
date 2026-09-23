/* LLMPA named ability registry.
 *
 * Abilities are trusted ooRexx code loaded from an approved abilities.d
 * directory.  The registry owns discovery, descriptor validation, alias
 * collision checks and invocation.  It does not grant execution authority:
 * each ability declares its authority class and is expected to delegate
 * machine mechanics to injected platform/provider services.
 *
 * Structured Response integration is deliberately an adapter seam.  This
 * module does not invent a competing Structured Response API.  A caller may
 * inject a service named "structured_response_emitter"; when present the
 * emitter receives the detached ability execution record before publication.
 */

::class LlmPaAbility public
::method abilityId
  return ""
::method version
  return "0.1"
::method description
  return ""
::method aliases
  return .array~new
::method authorityClass
  return "READ_ONLY"
::method mutating
  return .false
::method requestSchema
  return "llm.pa.ability.request/0.1"
::method responseSchema
  return "llm.pa.ability.response/0.1"
::method primitiveRequirements
  return .array~new
::method execute
  use arg context, request
  return .LlmPaResult~failure("ABILITY_NOT_IMPLEMENTED", self~abilityId)
::method cognitiveEffects
  use arg context, request, value
  return .array~new

::method descriptor
  d = .directory~new
  d["ability_id"] = self~abilityId~string~strip~lower
  d["version"] = self~version~string~strip
  d["description"] = self~description~string~strip
  d["aliases"] = self~copyArray(self~aliases)
  d["authority_class"] = self~authorityClass~string~strip~upper
  if self~mutating == .true then d["mutating"] = .JSON~true
  else d["mutating"] = .JSON~false
  d["request_schema"] = self~requestSchema~string~strip
  d["response_schema"] = self~responseSchema~string~strip
  d["primitive_requirements"] = self~copyArray(self~primitiveRequirements)
  d["class_id"] = self~class~id
  return d

::method copyArray private
  use arg source
  out = .array~new
  if source == .nil then return out
  if \source~isa(.Array) then return out
  do item over source
    out~append(item~string)
  end
  return out

::class LlmPaAbilityContext public
::method init
  expose services configuration
  services = .directory~new
  configuration = .directory~new

::method setService
  expose services
  use arg nameArg, service
  name = nameArg~string~strip~lower
  if name = "" then return .LlmPaResult~failure("ABILITY_SERVICE_NAME_REQUIRED")
  services[name] = service
  return .LlmPaResult~success(.true)

::method hasService
  expose services
  use arg nameArg
  return services~hasIndex(nameArg~string~strip~lower)

::method service
  expose services
  use arg nameArg
  name = nameArg~string~strip~lower
  if services~hasIndex(name) then return services[name]
  return .nil

::method setConfig
  expose configuration
  use arg nameArg, value
  name = nameArg~string~strip~lower
  if name = "" then return .LlmPaResult~failure("ABILITY_CONFIG_NAME_REQUIRED")
  configuration[name] = value
  return .LlmPaResult~success(.true)

::method config
  expose configuration
  use arg nameArg, default = .nil
  name = nameArg~string~strip~lower
  if configuration~hasIndex(name) then return configuration[name]
  return default

::class LlmPaAbilityRegistry public
::attribute abilityDir get
::method init
  expose abilityDir context abilities aliases loadedModules ready
  use arg abilityDirArg, contextArg = .nil
  abilityDir = abilityDirArg~string~strip
  if abilityDir = "" then raise syntax 88.900 array("ability directory is required")
  if contextArg == .nil then context = .LlmPaAbilityContext~new
  else context = contextArg
  abilities = .directory~new
  aliases = .directory~new
  loadedModules = .array~new
  ready = .false

::method context
  expose context
  return context

::method load
  expose abilityDir abilities aliases loadedModules ready
  abilities = .directory~new
  aliases = .directory~new
  loadedModules = .array~new
  ready = .false
  call SysFileTree abilityDir || "/*.cls", "files.", "FO"
  if files.0 = 0 then return .LlmPaResult~failure("ABILITY_DIRECTORY_EMPTY", abilityDir)
  paths = .array~new
  do i = 1 to files.0
    paths~append(files.i)
  end
  paths~sort
  do path over paths
    loaded = self~loadModule(path)
    if \loaded~ok then return loaded
  end
  if abilities~items = 0 then return .LlmPaResult~failure("ABILITY_NONE_DISCOVERED", abilityDir)
  ready = .true
  return .LlmPaResult~success(self~catalog)

::method loadModule private
  expose abilities aliases loadedModules
  use arg path
  signal on syntax name moduleSyntax
  pkg = .Package~new(path)
  classes = pkg~publicClasses~supplier
  discovered = 0
  do while classes~available
    cls = classes~item
    classes~next
    if cls == .LlmPaAbility then iterate
    if \cls~isSubclassOf(.LlmPaAbility) then iterate
    instance = cls~new
    descriptor = instance~descriptor
    valid = self~validateDescriptor(descriptor)
    if \valid~ok then return valid
    abilityId = descriptor["ability_id"]
    collision = self~claimName(abilityId, abilityId)
    if \collision~ok then return collision
    abilities[abilityId] = instance
    do alias over descriptor["aliases"]
      aliasName = alias~string~strip~lower
      collision = self~claimName(aliasName, abilityId)
      if \collision~ok then return collision
      aliases[aliasName] = abilityId
    end
    discovered += 1
  end
  loaded = .directory~new
  loaded["path"] = path
  loaded["ability_count"] = discovered
  loadedModules~append(loaded)
  return .LlmPaResult~success(discovered)
moduleSyntax:
  detail = condition("D")
  if detail == .nil then detail = condition("C")
  return .LlmPaResult~failure("ABILITY_MODULE_LOAD_FAILED", path || ": " || detail)

::method claimName private
  expose abilities aliases
  use arg nameArg, ownerArg
  name = nameArg~string~strip~lower
  owner = ownerArg~string~strip~lower
  if name = "" then return .LlmPaResult~failure("ABILITY_NAME_REQUIRED", owner)
  if abilities~hasIndex(name) then return .LlmPaResult~failure("ABILITY_NAME_COLLISION", name)
  if aliases~hasIndex(name) then return .LlmPaResult~failure("ABILITY_NAME_COLLISION", name)
  return .LlmPaResult~success(.true)

::method validateDescriptor private
  use arg d
  if d == .nil | \d~isa(.Directory) then return .LlmPaResult~failure("ABILITY_DESCRIPTOR_INVALID", "descriptor must be a Directory")
  required = .array~of("ability_id", "version", "description", "authority_class", "request_schema", "response_schema")
  do field over required
    if \d~hasIndex(field) then return .LlmPaResult~failure("ABILITY_DESCRIPTOR_FIELD_REQUIRED", field)
    if d[field]~string~strip = "" then return .LlmPaResult~failure("ABILITY_DESCRIPTOR_FIELD_REQUIRED", field)
  end
  name = d["ability_id"]~string~strip~lower
  if \self~validName(name) then return .LlmPaResult~failure("ABILITY_ID_INVALID", name)
  authority = d["authority_class"]~string~strip~upper
  allowed = .array~of("READ_ONLY", "EVIDENCE_ONLY", "ADVISORY", "GOVERNED_MUTATION")
  if allowed~hasItem(authority) = 0 then return .LlmPaResult~failure("ABILITY_AUTHORITY_CLASS_INVALID", authority)
  if \d["aliases"]~isa(.Array) then return .LlmPaResult~failure("ABILITY_ALIASES_INVALID", name)
  do alias over d["aliases"]
    aliasName = alias~string~strip~lower
    if \self~validName(aliasName) then return .LlmPaResult~failure("ABILITY_ALIAS_INVALID", aliasName)
  end
  if \d["primitive_requirements"]~isa(.Array) then return .LlmPaResult~failure("ABILITY_PRIMITIVE_REQUIREMENTS_INVALID", name)
  return .LlmPaResult~success(.true)

::method validName private
  use arg textArg
  text = textArg~string~strip~lower
  if text = "" then return .false
  allowed = "abcdefghijklmnopqrstuvwxyz0123456789._-"
  do i = 1 to text~length
    if allowed~pos(text~substr(i, 1)) = 0 then return .false
  end
  return .true

::method resolve
  expose abilities aliases ready
  use arg nameArg
  if \ready then return .LlmPaResult~failure("ABILITY_REGISTRY_NOT_READY")
  name = nameArg~string~strip~lower
  if abilities~hasIndex(name) then return .LlmPaResult~success(abilities[name])
  if aliases~hasIndex(name) then return .LlmPaResult~success(abilities[aliases[name]])
  return .LlmPaResult~failure("ABILITY_NOT_FOUND", name)

::method invoke
  expose context
  use arg nameArg, requestArg = .nil
  resolved = self~resolve(nameArg)
  if \resolved~ok then return resolved
  ability = resolved~value
  if requestArg == .nil then request = .directory~new
  else request = requestArg
  if \request~isa(.Directory) then return .LlmPaResult~failure("ABILITY_REQUEST_INVALID", "request must be a JSON object/Directory")
  outcome = ability~execute(context, request)
  if outcome == .nil | \outcome~isa(.LlmPaResult) then return .LlmPaResult~failure("ABILITY_RESULT_INVALID", ability~abilityId)
  if \outcome~ok then return outcome
  execution = .directory~new
  descriptor = ability~descriptor
  execution["schema"] = "llm.pa.ability.execution/0.1"
  execution["ability"] = descriptor
  execution["status"] = "SUCCEEDED"
  execution["result"] = outcome~value
  effects = ability~cognitiveEffects(context, request, outcome~value)
  if effects == .nil | \effects~isa(.Array) then return .LlmPaResult~failure("ABILITY_COGNITIVE_EFFECTS_INVALID", ability~abilityId)
  execution["cognitive_effects"] = effects
  emitter = context~service("structured_response_emitter")
  if emitter \== .nil then do
    projected = emitter~emitAbilityExecution(execution, request)
    if projected == .nil | \projected~isa(.LlmPaResult) then return .LlmPaResult~failure("STRUCTURED_RESPONSE_EMITTER_INVALID", ability~abilityId)
    return projected
  end
  return .LlmPaResult~success(execution)

::method catalog
  expose abilities aliases loadedModules
  use arg filterArg = ""
  filter = filterArg~string~strip~lower
  ids = .array~new
  do abilityId over abilities~allIndexes
    if filter = "" | abilityId~pos(filter) > 0 | abilities[abilityId]~description~lower~pos(filter) > 0 then ids~append(abilityId)
  end
  ids~sort
  rows = .array~new
  do abilityId over ids
    rows~append(abilities[abilityId]~descriptor)
  end
  d = .directory~new
  d["schema"] = "llm.pa.ability.catalogue/0.1"
  d["abilities"] = rows
  modules = .array~new
  do row over loadedModules
    modules~append(.LlmPaUtil~copyDirectory(row))
  end
  d["modules"] = modules
  d["count"] = rows~items
  return d

::requires "LlmPaCore.cls"
::requires "json.cls"
::requires "rxunixsys" library
