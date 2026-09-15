/*
 * RYTAObject.cls
 *
 * RYTA-owned house base over Alchemy Objects v0.8.
 *
 * The base supplies identity, construction/execution provenance, lifecycle and
 * usage telemetry, declared contracts, disclosure-bounded state descriptions,
 * requirement evidence, instrumentation, Security Manager semantics and sealed
 * introspection when a host supplies the corresponding evidence/security
 * services. None of those facilities confer HardWorld, Legal Effect or
 * EvidencePromotion authority.
 */

::class RYTAObject subclass AlchemyObject public
::constant RYTA_COMPONENT "virtual_ryta_hardworld"
::constant RYTA_VERSION "0.31-work"

::method init public
  use strict arg objectKind = "RYTAObject", authorityRole = "RYTA_OBJECT", options = .nil

  metadata = .directory~new
  metadata["COMPONENT"] = .RYTAObject~RYTA_COMPONENT
  metadata["COMPONENT_VERSION"] = .RYTAObject~RYTA_VERSION
  metadata["OBJECT_KIND"] = objectKind~string
  metadata["AUTHORITY_ROLE"] = authorityRole~string~translate
  metadata["AUTHORITY_NOTE"] = "Alchemy object identity/introspection/execution provenance is evidence, not decision authority"

  /* Alchemy Objects v0.8 STANDARD adoption metadata. */
  metadata["PURPOSE"] = "Deterministic RYTA/HardWorld evidence, decision and explicit authority-use infrastructure"
  metadata["PACKAGE"] = .RYTAObject~RYTA_COMPONENT
  metadata["PACKAGE_VERSION"] = .RYTAObject~RYTA_VERSION
  metadata["AUTHORSHIP"] = "The Architect + implementation assistants"
  metadata["STANDARDS"] = "ALCHEMY-HOUSE-OBJECT-0.8; RYTA evidence != fact != authority"
  metadata["DESIGN_LIMITATIONS"] = "Alchemy observability/security infrastructure does not confer HardWorld, Legal Effect or promotion authority; hot scalar/value records remain lightweight"

  sealer = .nil
  capabilityAuthority = .nil
  if options \== .nil then do
    if \options~isA(.Directory) & \options~isA(.Table) then raise syntax 88.900 array("RYTA Alchemy options must be a Directory/Table")
    candidate = options~at("SEALER")
    if candidate \== .nil then sealer = candidate
    candidate = options~at("CAPABILITY_AUTHORITY")
    if candidate \== .nil then capabilityAuthority = candidate
  end

  /* Preferred v0.8 construction chain: enter AlchemyObject through INIT rather
     than the pre-v0.5 initAlchemy compatibility path. */
  forward class (super) array (metadata, sealer, capabilityAuthority) continue

  self~registerExternalRequirement("library", "alchemy_objects", "v0.8", .true)
  self~registerInstrumentationPoint("RYTA.AUTHORITY.BEFORE", "before a RYTA-owned authority-use boundary", .true, "ALL", "INTERNAL")
  self~registerInstrumentationPoint("RYTA.AUTHORITY.AFTER", "after a RYTA-owned authority-use boundary", .true, "ALL", "INTERNAL")
  self~registerInstrumentationPoint("RYTA.AUTHORITY.REFUSED", "authority-use boundary refused or failed closed", .true, "ALL", "INTERNAL")
  return self

/* Compatibility message for older downstream RYTA subclasses. New RYTA-owned
   descendants use self~init:super(...), which preserves INIT construction
   provenance. The scoped send avoids redispatch into a descendant INIT. */
::method rytaInitAlchemy public protected
  use strict arg objectKind, authorityRole = "NONE", options = .nil
  return self~sendWith(.array~of("INIT", .RYTAObject), .array~of(objectKind, authorityRole, options))

::method rytaRegisterAuthorityMethod public protected
  use strict arg methodName, purpose, sideEffects = "UNKNOWN"
  self~registerMethodContract(methodName, purpose, .array~new, "ANY", .false, "AUTO", "CUSTOMER", "SENSITIVE", sideEffects, "USE")
  return self

::requires "AlchemyObject.cls"
