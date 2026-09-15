/* Test server: stock NoSQLServer v0.70 + lazy Algorithm Relation external engine + msqlshim v0.10 prepared cursors. */
parse arg port root
if port == '' then port = 3517
if root == '' then root = '/tmp/msqlshim_algrel_v068_external'

fed = .FederatedDatabaseEngine~new(root)
world = .RYTAWorldState~new('WORLD-MSQL-WIRE-EXT-1')
world~putKnown('HAS_QUERY', .true)
world~putKnown('PRODUCT_RELEVANT', .true)
world~putKnown('PRODUCT_VALUE_HIGH', .true)
world~putKnown('UPSELL_OPPORTUNITY', .true)
world~putKnown('ESSENTIAL_MEDICATION', .true)
world~putKnown('IMMEDIATE_ACCESS', .true)
world~putKnown('GUARANTEED_CUSTODY', .false)

provider = .RYTAAlgorithmProvider~new(.nil, '..')
algorithmEngine = .AlgorithmRelationEngine~new
if \algorithmEngine~addProvider(provider) then raise syntax 93.900 additional('provider registration failed')
ctx = .AlgorithmExecutionContext~new('WIRE-EXT-INV-1', world~snapshotOid, world~snapshotOid)
classes = .directory~new
classes['TABLE_DEFINITION'] = .TableDefinition
classes['DATABASE_ROW'] = .DatabaseRow
classes['DATABASE_RESULT'] = .DatabaseResult
bindings = .directory~new
bindings['RYTA_ACTION_DECISIONS'] = 'ryta_actions'
bindings['RYTA_DECISION_TRACE'] = 'ryta_trace'
external = .NoSQLAlgorithmRelationExternalEngine~new(algorithmEngine, 'VIRTUAL_RYTA', world, ctx, classes, bindings)
if \external~isReady then raise syntax 93.900 additional('external engine failed:' external~lastError)
ignore = fed~addEngine(external)

/* Live test-only stat table lets the wire client prove invocation count. */
stats = .array~of(.V013AlgorithmStats~new(provider, external))
sm = .ObjectTableMapping~new('algrel_provider_stats')
ignore = sm~column('invocations', 'INTEGER', 'invocationCount')
ignore = sm~column('metadata_calls', 'INTEGER', 'metadataCalls')
if \fed~register('algrel_provider_stats', stats, sm) then raise syntax 93.900 additional('stats registration failed')

ignore = fed~execute("CREATE TABLE action_labels (action_code VARCHAR PRIMARY KEY, label VARCHAR)")
ignore = fed~execute("INSERT INTO action_labels VALUES ('WARNING','Safety warning'),('UPSELL','Upsell'),('BIG_UPSELL','Large upsell')")

server = .MySQLWireServer~new(root, '127.0.0.1', port)
server~engine = fed
say 'MSQL V010 V070 ALGREL CURSOR READY port=' || port || ' invocations=' || provider~invocationCount || ' metadata_calls=' || external~metadataFactoryCalls
server~serve

::class V013AlgorithmStats
::attribute provider get
::attribute external get
::method init
  expose provider external
  use arg provider, external
::method invocationCount
  return self~provider~invocationCount
::method metadataCalls
  return self~external~metadataFactoryCalls

::requires 'src/MySQLWireServer.cls'
::requires '../integration/NoSQLServerAlgorithmRelationExternalEngine.cls'
::requires '../algorithm/RYTAAlgorithmProvider.cls'
::requires '../HardWorld.cls'
