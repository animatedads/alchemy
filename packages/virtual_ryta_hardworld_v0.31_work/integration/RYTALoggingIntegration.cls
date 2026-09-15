/*
 * Optional RYTA / ooRexx Logging integration.
 *
 * This class deliberately keeps Logging out of the RYTA core dependency
 * closure. Hosts that want governed method logging instantiate this subtype.
 * Logging owns observability only: it does not alter HardWorld decisions,
 * EvidencePromotion authority, Legal authority, or RYTA semantic identity.
 */

::class RYTALoggedVirtualRYTA subclass VirtualRYTA public inherit LogInstrumentationParticipant

::method init
  use strict arg alchemyOptions = .nil
  /* Explicitly enter VirtualRYTA's INIT. With a mixin participant in the
     subclass linearization, a generic SUPER forward can bypass the business
     initializer and leave RYTA state unconstructed. */
  self~sendWith(.array~of("INIT", .VirtualRYTA), .array~of(alchemyOptions))
  self~registerExternalRequirement("library", "oorexx_logging", "v0.5", .false)
  return self

/* The logging participant installs an object-specific wrapper.  A copied
   inherited method would execute with object scope and therefore cannot expose
   VirtualRYTA's class-scoped state safely.  Keep the integration surface as a
   tiny forwarding method declared on this adapter class; the business method
   is then invoked with its original VirtualRYTA scope. */
::method evaluate public
  args = arg(1, "A")
  return self~sendWith(.array~of("EVALUATE", .VirtualRYTA), args)

::requires "../VirtualRYTA.cls"
::requires "LoggingCore.cls"
