/* Test server: table-fed Algorithm Relation pipeline through stock NoSQLServer v0.68 + msqlshim v0.08. */
parse arg port root
if port == '' then port = 3528
if root == '' then root = '/tmp/msqlshim_table_feed_v068'

fed = .FederatedDatabaseEngine~new(root)

world = .RYTAWorldState~new('WORLD-WIRE-TABLE-FEED-A')
world~putKnown('HAS_QUERY', .true)
world~putKnown('PRODUCT_RELEVANT', .true)
world~putKnown('PRODUCT_VALUE_HIGH', .true)
world~putKnown('UPSELL_OPPORTUNITY', .true)
world~putKnown('ESSENTIAL_MEDICATION', .true)
world~putKnown('IMMEDIATE_ACCESS', .true)
world~putKnown('GUARANTEED_CUSTODY', .false)

rytaProvider = .RYTAAlgorithmProvider~new(.nil, '..')
algorithmEngine = .AlgorithmRelationEngine~new
if \algorithmEngine~addProvider(rytaProvider) then raise syntax 93.900 additional('RYTA provider registration failed')
classes = .directory~new
classes['TABLE_DEFINITION'] = .TableDefinition
classes['DATABASE_ROW'] = .DatabaseRow
classes['DATABASE_RESULT'] = .DatabaseResult
classes['TABLE_METADATA'] = .DatabaseTableMetadata
ctxA = .AlgorithmExecutionContext~new('WIRE-TABLE-A-1', world~snapshotOid, world~snapshotOid)
bindA = .directory~new
bindA['RYTA_ACTION_DECISIONS'] = 'ryta_actions'
bindA['RYTA_DECISION_TRACE'] = 'ryta_trace'
extA = .NoSQLAlgorithmRelationExternalEngine~new(algorithmEngine, 'VIRTUAL_RYTA', world, ctxA, classes, bindA)
if \extA~isReady then raise syntax 93.900 additional('RYTA external engine failed:' extA~lastError)
ignore = fed~addEngine(extA)

ignore = fed~execute("CREATE TABLE toy_policy (action_code VARCHAR PRIMARY KEY, label VARCHAR, preference_score INTEGER)")
ignore = fed~execute("INSERT INTO toy_policy VALUES ('ANSWER_QUERY','answer',10),('SELL_PRODUCT','sell',5),('WARNING','warn',-1000000),('UPSELL','upsell',3),('BIG_UPSELL','big upsell',1000000)")

sourceSql = "SELECT p.action_code AS row_id,p.label AS label,p.preference_score AS preference_score,r.disposition AS upstream_disposition FROM toy_policy p JOIN ryta_actions r ON p.action_code=r.action_code ORDER BY p.action_code"
inputSchema = .AlgorithmSchema~new('TABLE_FEED_SOURCE')
inputSchema~add('ROW_ID', 'TEXT', .false)
inputSchema~add('LABEL', 'TEXT', .false)
inputSchema~add('PREFERENCE_SCORE', 'NUMBER', .false)
inputSchema~addEnum('UPSTREAM_DISPOSITION', 'TEXT', .false, .array~of('UNRESOLVED','PERMITTED','REQUIRED','SUPPRESSED','PROHIBITED','REQUIRES_APPROVAL'))
capture = .NoSQLServerAlgorithmInputCapture~new(fed)
inputSnapshot = capture~capture(sourceSql, inputSchema, '', .AlgorithmInputRelationConstant~BAG_UNORDERED, 'MYSQL_WIRE_TABLE_FEED_SOURCE')
if inputSnapshot == .nil then raise syntax 93.900 additional('input capture failed:' capture~lastError)

feedProvider = .TableFeedDecisionProvider~new('..')
if \algorithmEngine~addProvider(feedProvider) then raise syntax 93.900 additional('feed provider registration failed')
ctxB = .AlgorithmExecutionContext~new('WIRE-TABLE-B-1', inputSnapshot~sourceOid, inputSnapshot~sourceOid)
bindB = .directory~new
bindB['TABLE_FEED_DECISIONS'] = 'table_feed_decisions'
bindB['TABLE_FEED_TRACE'] = 'table_feed_trace'
extB = .NoSQLAlgorithmRelationExternalEngine~new(algorithmEngine, 'TABLE_FEED_DECIDER', inputSnapshot, ctxB, classes, bindB)
if \extB~isReady then raise syntax 93.900 additional('table feed external engine failed:' extB~lastError)
ignore = fed~addEngine(extB)

statsObject = .PipelineStats~new(rytaProvider, feedProvider, inputSnapshot)
stats = .array~of(statsObject)
sm = .ObjectTableMapping~new('algrel_pipeline_stats')
ignore = sm~column('upstream_invocations', 'INTEGER', 'upstreamInvocations')
ignore = sm~column('downstream_invocations', 'INTEGER', 'downstreamInvocations')
ignore = sm~column('input_hash', 'VARCHAR', 'inputHash')
if \fed~register('algrel_pipeline_stats', stats, sm) then raise syntax 93.900 additional('stats registration failed')

server = .MySQLWireServer~new(root, '127.0.0.1', port)
server~engine = fed
say 'MSQL TABLE FEED READY port=' || port || ' upstream=' || rytaProvider~invocationCount || ' downstream=' || feedProvider~invocationCount
server~serve

::class PipelineStats public
::attribute upstreamProvider get
::attribute downstreamProvider get
::attribute inputSnapshot get
::method init
  expose upstreamProvider downstreamProvider inputSnapshot
  use arg upstreamArg, downstreamArg, inputArg
  upstreamProvider = upstreamArg
  downstreamProvider = downstreamArg
  inputSnapshot = inputArg
::method upstreamInvocations
  expose upstreamProvider
  return upstreamProvider~invocationCount
::method downstreamInvocations
  expose downstreamProvider
  return downstreamProvider~invocationCount
::method inputHash
  expose inputSnapshot
  return inputSnapshot~contentHash

::requires 'src/MySQLWireServer.cls'
::requires '../integration/NoSQLServerAlgorithmRelationExternalEngine.cls'
::requires '../integration/NoSQLServerAlgorithmInputCapture.cls'
::requires '../algorithm/RYTAAlgorithmProvider.cls'
::requires '../algorithm/TableFeedDecisionProvider.cls'
::requires '../HardWorld.cls'
