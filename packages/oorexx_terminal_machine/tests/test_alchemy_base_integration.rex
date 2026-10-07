/* Alchemy Objects v0.8 base/adoption acceptance for Terminal Machine v0.16. */
ring = .CryptoMacKeyRing~new
ring~addKey("terminal-alchemy-test", "00112233445566778899aabbccddeeff")
sealer = .AlchemyMacSealer~new(ring)
authority = .AlchemyCapabilityAuthority~new(ring)

watch = .TerminalWatchAlong~new(4, sealer, authority)
call assertTrue watch~isA(.AlchemyObject), "watch-along inherits AlchemyObject"
call assertTrue watch~isA(.TerminalAlchemyObject), "watch-along inherits TerminalAlchemyObject"
call assertTrue watch~checkSurfaceContract~ok, "watch-along registered surface is coherent"
watchAdoption = .AlchemyAdoptionVerifier~verify(watch, "STANDARD")
call assertTrue watchAdoption~ok, "watch-along meets Alchemy v0.8 STANDARD adoption"
call assertEq "0.8", watchAdoption~evidence["base_version"], "watch-along adoption base version"
call assertEq "INIT", watchAdoption~evidence["construction_provenance"]["entrypoint"], "watch-along uses preferred init:super construction"
call assertFalse hasWarning(watchAdoption~warnings, "LEGACY_INIT_ENTRYPOINT"), "watch-along has no legacy initAlchemy warning"
baseState = watch~alchemyBaseState
call assertEq "0.8", baseState["base_version"], "watch-along reports Alchemy v0.8 base state"
call assertTrue baseState~hasIndex("cooperative_interposition_available"), "v0.8 cooperative-interposition evidence is present"
call assertTrue baseState~hasIndex("coordinated_instrumentation_count"), "v0.8 coordinated-instrumentation count is present"

caps = .TerminalCapabilities~new~add("CHARACTER_GRID")
snap = .TerminalSnapshot~new(7, "IBM5250", 2, 8, 1, 1, "UNLOCKED", "OPERATOR_WAIT", .array~of("HELLO   ", "WORLD   "), .nil, caps)
watch~observe(snap)
call assertEq 7, watch~lastSeenGeneration, "watch records observed generation"
call assertTrue watch~alchemyMetrics["use_count"] > 0, "observation updates inherited lifecycle telemetry"

pub = watch~sealPublicIntrospection
call assertTrue sealer~verify(pub), "public terminal Alchemy evidence verifies"
call assertEq "PUBLIC", pub~payload["profile"], "public profile"
call assertFalse pub~payload~hasIndex("state"), "public evidence exposes no registered values"

cap = authority~issue("terminal-test", watch~alchemyObjectId, "SEALEDINTROSPECTION", "INTROSPECT:CUSTOMER")
customer = watch~sealedIntrospection("CUSTOMER", cap)
call assertTrue sealer~verify(customer), "customer terminal Alchemy evidence verifies"
state = customer~payload["state"]
call assertEq 4, state["CAPACITY"], "customer introspection exposes bounded observer capacity"
call assertEq 7, state["LASTSEENGENERATION"], "customer introspection exposes observed generation"
call assertFalse state~hasIndex("HISTORY"), "customer introspection does not expose internal snapshot history"

session = .TerminalSession~new("ALCHEMY-SESSION", .AlchemyFakeModel~new(snap), .nil, sealer, authority)
call assertTrue session~isA(.AlchemyObject), "generic session inherits AlchemyObject"
call assertTrue session~checkSurfaceContract~ok, "generic session registered surface is coherent"
sessionAdoption = .AlchemyAdoptionVerifier~verify(session, "STANDARD")
call assertTrue sessionAdoption~ok, "generic session meets Alchemy v0.8 STANDARD adoption"
call assertEq "INIT", sessionAdoption~evidence["construction_provenance"]["entrypoint"], "generic session uses preferred init:super construction"
committed = session~commit
call assertEq 7, committed~generation, "generic session still returns detached snapshot"

say "PASS test_alchemy_base_integration"
exit 0

assertTrue: procedure
  use strict arg actual, message
  if actual \= .true then raise syntax 88.900 array("assertTrue failed: " || message)
  return
assertFalse: procedure
  use strict arg actual, message
  if actual \= .false then raise syntax 88.900 array("assertFalse failed: " || message)
  return
assertEq: procedure
  use strict arg expected, actual, message
  if expected \== actual then raise syntax 88.900 array("assertEq failed: " || message || " expected=" || expected || " actual=" || actual)
  return

hasWarning: procedure
  use strict arg warnings, code
  wanted = code~string~translate
  do warning over warnings
    if warning["code"] == wanted then return .true
  end
  return .false

::class AlchemyFakeModel public
::method init
  expose snapshotValue
  use strict arg snapshotValue
::method snapshot
  expose snapshotValue
  return snapshotValue~copyDetached

::requires "TerminalCore.cls"
::requires "AlchemyEvidence.cls"
::requires "AlchemyAdoption.cls"
