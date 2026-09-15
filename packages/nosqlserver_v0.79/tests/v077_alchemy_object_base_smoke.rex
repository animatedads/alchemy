/* NoSQLServer v0.77 Alchemy Object house-base integration smoke. */
call directory directory("S")

root = .NoSQLServerTestSupport~createBlankDatabase("v077-alchemy")

ring = .CryptoMacKeyRing~new
ring~addKey("nosql-house", "00112233445566778899aabbccddeeff")
sealer = .AlchemyMacSealer~new(ring)
authority = .AlchemyCapabilityAuthority~new(ring)

file = .FileDatabaseEngine~new(root, .nil, sealer, authority)
call assert file~isA(.AlchemyObject), "FileDatabaseEngine inherits AlchemyObject"
call assert file~isA(.NoSQLAlchemyObject), "FileDatabaseEngine inherits NoSQLAlchemyObject"
call assert file~alchemyObjectId~strip \= "", "file engine gets house object identity"
call assert file~alchemyMetrics["lifecycle"] = "LIVE", "file engine lifecycle evidence"
call assert file~checkSurfaceContract~ok, "file engine registered method contracts match surface"

publicJson = file~serializedPublicSnapshot
call assert publicJson~pos('"PACKAGE_VERSION":0.79') > 0, "sealed public snapshot carries NoSQL version"
call assert publicJson~pos('"ROLE":"FILE_ENGINE"') > 0, "sealed public snapshot carries engine role"
call assert publicJson~pos('ALCHEMY-HOUSE-OBJECT-0.4') = 0, "house compliance is not falsely claimed by default"

sql = .NoSQLServerSQL~new(file, sealer, authority)
call assert sql~isA(.AlchemyObject), "SQL executor inherits AlchemyObject"
call assert sql~checkSurfaceContract~ok, "SQL executor method contracts match surface"
call assert sql~version~release = "0.79", "Alchemy-derived SQL executor remains operational"

tx = file~transaction
call assert tx~isA(.AlchemyObject), "transaction inherits AlchemyObject"
call assert tx~checkSurfaceContract~ok, "transaction method contracts match surface"
txJson = tx~serializedPublicSnapshot
call assert txJson~pos('"ROLE":"TRANSACTION"') > 0, "transaction inherited configured sealer"
ignore = tx~rollback

core = file~databaseCore
call assert core~isA(.AlchemyObject), "Database Core adapter inherits AlchemyObject"
call assert core~checkSurfaceContract~ok, "Database Core adapter method contracts match surface"

obj = .ObjectDatabaseEngine~new(sealer, authority)
call assert obj~isA(.AlchemyObject), "object engine inherits AlchemyObject"
call assert obj~checkSurfaceContract~ok, "object engine contracts"

json = .JsonDatabaseEngine~new("fixtures/v073_orders.json", sealer, authority)
call assert json~isA(.AlchemyObject), "JSON engine inherits AlchemyObject"
call assert json~checkSurfaceContract~ok, "JSON engine contracts"

sqlite = .SQLiteDatabaseEngine~new("fixtures/v067_inverness_sample.gpkg", sealer, authority)
call assert sqlite~isA(.AlchemyObject), "SQLite engine inherits AlchemyObject"
call assert sqlite~checkSurfaceContract~ok, "SQLite engine contracts"

gpkg = .GeoPackageDatabaseEngine~new("fixtures/v067_inverness_sample.gpkg", "", sealer, authority)
call assert gpkg~isA(.AlchemyObject), "GeoPackage engine inherits AlchemyObject"
call assert gpkg~checkSurfaceContract~ok, "GeoPackage engine contracts"

fed = .FederatedDatabaseEngine~new(root, sealer, authority)
call assert fed~isA(.AlchemyObject), "federated engine inherits AlchemyObject"
call assert fed~fileEngine~isA(.AlchemyObject), "federated FILE child inherits house base"
call assert fed~objectEngine~isA(.AlchemyObject), "federated OBJECT child inherits house base"
call assert fed~checkSurfaceContract~ok, "federated engine contracts"

v = .NoSQLServerVersionInfo~new
call assert v~release = "0.79", "successor release preserves v0.77 boundary"
call assert v~supports("ALCHEMY_OBJECT_BASE_0_8"), "successor Alchemy v0.8 house-base capability advertised"

ignore = .NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.77 ALCHEMY OBJECT BASE: OK"
exit 0

assert: procedure
  use arg condition, message
  if \condition then do
    say "ASSERT FAILED:" message
    exit 1
  end
  return

::requires "../src/NoSQLServer.cls"
::requires "TestSupport.cls"
