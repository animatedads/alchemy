/* AlchemyAdoption.cls - Alchemy Objects v0.8 inheritance/adoption verifier. */

::class AlchemyAdoptionResult public
::attribute ok get
::attribute level get
::attribute failures get
::attribute warnings get
::attribute evidence get

::method init
  expose ok level failures warnings evidence
  use strict arg ok, level, failures, warnings, evidence
  ok = ok
  level = level~string~translate
  failures = failures
  warnings = warnings
  evidence = evidence

::method toDirectory public
  expose ok level failures warnings evidence
  d = .directory~new
  d["schema"] = "alchemy.objects.adoption-result/0.1"
  d["ok"] = ok
  d["level"] = level
  d["failures"] = failures
  d["warnings"] = warnings
  d["evidence"] = evidence
  return d


::class AlchemyAdoptionCheckpoint public
::attribute schema get
::attribute objectId get
::attribute targetClass get
::attribute level get
::attribute capturedAt get
::attribute baseVersion get
::attribute integrityFingerprint get
::attribute constructionFingerprint get

::method init
  expose schema objectId targetClass level capturedAt baseVersion integrityFingerprint constructionFingerprint
  use strict arg objectId, targetClass, level, baseVersion, integrityFingerprint, constructionFingerprint
  schema = "alchemy.objects.adoption-checkpoint/0.1"
  objectId = objectId~string
  targetClass = targetClass~string
  level = level~string~translate
  capturedAt = date("S") || "T" || time("L")
  baseVersion = baseVersion~string
  integrityFingerprint = integrityFingerprint~string
  constructionFingerprint = constructionFingerprint~string

::method toDirectory public
  expose schema objectId targetClass level capturedAt baseVersion integrityFingerprint constructionFingerprint
  d = .directory~new
  d["schema"] = schema
  d["object_id"] = objectId
  d["target_class"] = targetClass
  d["level"] = level
  d["captured_at"] = capturedAt
  d["base_version"] = baseVersion
  d["integrity_fingerprint"] = integrityFingerprint
  d["construction_fingerprint"] = constructionFingerprint
  return d


::class AlchemyAdoptionVerifier public

::method contract class public
  d = .directory~new
  d["schema"] = "alchemy.objects.adoption-contract/0.2"
  d["base_class"] = "ALCHEMYOBJECT"
  d["base_version"] = .AlchemyObject~VERSION
  d["levels"] = .array~of("BASE", "STANDARD", "SECURE_READY")
  d["reserved_surface_rule"] = "Descendants may override INIT and may define business VERSION/SCHEMA; other non-private AlchemyObject surface names are reserved. Use INIT:SUPER for construction."
  d["standard_metadata"] = .array~of("PURPOSE", "PACKAGE", "PACKAGE_VERSION", "AUTHORSHIP", "STANDARDS", "DESIGN_LIMITATIONS")
  d["secure_ready_requirements"] = .array~of("EVIDENCE_SEALER", "CAPABILITY_AUTHORITY", "OBSERVED_SECURITY_RUNTIME")
  d["checkpoint_schema"] = "alchemy.objects.adoption-checkpoint/0.1"
  d["checkpoint_rule"] = "Admission checkpoints bind object identity, base version, construction provenance, and reserved-surface integrity at one instant. Later comparison detects drift; checkpoints are evidence, not authority."
  return d

::method verify class public
  use strict arg target, level = "STANDARD"
  level = level~string~translate
  if level \= "BASE" & level \= "STANDARD" & level \= "SECURE_READY" then raise syntax 88.900 array("Alchemy adoption level must be BASE, STANDARD, or SECURE_READY")

  failures = .array~new
  warnings = .array~new
  evidence = .directory~new
  evidence["schema"] = "alchemy.objects.adoption-verification/0.1"
  evidence["requested_level"] = level
  evidence["base_version"] = .AlchemyObject~VERSION

  if target == .nil then do
    self~addFailure(failures, "TARGET_NIL", "Target object is .nil")
    return .AlchemyAdoptionResult~new(.false, level, failures, warnings, evidence)
  end

  evidence["target_class"] = target~class~id
  if \target~isA(.AlchemyObject) then do
    self~addFailure(failures, "NOT_ALCHEMY_OBJECT", "Target does not inherit AlchemyObject")
    return .AlchemyAdoptionResult~new(.false, level, failures, warnings, evidence)
  end

  emptyArgs = .array~new
  baseState = target~sendWith(.array~of("ALCHEMYBASESTATE", .AlchemyObject), emptyArgs)
  evidence["base_state"] = baseState
  if baseState["initialized"] \= .true then self~addFailure(failures, "BASE_NOT_INITIALIZED", "AlchemyObject initialization did not run")
  construction = target~sendWith(.array~of("ALCHEMYCONSTRUCTIONPROVENANCE", .AlchemyObject), emptyArgs)
  evidence["construction_provenance"] = construction
  if construction["completed"] \= .true then self~addFailure(failures, "BASE_CONSTRUCTION_INCOMPLETE", "AlchemyObject construction provenance is incomplete", construction)
  if construction["entrypoint"] = "INITALCHEMY" then self~addWarning(warnings, "LEGACY_INIT_ENTRYPOINT", "Object entered the base through compatibility initAlchemy(); new descendants should use self~init:super(...)")

  integrity = target~sendWith(.array~of("ALCHEMYINHERITANCEINTEGRITY", .AlchemyObject), emptyArgs)
  evidence["inheritance_integrity"] = integrity
  if integrity["inherits_alchemy_object"] \= .true then self~addFailure(failures, "BASE_NOT_IN_LINEAGE", "AlchemyObject was not found in the class lineage")
  if integrity["reserved_override_count"] > 0 then self~addFailure(failures, "RESERVED_SURFACE_OVERRIDE", integrity["reserved_override_count"] || " reserved AlchemyObject surface(s) are shadowed", integrity["violations"])

  if baseState["initialized"] == .true then do
    surface = target~sendWith(.array~of("CHECKSURFACECONTRACT", .AlchemyObject), emptyArgs)
    surfaceEvidence = .directory~new
    surfaceEvidence["ok"] = surface~ok
    surfaceEvidence["code"] = surface~code
    surfaceEvidence["message"] = surface~message
    surfaceEvidence["evidence"] = surface~evidence
    evidence["surface_contract"] = surfaceEvidence
    if surface~ok \= .true then self~addFailure(failures, "SURFACE_CONTRACT_FAIL", surface~message, surface~evidence)
  end

  if level = "STANDARD" | level = "SECURE_READY" then do
    if baseState["initialized"] == .true then self~checkStandardMetadata(baseState["metadata"], failures, warnings)
  end

  if level = "SECURE_READY" then do
    if baseState["initialized"] == .true then do
      if baseState["sealer_configured"] \= .true then self~addFailure(failures, "SEALER_NOT_CONFIGURED", "No Alchemy evidence sealer is configured")
      if baseState["capability_authority_configured"] \= .true then self~addFailure(failures, "CAPABILITY_AUTHORITY_NOT_CONFIGURED", "No Alchemy capability authority is configured")
    end
    runtime = .AlchemySecurityRuntimeProfile~current~evidence
    evidence["security_runtime"] = runtime
    if runtime["observed"] \= .true then self~addFailure(failures, "SECURITY_RUNTIME_UNVERIFIED", "Live ooRexx Security Manager semantics probe did not verify this runtime", runtime)
  end

  ok = failures~items = 0
  return .AlchemyAdoptionResult~new(ok, level, failures, warnings, evidence)

::method checkpoint class public
  use strict arg target, level = "BASE"
  verification = self~verify(target, level)
  if verification~ok \= .true then raise syntax 88.900 array("Cannot create Alchemy adoption checkpoint for a target that fails " || level~string~translate || " verification")
  integrity = verification~evidence["inheritance_integrity"]
  construction = verification~evidence["construction_provenance"]
  constructionFingerprint = self~constructionFingerprint(construction)
  return .AlchemyAdoptionCheckpoint~new(verification~evidence["base_state"]["object_id"], verification~evidence["target_class"], level, verification~evidence["base_version"], integrity["fingerprint"], constructionFingerprint)

::method sealedCheckpoint class public
  use strict arg target, level, sealer
  if sealer == .nil then raise syntax 88.900 array("Alchemy adoption checkpoint sealer must not be .nil")
  cp = self~checkpoint(target, level)
  return sealer~seal(cp~objectId || ":adoption", cp~toDirectory)

::method compareCheckpoint class public
  use strict arg target, checkpoint
  failures = .array~new
  warnings = .array~new
  evidence = .directory~new
  if checkpoint == .nil then do
    self~addFailure(failures, "CHECKPOINT_MISSING", "Alchemy adoption checkpoint is .nil")
    return .AlchemyAdoptionResult~new(.false, "BASE", failures, warnings, evidence)
  end
  if checkpoint~isA(.AlchemyAdoptionCheckpoint) then cp = checkpoint~toDirectory
  else if checkpoint~isA(.Directory) | checkpoint~isA(.Table) then cp = checkpoint
  else do
    self~addFailure(failures, "CHECKPOINT_TYPE_INVALID", "Alchemy adoption checkpoint must be AlchemyAdoptionCheckpoint or Directory/Table")
    return .AlchemyAdoptionResult~new(.false, "BASE", failures, warnings, evidence)
  end
  evidence["checkpoint"] = cp
  if cp["schema"] \= "alchemy.objects.adoption-checkpoint/0.1" then do
    self~addFailure(failures, "CHECKPOINT_SCHEMA_INVALID", "Checkpoint schema is not alchemy.objects.adoption-checkpoint/0.1")
    return .AlchemyAdoptionResult~new(.false, "BASE", failures, warnings, evidence)
  end
  level = cp["level"]~string~translate
  if level \= "BASE" & level \= "STANDARD" & level \= "SECURE_READY" then do
    self~addFailure(failures, "CHECKPOINT_LEVEL_INVALID", "Checkpoint readiness level is invalid")
    return .AlchemyAdoptionResult~new(.false, "BASE", failures, warnings, evidence)
  end
  required = .array~of("object_id", "target_class", "base_version", "integrity_fingerprint", "construction_fingerprint")
  do requiredName over required
    if \cp~hasIndex(requiredName) then do
      self~addFailure(failures, "CHECKPOINT_FIELD_MISSING", "Checkpoint field is missing: " || requiredName, requiredName)
      return .AlchemyAdoptionResult~new(.false, level, failures, warnings, evidence)
    end
  end

  current = self~verify(target, level)
  failures = current~failures
  warnings = current~warnings
  evidence = current~evidence
  evidence["checkpoint"] = cp

  if target \== .nil then if target~isA(.AlchemyObject) then do
    baseState = target~sendWith(.array~of("ALCHEMYBASESTATE", .AlchemyObject), .array~new)
    if cp["object_id"] \= baseState["object_id"] then self~addFailure(failures, "CHECKPOINT_OBJECT_MISMATCH", "Checkpoint belongs to a different Alchemy object")
    if cp["target_class"] \= baseState["class"] then self~addFailure(failures, "CHECKPOINT_CLASS_MISMATCH", "Checkpoint target class differs from the current object class")
    if cp["base_version"] \= .AlchemyObject~VERSION then self~addFailure(failures, "CHECKPOINT_BASE_VERSION_MISMATCH", "Checkpoint base version differs from the current AlchemyObject base")
    integrity = target~sendWith(.array~of("ALCHEMYINHERITANCEINTEGRITY", .AlchemyObject), .array~new)
    if cp["integrity_fingerprint"] \= integrity["fingerprint"] then self~addFailure(failures, "ADMISSION_DRIFT", "Reserved Alchemy surface differs from the admitted checkpoint", integrity)
    construction = target~sendWith(.array~of("ALCHEMYCONSTRUCTIONPROVENANCE", .AlchemyObject), .array~new)
    currentConstructionFingerprint = self~constructionFingerprint(construction)
    if cp["construction_fingerprint"] \= currentConstructionFingerprint then self~addFailure(failures, "CONSTRUCTION_PROVENANCE_DRIFT", "Construction provenance differs from the admitted checkpoint", construction)
  end
  evidence["checkpoint_match"] = failures~items = 0
  return .AlchemyAdoptionResult~new(failures~items = 0, level, failures, warnings, evidence)

::method compareSealedCheckpoint class public
  use strict arg target, envelope, sealer
  if sealer == .nil then raise syntax 88.900 array("Alchemy adoption checkpoint sealer must not be .nil")
  failures = .array~new
  warnings = .array~new
  evidence = .directory~new
  if \sealer~verify(envelope) then do
    self~addFailure(failures, "CHECKPOINT_SEAL_INVALID", "Cryptographic adoption checkpoint verification failed")
    return .AlchemyAdoptionResult~new(.false, "BASE", failures, warnings, evidence)
  end
  payload = envelope~payload
  if \payload~isA(.Directory) & \payload~isA(.Table) then do
    self~addFailure(failures, "CHECKPOINT_PAYLOAD_INVALID", "Sealed checkpoint payload is not Directory/Table")
    return .AlchemyAdoptionResult~new(.false, "BASE", failures, warnings, evidence)
  end
  if payload["schema"] \= "alchemy.objects.adoption-checkpoint/0.1" then do
    self~addFailure(failures, "CHECKPOINT_SCHEMA_INVALID", "Sealed payload is not an Alchemy adoption checkpoint")
    return .AlchemyAdoptionResult~new(.false, "BASE", failures, warnings, evidence)
  end
  expectedProducer = payload["object_id"] || ":adoption"
  if envelope~producer \= expectedProducer then do
    self~addFailure(failures, "CHECKPOINT_PURPOSE_INVALID", "Sealed checkpoint producer/purpose binding is invalid")
    return .AlchemyAdoptionResult~new(.false, payload["level"], failures, warnings, evidence)
  end
  return self~compareCheckpoint(target, payload)

::method constructionFingerprint class private
  use strict arg construction
  stable = .directory~new
  keys = .array~of("schema", "entrypoint", "started_at", "completed", "completed_at", "receiver_class", "receiver_package", "base_class", "base_version", "identity_hash", "initial_integrity_ok", "initial_reserved_override_count", "initial_integrity_fingerprint")
  do key over keys
    if construction~hasIndex(key) then stable[key] = construction[key]
  end
  return .AlchemyCanonical~encode(stable)

::method checkStandardMetadata class private
  use strict arg metadata, failures, warnings
  required = .array~of("PURPOSE", "PACKAGE", "PACKAGE_VERSION", "AUTHORSHIP", "STANDARDS", "DESIGN_LIMITATIONS")
  do key over required
    if \metadata~hasIndex(key) then do
      self~addFailure(failures, "METADATA_MISSING", "Required adoption metadata is missing: " || key, key)
      iterate
    end
    value = metadata~at(key)
    if value == .nil then do
      self~addFailure(failures, "METADATA_EMPTY", "Required adoption metadata is .nil: " || key, key)
      iterate
    end
    if value~isA(.String) then if value~strip = "" then self~addFailure(failures, "METADATA_EMPTY", "Required adoption metadata is empty: " || key, key)
  end
  purpose = metadata~at("PURPOSE")
  if purpose \== .nil then if purpose~isA(.String) then if purpose = "Alchemy-derived object" then self~addFailure(failures, "PURPOSE_GENERIC", "STANDARD adoption requires a class/package-specific purpose")
  return .true

::method addFailure class private
  use strict arg failures, code, message, detail = .nil
  rec = .directory~new
  rec["code"] = code~string~translate
  rec["message"] = message~string
  if detail \== .nil then rec["detail"] = detail
  failures~append(rec)
  return rec

::method addWarning class private
  use strict arg warnings, code, message, detail = .nil
  rec = .directory~new
  rec["code"] = code~string~translate
  rec["message"] = message~string
  if detail \== .nil then rec["detail"] = detail
  warnings~append(rec)
  return rec

::requires "AlchemyObject.cls"
