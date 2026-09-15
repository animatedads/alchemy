call assert .NoSQLServerBuild~RELEASE = '0.79', 'referenced NoSQLServer package release is v0.79'
call assert .NoSQLServerBuild~SQLLEVEL = '0.79', 'referenced NoSQLServer package SQL level is v0.79'
call assert .GeoPackageDatabaseEngine \== .nil, 'GeoPackage engine class available from referenced package'
call assert .JsonDatabaseEngine \== .nil, 'JSON engine class available from referenced package'
call assert .SQLiteDatabaseEngine \== .nil, 'native SQLite relation provider available from referenced package'
call assert .SQLiteNativeDatabase \== .nil, 'native SQLite binary reader available from referenced package'
version = .NoSQLServerVersionInfo~new
call assert version~supports('SPATIAL_POINT_POLYGON_FUNCTIONS'), 'spatial POINT/POLYGON capability available from referenced package'
call assert version~supports('OPTIONAL_TUTOR_UNICODE'), 'optional Unicode capability available from referenced package'
call assert version~supports('ALCHEMY_OBJECT_BASE_0_8'), 'NoSQLServer Alchemy v0.8 adoption capability available'
say 'MSQLSHIM V0.21.2 BACKEND PACKAGE REFERENCE SMOKE PASS'
exit 0
::routine assert
  use arg condition, message
  if \condition then do; say 'FAIL:' message; exit 1; end
  say 'PASS' message
return
::requires 'NoSQLServer.cls'
