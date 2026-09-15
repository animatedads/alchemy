/* Runtime Registry v0.14
 *
 * Thin live-code microkernel for ooRexx.
 *
 * Design constraints:
 *   - code is loaded only through immutable RuntimeArtifact objects;
 *   - every load gets a unique .Package name;
 *   - environments activate generations by registry pointer, never by classname;
 *   - new leases go only to the active generation;
 *   - old generations drain existing leases before retirement/release;
 *   - verification is pluggable and staging fails closed;
 *   - reloadable code does not own the registry or global namespace.
 */

::class RuntimeRegistryBuild public
::constant PRODUCT "ooRexx Runtime Registry"
::constant RELEASE "0.14"
::constant API_VERSION "runtime.registry/0.3"

::class RuntimeResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get

::method init
  expose ok code detail value
  use arg ok, code = "OK", detail = "", value = .nil

::method success class
  use arg value = .nil, detail = ""
  return self~new(.true, "OK", detail, value)

::method failure class
  use arg code, detail = "", value = .nil
  return self~new(.false, code, detail, value)

::class RuntimeDependency public
::attribute moduleId get
::attribute apiVersion get
::attribute artifactId get

::method init
  expose moduleId apiVersion artifactId
  use arg moduleId, apiVersion = "", artifactId = ""
  moduleId = moduleId~string~strip
  apiVersion = apiVersion~string~strip
  artifactId = artifactId~string~strip
  if moduleId = "" then raise syntax 88.900 array("RuntimeDependency moduleId must not be empty")

::method canonical
  expose moduleId apiVersion artifactId
  return moduleId || "|" || apiVersion || "|" || artifactId

::class RuntimeManifest public
::attribute moduleId get
::attribute moduleKind get
::attribute version get
::attribute artifactId get
::attribute entryClass get
::attribute apiVersion get
::attribute signerId get
::attribute sourceSha512 get
::attribute signatureEd25519 get

::method init
  expose moduleId moduleKind version artifactId entryClass apiVersion signerId sourceSha512 signatureEd25519 dependencies environments
  use arg moduleId, moduleKind, version, artifactId, entryClass, dependencies = .nil, environments = .nil, apiVersion = "runtime.module/0.2", signerId = "", sourceSha512 = "", signatureEd25519 = ""

  moduleId = moduleId~string~strip
  moduleKind = moduleKind~string~strip~upper
  version = version~string~strip
  artifactId = artifactId~string~strip
  entryClass = entryClass~string~strip
  apiVersion = apiVersion~string~strip
  signerId = signerId~string~strip
  sourceSha512 = sourceSha512~string~strip~lower
  signatureEd25519 = signatureEd25519~string~strip~lower

  if moduleId = "" then raise syntax 88.900 array("RuntimeManifest moduleId must not be empty")
  if moduleKind = "" then raise syntax 88.900 array("RuntimeManifest moduleKind must not be empty")
  if version = "" then raise syntax 88.900 array("RuntimeManifest version must not be empty")
  if artifactId = "" then raise syntax 88.900 array("RuntimeManifest artifactId must not be empty")
  if entryClass = "" then raise syntax 88.900 array("RuntimeManifest entryClass must not be empty")
  if apiVersion = "" then raise syntax 88.900 array("RuntimeManifest apiVersion must not be empty")

  dependencies = self~copyDependencies(dependencies)
  environments = self~copyStrings(environments, .true)

::method copyDependencies private
  use arg source
  resultDependencies = .array~new
  if source == .nil then return resultDependencies
  do i = 1 to source~items
    dep = source~at(i)
    if dep == .nil then iterate
    resultDependencies~append(.RuntimeDependency~new(dep~moduleId, dep~apiVersion, dep~artifactId))
  end
  return resultDependencies

::method copyStrings private
  use arg source, lowerValues = .false
  resultStrings = .array~new
  if source == .nil then return resultStrings
  do i = 1 to source~items
    value = source~at(i)~string~strip
    if lowerValues then value = value~lower
    if value <> "" then resultStrings~append(value)
  end
  return resultStrings

::method dependencies
  expose dependencies
  return self~copyDependencies(dependencies)

::method environments
  expose environments
  return self~copyStrings(environments, .true)

::method allowsEnvironment
  expose environments
  use arg environment
  environment = environment~string~strip~lower
  if environments~items = 0 then return .true
  do i = 1 to environments~items
    allowed = environments~at(i)
    if allowed = "*" then return .true
    if allowed = environment then return .true
  end
  return .false

::method withSignature
  expose moduleId moduleKind version artifactId entryClass apiVersion signerId sourceSha512 dependencies environments
  use arg newSignerId, newSourceSha512, newSignature
  return .RuntimeManifest~new(moduleId, moduleKind, version, artifactId, entryClass, dependencies, environments, apiVersion, newSignerId, newSourceSha512, newSignature)

::method canonicalUnsignedText
  expose moduleId moduleKind version artifactId entryClass apiVersion signerId sourceSha512 dependencies environments
  lines = .array~new
  lines~append("RUNTIME-MANIFEST/1")
  lines~append("module-id:" || moduleId)
  lines~append("module-kind:" || moduleKind)
  lines~append("version:" || version)
  lines~append("artifact-id:" || artifactId)
  lines~append("entry-class:" || entryClass)
  lines~append("api-version:" || apiVersion)
  lines~append("signer-id:" || signerId)
  lines~append("source-sha512:" || sourceSha512)

  envRows = .array~new
  do i = 1 to environments~items
    envRows~append(environments~at(i))
  end
  envRows = .RuntimeCanonical~sortStrings(envRows)
  do i = 1 to envRows~items
    lines~append("environment:" || envRows~at(i))
  end

  depRows = .array~new
  do i = 1 to dependencies~items
    depRows~append(dependencies~at(i)~canonical)
  end
  depRows = .RuntimeCanonical~sortStrings(depRows)
  do i = 1 to depRows~items
    lines~append("dependency:" || depRows~at(i))
  end
  return .RuntimeCanonical~joinLines(lines)

::class RuntimeCanonical public
::method sortStrings class
  use arg values
  sorted = .array~new
  do i = 1 to values~items
    value = values~at(i)~string
    inserted = .false
    if sorted~items = 0 then sorted~append(value)
    else do
      do j = 1 to sorted~items
        if value < sorted~at(j) then do
          rebuilt = .array~new
          do k = 1 to j - 1
            rebuilt~append(sorted~at(k))
          end
          rebuilt~append(value)
          do k = j to sorted~items
            rebuilt~append(sorted~at(k))
          end
          sorted = rebuilt
          inserted = .true
          leave
        end
      end
      if \inserted then sorted~append(value)
    end
  end
  return sorted

::method joinLines class
  use arg lines
  text = ""
  do i = 1 to lines~items
    text = text || lines~at(i) || "0a"x
  end
  return text

::class RuntimeArtifact public
::attribute sourceLabel get

::method init
  expose manifest sourceLabel sourceLines
  use arg manifestOrModuleId, a2 = .nil, a3 = .nil, a4 = .nil, a5 = .nil, a6 = .nil, a7 = "runtime.module/0.2", a8 = "memory"

  if manifestOrModuleId~isA(.RuntimeManifest) then do
    manifest = manifestOrModuleId
    sourceLines = a2
    sourceLabel = a3
    if sourceLabel == .nil then sourceLabel = "memory"
  end
  else do
    manifest = .RuntimeManifest~new(manifestOrModuleId, a2, a3, a4, a5, .nil, .nil, a7)
    sourceLines = a6
    sourceLabel = a8
  end

  sourceLabel = sourceLabel~string
  if sourceLines == .nil then raise syntax 88.900 array("RuntimeArtifact sourceLines must not be .nil")
  sourceLines = self~copyLines(sourceLines)

::method manifest
  expose manifest
  return manifest

::method moduleId
  expose manifest
  return manifest~moduleId

::method moduleKind
  expose manifest
  return manifest~moduleKind

::method version
  expose manifest
  return manifest~version

::method artifactId
  expose manifest
  return manifest~artifactId

::method entryClass
  expose manifest
  return manifest~entryClass

::method apiVersion
  expose manifest
  return manifest~apiVersion

::method copyLines private
  use arg lines
  resultLines = .array~new
  do i = 1 to lines~items
    resultLines~append(lines~at(i)~string)
  end
  return resultLines

::method sourceLines
  expose sourceLines
  return self~copyLines(sourceLines)

::method sourceLineCount
  expose sourceLines
  return sourceLines~items

::method canonicalSource
  expose sourceLines
  return .RuntimeCanonical~joinLines(sourceLines)

::method sameSource
  expose sourceLines
  use arg otherLines
  if otherLines == .nil then return .false
  if sourceLines~items <> otherLines~items then return .false
  do i = 1 to sourceLines~items
    if sourceLines~at(i) \== otherLines~at(i)~string then return .false
  end
  return .true

::class RuntimeArtifactVerifier public
::method verify abstract

/* Exact pin verifier used by the first framework cut.
 *
 * This is intentionally NOT presented as cryptographic verification.  A trusted
 * deployment controller pins an artifactId to the exact source lines it has
 * approved.  Production signature/hash verification can replace this object
 * without changing RuntimeRegistry semantics.
 */
::class RuntimePinnedSourceVerifier subclass RuntimeArtifactVerifier public

::method init
  expose pins
  pins = .table~new

::method pin
  expose pins
  use arg artifactId, sourceLines
  key = artifactId~string
  copy = .array~new
  do i = 1 to sourceLines~items
    copy~append(sourceLines~at(i)~string)
  end
  pins~put(copy, key)
  return .RuntimeResult~success(key, "source pinned")

::method unpin
  expose pins
  use arg artifactId
  pins~remove(artifactId~string)
  return .RuntimeResult~success(.nil, "source pin removed")

::method verify
  expose pins
  use arg environmentOrArtifact, maybeArtifact = .nil
  if maybeArtifact == .nil then artifact = environmentOrArtifact
  else artifact = maybeArtifact
  key = artifact~artifactId
  expected = pins~at(key)
  if expected == .nil then return .RuntimeResult~failure("ARTIFACT_UNPINNED", "No trusted source pin for artifact " || key)
  if \artifact~sameSource(expected) then return .RuntimeResult~failure("ARTIFACT_SOURCE_MISMATCH", "Source does not match trusted pin for artifact " || key)
  return .RuntimeResult~success(artifact, "exact source pin verified")

::class RuntimeInternalToken

::class RuntimeModuleContext public
::attribute environment get
::attribute generationId get
::attribute artifactId get
::attribute moduleId get
::attribute registryApiVersion get
::attribute loadedAt get

::method init
  expose environment generationId artifactId moduleId registryApiVersion loadedAt dependencySnapshot dependencyReleaseToken
  use arg environment, generationId, artifactId, moduleId, registryApiVersion, dependencySnapshot = .nil, dependencyReleaseToken = .nil
  loadedAt = .DateTime~new

::method dependency
  expose dependencySnapshot
  use arg dependencyModuleId
  if dependencySnapshot == .nil then return .nil
  return dependencySnapshot~module(dependencyModuleId)

::method dependencyGenerationId
  expose dependencySnapshot
  use arg dependencyModuleId
  if dependencySnapshot == .nil then return ""
  value = dependencySnapshot~generationId(dependencyModuleId)
  if value == .nil then return ""
  return value

::method dependencyArtifactId
  expose dependencySnapshot
  use arg dependencyModuleId
  if dependencySnapshot == .nil then return ""
  lease = dependencySnapshot~lease(dependencyModuleId)
  if lease == .nil then return ""
  return lease~artifactId

::method dependencyModuleIds
  expose dependencySnapshot
  if dependencySnapshot == .nil then return .array~new
  return dependencySnapshot~moduleIds

::method releaseDependencies
  expose dependencySnapshot dependencyReleaseToken
  use arg authorityToken = .nil
  if authorityToken \== dependencyReleaseToken then return .RuntimeResult~failure("DEPENDENCY_RELEASE_FORBIDDEN", "dependency lifetime is owned by RuntimeRegistry")
  if dependencySnapshot == .nil then return .RuntimeResult~success(.nil, "no dependency snapshot")
  releaseResult = dependencySnapshot~release
  dependencySnapshot = .nil
  return releaseResult

::class RuntimeGeneration public
::attribute generationId get
::attribute environment get
::attribute moduleId get
::attribute moduleKind get
::attribute version get
::attribute artifactId get
::attribute apiVersion get
::attribute packageName get
::attribute state get
::attribute leaseCount get
::attribute acceptingLeases get
::attribute createdAt get
::attribute activatedAt get
::attribute retiredAt get
::attribute releasedAt get
::attribute lastLifecycleError get

::method init
  expose generationId environment moduleId moduleKind version artifactId apiVersion packageName state leaseCount acceptingLeases createdAt activatedAt retiredAt releasedAt lastLifecycleError packageObject moduleObject artifact context dependencyReleaseToken
  use arg generationId, environment, artifact, packageName, packageObject, moduleObject, context, dependencyReleaseToken = .nil
  moduleId = artifact~moduleId
  moduleKind = artifact~moduleKind
  version = artifact~version
  artifactId = artifact~artifactId
  apiVersion = artifact~apiVersion
  state = "LOADED"
  leaseCount = 0
  acceptingLeases = .false
  createdAt = .DateTime~new
  activatedAt = .nil
  retiredAt = .nil
  releasedAt = .nil
  lastLifecycleError = ""

::method artifact
  expose artifact
  return artifact

::method moduleObject
  expose moduleObject
  return moduleObject

::method packageObject
  expose packageObject
  return packageObject

::method context
  expose context
  return context

::method prepare
  expose state moduleObject context lastLifecycleError
  guard on
  if state <> "LOADED" then return .RuntimeResult~failure("INVALID_GENERATION_STATE", "prepare requires LOADED, found " || state)

  signal on syntax name prepareError
  if moduleObject~hasMethod("RUNTIMEPREPARE") then prepareResult = moduleObject~runtimePrepare(context)
  else prepareResult = .true
  signal off syntax

  if prepareResult == .false then do
    state = "QUARANTINED"
    lastLifecycleError = "runtimePrepare returned false"
    return .RuntimeResult~failure("MODULE_PREPARE_FAILED", lastLifecycleError)
  end

  return .RuntimeResult~success(self, "module prepared")

prepareError:
  conditionObject = condition("O")
  state = "QUARANTINED"
  lastLifecycleError = self~conditionMessage(conditionObject)
  return .RuntimeResult~failure("MODULE_PREPARE_EXCEPTION", lastLifecycleError)

::method selfTest
  expose state moduleObject lastLifecycleError
  guard on
  if state <> "LOADED" then return .RuntimeResult~failure("INVALID_GENERATION_STATE", "selfTest requires LOADED, found " || state)

  signal on syntax name selfTestError
  if moduleObject~hasMethod("RUNTIMESELFTEST") then testResult = moduleObject~runtimeSelfTest
  else testResult = .true
  signal off syntax

  if testResult == .false then do
    state = "QUARANTINED"
    lastLifecycleError = "runtimeSelfTest returned false"
    return .RuntimeResult~failure("MODULE_SELFTEST_FAILED", lastLifecycleError)
  end

  state = "READY"
  return .RuntimeResult~success(self, "module ready")

selfTestError:
  conditionObject = condition("O")
  state = "QUARANTINED"
  lastLifecycleError = self~conditionMessage(conditionObject)
  return .RuntimeResult~failure("MODULE_SELFTEST_EXCEPTION", lastLifecycleError)

::method startForActivation
  expose state moduleObject lastLifecycleError
  guard on
  if state <> "READY" then do
    if state <> "RETIRED" then return .RuntimeResult~failure("INVALID_GENERATION_STATE", "activation requires READY or RETIRED, found " || state)
  end

  signal on syntax name startError
  if moduleObject~hasMethod("RUNTIMESTART") then startResult = moduleObject~runtimeStart
  else startResult = .true
  signal off syntax

  if startResult == .false then do
    lastLifecycleError = "runtimeStart returned false"
    return .RuntimeResult~failure("MODULE_START_FAILED", lastLifecycleError)
  end

  return .RuntimeResult~success(self, "module started")

startError:
  conditionObject = condition("O")
  lastLifecycleError = self~conditionMessage(conditionObject)
  return .RuntimeResult~failure("MODULE_START_EXCEPTION", lastLifecycleError)

::method abortActivationStart
  expose state moduleObject lastLifecycleError
  guard on
  if state <> "READY" then do
    if state <> "RETIRED" then return .RuntimeResult~failure("INVALID_GENERATION_STATE", "abortActivationStart requires READY or RETIRED, found " || state)
  end
  signal on syntax name abortStartError
  if moduleObject~hasMethod("RUNTIMESTOP") then stopResult = moduleObject~runtimeStop
  else stopResult = .true
  signal off syntax
  if stopResult == .false then do
    lastLifecycleError = "runtimeStop returned false while aborting activation"
    return .RuntimeResult~failure("MODULE_ACTIVATION_ABORT_FAILED", lastLifecycleError)
  end
  return .RuntimeResult~success(self~view, "candidate activation start aborted")

abortStartError:
  conditionObject = condition("O")
  lastLifecycleError = self~conditionMessage(conditionObject)
  return .RuntimeResult~failure("MODULE_ACTIVATION_ABORT_EXCEPTION", lastLifecycleError)

::method publishActive
  expose state acceptingLeases activatedAt retiredAt
  guard on
  if state <> "READY" then do
    if state <> "RETIRED" then return .RuntimeResult~failure("INVALID_GENERATION_STATE", "publishActive requires READY or RETIRED, found " || state)
  end
  state = "ACTIVE"
  acceptingLeases = .true
  activatedAt = .DateTime~new
  retiredAt = .nil
  return .RuntimeResult~success(self, "generation active")

::method beginDrain
  expose state acceptingLeases moduleObject lastLifecycleError
  guard on
  if state <> "ACTIVE" then return .RuntimeResult~failure("INVALID_GENERATION_STATE", "beginDrain requires ACTIVE, found " || state)

  /* RuntimeRegistry holds its registry guard while activation runs. New
   * acquire() calls therefore wait while quiesce is attempted. If quiesce
   * fails, this generation remains ACTIVE and the old routing pointer stays
   * valid. */
  signal on syntax name quiesceError
  if moduleObject~hasMethod("RUNTIMEQUIESCE") then quiesceResult = moduleObject~runtimeQuiesce
  else quiesceResult = .true
  signal off syntax

  if quiesceResult == .false then do
    lastLifecycleError = "runtimeQuiesce returned false"
    return .RuntimeResult~failure("MODULE_QUIESCE_FAILED", lastLifecycleError, self~view)
  end

  acceptingLeases = .false
  state = "DRAINING"
  return .RuntimeResult~success(self~view, "generation draining")

quiesceError:
  conditionObject = condition("O")
  lastLifecycleError = self~conditionMessage(conditionObject)
  return .RuntimeResult~failure("MODULE_QUIESCE_EXCEPTION", lastLifecycleError, self~view)

::method acquireLease
  expose state acceptingLeases leaseCount
  guard on
  if state <> "ACTIVE" then return .RuntimeResult~failure("GENERATION_NOT_ACTIVE", "Generation " || self~generationId || " does not accept new leases")
  if \acceptingLeases then return .RuntimeResult~failure("GENERATION_NOT_ACTIVE", "Generation " || self~generationId || " does not accept new leases")
  leaseCount = leaseCount + 1
  return .RuntimeResult~success(.RuntimeLease~new(self), "lease acquired")

::method releaseLease
  expose leaseCount state retiredAt
  guard on
  if leaseCount <= 0 then return .RuntimeResult~failure("LEASE_UNDERFLOW", "Generation has no outstanding leases")
  leaseCount = leaseCount - 1
  if state = "DRAINING" then do
    if leaseCount = 0 then do
      state = "RETIRED"
      retiredAt = .DateTime~new
    end
  end
  return .RuntimeResult~success(leaseCount, "lease released")

::method retireIfDrained
  expose state leaseCount retiredAt
  guard on
  if state = "DRAINING" then do
    if leaseCount = 0 then do
      state = "RETIRED"
      retiredAt = .DateTime~new
    end
  end
  return .RuntimeResult~success(state, "retirement state checked")

::method releaseObjects
  expose state leaseCount acceptingLeases packageObject moduleObject context artifact releasedAt lastLifecycleError dependencyReleaseToken
  guard on
  releaseAllowed = state = "RETIRED"
  if \releaseAllowed then releaseAllowed = state = "QUARANTINED"
  if \releaseAllowed then releaseAllowed = state = "READY"
  if \releaseAllowed then return .RuntimeResult~failure("INVALID_GENERATION_STATE", "release requires RETIRED, QUARANTINED, or READY, found " || state)
  if leaseCount <> 0 then return .RuntimeResult~failure("GENERATION_BUSY", "Generation still has " || leaseCount || " leases")

  acceptingLeases = .false
  signal on syntax name stopError
  if moduleObject \== .nil then do
    if moduleObject~hasMethod("RUNTIMESTOP") then stopResult = moduleObject~runtimeStop
    else stopResult = .true
  end
  else stopResult = .true
  signal off syntax

  if stopResult == .false then do
    lastLifecycleError = "runtimeStop returned false"
    return .RuntimeResult~failure("MODULE_STOP_FAILED", lastLifecycleError)
  end

  if context \== .nil then do
    dependencyRelease = context~releaseDependencies(dependencyReleaseToken)
    if \dependencyRelease~ok then do
      lastLifecycleError = "dependency release failed: " || dependencyRelease~code || " " || dependencyRelease~detail
      return .RuntimeResult~failure("DEPENDENCY_RELEASE_FAILED", lastLifecycleError)
    end
  end

  moduleObject = .nil
  packageObject = .nil
  context = .nil
  artifact = .nil
  state = "RELEASED"
  releasedAt = .DateTime~new
  return .RuntimeResult~success(self, "generation references released")

stopError:
  conditionObject = condition("O")
  lastLifecycleError = self~conditionMessage(conditionObject)
  return .RuntimeResult~failure("MODULE_STOP_EXCEPTION", lastLifecycleError)

::method view
  return .RuntimeGenerationView~new(self)

::method descriptor
  expose generationId environment moduleId moduleKind version artifactId apiVersion packageName state leaseCount acceptingLeases createdAt activatedAt retiredAt releasedAt lastLifecycleError packageObject moduleObject context
  d = .directory~new
  d["generationId"] = generationId
  d["environment"] = environment
  d["moduleId"] = moduleId
  d["moduleKind"] = moduleKind
  d["version"] = version
  d["artifactId"] = artifactId
  d["apiVersion"] = apiVersion
  d["packageName"] = packageName
  d["state"] = state
  d["leaseCount"] = leaseCount
  d["acceptingLeases"] = acceptingLeases
  d["createdAt"] = createdAt
  d["activatedAt"] = activatedAt
  d["retiredAt"] = retiredAt
  d["releasedAt"] = releasedAt
  d["lastLifecycleError"] = lastLifecycleError
  d["moduleResident"] = moduleObject \== .nil
  d["packageResident"] = packageObject \== .nil
  if context \== .nil then d["dependencyModuleIds"] = context~dependencyModuleIds
  else d["dependencyModuleIds"] = .array~new
  return d

::method conditionMessage private
  use arg conditionObject
  if conditionObject == .nil then return "unknown ooRexx condition"
  message = conditionObject["MESSAGE"]
  code = conditionObject["CODE"]
  if message == .nil then message = "ooRexx condition"
  if code == .nil then return message~string
  return code~string || ": " || message~string

::class RuntimeGenerationView public
::method init
  expose generation
  use arg generation

::method generationId
  expose generation
  return generation~generationId
::method environment
  expose generation
  return generation~environment
::method moduleId
  expose generation
  return generation~moduleId
::method moduleKind
  expose generation
  return generation~moduleKind
::method version
  expose generation
  return generation~version
::method artifactId
  expose generation
  return generation~artifactId
::method apiVersion
  expose generation
  return generation~apiVersion
::method packageName
  expose generation
  return generation~packageName
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
::method lastLifecycleError
  expose generation
  return generation~lastLifecycleError
::method moduleResident
  expose generation
  return generation~moduleObject \== .nil
::method packageResident
  expose generation
  return generation~packageObject \== .nil
::method packageIdentity
  expose generation
  packageObject = generation~packageObject
  if packageObject == .nil then return ""
  return packageObject~identityHash
::method moduleClassIdentity
  expose generation
  moduleObject = generation~moduleObject
  if moduleObject == .nil then return ""
  return moduleObject~class~identityHash
::method dependencyGenerationId
  expose generation
  use arg moduleId
  context = generation~context
  if context == .nil then return ""
  return context~dependencyGenerationId(moduleId)
::method dependencyArtifactId
  expose generation
  use arg moduleId
  context = generation~context
  if context == .nil then return ""
  return context~dependencyArtifactId(moduleId)
::method descriptor
  expose generation
  return generation~descriptor

::class RuntimeExecutionEvidence public
::attribute evidenceApi get
::attribute environment get
::attribute generationId get
::attribute moduleId get
::attribute moduleKind get
::attribute version get
::attribute artifactId get
::attribute apiVersion get
::attribute generationState get
::attribute packageName get
::attribute generationCreatedAt get
::attribute generationActivatedAt get
::attribute generationRetiredAt get
::attribute capturedAt get

::method init
  expose evidenceApi environment generationId moduleId moduleKind version artifactId apiVersion generationState packageName generationCreatedAt generationActivatedAt generationRetiredAt capturedAt
  use arg generationView
  if generationView == .nil then raise syntax 88.900 array("RuntimeExecutionEvidence requires a generation view")
  evidenceApi = "runtime.execution/0.1"
  environment = generationView~environment
  generationId = generationView~generationId
  moduleId = generationView~moduleId
  moduleKind = generationView~moduleKind
  version = generationView~version
  artifactId = generationView~artifactId
  apiVersion = generationView~apiVersion
  generationState = generationView~state
  packageName = generationView~packageName
  generationCreatedAt = generationView~createdAt
  generationActivatedAt = generationView~activatedAt
  generationRetiredAt = generationView~retiredAt
  capturedAt = .DateTime~new

::method provenance
  expose evidenceApi environment generationId moduleId moduleKind version artifactId apiVersion generationState packageName generationCreatedAt generationActivatedAt generationRetiredAt capturedAt
  p = .directory~new
  p["kind"] = "RUNTIME_EXECUTION_EVIDENCE"
  p["api"] = evidenceApi
  p["environment"] = environment
  p["generation_id"] = generationId
  p["module_id"] = moduleId
  p["module_kind"] = moduleKind
  p["version"] = version
  p["artifact_id"] = artifactId
  p["api_version"] = apiVersion
  p["generation_state"] = generationState
  p["package_name"] = packageName
  if generationCreatedAt \== .nil then p["generation_created_at"] = generationCreatedAt~string
  if generationActivatedAt \== .nil then p["generation_activated_at"] = generationActivatedAt~string
  if generationRetiredAt \== .nil then p["generation_retired_at"] = generationRetiredAt~string
  p["captured_at"] = capturedAt~string
  return p

::method string
  expose environment generationId moduleId artifactId generationState
  return "RUNTIME-EXECUTION[" || environment || ":" || moduleId || ":" || generationId || "] " || artifactId || " " || generationState


::class RuntimeEvidenceEnvelope public
::attribute value get
::attribute runtimeEvidence get
::attribute locator get
::attribute createdAt get

::method init
  expose value runtimeEvidence locator createdAt
  use arg valueArg, runtimeEvidenceArg, locatorArg = ""
  if runtimeEvidenceArg == .nil then raise syntax 88.900 array("RuntimeEvidenceEnvelope requires runtime evidence")
  value = valueArg
  runtimeEvidence = runtimeEvidenceArg
  locator = locatorArg~string
  createdAt = .DateTime~new

::method isEvidenceBearing
  return .true

::method source
  expose value
  if value == .nil then return .nil
  if value~hasMethod("SOURCE") then return value~source
  return .nil

::method provenance
  expose value runtimeEvidence locator createdAt
  p = .directory~new
  p["kind"] = "RUNTIME_EVIDENCE_ENVELOPE"
  p["locator"] = locator
  p["created_at"] = createdAt~string
  p["runtime"] = runtimeEvidence~provenance
  if value \== .nil then do
    if value~hasMethod("PROVENANCE") then p["value"] = value~provenance
  end
  return p

::method string
  expose runtimeEvidence locator
  if locator = "" then return runtimeEvidence~string
  return runtimeEvidence~string || " @ " || locator


::class RuntimeLease public
::attribute generationId get
::attribute moduleId get
::attribute artifactId get
::attribute apiVersion get
::attribute version get
::attribute released get

::method init
  expose generation generationId moduleId artifactId apiVersion version released
  use arg generation
  generationId = generation~generationId
  moduleId = generation~moduleId
  artifactId = generation~artifactId
  apiVersion = generation~apiVersion
  version = generation~version
  released = .false

::method module
  expose generation released
  if released then return .nil
  return generation~moduleObject

::method generation
  expose generation released
  if released then return .nil
  return generation~view

::method executionEvidence
  expose generation released
  if released then return .nil
  if generation == .nil then return .nil
  return .RuntimeExecutionEvidence~new(generation~view)

::method envelope
  expose released
  use arg value, locator = ""
  if released then return .nil
  evidence = self~executionEvidence
  if evidence == .nil then return .nil
  return .RuntimeEvidenceEnvelope~new(value, evidence, locator)

::method release
  expose generation released
  if released then return .RuntimeResult~success(.nil, "lease already released")
  releaseResult = generation~releaseLease
  if releaseResult~ok then do
    released = .true
    generation = .nil
  end
  return releaseResult

::method uninit
  expose generation released
  if \released then do
    if generation \== .nil then releaseResult = generation~releaseLease
  end

::class RuntimeSnapshot public
::attribute environment get
::attribute createdAt get
::attribute released get

::method init
  expose environment createdAt leases released
  use arg environment, leases
  createdAt = .DateTime~new
  released = .false

::method moduleIds
  expose leases
  ids = .array~new
  do moduleId over leases
    ids~append(moduleId)
  end
  return ids

::method lease
  expose leases released
  use arg moduleId
  if released then return .nil
  return leases~at(moduleId~string)

::method module
  expose leases released
  use arg moduleId
  if released then return .nil
  lease = leases~at(moduleId~string)
  if lease == .nil then return .nil
  return lease~module

::method generationId
  expose leases released
  use arg moduleId
  if released then return .nil
  lease = leases~at(moduleId~string)
  if lease == .nil then return .nil
  return lease~generationId

::method executionEvidence
  expose leases released
  use arg moduleId
  if released then return .nil
  lease = leases~at(moduleId~string)
  if lease == .nil then return .nil
  return lease~executionEvidence

::method envelope
  expose leases released
  use arg moduleId, value, locator = ""
  if released then return .nil
  lease = leases~at(moduleId~string)
  if lease == .nil then return .nil
  return lease~envelope(value, locator)

::method release
  expose leases released
  if released then return .RuntimeResult~success(.nil, "snapshot already released")
  failures = .array~new
  do moduleId over leases
    lease = leases~at(moduleId)
    releaseResult = lease~release
    if \releaseResult~ok then failures~append(moduleId || ":" || releaseResult~code)
  end
  released = .true
  leases = .table~new
  if failures~items > 0 then return .RuntimeResult~failure("SNAPSHOT_RELEASE_PARTIAL", failures~makeString(","))
  return .RuntimeResult~success(.nil, "snapshot released")

::method uninit
  expose leases released
  if released then return
  do moduleId over leases
    lease = leases~at(moduleId)
    releaseResult = lease~release
  end
  released = .true

::class RuntimeEnvironmentSlot public
::attribute moduleId get
::attribute activeGenerationId get
::attribute previousGenerationId get

::method init
  expose moduleId activeGenerationId previousGenerationId
  use arg moduleId
  activeGenerationId = ""
  previousGenerationId = ""

::method activate
  expose activeGenerationId previousGenerationId
  use arg generationId
  if activeGenerationId <> "" then previousGenerationId = activeGenerationId
  activeGenerationId = generationId~string
  return previousGenerationId

::class RuntimeRegistry public
::attribute verifier get
::attribute apiVersion get

::method init
  expose verifier apiVersion generations environments nextGenerationNumber
  use arg verifier, apiVersion = "runtime.registry/0.3"
  if verifier == .nil then raise syntax 88.900 array("RuntimeRegistry requires an artifact verifier")
  generations = .table~new
  environments = .table~new
  nextGenerationNumber = 0

::method stage
  expose verifier apiVersion
  use arg environment, artifact
  environment = environment~string~strip~lower
  if environment = "" then return .RuntimeResult~failure("INVALID_ENVIRONMENT", "Environment must not be empty")
  if artifact == .nil then return .RuntimeResult~failure("INVALID_ARTIFACT", "Artifact must not be .nil")

  if \artifact~manifest~allowsEnvironment(environment) then return .RuntimeResult~failure("ARTIFACT_ENVIRONMENT_DENIED", "Artifact " || artifact~artifactId || " is not eligible for " || environment)

  verification = verifier~verify(environment, artifact)
  if \verification~ok then return verification

  dependencyResult = self~acquireDependencySnapshot(environment, artifact~manifest)
  if \dependencyResult~ok then return dependencyResult
  dependencySnapshot = dependencyResult~value

  generationId = self~allocateGenerationId
  packageName = "registry://" || environment || "/" || artifact~moduleId || "/" || artifact~artifactId || "/" || generationId
  dependencyReleaseToken = .RuntimeInternalToken~new
  context = .RuntimeModuleContext~new(environment, generationId, artifact~artifactId, artifact~moduleId, apiVersion, dependencySnapshot, dependencyReleaseToken)

  signal on syntax name stageError
  packageObject = .Package~new(packageName, artifact~sourceLines)
  entryClass = packageObject~findClass(artifact~entryClass)
  if entryClass == .nil then do
    signal off syntax
    cleanupResult = context~releaseDependencies(dependencyReleaseToken)
    return .RuntimeResult~failure("ENTRY_CLASS_NOT_FOUND", "Class " || artifact~entryClass || " not found in " || packageName)
  end
  moduleObject = entryClass~new
  signal off syntax

  generation = .RuntimeGeneration~new(generationId, environment, artifact, packageName, packageObject, moduleObject, context, dependencyReleaseToken)

  prepareResult = generation~prepare
  if \prepareResult~ok then do
    registerResult = self~registerGeneration(generation)
    dependencyCleanup = context~releaseDependencies(dependencyReleaseToken)
    if \dependencyCleanup~ok then return .RuntimeResult~failure("DEPENDENCY_RELEASE_FAILED", dependencyCleanup~detail, generation~view)
    return .RuntimeResult~failure(prepareResult~code, prepareResult~detail, generation~view)
  end

  testResult = generation~selfTest
  registerResult = self~registerGeneration(generation)
  if \testResult~ok then do
    dependencyCleanup = context~releaseDependencies(dependencyReleaseToken)
    if \dependencyCleanup~ok then return .RuntimeResult~failure("DEPENDENCY_RELEASE_FAILED", dependencyCleanup~detail, generation~view)
    return .RuntimeResult~failure(testResult~code, testResult~detail, generation~view)
  end

  return .RuntimeResult~success(generation~view, "generation staged and ready")

stageError:
  conditionObject = condition("O")
  message = self~conditionMessage(conditionObject)
  if context \== .nil then cleanupResult = context~releaseDependencies(dependencyReleaseToken)
  return .RuntimeResult~failure("PACKAGE_LOAD_FAILED", message)

::method activate
  expose generations environments
  use arg environment, moduleId, generationId
  guard on
  environment = environment~string~strip~lower
  moduleId = moduleId~string
  generationId = generationId~string

  generation = generations~at(generationId)
  if generation == .nil then return .RuntimeResult~failure("GENERATION_NOT_FOUND", generationId)
  if generation~environment <> environment then return .RuntimeResult~failure("GENERATION_ENVIRONMENT_MISMATCH", generation~environment || " != " || environment)
  if generation~moduleId <> moduleId then return .RuntimeResult~failure("GENERATION_MODULE_MISMATCH", generation~moduleId || " != " || moduleId)

  startResult = generation~startForActivation
  if \startResult~ok then return startResult

  envTable = self~environmentTable(environment)
  slot = envTable~at(moduleId)
  if slot == .nil then do
    slot = .RuntimeEnvironmentSlot~new(moduleId)
    envTable~put(slot, moduleId)
  end

  oldId = slot~activeGenerationId
  if oldId <> "" then do
    oldGeneration = generations~at(oldId)
    if oldGeneration \== .nil then do
      drainResult = oldGeneration~beginDrain
      if \drainResult~ok then do
        abortResult = generation~abortActivationStart
        if \abortResult~ok then return .RuntimeResult~failure("ACTIVATION_ABORT_FAILED", drainResult~code || ":" || drainResult~detail || "; " || abortResult~code || ":" || abortResult~detail, generation~view)
        return .RuntimeResult~failure(drainResult~code, drainResult~detail, drainResult~value)
      end
    end
  end

  publishResult = generation~publishActive
  if \publishResult~ok then return publishResult
  previousId = slot~activate(generationId)

  return .RuntimeResult~success(generation~view, "activated; previous=" || previousId)

::method acquire
  expose generations environments
  use arg environment, moduleId
  guard on
  environment = environment~string~strip~lower
  moduleId = moduleId~string
  envTable = environments~at(environment)
  if envTable == .nil then return .RuntimeResult~failure("ENVIRONMENT_NOT_FOUND", environment)
  slot = envTable~at(moduleId)
  if slot == .nil then return .RuntimeResult~failure("MODULE_NOT_ACTIVE", moduleId)
  activeId = slot~activeGenerationId
  if activeId = "" then return .RuntimeResult~failure("MODULE_NOT_ACTIVE", moduleId)
  generation = generations~at(activeId)
  if generation == .nil then return .RuntimeResult~failure("GENERATION_NOT_FOUND", activeId)
  return generation~acquireLease

::method snapshot
  expose generations environments
  use arg environment, requestedModuleIds = .nil
  guard on
  environment = environment~string~strip~lower
  envTable = environments~at(environment)
  if envTable == .nil then return .RuntimeResult~failure("ENVIRONMENT_NOT_FOUND", environment)

  if requestedModuleIds == .nil then do
    moduleIds = .array~new
    do moduleId over envTable
      moduleIds~append(moduleId)
    end
  end
  else moduleIds = requestedModuleIds

  leases = .table~new
  seenModuleIds = .table~new
  do i = 1 to moduleIds~items
    moduleId = moduleIds~at(i)~string
    if seenModuleIds~at(moduleId) \== .nil then iterate
    seenModuleIds~put(.true, moduleId)
    slot = envTable~at(moduleId)
    if slot == .nil then do
      cleanupResult = self~releaseLeaseTable(leases)
      return .RuntimeResult~failure("MODULE_NOT_ACTIVE", moduleId)
    end
    generation = generations~at(slot~activeGenerationId)
    if generation == .nil then do
      cleanupResult = self~releaseLeaseTable(leases)
      return .RuntimeResult~failure("GENERATION_NOT_FOUND", slot~activeGenerationId)
    end
    leaseResult = generation~acquireLease
    if \leaseResult~ok then do
      cleanupResult = self~releaseLeaseTable(leases)
      return leaseResult
    end
    leases~put(leaseResult~value, moduleId)
  end

  return .RuntimeResult~success(.RuntimeSnapshot~new(environment, leases), "snapshot acquired")

::method collectRetired
  expose generations
  guard on
  changed = .array~new
  do generationId over generations
    generation = generations~at(generationId)
    oldState = generation~state
    checkResult = generation~retireIfDrained
    if generation~state <> oldState then changed~append(generationId || ":" || generation~state)
  end
  return .RuntimeResult~success(changed, "drained generations collected")

::method releaseGeneration
  expose generations environments
  use arg generationId
  guard on
  generationId = generationId~string
  generation = generations~at(generationId)
  if generation == .nil then return .RuntimeResult~failure("GENERATION_NOT_FOUND", generationId)

  envTable = environments~at(generation~environment)
  if envTable \== .nil then do
    slot = envTable~at(generation~moduleId)
    if slot \== .nil then do
      if slot~activeGenerationId = generationId then return .RuntimeResult~failure("GENERATION_ACTIVE", "Cannot release active generation")
    end
  end

  if generation~state = "DRAINING" then do
    retireResult = generation~retireIfDrained
    if generation~state = "DRAINING" then return .RuntimeResult~failure("GENERATION_BUSY", "Generation still has " || generation~leaseCount || " leases")
  end

  releaseResult = generation~releaseObjects
  if releaseResult~ok then return .RuntimeResult~success(generation~view, releaseResult~detail)
  return .RuntimeResult~failure(releaseResult~code, releaseResult~detail, generation~view)

::method generation
  expose generations
  use arg generationId
  guard on
  generation = generations~at(generationId~string)
  if generation == .nil then return .nil
  return generation~view

::method activeGeneration
  expose generations environments
  use arg environment, moduleId
  guard on
  environment = environment~string~strip~lower
  envTable = environments~at(environment)
  if envTable == .nil then return .nil
  slot = envTable~at(moduleId~string)
  if slot == .nil then return .nil
  if slot~activeGenerationId = "" then return .nil
  generation = generations~at(slot~activeGenerationId)
  if generation == .nil then return .nil
  return generation~view

::method activeGenerationId
  generation = self~activeGeneration(arg(1), arg(2))
  if generation == .nil then return ""
  return generation~generationId

::method environmentModuleIds
  expose environments
  use arg environment
  guard on
  environment = environment~string~strip~lower
  envTable = environments~at(environment)
  ids = .array~new
  if envTable == .nil then return ids
  do moduleId over envTable
    slot = envTable~at(moduleId)
    if slot~activeGenerationId <> "" then ids~append(moduleId)
  end
  return ids

::method activeBindings
  expose environments
  use arg environment
  guard on
  environment = environment~string~strip~lower
  resultBindings = .table~new
  envTable = environments~at(environment)
  if envTable == .nil then return resultBindings
  do moduleId over envTable
    slot = envTable~at(moduleId)
    if slot~activeGenerationId <> "" then resultBindings~put(slot~activeGenerationId, moduleId)
  end
  return resultBindings

::method generationDescriptors
  expose generations
  use arg environment = "", moduleId = ""
  guard on
  environment = environment~string~strip~lower
  moduleId = moduleId~string
  rows = .array~new
  do generationId over generations
    generation = generations~at(generationId)
    include = .true
    if environment <> "" then do
      if generation~environment <> environment then include = .false
    end
    if include then do
      if moduleId <> "" then do
        if generation~moduleId <> moduleId then include = .false
      end
    end
    if include then rows~append(generation~descriptor)
  end
  return rows

::method acquireDependencySnapshot private
  use arg environment, manifest
  dependencies = manifest~dependencies
  if dependencies~items = 0 then return .RuntimeResult~success(.RuntimeSnapshot~new(environment, .table~new), "no dependencies")

  moduleIds = .array~new
  do i = 1 to dependencies~items
    moduleIds~append(dependencies~at(i)~moduleId)
  end

  /* RuntimeRegistry~snapshot is guarded, so all active dependency pointers are
   * captured as one coherent registry view before validation below. */
  snapshotResult = self~snapshot(environment, moduleIds)
  if \snapshotResult~ok then return .RuntimeResult~failure("DEPENDENCY_NOT_ACTIVE", snapshotResult~detail)
  dependencySnapshot = snapshotResult~value

  do i = 1 to dependencies~items
    dependency = dependencies~at(i)
    moduleId = dependency~moduleId
    lease = dependencySnapshot~lease(moduleId)
    if lease == .nil then do
      cleanupResult = dependencySnapshot~release
      return .RuntimeResult~failure("DEPENDENCY_NOT_ACTIVE", moduleId)
    end
    if dependency~apiVersion <> "" then do
      if lease~apiVersion <> dependency~apiVersion then do
        cleanupResult = dependencySnapshot~release
        return .RuntimeResult~failure("DEPENDENCY_API_MISMATCH", moduleId || " requires " || dependency~apiVersion || " but active is " || lease~apiVersion)
      end
    end
    if dependency~artifactId <> "" then do
      if lease~artifactId <> dependency~artifactId then do
        cleanupResult = dependencySnapshot~release
        return .RuntimeResult~failure("DEPENDENCY_ARTIFACT_MISMATCH", moduleId || " requires " || dependency~artifactId || " but active is " || lease~artifactId)
      end
    end
  end

  return .RuntimeResult~success(dependencySnapshot, "dependencies pinned")

::method allocateGenerationId private
  expose nextGenerationNumber
  guard on
  nextGenerationNumber = nextGenerationNumber + 1
  return "g" || right(nextGenerationNumber~string, 9, "0")

::method registerGeneration private
  expose generations
  use arg generation
  guard on
  generations~put(generation, generation~generationId)
  return .RuntimeResult~success(generation, "generation registered")

::method environmentTable private
  expose environments
  use arg environment
  envTable = environments~at(environment)
  if envTable == .nil then do
    envTable = .table~new
    environments~put(envTable, environment)
  end
  return envTable

::method releaseLeaseTable private
  use arg leases
  do moduleId over leases
    lease = leases~at(moduleId)
    releaseResult = lease~release
  end
  return .true

::method conditionMessage private
  use arg conditionObject
  if conditionObject == .nil then return "unknown ooRexx condition"
  message = conditionObject["MESSAGE"]
  code = conditionObject["CODE"]
  if message == .nil then message = "ooRexx condition"
  if code == .nil then return message~string
  return code~string || ": " || message~string

::class RuntimeSourceLoader public

::method readFile class
  use arg path
  path = path~string
  stream = .Stream~new(path)
  signal on syntax name readError
  openResult = stream~open("read")
  signal off syntax
  if openResult <> "READY:" then return .RuntimeResult~failure("SOURCE_OPEN_FAILED", path || ": " || openResult)

  sourceLines = .array~new
  signal on syntax name lineError
  do while stream~lines > 0
    sourceLines~append(stream~lineIn)
  end
  closeResult = stream~close
  signal off syntax
  return .RuntimeResult~success(sourceLines, path)

readError:
  conditionObject = condition("O")
  return .RuntimeResult~failure("SOURCE_OPEN_EXCEPTION", self~conditionMessage(conditionObject))

lineError:
  conditionObject = condition("O")
  closeResult = stream~close
  return .RuntimeResult~failure("SOURCE_READ_EXCEPTION", self~conditionMessage(conditionObject))

::method conditionMessage private class
  use arg conditionObject
  if conditionObject == .nil then return "unknown ooRexx condition"
  message = conditionObject["MESSAGE"]
  code = conditionObject["CODE"]
  if message == .nil then message = "ooRexx condition"
  if code == .nil then return message~string
  return code~string || ": " || message~string

::class RuntimeManifestParser public

::method parseLines class
  use arg lines
  if lines == .nil then return .RuntimeResult~failure("MANIFEST_EMPTY", "Manifest lines must not be .nil")
  if lines~items = 0 then return .RuntimeResult~failure("MANIFEST_EMPTY", "Manifest is empty")
  if lines~at(1)~string~strip <> "RUNTIME-MANIFEST/1" then return .RuntimeResult~failure("MANIFEST_VERSION_UNSUPPORTED", lines~at(1)~string)

  singleton = .table~new
  environments = .array~new
  dependencies = .array~new
  dependencyModules = .table~new
  allowed = " module-id module-kind version artifact-id entry-class api-version signer-id source-sha512 signature-ed25519 "

  do i = 2 to lines~items
    line = lines~at(i)~string
    if line~strip = "" then iterate
    colon = pos(":", line)
    if colon = 0 then return .RuntimeResult~failure("MANIFEST_LINE_INVALID", "line " || i || " has no ':'")
    key = left(line, colon - 1)~strip~lower
    value = substr(line, colon + 1)~strip

    if key = "environment" then do
      if value = "" then return .RuntimeResult~failure("MANIFEST_ENVIRONMENT_INVALID", "line " || i)
      environments~append(value~lower)
      iterate
    end

    if key = "dependency" then do
      firstBar = pos("|", value)
      if firstBar = 0 then return .RuntimeResult~failure("MANIFEST_DEPENDENCY_INVALID", "line " || i || " requires module|api|artifact")
      rest = substr(value, firstBar + 1)
      secondRelative = pos("|", rest)
      if secondRelative = 0 then return .RuntimeResult~failure("MANIFEST_DEPENDENCY_INVALID", "line " || i || " requires module|api|artifact")
      depModule = left(value, firstBar - 1)~strip
      depApi = left(rest, secondRelative - 1)~strip
      depArtifact = substr(rest, secondRelative + 1)~strip
      if depModule = "" then return .RuntimeResult~failure("MANIFEST_DEPENDENCY_INVALID", "line " || i || " has empty module id")
      if dependencyModules~at(depModule) \== .nil then return .RuntimeResult~failure("MANIFEST_DEPENDENCY_DUPLICATE", depModule)
      dependencyModules~put(.true, depModule)
      dependencies~append(.RuntimeDependency~new(depModule, depApi, depArtifact))
      iterate
    end

    if pos(" " || key || " ", allowed) = 0 then return .RuntimeResult~failure("MANIFEST_FIELD_UNKNOWN", key)
    if singleton~at(key) \== .nil then return .RuntimeResult~failure("MANIFEST_FIELD_DUPLICATE", key)
    singleton~put(value, key)
  end

  required = .array~of("module-id", "module-kind", "version", "artifact-id", "entry-class", "api-version")
  do i = 1 to required~items
    key = required~at(i)
    value = singleton~at(key)
    if value == .nil then return .RuntimeResult~failure("MANIFEST_FIELD_MISSING", key)
    if value~strip = "" then return .RuntimeResult~failure("MANIFEST_FIELD_EMPTY", key)
  end

  signerId = singleton~at("signer-id"); if signerId == .nil then signerId = ""
  sourceSha512 = singleton~at("source-sha512"); if sourceSha512 == .nil then sourceSha512 = ""
  signature = singleton~at("signature-ed25519"); if signature == .nil then signature = ""

  manifest = .RuntimeManifest~new(singleton~at("module-id"), singleton~at("module-kind"), singleton~at("version"), singleton~at("artifact-id"), singleton~at("entry-class"), dependencies, environments, singleton~at("api-version"), signerId, sourceSha512, signature)
  return .RuntimeResult~success(manifest, "manifest parsed")

::class RuntimeManifestLoader public

::method readFile class
  use arg path
  readResult = .RuntimeSourceLoader~readFile(path)
  if \readResult~ok then return readResult
  return .RuntimeManifestParser~parseLines(readResult~value)

::class RuntimeArtifactFactory public

::method fromFiles class
  use arg manifestPath, sourcePath
  manifestResult = .RuntimeManifestLoader~readFile(manifestPath)
  if \manifestResult~ok then return manifestResult
  sourceResult = .RuntimeSourceLoader~readFile(sourcePath)
  if \sourceResult~ok then return sourceResult
  artifact = .RuntimeArtifact~new(manifestResult~value, sourceResult~value, sourcePath)
  return .RuntimeResult~success(artifact, "manifest + artifact source loaded")

::method fromFile class
  use arg moduleId, moduleKind, version, artifactId, entryClass, sourcePath, apiVersion = "runtime.module/0.2"
  readResult = .RuntimeSourceLoader~readFile(sourcePath)
  if \readResult~ok then return readResult
  artifact = .RuntimeArtifact~new(moduleId, moduleKind, version, artifactId, entryClass, readResult~value, apiVersion, sourcePath)
  return .RuntimeResult~success(artifact, "artifact source loaded")

::class RuntimeKernel public
::attribute registry get

::method init
  expose registry
  use arg verifier
  registry = .RuntimeRegistry~new(verifier)

::method stage
  expose registry
  forward to (registry)

::method activate
  expose registry
  forward to (registry)

::method acquire
  expose registry
  forward to (registry)

::method snapshot
  expose registry
  forward to (registry)

::method collectRetired
  expose registry
  forward to (registry)

::method releaseGeneration
  expose registry
  forward to (registry)
