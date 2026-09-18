/*
 * TerminalAlchemy.cls - Alchemy Objects integration for Terminal Machine v0.19.
 *
 * Stateful terminal/service objects inherit this base. Detached evidence/value
 * objects deliberately remain plain terminal objects: inheriting lifecycle
 * telemetry would make an immutable snapshot mutable merely by observing it.
 *
 * IMPORTANT: Alchemy FULL introspection emits registered object variables by
 * reference. Terminal subclasses therefore register only scalar/value state.
 * Live mutable objects, authority capabilities, secret-capable runtimes,
 * transports, reservations and internal collections remain unregistered and
 * are represented through bounded scalar state, explicit detached methods or
 * relationship/instrumentation evidence instead.
 *
 * Alchemy Objects v0.8 construction rule:
 *   descendants enter AlchemyObject through self~init:super(...), not the
 *   compatibility initAlchemy(...) path.  initTerminalAlchemy() centralises
 *   the STANDARD-adoption metadata used by all Terminal Machine stateful
 *   objects while preserving class-specific purpose and supplemental metadata.
 */

::class TerminalAlchemyObject subclass AlchemyObject public
::constant VERSION "0.19"
::constant COMPONENT "oorexx_terminal_machine"
::constant ALCHEMY_BASE "alchemy_objects_v0.8"

::method initTerminalAlchemy public
  use arg purposeArg, metadataArg = .nil, sealerArg = .nil, capabilityAuthorityArg = .nil
  metadata = .directory~new
  metadata["purpose"] = purposeArg~string
  metadata["package"] = self~COMPONENT
  metadata["component"] = self~COMPONENT
  metadata["package_version"] = self~VERSION
  metadata["alchemy_base"] = self~ALCHEMY_BASE
  metadata["authorship"] = .array~of("The Architect", "OpenAI implementation")
  metadata["standards"] = .array~of("ALCHEMY_OBJECTS_0_8", "TERMINAL_ONE_WRITER_MANY_READERS", "TERMINAL_SECRET_BOUNDARY")
  metadata["design_limitations"] = .array~of("Alchemy registered state is scalar/value evidence only; live authority and mutable implementation references remain unregistered")
  if metadataArg \== .nil then do
    if \metadataArg~isA(.Directory) & \metadataArg~isA(.Table) then raise syntax 88.900 array("Terminal Alchemy metadata must be Directory/Table")
    do key over metadataArg~allIndexes
      metadata[key~string] = metadataArg~at(key)
    end
  end

  /* Preferred v0.8 non-virtual base construction path. */
  self~init:super(metadata, sealerArg, capabilityAuthorityArg)
  self~registerExternalRequirement("library", "alchemy_objects", "0.8", .true)
  self~registerInstrumentationPoint("TERMINAL.LIFECYCLE", "terminal object lifecycle state transition", .true, "ALL", "CUSTOMER")
  self~registerInstrumentationPoint("TERMINAL.AUTHORITY", "terminal authority/control transition", .true, "ALL", "INTERNAL")
  self~registerInstrumentationPoint("TERMINAL.OBSERVATION", "terminal observation/state publication", .true, "COLLAPSE", "CUSTOMER")
  return self

::method terminalLifecycleEvent public protected
  use arg stateArg, detailArg = ""
  evidence = .directory~new
  evidence["state"] = stateArg~string
  if detailArg~string \= "" then evidence["detail"] = detailArg~string
  return self~alchemyInstrument("TERMINAL.LIFECYCLE", evidence)

::method terminalAuthorityEvent public protected
  use arg actionArg, subjectArg = "", detailArg = ""
  evidence = .directory~new
  evidence["action"] = actionArg~string
  if subjectArg~string \= "" then evidence["subject"] = subjectArg~string
  if detailArg~string \= "" then evidence["detail"] = detailArg~string
  return self~alchemyInstrument("TERMINAL.AUTHORITY", evidence)

::method terminalObservationEvent public protected
  use arg generationArg = 0, detailArg = ""
  evidence = .directory~new
  evidence["generation"] = generationArg
  if detailArg~string \= "" then evidence["detail"] = detailArg~string
  return self~alchemyInstrument("TERMINAL.OBSERVATION", evidence)

::requires "AlchemyObject.cls"
