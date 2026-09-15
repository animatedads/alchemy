root = "/tmp/psychic-poker-alchemy-foundation"
call cleanTree root

cfg = .GameConfig~new(5, 10, 1000, 40, 123456)
rng = .PokerRandom~new(123456)
strategy = .PlayerStrategy~new("alchemy-test", 0.50, 0.05, 1.00)
player = .Player~new("Alice", 1000, strategy)
table = .PokerTable~new("alchemy-table", cfg)
casino = .Casino~new("Alchemy Casino")
lib = .PokerTableTalkLibrarian~new
grok = .GrokAPIClient~new("grok-test", "http://127.0.0.1:1", 1)
gemini = .GeminiAPIClient~new("gemini-test", "http://127.0.0.1:1/", 1)
players = .array~of(player)
store = .PokerExperimentStore~new(root, players)

call assertTrue cfg~isA(.AlchemyObject), "GameConfig inherits AlchemyObject"
call assertTrue rng~isA(.AlchemyObject), "PokerRandom inherits AlchemyObject"
call assertTrue strategy~isA(.AlchemyObject), "PlayerStrategy inherits AlchemyObject"
call assertTrue player~isA(.AlchemyObject), "Player inherits AlchemyObject"
call assertTrue table~isA(.AlchemyObject), "PokerTable inherits AlchemyObject"
call assertTrue casino~isA(.AlchemyObject), "Casino inherits AlchemyObject"
call assertTrue lib~isA(.AlchemyObject), "PokerTableTalkLibrarian inherits AlchemyObject"
call assertTrue grok~isA(.AlchemyObject), "GrokAPIClient inherits AlchemyObject"
call assertTrue gemini~isA(.AlchemyObject), "GeminiAPIClient inherits AlchemyObject"
call assertTrue store~isA(.AlchemyObject), "PokerExperimentStore inherits AlchemyObject"
call assertTrue store~socialModel~isA(.AlchemyObject), "PokerSocialEvidenceModel inherits AlchemyObject"

call assertTrue player~alchemyObjectId <> "", "player has inherited Alchemy identity"
call assertTrue table~alchemyObjectId <> "", "table has inherited Alchemy identity"
call assertTrue player~alchemyObjectId <> table~alchemyObjectId, "Alchemy identities are object-specific"
call assertTrue player~checkSurfaceContract~ok, "player Alchemy surface contract"
call assertTrue strategy~checkSurfaceContract~ok, "strategy Alchemy surface contract"

casino~addTable(table)
table~addPlayer(player)
metrics = table~alchemyMetrics
call assertTrue metrics["counters"]["COUNT:ADD_PLAYER"] >= 1, "table lifecycle telemetry records seat mutation"

/* Product inheritance roots intentionally do not register superclass-scoped
   object variables for fixed state emission. ooRexx object-variable scope is
   class-local, so doing so would yield misleading NIL values in deeper
   strategy/psychic subclasses. The integrated base is still fully usable for
   identity, contracts, lifecycle telemetry, requirements and relationships. */
call assertEq 0, player~alchemyMetrics["counters"]~items, "new Player has no fabricated lifecycle counters"
player~alchemyTouch("TEST_USE")
call assertEq 1, player~alchemyMetrics["counters"]["COUNT:TEST_USE"], "Player inherited lifecycle telemetry works"

/* Prove the inherited cryptographic disclosure boundary on a Poker-specific
   concrete Alchemy object whose registered state is defined in that concrete
   class, matching the v0.7 fixed-emitter contract. */
ring = .CryptoMacKeyRing~new
ring~addKey("poker-test", "00112233445566778899aabbccddeeff")
sealer = .AlchemyMacSealer~new(ring)
authority = .AlchemyCapabilityAuthority~new(ring)
probe = .PokerAlchemyProbe~new(sealer, authority)
pub = probe~sealPublicIntrospection
call assertTrue sealer~verify(pub), "public PokerAlchemyObject snapshot verifies"
call assertFalse pub~payload~hasIndex("state"), "PUBLIC profile exposes no registered values"
call assertFalse hasNamedRecord(pub~payload["state_description"], "SECRETNOTE"), "PUBLIC description hides secret slot name"

capCustomer = authority~issue("tester", probe~alchemyObjectId, "SEALEDINTROSPECTION", "INTROSPECT:CUSTOMER")
customer = probe~sealedIntrospection("CUSTOMER", capCustomer)
call assertTrue sealer~verify(customer), "CUSTOMER PokerAlchemyObject snapshot verifies"
state = customer~payload["state"]
call assertEq "visible", state["DISPLAYNAME"], "customer snapshot contains customer-visible state"
call assertFalse state~hasIndex("SECRETNOTE"), "customer snapshot excludes secret state"

capInternal = authority~issue("auditor", probe~alchemyObjectId, "SEALEDINTROSPECTION", "INTROSPECT:INTERNAL")
internal = probe~sealedIntrospection("INTERNAL", capInternal)
call assertTrue sealer~verify(internal), "INTERNAL PokerAlchemyObject snapshot verifies"
internalState = internal~payload["state"]
call assertEq 7, internalState["INTERNALCOUNT"], "internal snapshot contains internal state"
call assertFalse internalState~hasIndex("SECRETNOTE"), "internal snapshot still excludes SECRET state"

runtime = player~securityRuntimeSemantics
call assertTrue runtime["observed"], "Alchemy Security Manager semantics observed on this interpreter"
call assertTrue runtime["matches_reference"], "observed semantics match ooRexx reference"

call assertEq "0.77", .NoSQLServerBuild~RELEASE, "Poker is rebased to authoritative NoSQLServer v0.77"

say "PASS Psychic Poker AlchemyObject v0.7 foundation and NoSQLServer v0.77 rebase"
call cleanTree root
exit 0

assertTrue: procedure
  use arg value, message
  if value \== .true then raise syntax 93.900 array("assertTrue failed: " || message)
  return

assertFalse: procedure
  use arg value, message
  if value \== .false then raise syntax 93.900 array("assertFalse failed: " || message)
  return

assertEq: procedure
  use arg expected, actual, message
  if expected \== actual then raise syntax 93.900 array("assertEq failed: " || message || " expected=" || expected || " actual=" || actual)
  return

hasNamedRecord: procedure
  use arg records, wanted
  wanted = wanted~string~translate
  do rec over records
    name = rec~at("name")
    if name \== .nil then if name~string~translate = wanted then return .true
  end
  return .false

cleanTree: procedure
  use arg root
  call SysFileTree root || "/*", "oldFiles.", "FOS"
  do i = 1 to oldFiles.0
    call SysFileDelete oldFiles.i
  end
  call SysFileTree root || "/*", "oldDirs.", "DOS"
  do i = oldDirs.0 to 1 by -1
    call SysRmDir oldDirs.i
  end
  call SysRmDir root
  return

::class PokerAlchemyProbe public subclass PokerAlchemyObject
::method init
  expose displayName internalCount secretNote
  use arg sealer, authority
  displayName = "visible"
  internalCount = 7
  secretNote = "never below FULL"
  self~initPokerAlchemy("TEST_PROBE", "Regression probe for Poker Alchemy disclosure semantics")
  self~configureAlchemySecurity(sealer, authority)
  self~registerStateVariable("displayName", "CUSTOMER", "customer-visible probe state")
  self~registerStateVariable("internalCount", "INTERNAL", "internal-only probe state")
  self~registerStateVariable("secretNote", "SECRET", "secret probe state")

::requires "poker.cls"
::requires "ai_grok.cls"
::requires "ai_gemini.cls"
::requires "experiment_store.cls"
