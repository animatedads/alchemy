db = .FileDatabaseEngine~new("/tmp/nosql77-poker-boundary")
if \db~isA(.AlchemyObject) then raise syntax 93.900 array("NoSQLServer v0.77 service is not Alchemy-derived")
if .NoSQLServerBuild~RELEASE \= "0.77" then raise syntax 93.900 array("wrong NoSQLServer release")
say "PASS NoSQLServer v0.77 Alchemy service boundary"
exit 0
::requires "nosqlserver/src/NoSQLServer.cls"
