root = .NoSQLServerTestSupport~createBlankDatabase('v070_external_metadata')
fed = .FederatedDatabaseEngine~new(root)

raw = .table~new
raw['name'] = 'external_shape'
raw['rowCount'] = 0
raw['generation'] = 0
raw['columns'] = .array~new
idCol = .table~new
idCol['name'] = 'id'
idCol['type'] = 'INTEGER'
idCol['nullable'] = .false
idCol['primaryKey'] = .true
raw['columns']~append(idCol)
shapeCol = .table~new
shapeCol['name'] = 'shape'
shapeCol['type'] = 'GEOMETRY'
shapeCol['nullable'] = .true
raw['columns']~append(shapeCol)

relation = .V070ExternalRelation~new(raw, 'shape', 'POLYGON', 27700)
provider = .V070ExternalMetadataProvider~new(relation)
ignore = fed~addEngine(provider)

/* The legacy external package's metadata method is intentionally unusable.
 * v0.70 must not invoke it; metadata is derived from the relation contract.
 */
meta = fed~tableMetadata('external_shape')
call assert meta \== .nil, 'federated metadata exists'
call assert provider~metadataCalls = 0, 'external tableMetadata not called'
call assert meta~columns~items = 2, 'metadata column count'
geom = metadataColumn(meta, 'shape')
call assert geom \== .nil, 'geometry metadata column'
call assert geom~commonType = .DatabaseType~GEOMETRY, 'geometry common type'
call assert geom~geometryType = 'POLYGON', 'capability-shaped geometry subtype'
call assert geom~srid = 27700, 'capability-shaped geometry srid'

coreMeta = fed~databaseCore~tableMetadata('external_shape')
coreGeom = metadataColumn(coreMeta, 'shape')
call assert coreGeom~databaseType = .DatabaseType~GEOMETRY, 'DB Core geometry type'
call assert coreGeom~geometryType = 'POLYGON', 'DB Core geometry subtype'
call assert coreGeom~srid = 27700, 'DB Core geometry srid'
call assert provider~metadataCalls = 0, 'DB Core still does not call external metadata factory'
call assert fed~version~supports('FEDERATED_PROVIDER_NEUTRAL_METADATA'), 'metadata boundary capability advertised'

ignore = .NoSQLServerTestSupport~removeDatabase(root)
say 'NOSQLSERVER V0.70 EXTERNAL METADATA BOUNDARY SMOKE: OK'
exit 0

metadataColumn: procedure
  use arg metadata, wanted
  do column over metadata~columns
    if column~name~caselessEquals(wanted) then return column
  end
  return .nil

assert: procedure
  use arg condition, message
  if condition then return .true
  say 'ASSERT FAILED:' message
  exit 1

::class V070ExternalRelation
::attribute definition
::attribute geometryColumn
::attribute geometryType
::attribute srid
::method init
  use arg rawDefinition, geometryColumn, geometryType, srid
  self~definition = .TableDefinition~new(rawDefinition)
  self~geometryColumn = geometryColumn
  self~geometryType = geometryType
  self~srid = srid

::requires '../src/NoSQLServer.cls'
::requires 'TestSupport.cls'
::requires 'V070ExternalMetadataProvider.cls'
