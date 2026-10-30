/*
 * Legal Interrogation -> Intention Service v0.1-dev11 dynamic discovery adapter.
 *
 * This file uses only the public dev11 discovery types observed in the current
 * Library: IntentionDiscoverySnapshot, IntentionSurfaceAdvertisement and
 * IntentionService~registerDiscoveryProvider().  It does not vendor or clone
 * Intention Service, and it does not turn discovery into legal authority.
 */

::class LegalInterrogationDev11SurfaceSubject public
::attribute session
::attribute sessionId
::attribute sessionRevision
::attribute discoveryGeneration
::attribute intentionName
::attribute subjectRef
::attribute reason
::attribute priority
::attribute queryOnly

::method init
  use strict arg session, sessionRevision, discoveryGeneration, intention, queryOnly = .false
  self~session = session
  self~sessionId = session~id
  self~sessionRevision = sessionRevision
  self~discoveryGeneration = discoveryGeneration
  self~intentionName = intention~name
  self~subjectRef = intention~subjectRef
  self~reason = intention~reason
  self~priority = intention~priority
  self~queryOnly = queryOnly

::method stale
  return self~session~revision \== self~sessionRevision


::class LegalInterrogationDev11SurfaceProvider public
::attribute port
::attribute subject

::method init
  use strict arg port, subject
  self~port = port
  self~subject = subject

/*
 * A surface advertisement is a live specialist capability description, not a
 * general NLP engine.  Intention Service remains free to use its configured
 * providers/controller to turn user language into a READY decision.
 */
::method propose
  use arg service, text
  return .array~new

/*
 * Execute only after the host Intention controller has produced a READY
 * decision for this exact advertised operation.  The caller supplies the
 * structured legal-authoring payload; this adapter never invents one from prose.
 */
::method executeReady
  use strict arg decision, payload = .nil, actor = ""
  if decision == .nil then return .LegalInterrogationResult~failure("INTENTION_DECISION_REQUIRED", self~subject~intentionName)
  if \decision~hasMethod("STATUS") then return .LegalInterrogationResult~failure("BAD_INTENTION_DECISION", "READY status is required")
  if decision~status \== "READY" then return .LegalInterrogationResult~failure("INTENTION_NOT_READY", decision~status)
  if self~subject~stale then return .LegalInterrogationResult~failure("STALE_DISCOVERY", "Legal interrogation changed after this intention surface was discovered")
  return self~port~execute(self~subject~session, self~subject~intentionName, payload, actor, self~subject~subjectRef)

::method current
  return \self~subject~stale


::class LegalInterrogationDev11DiscoveryProvider public
::attribute port
::attribute session
::attribute providerId

::method init
  use strict arg port, session, providerId = "LEGAL_INTERROGATION"
  if port == .nil | \port~isA(.LegalInterrogationIntentionPort) then raise syntax 93.900 array("LegalInterrogationIntentionPort required")
  if session == .nil | \session~isA(.LegalInterrogationSession) then raise syntax 93.900 array("LegalInterrogationSession required")
  self~port = port
  self~session = session
  self~providerId = providerId

::method discover
  use strict arg service
  discovery = self~port~discover(self~session)
  if \discovery~ok then return .nil
  legalSurface = discovery~value
  snapshotId = self~snapshotId
  /* Intention Service owns discovery generation.  The provider revision must
   * describe semantic state, not how many times discover() has been called.
   * Session revision advances on authoring mutations; closure is retained as a
   * second state discriminator for defensive compatibility. */
  snapshotRevision = self~session~revision || ":" || self~session~closureState
  snapshot = .IntentionDiscoverySnapshot~new(snapshotId, snapshotRevision)

  do intention over legalSurface~intentions
    self~advertise(snapshot, intention, legalSurface~generation, .false)
  end
  do intention over legalSurface~queryOperations
    self~advertise(snapshot, intention, legalSurface~generation, .true)
  end
  return snapshot

::method advertise
  use strict arg snapshot, intention, generation, queryOnly
  subject = .LegalInterrogationDev11SurfaceSubject~new(self~session, self~session~revision, generation, intention, queryOnly)
  provider = .LegalInterrogationDev11SurfaceProvider~new(self~port, subject)
  surfaceId = self~surfaceId(intention)
  /*
   * ADVISORY describes the discovery advertisement itself.  It does not claim
   * the underlying legal-authoring mutation is advisory or pre-authorised.
   */
  advertisement = .IntentionSurfaceAdvertisement~new(surfaceId, provider, subject, "AVAILABLE", "SESSION", "DISCOVERY", "ADVISORY")
  snapshot~addSurfaceAdvertisement(advertisement)
  return advertisement

::method snapshotId
  return self~providerId || "." || self~safeToken(self~session~id)

::method surfaceId
  use strict arg intention
  return self~snapshotId || "." || self~safeToken(intention~name) || "." || self~safeToken(intention~subjectRef)

::method safeToken
  use strict arg value
  token = value~string~upper
  out = ""
  allowed = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-."
  do i = 1 to length(token)
    ch = substr(token, i, 1)
    if pos(ch, allowed) > 0 then out = out || ch
    else out = out || "_"
  end
  if out == "" then out = "NONE"
  return out


::class LegalInterrogationIntentionServiceDev11Binding public
::method bind
  use strict arg intentionService, port, session
  if intentionService == .nil then return .LegalInterrogationResult~failure("INTENTION_SERVICE_REQUIRED", "Intention Service instance required")
  if port == .nil | \port~isA(.LegalInterrogationIntentionPort) then return .LegalInterrogationResult~failure("BAD_PORT", "LegalInterrogationIntentionPort required")
  if session == .nil | \session~isA(.LegalInterrogationSession) then return .LegalInterrogationResult~failure("BAD_SESSION", "LegalInterrogationSession required")
  if \intentionService~hasMethod("REGISTERDISCOVERYPROVIDER") then return .LegalInterrogationResult~failure("INTENTION_DEV11_DISCOVERY_UNAVAILABLE", "Intention Service must implement registerDiscoveryProvider(provider)")
  provider = .LegalInterrogationDev11DiscoveryProvider~new(port, session)
  intentionService~registerDiscoveryProvider(provider)
  return .LegalInterrogationResult~success(provider, "INTENTION_DEV11_DISCOVERY_BOUND", "Legal Interrogation is bound as a live Intention Service discovery provider")

::requires "LegalInterrogationIntentionPort.cls"
::requires "IntentionContext.cls"
