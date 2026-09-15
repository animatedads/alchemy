/* Ability Registry v0.1
 *
 * Client/profile configuration layer above RuntimeRegistry.
 *
 * A staged ability generation captures one immutable RuntimeSnapshot and owns
 * those runtime leases for its whole warm lifetime. Requests lease the ability
 * generation, not the current global runtime bindings. This gives a nested
 * lifecycle:
 *
 *   RuntimeGeneration -> AbilityGeneration -> AbilitySession
 *
 * Runtime upgrades can therefore be published while existing client profiles
 * remain pinned to their previously-certified runtime closure. A replacement
 * profile generation can be staged against the new active runtime closure and
 * then atomically published for the client.
 */

::class AbilityRegistryBuild public
::constant PRODUCT "ooRexx Ability Registry"
::constant RELEASE "0.1"
::constant API_VERSION "ability.registry/0.1"

::class AbilityRuntimeBinding public
::attribute alias get
::attribute moduleId get
::attribute artifactId get

::method init
  expose alias moduleId artifactId
  use arg alias, moduleId, artifactId = ""
  alias = alias~string~strip~lower
  moduleId = moduleId~string~strip
  artifactId = artifactId~string~strip
  if alias = "" then raise syntax 88.900 array("AbilityRuntimeBinding alias must not be empty")
  if moduleId = "" then raise syntax 88.900 array("AbilityRuntimeBinding moduleId must not be empty")

::class AbilityDescriptor public
::attribute abilityId get
::attribute kind get
::attribute readOnly get
::attribute description get
::attribute inputSchema get
::attribute outputSchema get

::method init
  expose abilityId kind readOnly description requiredAliases inputSchema outputSchema
  use arg abilityId, kind, requiredAliases = .nil, readOnly = .true, description = "", inputSchemaArg = .nil, outputSchemaArg = .nil
  abilityId = abilityId~string~strip~lower
  kind = kind~string~strip~upper
  readOnly = readOnly == .true
  description = description~string
  if abilityId = "" then raise syntax 88.900 array("AbilityDescriptor abilityId must not be empty")
  if kind = "" then raise syntax 88.900 array("AbilityDescriptor kind must not be empty")
  requiredAliases = self~copyAliases(requiredAliases)
  if inputSchemaArg == .nil then inputSchema = .AbilityJsonSchema~genericObject
  else if inputSchemaArg~isa(.AbilityJsonSchema) then inputSchema = .AbilityJsonSchema~new(inputSchemaArg~document)
  else inputSchema = .AbilityJsonSchema~new(inputSchemaArg)
  if outputSchemaArg == .nil then outputSchema = .AbilityJsonSchema~any
  else if outputSchemaArg~isa(.AbilityJsonSchema) then outputSchema = .AbilityJsonSchema~new(outputSchemaArg~document)
  else outputSchema = .AbilityJsonSchema~new(outputSchemaArg)

::method requiredAliases
  expose requiredAliases
  return self~copyAliases(requiredAliases)

::method validateInput
  expose inputSchema
  use arg value
  return inputSchema~validate(value)

::method validateOutput
  expose outputSchema
  use arg value
  return outputSchema~validate(value)

::method copyAliases private
  use arg source
  resultAliases = .array~new
  if source == .nil then return resultAliases
  seen = .table~new
  do i = 1 to source~items
    alias = source~at(i)~string~strip~lower
    if alias = "" then iterate
    if seen~at(alias) \== .nil then iterate
    seen~put(.true, alias)
    resultAliases~append(alias)
  end
  return resultAliases

::class AbilityDataBinding public
::attribute logicalName get
::attribute runtimeAlias get
::attribute resourceName get
::attribute accessMode get

::method init
  expose logicalName runtimeAlias resourceName accessMode
  use arg logicalName, runtimeAlias, resourceName, accessMode = "READ"
  logicalName = logicalName~string~strip~lower
  runtimeAlias = runtimeAlias~string~strip~lower
  resourceName = resourceName~string~strip
  accessMode = accessMode~string~strip~upper
  if logicalName = "" then raise syntax 88.900 array("AbilityDataBinding logicalName must not be empty")
  if runtimeAlias = "" then raise syntax 88.900 array("AbilityDataBinding runtimeAlias must not be empty")
  if resourceName = "" then raise syntax 88.900 array("AbilityDataBinding resourceName must not be empty")
  if accessMode = "" then raise syntax 88.900 array("AbilityDataBinding accessMode must not be empty")

::class AbilityRuleBinding public
::attribute logicalName get
::attribute runtimeAlias get
::attribute ruleSetName get

::method init
  expose logicalName runtimeAlias ruleSetName
  use arg logicalName, runtimeAlias, ruleSetName = ""
  logicalName = logicalName~string~strip~lower
  runtimeAlias = runtimeAlias~string~strip~lower
  ruleSetName = ruleSetName~string~strip
  if logicalName = "" then raise syntax 88.900 array("AbilityRuleBinding logicalName must not be empty")
  if runtimeAlias = "" then raise syntax 88.900 array("AbilityRuleBinding runtimeAlias must not be empty")

::class AbilityProfileRevision public
::attribute profileId get
::attribute revision get
::attribute clientId get
::attribute description get
::attribute createdAt get

::method init
  expose profileId revision clientId description createdAt runtimeBindings abilities dataBindings ruleBindings
  use arg profileId, revision, clientId, runtimeBindings = .nil, abilities = .nil, dataBindings = .nil, ruleBindings = .nil, description = ""
  profileId = profileId~string~strip~lower
  revision = revision~string~strip
  clientId = clientId~string~strip~lower
  description = description~string
  createdAt = .DateTime~new
  if profileId = "" then raise syntax 88.900 array("AbilityProfileRevision profileId must not be empty")
  if revision = "" then raise syntax 88.900 array("AbilityProfileRevision revision must not be empty")
  if clientId = "" then raise syntax 88.900 array("AbilityProfileRevision clientId must not be empty")

  runtimeBindings = self~copyRuntimeBindings(runtimeBindings)
  abilities = self~copyAbilities(abilities)
  dataBindings = self~copyDataBindings(dataBindings)
  ruleBindings = self~copyRuleBindings(ruleBindings)

  validation = self~validateReferences
  if \validation~ok then raise syntax 88.900 array(validation~code || ": " || validation~detail)

::method identity
  expose profileId revision clientId
  return clientId || "/" || profileId || "@" || revision

::method canonicalText
  expose profileId revision clientId description runtimeBindings abilities dataBindings ruleBindings
  lines = .array~new
  lines~append("ABILITY-PROFILE/1")
  lines~append("profile-id: " || profileId)
  lines~append("revision: " || revision)
  lines~append("client-id: " || clientId)
  lines~append("description: " || description)

  aliases = self~runtimeAliases
  do i = 1 to aliases~items
    alias = aliases~at(i)
    binding = runtimeBindings~at(alias)
    lines~append("runtime: " || binding~alias || "|" || binding~moduleId || "|" || binding~artifactId)
  end

  abilityIds = self~abilityIds
  do i = 1 to abilityIds~items
    abilityId = abilityIds~at(i)
    descriptor = abilities~at(abilityId)
    required = .RuntimeCanonical~sortStrings(descriptor~requiredAliases)
    requiredText = ""
    do j = 1 to required~items
      if j > 1 then requiredText = requiredText || ","
      requiredText = requiredText || required~at(j)
    end
    lines~append("ability: " || descriptor~abilityId || "|" || descriptor~kind || "|" || descriptor~readOnly || "|" || requiredText || "|" || descriptor~description)
    lines~append("ability-input-schema: " || descriptor~abilityId || "|" || descriptor~inputSchema~canonicalText)
    lines~append("ability-output-schema: " || descriptor~abilityId || "|" || descriptor~outputSchema~canonicalText)
  end

  dataNames = self~dataBindingNames
  do i = 1 to dataNames~items
    name = dataNames~at(i)
    binding = dataBindings~at(name)
    lines~append("data: " || binding~logicalName || "|" || binding~runtimeAlias || "|" || binding~resourceName || "|" || binding~accessMode)
  end

  ruleNames = self~ruleBindingNames
  do i = 1 to ruleNames~items
    name = ruleNames~at(i)
    binding = ruleBindings~at(name)
    lines~append("rule: " || binding~logicalName || "|" || binding~runtimeAlias || "|" || binding~ruleSetName)
  end
  return .RuntimeCanonical~joinLines(lines)

::method runtimeBinding
  expose runtimeBindings
  use arg alias
  return runtimeBindings~at(alias~string~strip~lower)

::method runtimeAliases
  expose runtimeBindings
  aliases = .array~new
  do alias over runtimeBindings
    aliases~append(alias)
  end
  return .RuntimeCanonical~sortStrings(aliases)

::method requiredModuleIds
  expose runtimeBindings
  ids = .array~new
  seen = .table~new
  do alias over runtimeBindings
    binding = runtimeBindings~at(alias)
    moduleId = binding~moduleId
    if seen~at(moduleId) \== .nil then iterate
    seen~put(.true, moduleId)
    ids~append(moduleId)
  end
  return .RuntimeCanonical~sortStrings(ids)

::method ability
  expose abilities
  use arg abilityId
  return abilities~at(abilityId~string~strip~lower)

::method abilityIds
  expose abilities
  ids = .array~new
  do abilityId over abilities
    ids~append(abilityId)
  end
  return .RuntimeCanonical~sortStrings(ids)

::method dataBinding
  expose dataBindings
  use arg logicalName
  return dataBindings~at(logicalName~string~strip~lower)

::method dataBindingNames
  expose dataBindings
  names = .array~new
  do name over dataBindings
    names~append(name)
  end
  return .RuntimeCanonical~sortStrings(names)

::method ruleBinding
  expose ruleBindings
  use arg logicalName
  return ruleBindings~at(logicalName~string~strip~lower)

::method ruleBindingNames
  expose ruleBindings
  names = .array~new
  do name over ruleBindings
    names~append(name)
  end
  return .RuntimeCanonical~sortStrings(names)

::method validateReferences private
  expose runtimeBindings abilities dataBindings ruleBindings
  do abilityId over abilities
    descriptor = abilities~at(abilityId)
    aliases = descriptor~requiredAliases
    do i = 1 to aliases~items
      alias = aliases~at(i)
      if runtimeBindings~at(alias) == .nil then return .RuntimeResult~failure("ABILITY_RUNTIME_ALIAS_NOT_FOUND", abilityId || ":" || alias)
    end
  end
  do logicalName over dataBindings
    binding = dataBindings~at(logicalName)
    if runtimeBindings~at(binding~runtimeAlias) == .nil then return .RuntimeResult~failure("DATA_RUNTIME_ALIAS_NOT_FOUND", logicalName || ":" || binding~runtimeAlias)
  end
  do logicalName over ruleBindings
    binding = ruleBindings~at(logicalName)
    if runtimeBindings~at(binding~runtimeAlias) == .nil then return .RuntimeResult~failure("RULE_RUNTIME_ALIAS_NOT_FOUND", logicalName || ":" || binding~runtimeAlias)
  end
  return .RuntimeResult~success(self, "profile references valid")

::method copyRuntimeBindings private
  use arg source
  target = .table~new
  if source == .nil then return target
  do i = 1 to source~items
    binding = source~at(i)
    if binding == .nil then iterate
    copy = .AbilityRuntimeBinding~new(binding~alias, binding~moduleId, binding~artifactId)
    if target~at(copy~alias) \== .nil then raise syntax 88.900 array("Duplicate ability runtime alias: " || copy~alias)
    target~put(copy, copy~alias)
  end
  return target

::method copyAbilities private
  use arg source
  target = .table~new
  if source == .nil then return target
  do i = 1 to source~items
    descriptor = source~at(i)
    if descriptor == .nil then iterate
    copy = .AbilityDescriptor~new(descriptor~abilityId, descriptor~kind, descriptor~requiredAliases, descriptor~readOnly, descriptor~description, descriptor~inputSchema, descriptor~outputSchema)
    if target~at(copy~abilityId) \== .nil then raise syntax 88.900 array("Duplicate ability descriptor: " || copy~abilityId)
    target~put(copy, copy~abilityId)
  end
  return target

::method copyDataBindings private
  use arg source
  target = .table~new
  if source == .nil then return target
  do i = 1 to source~items
    binding = source~at(i)
    if binding == .nil then iterate
    copy = .AbilityDataBinding~new(binding~logicalName, binding~runtimeAlias, binding~resourceName, binding~accessMode)
    if target~at(copy~logicalName) \== .nil then raise syntax 88.900 array("Duplicate data binding: " || copy~logicalName)
    target~put(copy, copy~logicalName)
  end
  return target

::method copyRuleBindings private
  use arg source
  target = .table~new
  if source == .nil then return target
  do i = 1 to source~items
    binding = source~at(i)
    if binding == .nil then iterate
    copy = .AbilityRuleBinding~new(binding~logicalName, binding~runtimeAlias, binding~ruleSetName)
    if target~at(copy~logicalName) \== .nil then raise syntax 88.900 array("Duplicate rule binding: " || copy~logicalName)
    target~put(copy, copy~logicalName)
  end
  return target

::class AbilityGeneration public
::attribute generationId get
::attribute environment get
::attribute clientId get
::attribute profileId get
::attribute revision get
::attribute state get
::attribute leaseCount get
::attribute acceptingLeases get
::attribute createdAt get
::attribute activatedAt get
::attribute retiredAt get
::attribute releasedAt get

::method init
  expose generationId environment clientId profileId revision state leaseCount acceptingLeases createdAt activatedAt retiredAt releasedAt profile runtimeSnapshot
  use arg generationId, environment, profile, runtimeSnapshot
  clientId = profile~clientId
  profileId = profile~profileId
  revision = profile~revision
  state = "READY"
  leaseCount = 0
  acceptingLeases = .false
  createdAt = .DateTime~new
  activatedAt = .nil
  retiredAt = .nil
  releasedAt = .nil

::method profile
  expose profile
  return profile

::method runtimeSnapshot
  expose runtimeSnapshot
  return runtimeSnapshot

::method publishActive
  expose state acceptingLeases activatedAt retiredAt
  guard on
  if state \= "READY" then do
    if state \= "RETIRED" then do
      if state \= "DRAINING" then return .RuntimeResult~failure("INVALID_ABILITY_STATE", "publishActive requires READY, DRAINING, or RETIRED, found " || state)
    end
  end
  state = "ACTIVE"
  acceptingLeases = .true
  activatedAt = .DateTime~new
  retiredAt = .nil
  return .RuntimeResult~success(self, "ability generation active")

::method beginDrain
  expose state acceptingLeases leaseCount retiredAt
  guard on
  if state \= "ACTIVE" then return .RuntimeResult~failure("INVALID_ABILITY_STATE", "beginDrain requires ACTIVE, found " || state)
  acceptingLeases = .false
  if leaseCount = 0 then do
    state = "RETIRED"
    retiredAt = .DateTime~new
  end
  else state = "DRAINING"
  return .RuntimeResult~success(self, "ability generation draining")

::method acquireSession
  expose state acceptingLeases leaseCount
  guard on
  if state \= "ACTIVE" then return .RuntimeResult~failure("ABILITY_NOT_ACTIVE", generationId)
  if \acceptingLeases then return .RuntimeResult~failure("ABILITY_NOT_ACTIVE", generationId)
  leaseCount = leaseCount + 1
  return .RuntimeResult~success(.AbilitySession~new(self), "ability session acquired")

::method releaseSession
  expose state leaseCount retiredAt
  guard on
  if leaseCount <= 0 then return .RuntimeResult~failure("ABILITY_LEASE_UNDERFLOW", generationId)
  leaseCount = leaseCount - 1
  if state = "DRAINING" then do
    if leaseCount = 0 then do
      state = "RETIRED"
      retiredAt = .DateTime~new
    end
  end
  return .RuntimeResult~success(leaseCount, "ability session released")

::method retireIfDrained
  expose state leaseCount retiredAt
  guard on
  if state = "DRAINING" then do
    if leaseCount = 0 then do
      state = "RETIRED"
      retiredAt = .DateTime~new
    end
  end
  return .RuntimeResult~success(state, "ability retirement state checked")

::method releaseObjects
  expose state leaseCount acceptingLeases runtimeSnapshot profile releasedAt
  guard on
  releaseAllowed = state = "RETIRED"
  if \releaseAllowed then releaseAllowed = state = "READY"
  if \releaseAllowed then return .RuntimeResult~failure("INVALID_ABILITY_STATE", "release requires RETIRED or READY, found " || state)
  if leaseCount \= 0 then return .RuntimeResult~failure("ABILITY_GENERATION_BUSY", "Ability generation still has " || leaseCount || " sessions")
  acceptingLeases = .false
  if runtimeSnapshot \== .nil then do
    releaseResult = runtimeSnapshot~release
    if \releaseResult~ok then return .RuntimeResult~failure("ABILITY_RUNTIME_RELEASE_FAILED", releaseResult~code || " " || releaseResult~detail)
  end
  runtimeSnapshot = .nil
  profile = .nil
  state = "RELEASED"
  releasedAt = .DateTime~new
  return .RuntimeResult~success(self, "ability generation references released")

::method moduleByAlias
  expose profile runtimeSnapshot
  use arg alias
  if profile == .nil then return .nil
  binding = profile~runtimeBinding(alias)
  if binding == .nil then return .nil
  return runtimeSnapshot~module(binding~moduleId)

::method runtimeGenerationIdByAlias
  expose profile runtimeSnapshot
  use arg alias
  if profile == .nil then return .nil
  binding = profile~runtimeBinding(alias)
  if binding == .nil then return .nil
  return runtimeSnapshot~generationId(binding~moduleId)

::method runtimeArtifactIdByAlias
  expose profile runtimeSnapshot
  use arg alias
  if profile == .nil then return .nil
  binding = profile~runtimeBinding(alias)
  if binding == .nil then return .nil
  lease = runtimeSnapshot~lease(binding~moduleId)
  if lease == .nil then return .nil
  return lease~artifactId

::method runtimeExecutionEvidenceByAlias
  expose profile runtimeSnapshot
  use arg alias
  if profile == .nil then return .nil
  binding = profile~runtimeBinding(alias)
  if binding == .nil then return .nil
  return runtimeSnapshot~executionEvidence(binding~moduleId)

::method runtimeEnvelopeByAlias
  expose profile runtimeSnapshot
  use arg alias, value, locator = ""
  if profile == .nil then return .nil
  binding = profile~runtimeBinding(alias)
  if binding == .nil then return .nil
  return runtimeSnapshot~envelope(binding~moduleId, value, locator)

::method view
  return .AbilityGenerationView~new(self)

::method descriptor
  expose generationId environment clientId profileId revision state leaseCount acceptingLeases createdAt activatedAt retiredAt releasedAt profile runtimeSnapshot
  d = .directory~new
  d["generationId"] = generationId
  d["environment"] = environment
  d["clientId"] = clientId
  d["profileId"] = profileId
  d["revision"] = revision
  d["state"] = state
  d["leaseCount"] = leaseCount
  d["acceptingLeases"] = acceptingLeases
  d["createdAt"] = createdAt
  d["activatedAt"] = activatedAt
  d["retiredAt"] = retiredAt
  d["releasedAt"] = releasedAt
  if profile \== .nil then d["profileIdentity"] = profile~identity
  else d["profileIdentity"] = ""
  if runtimeSnapshot \== .nil then d["runtimeModuleIds"] = runtimeSnapshot~moduleIds
  else d["runtimeModuleIds"] = .array~new
  return d

::class AbilityGenerationView public
::method init
  expose generation
  use arg generation
::method generationId
  expose generation
  return generation~generationId
::method environment
  expose generation
  return generation~environment
::method clientId
  expose generation
  return generation~clientId
::method profileId
  expose generation
  return generation~profileId
::method revision
  expose generation
  return generation~revision
::method state
  expose generation
  return generation~state
::method leaseCount
  expose generation
  return generation~leaseCount
::method acceptingLeases
  expose generation
  return generation~acceptingLeases
::method createdAt
  expose generation
  return generation~createdAt
::method activatedAt
  expose generation
  return generation~activatedAt
::method retiredAt
  expose generation
  return generation~retiredAt
::method releasedAt
  expose generation
  return generation~releasedAt
::method descriptor
  expose generation
  return generation~descriptor

::class AbilitySession public
::attribute generationId get
::attribute environment get
::attribute clientId get
::attribute profileId get
::attribute revision get
::attribute released get
::attribute acquiredAt get

::method init
  expose generation generationId environment clientId profileId revision released acquiredAt
  use arg generation
  generationId = generation~generationId
  environment = generation~environment
  clientId = generation~clientId
  profileId = generation~profileId
  revision = generation~revision
  released = .false
  acquiredAt = .DateTime~new

::method profile
  expose generation released
  if released then return .nil
  return generation~profile

::method ability
  expose generation released
  use arg abilityId
  if released then return .nil
  return generation~profile~ability(abilityId)

::method dataBinding
  expose generation released
  use arg logicalName
  if released then return .nil
  return generation~profile~dataBinding(logicalName)

::method ruleBinding
  expose generation released
  use arg logicalName
  if released then return .nil
  return generation~profile~ruleBinding(logicalName)

::method module
  expose generation released
  use arg runtimeAlias
  if released then return .nil
  return generation~moduleByAlias(runtimeAlias)

::method runtimeGenerationId
  expose generation released
  use arg runtimeAlias
  if released then return .nil
  return generation~runtimeGenerationIdByAlias(runtimeAlias)

::method runtimeArtifactId
  expose generation released
  use arg runtimeAlias
  if released then return .nil
  return generation~runtimeArtifactIdByAlias(runtimeAlias)

::method runtimeExecutionEvidence
  expose generation released
  use arg runtimeAlias
  if released then return .nil
  return generation~runtimeExecutionEvidenceByAlias(runtimeAlias)

::method runtimeEnvelope
  expose generation released
  use arg runtimeAlias, value, locator = ""
  if released then return .nil
  return generation~runtimeEnvelopeByAlias(runtimeAlias, value, locator)

::method release
  expose generation released
  if released then return .RuntimeResult~success(.nil, "ability session already released")
  releaseResult = generation~releaseSession
  if releaseResult~ok then do
    released = .true
    generation = .nil
  end
  return releaseResult

::method uninit
  expose generation released
  if \released then do
    if generation \== .nil then releaseResult = generation~releaseSession
  end

::class AbilityClientSlot public
::attribute clientId get
::attribute activeGenerationId get
::attribute previousGenerationId get

::method init
  expose clientId activeGenerationId previousGenerationId
  use arg clientId
  activeGenerationId = ""
  previousGenerationId = ""

::method activate
  expose activeGenerationId previousGenerationId
  use arg generationId
  oldId = activeGenerationId
  previousGenerationId = oldId
  activeGenerationId = generationId
  return oldId

::class AbilityRegistry public

::method init
  expose runtimeKernel generations environments nextGenerationNumber profilePins
  use arg runtimeKernel
  if runtimeKernel == .nil then raise syntax 88.900 array("AbilityRegistry requires RuntimeKernel")
  generations = .table~new
  environments = .table~new
  profilePins = .table~new
  nextGenerationNumber = 1

::method stage
  expose runtimeKernel generations profilePins
  use arg environment, profile
  guard on
  environment = environment~string~strip~lower
  if environment = "" then return .RuntimeResult~failure("ABILITY_ENVIRONMENT_REQUIRED", "")
  if profile == .nil then return .RuntimeResult~failure("ABILITY_PROFILE_REQUIRED", "")

  profileIdentity = profile~identity
  canonicalProfile = profile~canonicalText
  pinnedProfile = profilePins~at(profileIdentity)
  if pinnedProfile \== .nil then do
    if pinnedProfile \== canonicalProfile then return .RuntimeResult~failure("ABILITY_PROFILE_IDENTITY_REUSED", profileIdentity)
  end

  moduleIds = profile~requiredModuleIds
  snapshotResult = runtimeKernel~snapshot(environment, moduleIds)
  if \snapshotResult~ok then return .RuntimeResult~failure("ABILITY_RUNTIME_SNAPSHOT_FAILED", snapshotResult~code || " " || snapshotResult~detail)
  runtimeSnapshot = snapshotResult~value

  aliases = profile~runtimeAliases
  do i = 1 to aliases~items
    alias = aliases~at(i)
    binding = profile~runtimeBinding(alias)
    if binding~artifactId = "" then iterate
    lease = runtimeSnapshot~lease(binding~moduleId)
    if lease == .nil then do
      cleanupResult = runtimeSnapshot~release
      return .RuntimeResult~failure("ABILITY_RUNTIME_MODULE_MISSING", binding~moduleId)
    end
    if lease~artifactId \= binding~artifactId then do
      actualArtifactId = lease~artifactId
      cleanupResult = runtimeSnapshot~release
      return .RuntimeResult~failure("ABILITY_RUNTIME_ARTIFACT_MISMATCH", alias || " expected=" || binding~artifactId || " actual=" || actualArtifactId)
    end
  end

  generationId = self~allocateGenerationId
  generation = .AbilityGeneration~new(generationId, environment, profile, runtimeSnapshot)
  generations~put(generation, generationId)
  if pinnedProfile == .nil then profilePins~put(canonicalProfile, profileIdentity)
  return .RuntimeResult~success(generation~view, "ability profile staged")

::method activate
  expose generations
  use arg environment, clientId, generationId
  guard on
  environment = environment~string~strip~lower
  clientId = clientId~string~strip~lower
  generationId = generationId~string~strip
  generation = generations~at(generationId)
  if generation == .nil then return .RuntimeResult~failure("ABILITY_GENERATION_NOT_FOUND", generationId)
  if generation~environment \= environment then return .RuntimeResult~failure("ABILITY_ENVIRONMENT_MISMATCH", generation~environment || " != " || environment)
  if generation~clientId \= clientId then return .RuntimeResult~failure("ABILITY_CLIENT_MISMATCH", generation~clientId || " != " || clientId)

  envTable = self~environmentTable(environment)
  slot = envTable~at(clientId)
  if slot == .nil then do
    slot = .AbilityClientSlot~new(clientId)
    envTable~put(slot, clientId)
  end

  startResult = generation~publishActive
  if \startResult~ok then return startResult

  oldId = slot~activeGenerationId
  if oldId \= "" then do
    oldGeneration = generations~at(oldId)
    if oldGeneration \== .nil then drainResult = oldGeneration~beginDrain
  end
  previousId = slot~activate(generationId)
  return .RuntimeResult~success(generation~view, "ability generation activated; previous=" || previousId)

::method acquire
  expose generations environments
  use arg environment, clientId
  guard on
  environment = environment~string~strip~lower
  clientId = clientId~string~strip~lower
  envTable = environments~at(environment)
  if envTable == .nil then return .RuntimeResult~failure("ABILITY_ENVIRONMENT_NOT_FOUND", environment)
  slot = envTable~at(clientId)
  if slot == .nil then return .RuntimeResult~failure("ABILITY_CLIENT_NOT_ACTIVE", clientId)
  generation = generations~at(slot~activeGenerationId)
  if generation == .nil then return .RuntimeResult~failure("ABILITY_GENERATION_NOT_FOUND", slot~activeGenerationId)
  return generation~acquireSession

::method releaseGeneration
  expose generations environments
  use arg generationId
  guard on
  generationId = generationId~string~strip
  generation = generations~at(generationId)
  if generation == .nil then return .RuntimeResult~failure("ABILITY_GENERATION_NOT_FOUND", generationId)

  do environment over environments
    envTable = environments~at(environment)
    do clientId over envTable
      slot = envTable~at(clientId)
      if slot~activeGenerationId = generationId then return .RuntimeResult~failure("ABILITY_GENERATION_ACTIVE", environment || ":" || clientId)
    end
  end
  releaseResult = generation~releaseObjects
  if releaseResult~ok then return .RuntimeResult~success(generation~view, releaseResult~detail)
  return .RuntimeResult~failure(releaseResult~code, releaseResult~detail, generation~view)

::method collectRetired
  expose generations
  guard on
  changed = .array~new
  do generationId over generations
    generation = generations~at(generationId)
    oldState = generation~state
    checkResult = generation~retireIfDrained
    if generation~state \= oldState then changed~append(generationId)
  end
  return .RuntimeResult~success(changed, "ability retirement checked")

::method generation
  expose generations
  use arg generationId
  generation = generations~at(generationId~string~strip)
  if generation == .nil then return .nil
  return generation~view

::method activeGenerationId
  expose environments
  use arg environment, clientId
  environment = environment~string~strip~lower
  clientId = clientId~string~strip~lower
  envTable = environments~at(environment)
  if envTable == .nil then return ""
  slot = envTable~at(clientId)
  if slot == .nil then return ""
  return slot~activeGenerationId

::method activeProfileIdentity
  expose generations
  use arg environment, clientId
  generationId = self~activeGenerationId(environment, clientId)
  if generationId = "" then return ""
  generation = generations~at(generationId)
  if generation == .nil then return ""
  if generation~profile == .nil then return ""
  return generation~profile~identity

::method generationDescriptors
  expose generations
  descriptors = .array~new
  do generationId over generations
    descriptors~append(generations~at(generationId)~descriptor)
  end
  return descriptors

::method allocateGenerationId private
  expose nextGenerationNumber
  generationId = "ability-gen-" || nextGenerationNumber
  nextGenerationNumber = nextGenerationNumber + 1
  return generationId

::method environmentTable private
  expose environments
  use arg environment
  environment = environment~string~strip~lower
  envTable = environments~at(environment)
  if envTable == .nil then do
    envTable = .table~new
    environments~put(envTable, environment)
  end
  return envTable

::class AbilityProfileParser public

::method parseLines class
  use arg lines
  if lines == .nil then return .RuntimeResult~failure("ABILITY_PROFILE_EMPTY", "")
  profileId = ""; revision = ""; clientId = ""; description = ""
  runtimeBindings = .array~new
  abilities = .array~new
  dataBindings = .array~new
  ruleBindings = .array~new
  inputSchemas = .table~new
  outputSchemas = .table~new
  sawHeader = .false

  do i = 1 to lines~items
    raw = lines~at(i)~string
    line = raw~strip
    if line = "" then iterate
    if left(line, 1) = "#" then iterate
    if \sawHeader then do
      if line \= "ABILITY-PROFILE/1" then return .RuntimeResult~failure("ABILITY_PROFILE_HEADER_INVALID", line)
      sawHeader = .true
      iterate
    end

    colon = pos(":", line)
    if colon = 0 then return .RuntimeResult~failure("ABILITY_PROFILE_LINE_INVALID", line)
    key = left(line, colon - 1)~strip~lower
    value = substr(line, colon + 1)~strip

    select
      when key = "profile-id" then do
        if profileId <> "" then return .RuntimeResult~failure("ABILITY_PROFILE_FIELD_DUPLICATE", key)
        profileId = value
      end
      when key = "revision" then do
        if revision <> "" then return .RuntimeResult~failure("ABILITY_PROFILE_FIELD_DUPLICATE", key)
        revision = value
      end
      when key = "client-id" then do
        if clientId <> "" then return .RuntimeResult~failure("ABILITY_PROFILE_FIELD_DUPLICATE", key)
        clientId = value
      end
      when key = "description" then do
        if description <> "" then return .RuntimeResult~failure("ABILITY_PROFILE_FIELD_DUPLICATE", key)
        description = value
      end
      when key = "runtime" then do
        fields = self~split(value, "|")
        if fields~items <> 3 then return .RuntimeResult~failure("ABILITY_PROFILE_RUNTIME_INVALID", value)
        runtimeBindings~append(.AbilityRuntimeBinding~new(fields~at(1), fields~at(2), fields~at(3)))
      end
      when key = "ability" then do
        fields = self~split(value, "|")
        if fields~items <> 5 then return .RuntimeResult~failure("ABILITY_PROFILE_ABILITY_INVALID", value)
        readOnlyText = fields~at(3)~strip~lower
        if readOnlyText = "true" then readOnly = .true
        else if readOnlyText = "1" then readOnly = .true
        else if readOnlyText = "false" then readOnly = .false
        else if readOnlyText = "0" then readOnly = .false
        else return .RuntimeResult~failure("ABILITY_PROFILE_BOOLEAN_INVALID", fields~at(3))
        aliases = .array~new
        aliasText = fields~at(4)~strip
        if aliasText <> "" then do
          aliasFields = self~split(aliasText, ",")
          do j = 1 to aliasFields~items
            aliases~append(aliasFields~at(j)~strip)
          end
        end
        abilities~append(.AbilityDescriptor~new(fields~at(1), fields~at(2), aliases, readOnly, fields~at(5)))
      end
      when key = "ability-input-schema" then do
        schemaFields = self~splitFirst(value, "|")
        if schemaFields~items <> 2 then return .RuntimeResult~failure("ABILITY_PROFILE_SCHEMA_INVALID", value)
        schemaAbilityId = schemaFields~at(1)~strip~lower
        if schemaAbilityId = "" then return .RuntimeResult~failure("ABILITY_PROFILE_SCHEMA_INVALID", value)
        if inputSchemas~at(schemaAbilityId) \== .nil then return .RuntimeResult~failure("ABILITY_PROFILE_SCHEMA_DUPLICATE", "input:" || schemaAbilityId)
        schemaParse = .AbilityJsonSchema~fromJson(schemaFields~at(2))
        if \schemaParse~ok then return .RuntimeResult~failure("ABILITY_PROFILE_SCHEMA_INVALID", schemaAbilityId || ":" || schemaParse~code || ":" || schemaParse~detail)
        inputSchemas[schemaAbilityId] = schemaParse~value
      end
      when key = "ability-output-schema" then do
        schemaFields = self~splitFirst(value, "|")
        if schemaFields~items <> 2 then return .RuntimeResult~failure("ABILITY_PROFILE_SCHEMA_INVALID", value)
        schemaAbilityId = schemaFields~at(1)~strip~lower
        if schemaAbilityId = "" then return .RuntimeResult~failure("ABILITY_PROFILE_SCHEMA_INVALID", value)
        if outputSchemas~at(schemaAbilityId) \== .nil then return .RuntimeResult~failure("ABILITY_PROFILE_SCHEMA_DUPLICATE", "output:" || schemaAbilityId)
        schemaParse = .AbilityJsonSchema~fromJson(schemaFields~at(2))
        if \schemaParse~ok then return .RuntimeResult~failure("ABILITY_PROFILE_SCHEMA_INVALID", schemaAbilityId || ":" || schemaParse~code || ":" || schemaParse~detail)
        outputSchemas[schemaAbilityId] = schemaParse~value
      end
      when key = "data" then do
        fields = self~split(value, "|")
        if fields~items <> 4 then return .RuntimeResult~failure("ABILITY_PROFILE_DATA_INVALID", value)
        dataBindings~append(.AbilityDataBinding~new(fields~at(1), fields~at(2), fields~at(3), fields~at(4)))
      end
      when key = "rule" then do
        fields = self~split(value, "|")
        if fields~items <> 3 then return .RuntimeResult~failure("ABILITY_PROFILE_RULE_INVALID", value)
        ruleBindings~append(.AbilityRuleBinding~new(fields~at(1), fields~at(2), fields~at(3)))
      end
      otherwise return .RuntimeResult~failure("ABILITY_PROFILE_FIELD_UNKNOWN", key)
    end
  end

  if \sawHeader then return .RuntimeResult~failure("ABILITY_PROFILE_HEADER_MISSING", "")
  if profileId = "" then return .RuntimeResult~failure("ABILITY_PROFILE_REQUIRED_FIELD", "profile-id")
  if revision = "" then return .RuntimeResult~failure("ABILITY_PROFILE_REQUIRED_FIELD", "revision")
  if clientId = "" then return .RuntimeResult~failure("ABILITY_PROFILE_REQUIRED_FIELD", "client-id")

  finalAbilities = .array~new
  seenAbilities = .table~new
  do i = 1 to abilities~items
    descriptor = abilities~at(i)
    abilityId = descriptor~abilityId
    seenAbilities[abilityId] = .true
    inputSchema = inputSchemas~at(abilityId)
    if inputSchema == .nil then inputSchema = descriptor~inputSchema
    outputSchema = outputSchemas~at(abilityId)
    if outputSchema == .nil then outputSchema = descriptor~outputSchema
    finalAbilities~append(.AbilityDescriptor~new(abilityId, descriptor~kind, descriptor~requiredAliases, descriptor~readOnly, descriptor~description, inputSchema, outputSchema))
  end
  do abilityId over inputSchemas
    if seenAbilities~at(abilityId) == .nil then return .RuntimeResult~failure("ABILITY_PROFILE_SCHEMA_ABILITY_NOT_FOUND", "input:" || abilityId)
  end
  do abilityId over outputSchemas
    if seenAbilities~at(abilityId) == .nil then return .RuntimeResult~failure("ABILITY_PROFILE_SCHEMA_ABILITY_NOT_FOUND", "output:" || abilityId)
  end

  signal on syntax name profileBuildError
  profile = .AbilityProfileRevision~new(profileId, revision, clientId, runtimeBindings, finalAbilities, dataBindings, ruleBindings, description)
  signal off syntax
  return .RuntimeResult~success(profile, "ability profile parsed")

profileBuildError:
  conditionObject = condition("O")
  message = conditionObject~description
  if message == .nil then message = "profile construction failed"
  return .RuntimeResult~failure("ABILITY_PROFILE_CONSTRUCTION_FAILED", message)

::method split private class
  use arg text, separator
  resultFields = .array~new
  remaining = text~string
  do forever
    p = pos(separator, remaining)
    if p = 0 then do
      resultFields~append(remaining)
      leave
    end
    resultFields~append(left(remaining, p - 1))
    remaining = substr(remaining, p + length(separator))
  end
  return resultFields

::method splitFirst private class
  use arg text, separator
  resultFields = .array~new
  p = pos(separator, text)
  if p = 0 then do
    resultFields~append(text)
    return resultFields
  end
  resultFields~append(left(text, p - 1))
  resultFields~append(substr(text, p + length(separator)))
  return resultFields

::class AbilityProfileLoader public
::method readFile class
  use arg path
  readResult = .RuntimeSourceLoader~readFile(path)
  if \readResult~ok then return readResult
  return .AbilityProfileParser~parseLines(readResult~value)

::requires "AbilitySchema.cls"
::requires "RuntimeRegistry.cls"
