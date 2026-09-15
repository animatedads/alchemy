/* Current-stack acceptance server:
 * native EDIFACT evidence -> Structured Relation -> HardWorld rich evidence bridge
 * -> Algorithm Relation materialisation -> NoSQLServer external engine -> MySQL cursor.
 * No upstream/downstream source is copied or modified by this harness.
 */
parse arg port root fixture hardworldRoot
if port == '' then port = 3696
if root == '' then root = '/tmp/algrel_structured_current'
if fixture == '' then raise syntax 93.900 additional('fixture path required')
if hardworldRoot == '' then raise syntax 93.900 additional('HardWorld root required')

doc = .EdiFactDocumentContext~new(fixture)
envelope = doc~validateEnvelope
sr = .EdiFactRelationProvider~new(.nil)
def = sr~defineRelation('pnr_ssr', doc, 'SEGMENT:SSR')
def~columnMap('group_ref', '@groupReference')
def~columnMap('message_ref', '@messageReference')
def~columnMap('service_code', '1/1')
def~columnMap('service_value', '2')

schema = .AlgorithmSchema~new('STRUCTURED_RICH_INPUT')
schema~add('FACT_ID', 'TEXT', .false)
schema~add('RICH_VALUE', 'RICH_OBJECT', .false)
builder = .AlgorithmInputRelationBuilder~new(schema, 'STRUCTURED_RICH_INPUT')
richValues = .array~new
nativeFacts = .array~new

matches = 0
do row over sr~table('pnr_ssr')~readRows
  groupRef = row['group_ref']
  serviceCode = row['service_code']
  if groupRef == .nil | serviceCode == .nil then iterate
  if groupRef \== 'G07' | serviceCode~upper \== 'NSST' then iterate
  fact = row~fact('service_value')
  rich = .StructuredRelationRichEvidenceAdapter~adaptFact(fact, 'FROZEN_OBSERVATION', 'PNRGOV-G07-NSST')
  if rich~nativeObject \== fact~source then raise syntax 93.900 additional('native source identity lost before Algorithm Relation')
  if rich~sources~items \= 1 then raise syntax 93.900 additional('expected one source ref per PNRGOV fact')
  if rich~sources[1]~nativeObject \== fact~source then raise syntax 93.900 additional('source ref native identity lost')
  if rich~contexts~items \= 1 then raise syntax 93.900 additional('expected one structured context')
  if rich~contexts[1]~nativeFact \== fact then raise syntax 93.900 additional('native fact identity lost')
  if rich~contexts[1]~nativeRow \== row then raise syntax 93.900 additional('native projected-row identity lost')
  matches += 1
  factId = groupRef || ':' || row['message_ref'] || ':NSST'
  values = .directory~new
  values['FACT_ID'] = factId
  values['RICH_VALUE'] = rich
  if \builder~addValues(values) then raise syntax 93.900 additional('Algorithm input rejected rich structured fact')
  richValues~append(rich)
  nativeFacts~append(fact)
end
if matches \= 3 then raise syntax 93.900 additional('expected exactly three G07 NSST facts; got' matches)

snapshot = builder~freeze('PNRGOV-G07-NSST', 'SEGMENT:SSR group=G07 service=NSST', fixture)
if snapshot == .nil then raise syntax 93.900 additional('failed to freeze Algorithm Relation input')

algorithmProvider = .RichBusinessFactAlgorithmProvider~new(hardworldRoot)
algorithmEngine = .AlgorithmRelationEngine~new
if \algorithmEngine~addProvider(algorithmProvider) then raise syntax 93.900 additional('provider registration failed')
ctx = .AlgorithmExecutionContext~new('STRUCTURED-CURSOR-INV-1', snapshot~sourceOid, snapshot~sourceOid)
classes = .directory~new
classes['TABLE_DEFINITION'] = .TableDefinition
classes['DATABASE_ROW'] = .DatabaseRow
classes['DATABASE_RESULT'] = .DatabaseResult
bindings = .directory~new
bindings['RICH_FACT_SUMMARY'] = 'pnr_fact_summary'
bindings['RICH_FACT_SOURCES'] = 'pnr_fact_sources'
bindings['RICH_FACT_TRACE'] = 'pnr_fact_trace'
external = .NoSQLAlgorithmRelationExternalEngine~new(algorithmEngine, 'RICH_BUSINESS_FACTS', snapshot, ctx, classes, bindings)
if \external~isReady then raise syntax 93.900 additional('external engine failed:' external~lastError)

fed = .FederatedDatabaseEngine~new(root)
ignore = fed~addEngine(external)
statsObject = .StructuredCursorProbeStats~new(algorithmProvider, snapshot, richValues, nativeFacts, doc, envelope, external)
stats = .array~of(statsObject)
sm = .ObjectTableMapping~new('structured_probe_stats')
ignore = sm~column('invocations', 'INTEGER', 'invocationCount')
ignore = sm~column('native_identity_preserved', 'VARCHAR', 'nativeIdentityPreserved')
ignore = sm~column('source_rows', 'INTEGER', 'sourceRows')
ignore = sm~column('envelope_status', 'VARCHAR', 'envelopeStatus')
ignore = sm~column('external_integration', 'VARCHAR', 'externalIntegration')
if \fed~register('structured_probe_stats', stats, sm) then raise syntax 93.900 additional('stats registration failed')

say 'STRUCTURED ALGREL CURSOR READY port=' || port || ' invocations=' || algorithmProvider~invocationCount || ' native=' || statsObject~nativeIdentityPreserved || ' envelope=' || envelope~status
server = .MySQLWireServer~new(root, '127.0.0.1', port)
server~engine = fed
server~serve

::class StructuredCursorProbeStats
::attribute provider
::attribute snapshot
::attribute richValues
::attribute nativeFacts
::attribute document
::attribute envelope
::attribute external
::method init
  use arg providerArg, snapshotArg, richValuesArg, nativeFactsArg, documentArg, envelopeArg, externalArg
  self~provider = providerArg
  self~snapshot = snapshotArg
  self~richValues = richValuesArg
  self~nativeFacts = nativeFactsArg
  self~document = documentArg
  self~envelope = envelopeArg
  self~external = externalArg
::method invocationCount
  return self~provider~invocationCount
::method sourceRows
  return self~richValues~items
::method envelopeStatus
  return self~envelope~status
::method externalIntegration
  return self~external~integrationVersion
::method nativeIdentityPreserved
  if self~richValues~items \= self~nativeFacts~items then return 'FALSE'
  do i = 1 to self~richValues~items
    rich = self~richValues[i]
    fact = self~nativeFacts[i]
    if rich~nativeObject \== fact~source then return 'FALSE'
    if rich~sources[1]~nativeObject \== fact~source then return 'FALSE'
    if rich~contexts[1]~nativeFact \== fact then return 'FALSE'
  end
  do rich over self~richValues
    found = .false
    do inputRow over self~snapshot~rows
      if inputRow~value('RICH_VALUE') == rich then found = .true
    end
    if \found then return 'FALSE'
  end
  return 'TRUE'

::requires 'src/MySQLWireServer.cls'
::requires '../integration/NoSQLServerAlgorithmRelationExternalEngine.cls'
::requires '../integration/RichBusinessFactAlgorithmProvider.cls'
::requires '../integration/StructuredRelationRichEvidenceAdapter.cls'
::requires 'EdiFactRelationAdapter.cls'
