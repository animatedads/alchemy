/* NoSQLServer v0.78 Alchemy Objects successor STANDARD adoption smoke. */
call directory directory("S")

root = .NoSQLServerTestSupport~createBlankDatabase("v078-alchemy")

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
call assert publicJson~pos('ALCHEMY-HOUSE-OBJECT-0.8') > 0, "STANDARD metadata names adopted house standard"
call assert .AlchemyAdoptionVerifier~verify(file, "STANDARD")~ok, "file engine satisfies successor STANDARD adoption"

sql = .NoSQLServerSQL~new(file, sealer, authority)
call assert sql~isA(.AlchemyObject), "SQL executor inherits AlchemyObject"
call assert sql~checkSurfaceContract~ok, "SQL executor method contracts match surface"
call assert sql~version~release = "0.79", "Alchemy-derived SQL executor remains operational"
call assert .AlchemyAdoptionVerifier~verify(sql, "STANDARD")~ok, "SQL executor STANDARD adoption"

tx = file~transaction
call assert tx~isA(.AlchemyObject), "transaction inherits AlchemyObject"
call assert tx~checkSurfaceContract~ok, "transaction method contracts match surface"
call assert .AlchemyAdoptionVerifier~verify(tx, "STANDARD")~ok, "transaction STANDARD adoption"
txJson = tx~serializedPublicSnapshot
call assert txJson~pos('"ROLE":"TRANSACTION"') > 0, "transaction inherited configured sealer"
ignore = tx~rollback

core = file~databaseCore
call assert core~isA(.AlchemyObject), "Database Core adapter inherits AlchemyObject"
call assert core~checkSurfaceContract~ok, "Database Core adapter method contracts match surface"
call assert .AlchemyAdoptionVerifier~verify(core, "STANDARD")~ok, "Database Core adapter STANDARD adoption"

obj = .ObjectDatabaseEngine~new(sealer, authority)
call assert obj~isA(.AlchemyObject), "object engine inherits AlchemyObject"
call assert obj~checkSurfaceContract~ok, "object engine contracts"
call assert .AlchemyAdoptionVerifier~verify(obj, "STANDARD")~ok, "object engine STANDARD adoption"

json = .JsonDatabaseEngine~new("fixtures/v073_orders.json", sealer, authority)
call assert json~isA(.AlchemyObject), "JSON engine inherits AlchemyObject"
call assert json~checkSurfaceContract~ok, "JSON engine contracts"
call assert .AlchemyAdoptionVerifier~verify(json, "STANDARD")~ok, "JSON engine STANDARD adoption"

sqlite = .SQLiteDatabaseEngine~new("fixtures/v067_inverness_sample.gpkg", sealer, authority)
call assert sqlite~isA(.AlchemyObject), "SQLite engine inherits AlchemyObject"
call assert sqlite~checkSurfaceContract~ok, "SQLite engine contracts"
call assert .AlchemyAdoptionVerifier~verify(sqlite, "STANDARD")~ok, "SQLite engine STANDARD adoption"

gpkg = .GeoPackageDatabaseEngine~new("fixtures/v067_inverness_sample.gpkg", "", sealer, authority)
call assert gpkg~isA(.AlchemyObject), "GeoPackage engine inherits AlchemyObject"
call assert gpkg~checkSurfaceContract~ok, "GeoPackage engine contracts"
call assert .AlchemyAdoptionVerifier~verify(gpkg, "STANDARD")~ok, "GeoPackage engine STANDARD adoption"

fed = .FederatedDatabaseEngine~new(root, sealer, authority)
call assert fed~isA(.AlchemyObject), "federated engine inherits AlchemyObject"
call assert fed~fileEngine~isA(.AlchemyObject), "federated FILE child inherits house base"
call assert fed~objectEngine~isA(.AlchemyObject), "federated OBJECT child inherits house base"
call assert fed~checkSurfaceContract~ok, "federated engine contracts"
call assert .AlchemyAdoptionVerifier~verify(fed, "STANDARD")~ok, "federated engine STANDARD adoption"

v = .NoSQLServerVersionInfo~new
call assert v~release = "0.79", "release bumped"
call assert v~supports("ALCHEMY_OBJECT_BASE_0_8"), "successor v0.8 house-base capability advertised"
call assert v~supports("ALCHEMY_OBJECT_STANDARD_0_8"), "successor STANDARD adoption capability advertised"

plain = .ObjectDatabaseEngine~new
call assert .AlchemyAdoptionVerifier~verify(plain, "STANDARD")~ok, "STANDARD adoption does not require host security configuration"
call assert \.AlchemyAdoptionVerifier~verify(plain, "SECURE_READY")~ok, "SECURE_READY is not implied without host sealer/authority"

ignore = .NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.78 ALCHEMY V0.5 STANDARD ADOPTION: OK"
exit 0

assert: procedure
  use arg condition, message
  if \condition then do
    say "ASSERT FAILED:" message
    exit 1
  end
  return

::requires "../src/NoSQLServer.cls"
::requires "AlchemyAdoption.cls"
::requires "TestSupport.cls"
