/* GeoPackageOoRexxBackend.cls - portable pure-ooRexx GeoPackage backend profile v0.1 */

::class GeoPackageOoRexxBackend public subclass NativeDatabaseBackend
::method init
  self~init:super("GEOPACKAGE","nosqlserver-oorexx-direct","0.1",.NativeDatabaseImplementationKind~OOREXX_NATIVE,20)
  self~addRequirement("NOSQLSERVER",.true,"NoSQLServer package providing GeoPackageDatabaseEngine")
  self~addCapability("READ_ONLY","SUPPORTED","TESTED","Direct ooRexx SQLite/GeoPackage binary reader","tests/test_geopackage_oorexx_backend.rex")
  self~addCapability("TABLE_DISCOVERY","SUPPORTED","TESTED","gpkg_contents and SQLite schema discovery")
  self~addCapability("TYPED_GEOMETRY","SUPPORTED","TESTED","GeoPackage geometry BLOB promoted to typed geometry with SRID")
  self~addCapability("SPATIAL_PREDICATES","SUPPORTED","DECLARED","NoSQLServer spatial accessor/predicate layer over typed geometry")
  self~addCapability("EXTERNAL_NATIVE_LIBRARY","UNSUPPORTED","TESTED","Primary portable path does not require sqlite3/GDAL/native helper libraries")
  self~addCapability("MUTATION","UNSUPPORTED","TESTED","GeoPackage engine is intentionally read-only")
  self~addCapability("FOREIGN_ACCELERATION","CONDITIONAL","DECLARED","A future optional Foreign Runtime accelerator may implement the same upper contract")
  self~addLimitation("READ_ONLY","GeoPackage mutation is not exposed by the portable direct-reader")
  self~addLimitation("WITHOUT_ROWID","Current GeoPackage direct-reader rejects unsupported WITHOUT ROWID table storage")
  self~addLimitation("PERFORMANCE_PORTABILITY_TRADEOFF","Pure ooRexx is the library-independent portability baseline; optional Foreign Runtime acceleration may be selected when qualified")
::method available
  return .true
::method acquire
  use strict arg source
  path=source
  if source~hasMethod("DATABASEName") then path=source~databaseName
  if path==.nil then return .nil
  if path~string="" then return .nil
  signal on syntax name failed
  engine=.GeoPackageDatabaseEngine~new(path~string)
  signal off syntax
  return .GeoPackageOoRexxSession~new(self,engine,path~string)
failed:
  signal off syntax
  return .nil

::class GeoPackageOoRexxSession public
::method init
  expose backend engine path closed
  use strict arg backend, engine, path
  closed=.false
::attribute backend get
::attribute engine get
::attribute path get
::attribute closed get
::method tableNames
  expose engine
  return engine~tableNames
::method query
  expose engine closed
  use strict arg sql
  if closed then raise syntax 93.900 array("GeoPackage ooRexx session is closed")
  return engine~query(sql)
::method close
  expose closed
  closed=.true
  return self

::requires "NativeDatabaseBackend.cls"
::requires "NoSQLServer.cls"
